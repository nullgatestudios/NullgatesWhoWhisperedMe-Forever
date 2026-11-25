-- Nullgate's Who Whispered Me: the list of players who whispered you, the lookup queue,
-- the filters and the sorting. No game calls here, so it is tested on its own (tests/run.lua).
--
-- An entry: name, guid, class (token), race, level, levelSource ("who", "unit", "guild",
-- "friend", "memory"), levelAt, guild ("" = no guild, nil = not known), zone, message,
-- time (last whisper), count, roles (set named in the whispers), tries, status:
--   "new"      just arrived     "queued"   waits for a /who    "looking"  /who sent
--   "found"    level known      "notfound" the /who found nobody (offline or a typo)
local _, ns = ...

local Data = ns.Data

local Roster = {}
ns.Roster = Roster

Roster.RETRY_SECONDS = 300 -- a player who wasn't found is tried once more after this long
Roster.MAX_TRIES = 2

local entries = {}

local function Key(name) return string.lower(name) end
Roster.Key = Key

function Roster.Get(name)
    return type(name) == "string" and entries[Key(name)] or nil
end

function Roster.All()
    local list = {}
    for _, entry in pairs(entries) do list[#list + 1] = entry end
    return list
end

function Roster.Count()
    local n = 0
    for _ in pairs(entries) do n = n + 1 end
    return n
end

function Roster.Remove(name)
    if type(name) == "string" then entries[Key(name)] = nil end
end

function Roster.Clear()
    entries = {}
end

-- Records a whisper. Returns the entry and whether the player is new to the list.
function Roster.Whisper(name, message, now, guid)
    local key = Key(name)
    local entry = entries[key]
    local isNew = entry == nil
    if isNew then
        entry = { name = name, tries = 0, count = 0, status = "new", first = now }
        entries[key] = entry
    end
    entry.guid = guid or entry.guid
    entry.message = message or entry.message or ""
    entry.time = now
    entry.count = entry.count + 1
    local stated = Data.StatedRoles(message)
    if stated then
        entry.roles = entry.roles or {}
        for role in pairs(stated) do entry.roles[role] = true end
    end
    return entry, isNew
end

-- Merges what a source knows about the player. A remembered level never replaces a live one.
function Roster.SetInfo(entry, info, source, at)
    if info.class then entry.class = info.class end
    if info.race then entry.race = info.race end
    if info.guild then entry.guild = info.guild end
    if info.zone then entry.zone = info.zone end
    if info.level and (not entry.level or source ~= "memory" or entry.levelSource == "memory") then
        entry.level, entry.levelSource, entry.levelAt = info.level, source, at
    end
    if entry.level and entry.status ~= "looking" then entry.status = "found" end
end

-- Puts a player without a level in the lookup queue.
function Roster.Queue(entry)
    if entry.status == "new" or entry.status == "notfound" then entry.status = "queued" end
end

function Roster.NotFound(entry, now)
    entry.status = "notfound"
    entry.notFoundAt = now
end

-- 2 = waiting for its first lookup, 1 = not found earlier and due for one more try, nil = not waiting.
local function Waiting(entry, now)
    if entry.status == "queued" then return 2 end
    if entry.status == "notfound" and entry.tries < Roster.MAX_TRIES
        and now - (entry.notFoundAt or 0) >= Roster.RETRY_SECONDS then
        return 1
    end
    return nil
end

-- The next player to look up: first lookups before retries, newest whisper first.
function Roster.Next(now)
    local best, bestRank
    for _, entry in pairs(entries) do
        local rank = Waiting(entry, now)
        if rank and (not best or rank > bestRank or (rank == bestRank and
            (entry.time > best.time or (entry.time == best.time and Key(entry.name) < Key(best.name))))) then
            best, bestRank = entry, rank
        end
    end
    return best
end

function Roster.QueueSize(now)
    local n = 0
    for _, entry in pairs(entries) do
        if Waiting(entry, now) then n = n + 1 end
    end
    return n
end

-- --- Filters ----------------------------------------------------------------------

-- "20-29, 58-60, 45, 55+" -> { {20,29}, {58,60}, {45,45}, {55,999} }; nil when it names no level.
function Roster.ParseLevels(text)
    local ranges = {}
    text = string.gsub(text or "", "%s*%-%s*", "-")
    for part in string.gmatch(text, "[^,;%s]+") do
        local lo, hi = part:match("^(%d+)%-(%d+)$")
        if not lo then
            lo = part:match("^(%d+)%+$")
            if lo then hi = "999" else lo = part:match("^(%d+)$"); hi = lo end
        end
        if lo then
            lo, hi = tonumber(lo), tonumber(hi)
            if lo > hi then lo, hi = hi, lo end
            ranges[#ranges + 1] = { lo, hi }
        end
    end
    return ranges[1] and ranges or nil
end

local function Any(set) return type(set) == "table" and next(set) ~= nil end

-- Whether the player can fill the role: the roles named in their whispers when there are
-- any, otherwise what the class can do.
function Roster.HasRole(entry, role)
    if entry.roles then return entry.roles[role] == true end
    return Data.CanDo(entry.class, role)
end

local function Contains(text, needle)
    return type(text) == "string" and string.find(string.lower(text), needle, 1, true) ~= nil
end

-- Different filter types must all match; within a type any choice matches. What isn't
-- known yet (no class, no level, guild not seen) passes, so the row stays visible with
-- a "?"; Hide unknown levels hides players whose level isn't known.
function Roster.Matches(entry, f, ranges)
    if f.hideNotFound and entry.status == "notfound" then return false end
    if f.hideUnknown and not entry.level then return false end
    if Any(f.classes) and entry.class and not f.classes[entry.class] then return false end
    if ranges and entry.level then
        local inside = false
        for _, r in ipairs(ranges) do
            if entry.level >= r[1] and entry.level <= r[2] then inside = true end
        end
        if not inside then return false end
    end
    if Any(f.armor) and entry.class then
        local ok = false
        for _, armor in ipairs(Data.Armor(entry.class, entry.level)) do
            if f.armor[armor] then ok = true end
        end
        if not ok then return false end
    end
    if Any(f.roles) and (entry.class or entry.roles) then
        local ok = false
        for role in pairs(f.roles) do
            if Roster.HasRole(entry, role) then ok = true end
        end
        if not ok then return false end
    end
    if f.guild == "yes" and entry.guild == "" then return false end
    if f.guild == "no" and entry.guild and entry.guild ~= "" then return false end
    local text = string.lower(f.text or "")
    if text ~= "" and not (Contains(entry.name, text) or Contains(entry.guild, text) or Contains(entry.message, text)) then
        return false
    end
    return true
end

function Roster.Filter(list, f)
    local ranges = Roster.ParseLevels(f.levels)
    local out = {}
    for _, entry in ipairs(list) do
        if Roster.Matches(entry, f, ranges) then out[#out + 1] = entry end
    end
    return out
end

-- --- Sorting ----------------------------------------------------------------------

local STATUS_ORDER = { looking = 1, queued = 2, new = 3, found = 4, notfound = 5 }
local ARMOR_ORDER = { CLOTH = 1, LEATHER = 2, MAIL = 3, PLATE = 4 }

local function Text(value)
    if type(value) ~= "string" or value == "" then return nil end
    return string.lower(value)
end

local function Value(entry, key)
    if key == "level" then return entry.level end
    if key == "time" then return entry.time end
    if key == "status" then return STATUS_ORDER[entry.status] end
    if key == "class" then return entry.class and Text(Data.ClassName(entry.class)) end
    if key == "armor" then
        local armor = Data.Armor(entry.class, entry.level)
        return armor[1] and ARMOR_ORDER[armor[#armor]] or nil
    end
    return Text(entry[key]) -- name, race, guild, zone, message
end

-- keys = { { key = "level", desc = true }, { key = "name" } }. Unknown values always sort
-- last; ties fall back to the name.
function Roster.Sort(list, keys)
    table.sort(list, function(a, b)
        for _, k in ipairs(keys) do
            local va, vb = Value(a, k.key), Value(b, k.key)
            if va ~= vb then
                if va == nil then return false end
                if vb == nil then return true end
                if k.desc then return va > vb end
                return va < vb
            end
        end
        return Key(a.name) < Key(b.name)
    end)
    return list
end
