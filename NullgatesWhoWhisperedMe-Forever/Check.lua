-- Nullgate's Who Whispered Me: /nwho check, the in-game self test. It records what the
-- addon depends on in this client to chat and to NullgatesWhoWhisperedMeDB.check, then
-- opens the bug report window every Nullgate addon shares. Its buttons test:
--   1. a /who from a click (the game allows it),
--   2. a /who from a timer (the game should drop it: nothing comes back),
--   3. adding your target to the list as if they had whispered you.
local _, ns = ...

local Check = {}
ns.Check = Check

local LOG_LIMIT = 400
local panel

local function Log(text)
    local db = NullgatesWhoWhisperedMeDB
    if db then
        db.check = db.check or {}
        local log = db.check
        if #log >= LOG_LIMIT then table.remove(log, 1) end
        log[#log + 1] = text
    end
    print("|cff00c0ffNullgate's Who Whispered Me check:|r " .. text)
    if NullgateReport then NullgateReport.Update("who-whispered-me") end
end
Check.Log = Log

function Check.IsOpen() return panel ~= nil and panel:IsShown() end

-- Opens the report window every Nullgate addon shares (NullgateReport.lua) with this check's log.
function Check.ShowReport()
    local L = ns.L
    return NullgateReport.Show({
        slug = "who-whispered-me", name = "Nullgate's Who Whispered Me", addon = "NullgatesWhoWhisperedMe-Forever",
        command = "/nwho check",
        lines = function() return NullgatesWhoWhisperedMeDB and NullgatesWhoWhisperedMeDB.check end,
        title = L["Bug report"], selectAll = L["Select all"], selectLink = L["Select link"],
        help = L["Press Ctrl+C to copy this report, then paste it into a new report at the link below, with a few words on what happened."],
    })
end

local function Exists(path)
    local value = _G
    for part in path:gmatch("[^.]+") do
        if type(value) ~= "table" then return false end
        value = value[part]
    end
    return type(value) == "function"
end

local function StaticChecks()
    local db = ns.db
    Log(string.format("client %s, build %s, interface %s; locale %s; addon language %s",
        tostring(GetBuildInfo and select(1, GetBuildInfo())), tostring(GetBuildInfo and select(2, GetBuildInfo())),
        tostring(GetBuildInfo and select(4, GetBuildInfo())), tostring(GetLocale and GetLocale()), tostring(ns.ActiveLanguage())))
    local calls = {}
    for _, name in ipairs({ "C_FriendList.SendWho", "SendWho", "C_FriendList.SetWhoToUi", "C_FriendList.GetNumWhoResults",
        "C_FriendList.GetWhoInfo", "GetWhoInfo", "GetPlayerInfoByGUID", "Ambiguate", "C_LFGList.HasActiveEntryInfo",
        "ChatFrame_SendTell", "C_PartyInfo.InviteUnit", "InviteUnit", "GetGuildRosterInfo",
        "C_FriendList.GetFriendInfoByIndex", "issecretvalue", "ChatFrame_AddMessageEventFilter" }) do
        calls[#calls + 1] = name .. "=" .. (Exists(name) and "yes" or "no")
    end
    Log("calls: " .. table.concat(calls, " "))
    Log(string.format("listening %s (setting %s, group listed %s); %d on the list, %d waiting for a lookup; %d remembered",
        tostring(ns.IsListening()), tostring(db.listening), tostring(ns.IsListed()), ns.Roster.Count(),
        ns.Roster.QueueSize(time()), (function() local n = 0; for _ in pairs(db.seen) do n = n + 1 end; return n end)()))
    for _, line in ipairs(db.lookups or {}) do Log("earlier: " .. line) end
end

-- A lookup that isn't on the list: yourself.
local function SelfEntry()
    return { name = ns.Safe.UnitFullName("player") or "?", tries = 0, count = 0, status = "queued", test = true, time = time() }
end

local function Button(label, y, onClick)
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetSize(270, 22)
    button:SetPoint("TOP", panel, "TOP", 0, y)
    button:SetText(label)
    button:SetScript("OnClick", onClick)
    return button
end

local function BuildPanel()
    panel = CreateFrame("Frame", "NullgatesWhoWhisperedMeCheck", UIParent, "BasicFrameTemplateWithInset")
    panel:SetSize(300, 170)
    panel:SetPoint("TOPLEFT", NullgateReport.Frame(), "TOPRIGHT", 4, 0)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    local title = "Who Whispered Me check"
    if type(panel.SetTitle) == "function" then panel:SetTitle(title)
    elseif type(panel.TitleText) == "table" then panel.TitleText:SetText(title) end

    Button("1. Look yourself up (a click)", -34, function()
        local now = GetTime()
        if not ns.Who.Ready(now) then
            Log("test 1: not ready yet, wait " .. math.ceil(ns.Who.Wait(now)) .. "s and click again")
            return
        end
        ns.Who.Send(SelfEntry(), now)
        Log("test 1: sent a /who from a click; the answer follows")
    end)
    Button("2. Look yourself up from a timer", -62, function()
        Log("test 2: a /who will be sent in 1 second from a timer (no click)")
        C_Timer.After(1, function()
            if not ns.Who.Ready(GetTime()) then
                Log("test 2: not ready yet (cooldown); click again in a few seconds")
                return
            end
            ns.Who.Send(SelfEntry(), GetTime())
            Log("test 2: sent; if no answer comes within 5 seconds, the game blocked it")
        end)
    end)
    Button("3. Add your target to the list", -90, function()
        local name = ns.Safe.UnitFullName("target")
        if not (name and UnitIsPlayer("target")) then
            Log("test 3: target a player first")
            return
        end
        ns.AddWhisper(name, "(test) added by /nwho check", UnitGUID and UnitGUID("target"), true)
        local entry = ns.Roster.Get(name)
        Log(string.format("test 3: %s added: class %s, race %s, level %s (%s), status %s", name, tostring(entry.class),
            tostring(entry.race), tostring(entry.level), tostring(entry.levelSource), entry.status))
        ns.UI.Show()
    end)
    local note = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("BOTTOM", panel, "BOTTOM", 0, 14)
    note:SetWidth(270)
    note:SetText("Results go to chat and are saved. Wait 5 seconds between tests 1 and 2.")
end

-- Every blocked action is logged while the check is open.
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_ACTION_BLOCKED")
watcher:RegisterEvent("ADDON_ACTION_FORBIDDEN")
watcher:SetScript("OnEvent", function(_, event, a, b)
    if Check.IsOpen() then Log(event .. ": " .. tostring(a) .. " tried " .. tostring(b)) end
end)

function Check.Run()
    if NullgatesWhoWhisperedMeDB then NullgatesWhoWhisperedMeDB.check = {} end
    StaticChecks()
    if not panel then BuildPanel() end
    panel:Show()
    Log("now click the buttons in the check window")
    Check.ShowReport()
end
