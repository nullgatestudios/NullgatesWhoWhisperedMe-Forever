-- Nullgate's Who Whispered Me: smoke test of the whole addon with stand-in game API.
-- Loads the files in .toc order, logs in, takes whispers, runs lookups (answers, the server's
-- cooldown, nobody found, someone else's /who, no answer), drives the window and /nwho check.
-- Run from the repository root:  lua tests/smoke.lua

local source = debug.getinfo(1, "S").source or ""
local script = source:match("^@(.*)$") or "tests/smoke.lua"
local scriptDir = script:match("^(.*)[/\\][^/\\]*$") or "."
local repo = scriptDir:match("^(.*)[/\\][^/\\]*$") or "."
local folder = "NullgatesWhoWhisperedMe-Forever"
local root = repo .. "/" .. folder .. "/"
local write = io.write

local checks, failures = 0, 0
local function OK(cond, name)
    checks = checks + 1
    if not cond then failures = failures + 1; write("FAIL " .. name .. "\n") end
end

-- --- Stand-in game API ----------------------------------------------------------
local frames, printed = {}, {}
local function NewFrame(kind, name, parent, template)
    local f = { kind = kind, name = name, template = template, scripts = {}, attributes = {}, events = {}, shown = false }
    -- Unknown methods (capitalized) are no-ops; unset fields are nil, like real frames
    setmetatable(f, { __index = function(_, key) if type(key) == "string" and key:match("^%u") then return function() return nil end end end })
    function f:SetScript(k, fn) self.scripts[k] = fn end
    function f:GetScript(k) return self.scripts[k] end
    function f:HookScript(k, fn) local old = self.scripts[k]; self.scripts[k] = function(...) if old then old(...) end fn(...) end end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterAllEvents() self.events = {} end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetShown(v) self.shown = v and true or false end
    function f:IsShown() return self.shown end
    function f:SetText(t) self.text = t end
    function f:GetText() return self.text end
    function f:SetChecked(v) self.checked = v and true or false end
    function f:GetChecked() return self.checked end
    function f:SetAlpha(a) self.alpha = a end
    function f:CreateFontString() return NewFrame("FontString") end
    function f:CreateTexture() return NewFrame("Texture") end
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
CreateFrame = NewFrame
SlashCmdList = {}
UISpecialFrames = {}
UIParent = NewFrame("Frame", "UIParent")
function UIParent:GetEffectiveScale() return 1 end
GameTooltip = NewFrame("GameTooltip", "GameTooltip")
FriendsFrame = NewFrame("Frame", "FriendsFrame")
function HideUIPanel(f) f:Hide() end
RAID_CLASS_COLORS = { PRIEST = { r = 1, g = 1, b = 1 }, ROGUE = { r = 1, g = 0.96, b = 0.41 }, WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
LOCALIZED_CLASS_NAMES_MALE = { WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
    SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid" }
print = function(text) printed[#printed + 1] = tostring(text) end
date = os.date
function GetCursorPosition() return 100, 100 end
function GetBuildInfo() return "1.60.1", "71037", "Nov 2026", 16001 end
function GetLocale() return "enUS" end

local clock, wall = 1000, 1700000000
function GetTime() return clock end
time = function() return wall end
local timers = {}
C_Timer = { After = function(seconds, fn) timers[#timers + 1] = { at = clock + seconds, fn = fn } end }
local function RunTimers(upTo)
    local due = {}
    for i = #timers, 1, -1 do if timers[i].at <= upTo then due[#due + 1] = timers[i].fn; table.remove(timers, i) end end
    for _, fn in ipairs(due) do fn() end
end

-- Units, GUIDs, guild and friends.
local units = { player = { name = "Me", level = 60, class = "MAGE", race = "Human" } }
function UnitExists(unit) return units[unit] ~= nil end
function UnitIsPlayer(unit) return units[unit] ~= nil end
function UnitName(unit) return units[unit] and units[unit].name or nil end
function UnitLevel(unit) return units[unit] and units[unit].level or 0 end
function UnitClass(unit) local u = units[unit]; return u and u.class, u and u.class end
function UnitRace(unit) return units[unit] and units[unit].race or nil end
function UnitGUID(unit) return units[unit] and ("Player-" .. units[unit].name) or nil end
function IsInRaid() return false end
function IsInGuild() return false end
function Ambiguate(name) return (name:gsub("%-.*$", "")) end
local guids = { ["Player-Healbot"] = { "Priest", "PRIEST", "Undead", "Scourge" }, ["Player-Stabby"] = { "Rogue", "ROGUE", "Orc", "Orc" } }
function GetPlayerInfoByGUID(guid) local g = guids[guid]; if g then return g[1], g[2], g[3], g[4], 2, "x", "" end end

-- /who: what was sent, and the answer the server will give.
local sent, toUi, whoResults = {}, {}, {}
C_FriendList = {
    SendWho = function(query) sent[#sent + 1] = query end,
    SetWhoToUi = function(on) toUi[#toUi + 1] = on end,
    GetNumWhoResults = function() return #whoResults, #whoResults end,
    GetWhoInfo = function(i) return whoResults[i] end,
    GetNumFriends = function() return 0 end,
    GetFriendInfoByIndex = function() return nil end,
}
local chatFilters = {}
function ChatFrame_AddMessageEventFilter(event, fn) chatFilters[event] = fn end
local told, invited = {}, {}
function ChatFrame_SendTell(name) told[#told + 1] = name end
C_PartyInfo = { InviteUnit = function(name) invited[#invited + 1] = name end }

-- --- Load the files in .toc order -----------------------------------------------
local ns = {}
local toc = assert(io.open(root .. folder .. ".toc", "r")):read("*a")
for line in toc:gmatch("[^\r\n]+") do
    if not line:match("^##") and line:match("%.lua$") then
        assert(loadfile(root .. line:gsub("\\", "/")))(folder, ns)
    end
end
local core
for _, f in ipairs(frames) do if f.events.PLAYER_LOGIN then core = f end end
local function Fire(event, ...) core.scripts.OnEvent(core, event, ...) end
local function Tick(seconds) clock = clock + seconds; wall = wall + seconds; core.scripts.OnUpdate(core, 0.6) end
for _, f in ipairs(frames) do
    if f.events.ADDON_LOADED and f.scripts.OnEvent then f.scripts.OnEvent(f, "ADDON_LOADED", folder) end
end
local db = NullgatesWhoWhisperedMeDB
OK(type(db) == "table" and db.keepMinutes == 15 and db.filters.guild == "any", "saved data gets its defaults")
OK(SLASH_NULLGATESWHOWHISPEREDME1 == "/nwho" and SLASH_NULLGATESWHOWHISPEREDME2 == "/whowhispered", "slash commands /nwho and /whowhispered")
OK(_G["BINDING_NAME_CLICK NullgatesWhoWhisperedMeLookup:LeftButton"] ~= nil, "the Look up next key binding has a name")
OK(core.events.CHAT_MSG_WHISPER and core.events.WHO_LIST_UPDATE, "whispers and /who answers are listened to")

Fire("PLAYER_LOGIN")
local window, lookup = NullgatesWhoWhisperedMeFrame, NullgatesWhoWhisperedMeLookup
OK(window and lookup, "the window and the Look up next button exist at login (for the key binding)")
OK(not window.shown, "the window starts hidden")
OK(chatFilters.CHAT_MSG_SYSTEM ~= nil, "the server's cooldown line can be hidden from chat")

local Roster = ns.Roster
local function Whisper(text, from, guid, flag) wall = wall + 1; Fire("CHAT_MSG_WHISPER", text, from, "", "", from, flag or "", 0, 0, "", 0, 1, guid) end

-- --- Whispers -------------------------------------------------------------------------
Whisper("inv?", "Healbot", "Player-Healbot")
OK(Roster.Count() == 0, "not listening: whispers are not collected")
SlashCmdList.NULLGATESWHOWHISPEREDME("listen on")
OK(db.listening == true and ns.IsListening(), "/nwho listen on starts listening")

Whisper("lf heals? 58 priest", "Healbot-Realm", "Player-Healbot")
local healbot = Roster.Get("Healbot")
OK(healbot ~= nil, "a whisper adds the player, without the realm")
OK(healbot.class == "PRIEST" and healbot.race == "Undead", "class and race come from the whisper's GUID")
OK(healbot.status == "queued" and not healbot.level, "no level known: queued for a lookup")
OK(window.shown, "the window opens on the first whisper")
window.shown = false
Whisper("inv pls", "Stabby", "Player-Stabby")
OK(not window.shown, "it doesn't open again for every whisper")
window:Show()

units.party1 = { name = "Buddy", level = 33, class = "WARRIOR", race = "Orc" }
Whisper("tank here", "Buddy", "Player-Buddy")
local buddy = Roster.Get("Buddy")
OK(buddy.level == 33 and buddy.levelSource == "unit" and buddy.status == "found", "a party member's level is known without a /who")
OK(buddy.roles and buddy.roles.TANK, "the role named in the whisper is kept")

db.seen.oldfriend = { level = 52, class = "HUNTER", at = wall - 3600 }
Whisper("hi again", "Oldfriend", nil)
local old = Roster.Get("Oldfriend")
OK(old.level == 52 and old.levelSource == "memory", "a level remembered from an earlier lookup is used")

Whisper("GM here", "Gamemaster", nil, "GM")
OK(Roster.Get("Gamemaster") == nil, "whispers from a GM are not listed")
OK(Roster.QueueSize(wall) == 2, "two players wait for a lookup")

-- --- Lookups --------------------------------------------------------------------------
FriendsFrame.shown = false
lookup.scripts.OnClick(lookup)
OK(sent[#sent] == 'n-"Stabby"', "Look up next sends one exact-name /who for the newest whisper")
OK(toUi[#toUi] == true, "the answer is sent to the who list, not chat")
local stabby = Roster.Get("Stabby")
OK(stabby.status == "looking", "the player shows as being looked up")
FriendsFrame.shown = true -- the game opened its window for the answer
whoResults = { { fullName = "Stabby", level = 44, filename = "ROGUE", raceStr = "Orc", fullGuildName = "Sipped", area = "Angor Fortress" } }
Fire("WHO_LIST_UPDATE")
OK(stabby.level == 44 and stabby.guild == "Sipped" and stabby.zone == "Angor Fortress" and stabby.status == "found", "the answer fills in level, guild and zone")
OK(FriendsFrame.shown, "the game's window is left until the next frame (it may open after us)")
RunTimers(clock)
OK(not FriendsFrame.shown, "a window the lookup opened is closed again")
OK(db.seen.stabby and db.seen.stabby.level == 44, "the level is remembered for next time")

local before = #sent
lookup.scripts.OnClick(lookup)
OK(#sent == before, "a second click during the cooldown sends nothing")
Tick(5)
lookup.scripts.OnClick(lookup)
OK(sent[#sent] == 'n-"Healbot"', "after the cooldown the next player is looked up")
local hidden = chatFilters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", "You must wait 3 seconds before using /who again.")
OK(hidden == true, "the server's cooldown line is hidden from chat")
Fire("CHAT_MSG_SYSTEM", "You must wait 3 seconds before using /who again.")
OK(healbot.status == "queued" and healbot.tries == 0, "a lookup the server refused goes back in the queue, not counted")
OK(math.ceil(ns.Who.Wait(clock)) == 3, "the wait the server named is used")
local other = chatFilters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", "Telaviv Steve has gone offline.")
OK(other == false, "other system lines are left alone")

Tick(3)
lookup.scripts.OnClick(lookup)
whoResults = {}
Fire("WHO_LIST_UPDATE")
OK(healbot.status == "notfound" and healbot.tries == 1, "nobody found: Not found")
OK(Roster.QueueSize(wall) == 0, "not retried at once")

Whisper("lfg?", "Quiet", nil)
Tick(5)
lookup.scripts.OnClick(lookup)
OK(sent[#sent] == 'n-"Quiet"', "the next new whisper is looked up")
whoResults = { { fullName = "Someone", level = 20 }, { fullName = "Else", level = 21 } }
Fire("WHO_LIST_UPDATE")
OK(Roster.Get("Quiet").status == "queued", "an answer without our player (a /who you typed) puts them back in the queue")

Tick(5)
lookup.scripts.OnClick(lookup)
OK(Roster.Get("Quiet").status == "looking", "looked up again")
Tick(6)
OK(Roster.Get("Quiet").status == "queued", "no answer within 5 seconds: back in the queue")
OK(table.concat(db.lookups, "\n"):find("no answer after", 1, true) ~= nil, "lookups are recorded for /nwho check")

Tick(Roster.RETRY_SECONDS)
OK(Roster.QueueSize(wall) == 2, "after a while, a player who wasn't found waits for one more try")

-- --- The window -----------------------------------------------------------------------
local rows = {}
for _, f in ipairs(frames) do if f.cells then rows[#rows + 1] = f end end
OK(#rows == 16, "16 rows")
ns.UI.Refresh()
local function RowNames()
    local out = {}
    for _, row in ipairs(rows) do if row.shown and row.entry then out[#out + 1] = row.entry.name end end
    return table.concat(out, ",")
end
OK(RowNames() == "Quiet,Oldfriend,Stabby,Healbot,Buddy", "newest whisper first, the party member last")
local stabbyRow
for _, row in ipairs(rows) do if row.entry == stabby then stabbyRow = row end end
OK(stabbyRow.cells.level.text:find("44", 1, true) and stabbyRow.cells.armor.text:find("Leather", 1, true), "a row shows level and armor")
OK(stabbyRow.cells.status.text:find("Found", 1, true) ~= nil, "a row shows the status")

db.filters.levels = "40-55"
db.filters.hideUnknown = true
ns.UI.Refresh()
OK(RowNames() == "Oldfriend,Stabby", "the level filter with Hide unknown levels")
db.filters.levels, db.filters.hideUnknown = "", false
db.filters.classes.PRIEST = true
ns.UI.Refresh()
OK(RowNames() == "Quiet,Healbot", "a class filter: the priest, and Quiet whose class is unknown")
db.filters.classes.PRIEST = nil

local levelHeader
for _, f in ipairs(frames) do if f.col and f.col.key == "level" then levelHeader = f end end
levelHeader.scripts.OnClick(levelHeader)
ns.UI.Refresh()
OK(db.sort[1].key == "level" and db.sort[1].desc == true and RowNames() == "Oldfriend,Stabby,Healbot,Quiet,Buddy", "a header click sorts by level, highest first")

stabbyRow = nil
for _, row in ipairs(rows) do if row.entry == stabby then stabbyRow = row end end
stabbyRow.scripts.OnClick(stabbyRow, "LeftButton")
OK(told[#told] == "Stabby", "a click whispers the player")
stabbyRow.scripts.OnDoubleClick(stabbyRow)
OK(invited[#invited] == "Stabby", "a double-click invites them")
stabbyRow.scripts.OnClick(stabbyRow, "RightButton")
local menu = NullgatesWhoWhisperedMeMenu
OK(menu and menu.shown and menu.entry == stabby, "a right-click opens the menu")
local dismiss
for _, f in ipairs(frames) do if f.text == "Dismiss" then dismiss = f end end
dismiss.scripts.OnClick(dismiss)
OK(Roster.Get("Stabby") == nil and not menu.shown, "Dismiss removes the player")

-- --- Listening stops ------------------------------------------------------------------
SlashCmdList.NULLGATESWHOWHISPEREDME("listen off")
OK(not ns.IsListening() and Roster.Count() == 4, "stopping keeps the list for now")
RunTimers(clock + 14 * 60)
OK(Roster.Count() == 4, "still there after 14 minutes")
RunTimers(clock + 15 * 60)
OK(Roster.Count() == 0, "cleared 15 minutes after listening stopped")
SlashCmdList.NULLGATESWHOWHISPEREDME("listen on")
SlashCmdList.NULLGATESWHOWHISPEREDME("listen off")
SlashCmdList.NULLGATESWHOWHISPEREDME("listen on")
Whisper("hello", "Late", nil)
RunTimers(clock + 60 * 60)
OK(Roster.Get("Late") ~= nil, "listening again cancels the pending clear")

-- Forever names: a first name and a surname (UnitName returns them apart; NameUtil joins them).
NameUtil = { FormatUnitNameForDisplay = function(unit)
    local u = units[unit]
    return u and (u.surname and (u.name .. " " .. u.surname) or u.name)
end }
units.player.name, units.player.surname = "Herald", "Talenel"
OK(ns.Safe.UnitFullName("player") == "Herald Talenel", "a unit's full name includes the surname")
Whisper("self test", "Herald Talenel", nil)
OK(Roster.Get("Herald Talenel") == nil, "your own whisper is ignored by full name")
Whisper("lf heals", "Nocturne Nolastname", nil)
Tick(5)
lookup.scripts.OnClick(lookup)
OK(sent[#sent] == 'n-"Nocturne Nolastname"', "a name with a surname is looked up whole")
whoResults = { { fullName = "Nocturne Other", level = 10 }, { fullName = "Nocturne Nolastname", level = 44, filename = "ROGUE" } }
Fire("WHO_LIST_UPDATE")
OK(Roster.Get("Nocturne Nolastname").level == 44, "the exact full name is picked among similar names")
Whisper("hi", "Kicknazz", nil)
Tick(5)
lookup.scripts.OnClick(lookup)
whoResults = { { fullName = "Kicknazz Takennames", level = 60, filename = "DRUID" }, { fullName = "Someone Else", level = 3 } }
Fire("WHO_LIST_UPDATE")
OK(Roster.Get("Kicknazz").level == 60, "a first name alone matches the one result with that first name")
Whisper("yo", "Blocky", nil)
Tick(5)
lookup.scripts.OnClick(lookup)
Fire("ADDON_ACTION_BLOCKED", folder, "UNKNOWN()")
OK(Roster.Get("Blocky").status == "queued" and Roster.Get("Blocky").tries == 0 and ns.Who.Ready(clock),
    "a blocked /who goes straight back in the queue, ready to try again")
units.player.surname = nil
units.player.name = "Me"

-- Listing a group in the group finder listens by itself.
SlashCmdList.NULLGATESWHOWHISPEREDME("listen off")
local isListed = false
C_LFGList = { HasActiveEntryInfo = function() return isListed end }
isListed = true
Fire("LFG_LIST_ACTIVE_ENTRY_UPDATE")
OK(ns.IsListening() and ns.IsListed() and db.listening == false, "a listed group listens without the switch")
isListed = false
Fire("LFG_LIST_ACTIVE_ENTRY_UPDATE")
OK(not ns.IsListening(), "delisting stops listening")
SlashCmdList.NULLGATESWHOWHISPEREDME("listen on")

-- --- Settings and /nwho check ----------------------------------------------------------
SlashCmdList.NULLGATESWHOWHISPEREDME("options")
OK(NullgatesWhoWhisperedMeOptions and NullgatesWhoWhisperedMeOptions.shown, "/nwho options opens the settings")
SlashCmdList.NULLGATESWHOWHISPEREDME("check")
do -- the report window every Nullgate addon shares
    local w = NullgateReportWindow
    OK(w and w.shown and w.url == "https://nullgatestudios.com/report?addon=who-whispered-me", "check opens the shared report window with this addon's link")
    OK(w and w.text and w.text:find("Addon: who-whispered-me\nNullgate's Who Whispered Me - Forever ", 1, true) == 1, "the report starts with the addon's slug and name")
    OK(w and w.box.text == w.text and w.link.text == w.url, "the report and the link are in the window, ready to copy")
end
local text = table.concat(db.check or {}, "\n")
OK(text:find("C_FriendList.SendWho=yes", 1, true) ~= nil, "check reports which calls exist")
OK(text:find("earlier: ", 1, true) ~= nil, "check includes the recent lookups")
OK(NullgatesWhoWhisperedMeCheck and NullgatesWhoWhisperedMeCheck.shown, "the check window opens")

io.write(string.format("smoke: %d checks, %d failure(s)\n", checks, failures))
if failures > 0 then os.exit(1) end
