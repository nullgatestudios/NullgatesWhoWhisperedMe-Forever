-- Nullgate's Who Whispered Me: everything that tells us a player's class and level without
-- a /who: the whisper's GUID, your group, target, mouseover and nameplates, your guild and
-- friends lists, and levels remembered from earlier lookups.
local _, ns = ...

local Safe, Data, Roster = ns.Safe, ns.Data, ns.Roster

local Sources = {}
ns.Sources = Sources

local guild, friends = {}, {} -- lowercase name -> { level, class, zone, guild }

local function Now() return time() end

-- Class token and race from the whisper's GUID (no lookup needed).
function Sources.FromGUID(guid)
    if not Safe.Str(guid) or type(GetPlayerInfoByGUID) ~= "function" then return nil end
    local ok, _, class, race = pcall(GetPlayerInfoByGUID, guid)
    if not ok then return nil end
    return Safe.Str(class), Safe.Str(race)
end

-- Remembers what we learned, so the same player is known next time without a /who.
function Sources.Remember(entry, at)
    local db = ns.db
    if not (db and entry.level) or entry.test then return end
    db.seen[Roster.Key(entry.name)] = { level = entry.level, class = entry.class, race = entry.race,
        guild = entry.guild, at = at or Now() }
end

-- Drops remembered players older than the memory setting.
function Sources.Prune(now)
    local db = ns.db
    if not db then return end
    local limit = (db.memoryHours or 24) * 3600
    for key, seen in pairs(db.seen) do
        if type(seen) ~= "table" or not seen.at or (now - seen.at) > limit then db.seen[key] = nil end
    end
end

local function Apply(entry, info, source, at)
    Roster.SetInfo(entry, info, source, at)
    if source ~= "memory" then Sources.Remember(entry, at) end
end

-- What a unit token shows about a player: name and info, or nil.
local function UnitInfo(unit)
    if not (UnitExists(unit) and UnitIsPlayer(unit)) then return nil end
    local name = Safe.Name((UnitName(unit)))
    if not name then return nil end
    local _, class = UnitClass(unit)
    local info = { level = Safe.Level(UnitLevel(unit)), class = Safe.Str(class) }
    if type(UnitRace) == "function" then info.race = Safe.Str((UnitRace(unit))) end
    return name, info
end

-- A unit that may be someone on the list (target, mouseover, nameplate, group member).
function Sources.FromUnit(unit, now)
    local ok, name, info = pcall(UnitInfo, unit)
    if not ok or not name then return false end
    local entry = Roster.Get(name)
    if not entry then return false end
    Apply(entry, info, "unit", now or Now())
    return true
end

local function GroupUnits()
    local units = {}
    if IsInRaid and IsInRaid() then
        for i = 1, 40 do units[#units + 1] = "raid" .. i end
    else
        for i = 1, 4 do units[#units + 1] = "party" .. i end
    end
    return units
end

local LOOK_AT = { "target", "focus", "mouseover" }

-- Every unit we can see right now.
local function VisibleUnits()
    local units = GroupUnits()
    for _, unit in ipairs(LOOK_AT) do units[#units + 1] = unit end
    for i = 1, 40 do units[#units + 1] = "nameplate" .. i end
    return units
end

-- Whether the player is in your party or raid.
function Sources.InGroup(name)
    local key = Roster.Key(name)
    for _, unit in ipairs(GroupUnits()) do
        if UnitExists(unit) then
            local ok, unitName = pcall(UnitName, unit)
            local short = ok and Safe.Name(unitName)
            if short and Roster.Key(short) == key then return true end
        end
    end
    return false
end

function Sources.RefreshGuild()
    guild = {}
    if not (IsInGuild and IsInGuild()) or type(GetGuildRosterInfo) ~= "function" then return end
    local guildName = GetGuildInfo and Safe.Str((GetGuildInfo("player"))) or nil
    for i = 1, (GetNumGuildMembers and GetNumGuildMembers() or 0) do
        local ok, name, _, _, level, _, zone, _, _, _, _, classFile = pcall(GetGuildRosterInfo, i)
        name = ok and Safe.Name(name)
        if name then
            guild[Roster.Key(name)] = { level = Safe.Level(level), class = Safe.Str(classFile), zone = Safe.Str(zone), guild = guildName }
        end
    end
end

function Sources.RefreshFriends()
    friends = {}
    local list = C_FriendList
    if not (list and list.GetNumFriends and list.GetFriendInfoByIndex) then return end
    for i = 1, (list.GetNumFriends() or 0) do
        local ok, info = pcall(list.GetFriendInfoByIndex, i)
        local name = ok and type(info) == "table" and Safe.Name(info.name)
        if name and info.connected then
            friends[Roster.Key(name)] = { level = Safe.Level(info.level), class = Data.ClassToken(Safe.Str(info.className)),
                zone = Safe.Str(info.area) }
        end
    end
end

-- Fills in everything known without a /who. Returns true when the level is known.
function Sources.Fill(entry, now)
    now = now or Now()
    if entry.guid and not entry.class then
        local class, race = Sources.FromGUID(entry.guid)
        entry.class, entry.race = class or entry.class, race or entry.race
    end
    local key = Roster.Key(entry.name)
    for _, unit in ipairs(VisibleUnits()) do
        if UnitExists(unit) then
            local ok, name, info = pcall(UnitInfo, unit)
            if ok and name and Roster.Key(name) == key then
                Apply(entry, info, "unit", now)
                if entry.level then return true end
            end
        end
    end
    if guild[key] then Apply(entry, guild[key], "guild", now) end
    if friends[key] and not entry.level then Apply(entry, friends[key], "friend", now) end
    local seen = ns.db and ns.db.seen[key]
    if seen and not entry.level then Roster.SetInfo(entry, seen, "memory", seen.at) end
    return entry.level ~= nil
end

-- After the group, guild or friends list changes: fill in players still waiting.
function Sources.Update(now)
    for _, entry in ipairs(Roster.All()) do
        if entry.status == "queued" or entry.status == "notfound" or entry.levelSource == "memory" then
            Sources.Fill(entry, now)
        end
    end
end
