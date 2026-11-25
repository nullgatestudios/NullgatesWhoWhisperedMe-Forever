-- Nullgate's Who Whispered Me: /who lookups. The game only sends a /who from a key press or
-- mouse click (tested in Forever: one sent from a timer is dropped silently), so Who.Send is
-- only ever called from a button's OnClick or its key binding. The server also has a short
-- cooldown; a /who sent too soon is answered with "You must wait N seconds before using
-- /who again", which we read to know when the next one may go.
local _, ns = ...

local Safe, Roster, Sources = ns.Safe, ns.Roster, ns.Sources

local Who = {}
ns.Who = Who

Who.COOLDOWN = 5 -- seconds we wait between our own lookups
Who.TIMEOUT = 5  -- no answer after this long: the player goes back in the queue
-- Frames the game may open to show /who results; one our lookup opened is closed again.
Who.POPUPS = { "FriendsFrame", "WhoFrame", "LFGParentFrame", "LFGBrowseFrame", "LFGFrame", "LookingForGroupFrame" }

local pending       -- { entry, at, shown } while a lookup waits for its answer
local readyAt = 0   -- GetTime() when the next lookup may be sent
local hideText, hideUntil -- the server's "must wait" line, hidden from chat

-- Records a line about a lookup (kept for /nwho check); Core replaces it.
Who.Log = function(_) end

local function Api(name)
    local list = C_FriendList
    return (list and list[name]) or _G[name]
end

function Who.Available()
    return type(Api("SendWho")) == "function"
end

function Who.Pending()
    return pending and pending.entry or nil
end

-- Seconds until the next lookup may be sent (0 = now).
function Who.Wait(now)
    return math.max(0, readyAt - now)
end

function Who.Ready(now)
    return Who.Available() and not pending and Who.Wait(now) <= 0
end

local function ShownPopups()
    local shown = {}
    for _, name in ipairs(Who.POPUPS) do
        local frame = _G[name]
        if type(frame) == "table" and frame.IsShown and frame:IsShown() then shown[name] = true end
    end
    return shown
end

local function SetWhoToUi(on)
    local fn = Api("SetWhoToUi") or _G.SetWhoToUI
    if type(fn) == "function" then pcall(fn, on) end
end

-- Sends one /who for the entry. Call only from a click or key binding.
function Who.Send(entry, now)
    if not entry or not Who.Ready(now) then return false end
    SetWhoToUi(true) -- answers go to the who list, not to chat
    pending = { entry = entry, at = now, shown = ShownPopups() }
    readyAt = now + Who.COOLDOWN
    entry.status = "looking"
    entry.tries = (entry.tries or 0) + 1
    local ok, err = pcall(Api("SendWho"), 'n-"' .. entry.name .. '"')
    if not ok then
        pending = nil
        entry.status = "queued"
        Who.Log("lookup " .. entry.name .. ": error " .. tostring(err))
        return false
    end
    Who.Log("lookup " .. entry.name .. ": sent")
    return true
end

local function Short(name)
    return name and (name:match("^([^%-]+)") or name)
end

local function Result(i)
    local list = C_FriendList
    if list and list.GetWhoInfo then
        local ok, info = pcall(list.GetWhoInfo, i)
        if not ok or type(info) ~= "table" then return nil end
        return { name = Safe.Str(info.fullName), level = Safe.Level(info.level), class = Safe.Str(info.filename),
            race = Safe.Str(info.raceStr), guild = Safe.Str(info.fullGuildName) or "", zone = Safe.Str(info.area) }
    end
    if type(GetWhoInfo) == "function" then
        local ok, name, guildName, level, race, _, zone, classFile = pcall(GetWhoInfo, i)
        if not ok then return nil end
        return { name = Safe.Str(name), level = Safe.Level(level), class = Safe.Str(classFile), race = Safe.Str(race),
            guild = Safe.Str(guildName) or "", zone = Safe.Str(zone) }
    end
    return nil
end

-- Closes a results window that opened because of our lookup.
local function ClosePopups(before)
    for _, name in ipairs(Who.POPUPS) do
        local frame = _G[name]
        if not before[name] and type(frame) == "table" and frame.IsShown and frame:IsShown() then
            if type(HideUIPanel) == "function" then pcall(HideUIPanel, frame) else frame:Hide() end
            Who.Log("closed " .. name .. ", which our lookup opened")
        end
    end
end

-- WHO_LIST_UPDATE: the answer to a /who.
function Who.OnResults(now, wallNow)
    if not pending then return end
    local entry, before = pending.entry, pending.shown
    pending = nil
    SetWhoToUi(false)
    local count = Api("GetNumWhoResults")
    local n = (type(count) == "function" and tonumber((count()))) or 0
    -- An exact full name wins. A name without a surname (a client or source that only gave
    -- the first name) matches a "First Surname" result only when that first name is unique.
    local want, sep = Roster.Key(Short(entry.name)), Safe.SurnameSeparator()
    local match, firstOnly, firstCount = nil, nil, 0
    for i = 1, n do
        local info = Result(i)
        local got = info and info.name and Roster.Key(Short(info.name))
        if got == want then match = info end
        if got and not want:find(sep, 1, true) then
            local first = got:match("^(.-)" .. (sep:gsub("%p", "%%%0")))
            if first == want then firstOnly, firstCount = info, firstCount + 1 end
        end
    end
    if not match and firstCount == 1 then
        match = firstOnly
    end
    -- Forever's group finder opens its Who tab on this same event, maybe after us: look a frame later.
    if C_Timer and C_Timer.After then C_Timer.After(0, function() ClosePopups(before) end) else ClosePopups(before) end
    if match then
        entry.status = "found"
        Roster.SetInfo(entry, match, "who", wallNow)
        Sources.Remember(entry, wallNow)
        Who.Log(string.format("lookup %s: found, level %s %s, guild '%s', zone %s", entry.name, tostring(match.level),
            tostring(match.class), match.guild or "", tostring(match.zone)))
    elseif n == 0 then
        Roster.NotFound(entry, wallNow)
        Who.Log("lookup " .. entry.name .. ": nobody found (offline?)")
    else
        -- Results without our player answer a /who someone typed: try ours again later.
        entry.status = "queued"
        entry.tries = entry.tries - 1
        Who.Log(string.format("lookup %s: %d results without them (a /who you typed?), queued again", entry.name, n))
    end
end

-- The server's cooldown line: it names the /who command and a number of seconds, and
-- comes right after our lookup.
local function IsWaitLine(text, now)
    return pending ~= nil and now - pending.at <= 3 and text:find("/", 1, true) ~= nil and text:find("%d") ~= nil
end

-- A system chat line. Returns true when it is the server's cooldown answer to our lookup,
-- which is hidden from chat (the chat filter and the event both call this).
function Who.OnSystemMessage(text, now)
    text = Safe.Str(text)
    if not text then return false end
    if hideText == text and now <= hideUntil then return true end
    if not IsWaitLine(text, now) then return false end
    local entry = pending.entry
    pending = nil
    SetWhoToUi(false)
    local seconds = tonumber(text:match("(%d+)")) or Who.COOLDOWN
    readyAt = now + seconds
    entry.status = "queued"
    entry.tries = entry.tries - 1
    hideText, hideUntil = text, now + 2
    Who.Log("lookup " .. entry.name .. ": the server asked to wait " .. seconds .. "s (" .. text .. ")")
    return true
end

-- ADDON_ACTION_BLOCKED for this addon right after a send: the game refused the /who (it
-- didn't come from a click), so the player goes straight back in the queue.
function Who.OnBlocked(now)
    if not pending or now - pending.at > 2 then return false end
    local entry = pending.entry
    pending = nil
    SetWhoToUi(false)
    readyAt = now
    entry.status = "queued"
    entry.tries = entry.tries - 1
    Who.Log("lookup " .. entry.name .. ": blocked by the game (it must come from a click or key press)")
    return true
end

-- Called twice a second: a lookup with no answer goes back in the queue.
function Who.Tick(now)
    if pending and now - pending.at > Who.TIMEOUT then
        local entry = pending.entry
        pending = nil
        SetWhoToUi(false)
        if entry.status == "looking" then entry.status = "queued" end
        entry.tries = entry.tries - 1
        Who.Log("lookup " .. entry.name .. ": no answer after " .. Who.TIMEOUT .. "s (blocked by the game, or lost)")
        return true
    end
    return false
end

-- Sends the next queued lookup (the Look up next button and its key binding).
function Who.Next(now, wallNow)
    local entry = Roster.Next(wallNow)
    if not entry then return false end
    return Who.Send(entry, now)
end
