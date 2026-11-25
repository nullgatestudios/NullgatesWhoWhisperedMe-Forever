-- Nullgate's Who Whispered Me: tests for the class data, the list, its filters, sorting and
-- the lookup queue. Run from the repository root:  lua tests/run.lua   (Lua 5.1 or newer)

local source = debug.getinfo(1, "S").source or ""
local script = source:match("^@(.*)$") or "tests/run.lua"
local scriptDir = script:match("^(.*)[/\\][^/\\]*$") or "."
local root = (scriptDir:match("^(.*)[/\\][^/\\]*$") or ".") .. "/NullgatesWhoWhisperedMe-Forever/"

LOCALIZED_CLASS_NAMES_MALE = { WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
    SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid" }

local ns = {}
local function Load(file) assert(loadfile(root .. file), "cannot load " .. file)("NullgatesWhoWhisperedMe-Forever", ns) end
Load("Data.lua")
Load("Roster.lua")

local checks, failures = 0, 0
local function EQ(got, want, name)
    checks = checks + 1
    if got ~= want then
        failures = failures + 1
        print(string.format("FAIL %s: expected %s, got %s", name, tostring(want), tostring(got)))
    end
end

local Data, Roster = ns.Data, ns.Roster
local function Join(list) return table.concat(list, ",") end

-- --- Armor and roles ----------------------------------------------------------------
EQ(Join(Data.Armor("MAGE", 60)), "CLOTH", "mages wear cloth")
EQ(Join(Data.Armor("HUNTER", 39)), "LEATHER", "a level 39 hunter wears leather")
EQ(Join(Data.Armor("HUNTER", 40)), "MAIL", "a level 40 hunter wears mail")
EQ(Join(Data.Armor("WARRIOR", 25)), "MAIL", "a level 25 warrior wears mail")
EQ(Join(Data.Armor("PALADIN", 60)), "PLATE", "a level 60 paladin wears plate")
EQ(Join(Data.Armor("SHAMAN", nil)), "LEATHER,MAIL", "level unknown: both armors a shaman may wear")
EQ(Join(Data.Armor(nil, 30)), "", "class unknown: no armor")
EQ(Data.CanDo("DRUID", "TANK"), true, "druids can tank")
EQ(Data.CanDo("PRIEST", "TANK"), false, "priests can't tank")
EQ(Data.CanDo("SHAMAN", "HEALER"), true, "shamans can heal")
EQ(Data.CanDo("MAGE", "HEALER"), false, "mages can't heal")

local function Roles(text)
    local set = Data.StatedRoles(text)
    if not set then return "none" end
    local out = {}
    for _, role in ipairs(Data.ROLES) do if set[role] then out[#out + 1] = role end end
    return Join(out)
end
EQ(Roles("lf heals? 58 sham"), "HEALER", "'heals' is a healer")
EQ(Roles("Tank LFG"), "TANK", "any case")
EQ(Roles("dps or heal"), "HEALER,DAMAGE", "two roles")
EQ(Roles("tankard of ale"), "none", "a word containing 'tank' isn't a role")
EQ(Roles("Хил 60 лвл"), "HEALER", "Russian healer")
EQ(Roles("힐러 구합니다"), "HEALER", "Korean healer")
EQ(Roles("治疗 60"), "HEALER", "Chinese healer")
EQ(Roles("inv pls"), "none", "no role named")
EQ(Data.ClassToken("Priest"), "PRIEST", "a class name in the game's language gives its token")
EQ(Data.ClassToken("Nonsense"), nil, "an unknown class name gives nothing")

-- --- Level ranges --------------------------------------------------------------------
local function Ranges(text)
    local r = Roster.ParseLevels(text)
    if not r then return "none" end
    local out = {}
    for _, range in ipairs(r) do out[#out + 1] = range[1] .. "-" .. range[2] end
    return Join(out)
end
EQ(Ranges("20-29, 58-60"), "20-29,58-60", "two ranges")
EQ(Ranges("45"), "45-45", "one level")
EQ(Ranges("55+"), "55-999", "a level and up")
EQ(Ranges("29 - 20"), "20-29", "spaces and reversed")
EQ(Ranges(""), "none", "empty: no level filter")
EQ(Ranges("abc"), "none", "nonsense: no level filter")

-- --- The list ------------------------------------------------------------------------
local e1, new1 = Roster.Whisper("Healbot", "lf heals? 58 priest", 100, "Player-1")
EQ(new1, true, "a first whisper adds the player")
local again, new2 = Roster.Whisper("healbot", "hello?", 110)
EQ(again == e1 and new2 == false, true, "the same name in another case is the same player")
EQ(e1.count, 2, "whispers are counted")
EQ(e1.message, "hello?", "the newest message is kept")
EQ(e1.roles and e1.roles.HEALER, true, "a role named in an earlier whisper is kept")
EQ(e1.guid, "Player-1", "the GUID from the first whisper is kept")

Roster.Queue(e1)
EQ(e1.status, "queued", "no level: queued")
local e2 = Roster.Whisper("Stabby", "inv", 120)
Roster.Queue(e2)
EQ(Roster.Next(200), e2, "newest whisper is looked up first")
EQ(Roster.QueueSize(200), 2, "two waiting")
Roster.SetInfo(e2, { level = 44, class = "ROGUE", guild = "", race = "Undead", zone = "Angor Fortress" }, "who", 200)
EQ(e2.status, "found", "a level found: found")
EQ(Roster.Next(200), e1, "then the next one")
Roster.NotFound(e1, 200)
e1.tries = 1
EQ(Roster.Next(300), nil, "not found: not retried at once")
EQ(Roster.Next(200 + Roster.RETRY_SECONDS), e1, "retried once after a while")
e1.tries = Roster.MAX_TRIES
EQ(Roster.Next(10000), nil, "never more than MAX_TRIES")
Roster.SetInfo(e1, { level = 58, class = "PRIEST" }, "memory", 50)
EQ(e1.level == 58 and e1.levelSource == "memory", true, "a remembered level fills a gap")
Roster.SetInfo(e1, { level = 59 }, "who", 400)
EQ(e1.level == 59 and e1.levelSource == "who", true, "a live level replaces a remembered one")
Roster.SetInfo(e1, { level = 50 }, "memory", 10)
EQ(e1.level, 59, "a remembered level never replaces a live one")

local e3 = Roster.Whisper("Tanky", "tank here", 130)
Roster.SetInfo(e3, { level = 60, class = "WARRIOR", guild = "Night Watch", race = "Orc" }, "unit", 130)
local e4 = Roster.Whisper("Mystery", "hi", 140) -- nothing known yet
local e5 = Roster.Whisper("Huntress", "lfg", 150)
Roster.SetInfo(e5, { class = "HUNTER" }, "unit", 150)
EQ(Roster.Count(), 5, "five on the list")

-- --- Filters ---------------------------------------------------------------------------
local function Names(f)
    local list = Roster.Sort(Roster.Filter(Roster.All(), f), { { key = "name" } })
    local out = {}
    for _, e in ipairs(list) do out[#out + 1] = e.name end
    return Join(out)
end
local function F(t)
    local f = { classes = {}, levels = "", armor = {}, roles = {}, guild = "any", text = "", hideUnknown = false, hideNotFound = false }
    for k, v in pairs(t) do f[k] = v end
    return f
end
EQ(Names(F({})), "Healbot,Huntress,Mystery,Stabby,Tanky", "no filter: everyone")
EQ(Names(F({ classes = { PRIEST = true, WARRIOR = true } })), "Healbot,Mystery,Tanky", "class: either class, unknown stays")
EQ(Names(F({ levels = "55-60" })), "Healbot,Huntress,Mystery,Tanky", "level range: unknown levels stay")
EQ(Names(F({ levels = "55-60", hideUnknown = true })), "Healbot,Tanky", "Hide unknown levels")
EQ(Names(F({ levels = "40-45, 60" })), "Huntress,Mystery,Stabby,Tanky", "two level ranges")
EQ(Names(F({ armor = { PLATE = true } })), "Mystery,Tanky", "armor: plate at 60")
EQ(Names(F({ armor = { MAIL = true } })), "Huntress,Mystery", "armor: a hunter of unknown level may wear mail")
EQ(Names(F({ armor = { LEATHER = true } })), "Huntress,Mystery,Stabby", "armor: leather")
EQ(Names(F({ roles = { HEALER = true } })), "Healbot,Mystery", "role: a named role or class ability")
EQ(Names(F({ roles = { TANK = true } })), "Mystery,Tanky", "role: tank")
EQ(Names(F({ roles = { DAMAGE = true } })), "Huntress,Mystery,Stabby", "role: a whisper naming tank isn't damage")
EQ(Names(F({ guild = "yes" })), "Healbot,Huntress,Mystery,Tanky", "in a guild: no-guild players hidden, unknown stays")
EQ(Names(F({ guild = "no" })), "Healbot,Huntress,Mystery,Stabby", "no guild: guild members hidden")
EQ(Names(F({ text = "WATCH" })), "Tanky", "search the guild, any case")
EQ(Names(F({ text = "lfg" })), "Huntress", "search the message")
EQ(Names(F({ classes = { WARRIOR = true }, levels = "60", roles = { TANK = true } })), "Mystery,Tanky", "filter types combine")
Roster.NotFound(e4, 500)
EQ(Names(F({ hideNotFound = true })), "Healbot,Huntress,Stabby,Tanky", "Hide not found")

-- --- Sorting ---------------------------------------------------------------------------
local function Sorted(keys)
    local list = Roster.Sort(Roster.All(), keys)
    local out = {}
    for _, e in ipairs(list) do out[#out + 1] = e.name end
    return Join(out)
end
EQ(Sorted({ { key = "level", desc = true } }), "Tanky,Healbot,Stabby,Huntress,Mystery", "level, highest first, unknown last")
EQ(Sorted({ { key = "level" } }), "Stabby,Healbot,Tanky,Huntress,Mystery", "level, lowest first, unknown still last")
EQ(Sorted({ { key = "time", desc = true } }), "Huntress,Mystery,Tanky,Stabby,Healbot", "newest whisper first")
EQ(Sorted({ { key = "class" } }), "Huntress,Healbot,Stabby,Tanky,Mystery", "class name A to Z")
EQ(Sorted({ { key = "armor", desc = true }, { key = "level", desc = true } }), "Tanky,Huntress,Stabby,Healbot,Mystery",
    "armor heaviest first, then level")

Roster.Remove("TANKY")
EQ(Roster.Get("Tanky"), nil, "Dismiss removes a player")
Roster.Clear()
EQ(Roster.Count(), 0, "Clear empties the list")

print(string.format("%d checks, %d failure(s)", checks, failures))
if failures > 0 then os.exit(1) end
