-- Nullgate's Who Whispered Me: saved data, events, listening and slash commands.
local addonName, ns = ...

local L = ns.L
local Safe, Roster, Sources, Who = ns.Safe, ns.Roster, ns.Sources, ns.Who

local LOOKUP_LOG = 40 -- lookup lines kept for /nwho check

ns.DEFAULTS = {
    listening = false,
    autoOpen = true,
    keepMinutes = 15,
    memoryHours = 24,
    language = "auto",
    filters = { classes = {}, levels = "", armor = {}, roles = {}, guild = "any", text = "",
        hideUnknown = false, hideNotFound = false },
    sort = { { key = "time", desc = true } },
    seen = {},
    lookups = {},
    window = {},
}

local function Merge(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            if key ~= "sort" or not target[key][1] then Merge(target[key], value) end
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

function ns.Print(text)
    print("|cff00c0ffWho Whispered Me:|r " .. tostring(text))
end

Who.Log = function(text)
    local log = ns.db and ns.db.lookups
    if log then
        if #log >= LOOKUP_LOG then table.remove(log, 1) end
        log[#log + 1] = date("%H:%M:%S ") .. text
    end
    if ns.Check and ns.Check.IsOpen() then ns.Check.Log(text) end
end

-- --- Listening ------------------------------------------------------------------------
-- Whispers are collected while the Listening switch is on, or while your group is listed
-- in a group finder that addons can see (C_LFGList, when the client has it).

local listed = false
local openedThisTime = false
local clearToken = 0

local function ReadListed()
    local lfg = C_LFGList
    if lfg and type(lfg.HasActiveEntryInfo) == "function" then
        local ok, active = pcall(lfg.HasActiveEntryInfo)
        return ok and active == true
    end
    return false
end

function ns.IsListed() return listed end
function ns.IsListening() return (ns.db and ns.db.listening) or listed end

-- When listening stops, the list is kept for a while (a quick relist keeps it), then cleared.
local function ListeningChanged(wasListening)
    local now = ns.IsListening()
    if now == wasListening then return end
    clearToken = clearToken + 1
    if now then
        openedThisTime = false
        ns.Print(L["Listening for whispers."])
    else
        local token = clearToken
        ns.Print(string.format(L["Stopped listening. The list clears in %d minutes."], ns.db.keepMinutes))
        C_Timer.After(ns.db.keepMinutes * 60, function()
            if token == clearToken and not ns.IsListening() then Roster.Clear(); ns.UI.Refresh() end
        end)
    end
    ns.UI.Refresh()
end

function ns.SetListening(on)
    local was = ns.IsListening()
    ns.db.listening = on and true or false
    ListeningChanged(was)
end

local function UpdateListed()
    local was = ns.IsListening()
    listed = ReadListed()
    ListeningChanged(was)
end

-- Adds a whisper to the list and fills in what's known. force = add even when not listening
-- (the /nwho check test).
function ns.AddWhisper(name, message, guid, force)
    if not (force or ns.IsListening()) then return end
    local now = time()
    local entry, isNew = Roster.Whisper(name, message or "", now, Safe.Str(guid))
    if isNew then
        if not Sources.Fill(entry, now) then Roster.Queue(entry) end
        if ns.db.autoOpen and not openedThisTime and not force then
            openedThisTime = true
            ns.UI.Show()
        end
    end
    ns.UI.Refresh()
end

local function OnWhisper(message, sender, _, _, _, flag, _, _, _, _, _, guid)
    if not ns.IsListening() then return end
    if Safe.Str(flag) == "GM" then return end
    local name = Safe.Name(sender)
    if not name or name == UnitName("player") then return end
    ns.AddWhisper(name, Safe.Str(message), guid)
end

-- The server's "must wait" answer to our /who is hidden from chat.
local function SystemFilter(_, _, message, ...)
    if Who.OnSystemMessage(message, GetTime()) then
        ns.UI.Refresh()
        return true
    end
    return false, message, ...
end

-- Key binding names (Bindings.xml), set once the language is known.
BINDING_HEADER_NULLGATESWHOWHISPEREDME = "Nullgate's Who Whispered Me"
local function NameBindings()
    _G["BINDING_NAME_CLICK NullgatesWhoWhisperedMeLookup:LeftButton"] = L["Look up the next player"]
    _G["BINDING_NAME_NULLGATESWHOWHISPEREDME_TOGGLE"] = L["Open or close the window"]
end

-- --- Events -----------------------------------------------------------------------------

local events = CreateFrame("Frame")

local function OnEvent(_, event, ...)
    local arg1 = ...
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            if type(NullgatesWhoWhisperedMeDB) ~= "table" then NullgatesWhoWhisperedMeDB = {} end
            Merge(NullgatesWhoWhisperedMeDB, ns.DEFAULTS)
            ns.db = NullgatesWhoWhisperedMeDB
            ns.SetLanguage(ns.db.language)
            NameBindings()
            Sources.Prune(time())
        end
        if arg1 == addonName or arg1 == "NullgatesAddonConfig-Forever" then ns.Options.RegisterHub() end
    elseif event == "PLAYER_LOGIN" then
        ns.UI.Create()
        listed = ReadListed()
        if type(ChatFrame_AddMessageEventFilter) == "function" then
            ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", SystemFilter)
        end
        Sources.RefreshFriends()
        Sources.RefreshGuild()
    elseif event == "CHAT_MSG_WHISPER" then
        OnWhisper(...)
    elseif event == "WHO_LIST_UPDATE" then
        Who.OnResults(GetTime(), time())
        ns.UI.Refresh()
    elseif event == "CHAT_MSG_SYSTEM" then
        if Who.OnSystemMessage(arg1, GetTime()) then ns.UI.Refresh() end
    elseif event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
        UpdateListed()
    elseif event == "GUILD_ROSTER_UPDATE" then
        Sources.RefreshGuild()
        Sources.Update(time())
        ns.UI.Refresh()
    elseif event == "FRIENDLIST_UPDATE" then
        Sources.RefreshFriends()
        Sources.Update(time())
        ns.UI.Refresh()
    elseif event == "GROUP_ROSTER_UPDATE" then
        Sources.Update(time())
        ns.UI.Refresh()
    elseif event == "PLAYER_TARGET_CHANGED" then
        if Sources.FromUnit("target") then ns.UI.Refresh() end
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        if Sources.FromUnit("mouseover") then ns.UI.Refresh() end
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        if Sources.FromUnit(arg1) then ns.UI.Refresh() end
    end
end

events:SetScript("OnEvent", OnEvent)
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "CHAT_MSG_WHISPER", "WHO_LIST_UPDATE", "CHAT_MSG_SYSTEM",
    "LFG_LIST_ACTIVE_ENTRY_UPDATE", "GUILD_ROSTER_UPDATE", "FRIENDLIST_UPDATE", "GROUP_ROSTER_UPDATE",
    "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED" }) do
    pcall(events.RegisterEvent, events, event) -- an event this client doesn't have is skipped
end

-- Twice a second: lookups with no answer go back in the queue, and the open window updates.
local elapsed = 0
events:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.5 then return end
    elapsed = 0
    if Who.Tick(GetTime()) then ns.UI.Refresh() end
    ns.UI.Tick()
end)

-- --- Slash commands ------------------------------------------------------------------------

local function Help()
    ns.Print(L["commands:"])
    print("  /nwho - " .. L["open or close the window"])
    print("  /nwho listen [on|off] - " .. L["start or stop listening for whispers"])
    print("  /nwho clear - " .. L["clear the list"])
    print("  /nwho options - " .. L["open the settings"])
    print("  /nwho check - " .. L["test the addon in this client and open a bug report to copy"])
end

SLASH_NULLGATESWHOWHISPEREDME1 = "/nwho"
SLASH_NULLGATESWHOWHISPEREDME2 = "/whowhispered"
SlashCmdList["NULLGATESWHOWHISPEREDME"] = function(msg)
    local command, rest = string.lower(msg or ""):match("^%s*(%S*)%s*(%S*)")
    if command == "" then
        ns.UI.Toggle()
    elseif command == "listen" then
        if rest == "on" then ns.SetListening(true)
        elseif rest == "off" then ns.SetListening(false)
        else ns.SetListening(not ns.db.listening) end
    elseif command == "clear" then
        Roster.Clear()
        ns.UI.Refresh()
    elseif command == "options" or command == "config" then
        ns.Options.Open()
    elseif command == "check" then
        ns.Check.Run()
    else
        Help()
    end
end
