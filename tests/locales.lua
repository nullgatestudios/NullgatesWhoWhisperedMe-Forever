-- Nullgate's Who Whispered Me: every language pack translates every string the code uses,
-- with the same %s/%d placeholders in the same order, and language selection works.
-- Run from the repository root:  lua tests/locales.lua

local source = debug.getinfo(1, "S").source or ""
local script = source:match("^@(.*)$") or "tests/locales.lua"
local scriptDir = script:match("^(.*)[/\\][^/\\]*$") or "."
local repo = scriptDir:match("^(.*)[/\\][^/\\]*$") or "."
local folder = "NullgatesWhoWhisperedMe-Forever"
local root = repo .. "/" .. folder .. "/"

local checks, failures = 0, 0
local function OK(cond, name)
    checks = checks + 1
    if not cond then failures = failures + 1; io.write("FAIL " .. name .. "\n") end
end

-- Load Locale.lua and every pack listed in the .toc, capturing what each pack registers.
local ns, registered = {}, {}
local toc = assert(io.open(root .. folder .. ".toc", "r")):read("*a")
local locale = "enUS"
GetLocale = function() return locale end
assert(loadfile(root .. "Locale.lua"))(folder, ns)
local register = ns.RegisterLanguagePack
ns.RegisterLanguagePack = function(code, name, strings) registered[code] = strings; register(code, name, strings) end
for file in toc:gmatch("Locales\\(%w+%.lua)") do assert(loadfile(root .. "Locales/" .. file))(folder, ns) end

-- Every L["..."] the code uses (plain string keys).
local used = {}
for line in toc:gmatch("[^\r\n]+") do
    if not line:match("^##") and line:match("%.lua$") and not line:match("^Locales") and line ~= "Locale.lua" then
        local text = assert(io.open(root .. line:gsub("\\", "/"), "r")):read("*a")
        for key in text:gmatch('L%["(.-)"%]') do
            if not key:find('" or "', 1, true) then used[key:gsub("\\'", "'")] = true end
        end
    end
end

local function Placeholders(text) local out = {}; for p in text:gmatch("%%[sd]") do out[#out + 1] = p end; return table.concat(out) end

local count = 0
for code, strings in pairs(registered) do
    count = count + 1
    for key in pairs(used) do
        local value = strings[key]
        OK(type(value) == "string" and value ~= "", code .. " translates: " .. key)
        if value then OK(Placeholders(value) == Placeholders(key), code .. " keeps the placeholders of: " .. key) end
    end
end
OK(count == 9, "9 language packs besides English (" .. count .. ")")
OK(#ns.LANGUAGES == 10, "10 languages in the Language setting, the ones the game client runs in")

-- Selection: automatic follows the game; esMX uses Spanish; a picked language wins.
locale = "deDE"; ns.SetLanguage("auto")
OK(ns.L["Whisper"] == "Anflüstern", "a German client gets German automatically")
locale = "esMX"; ns.SetLanguage("auto")
OK(ns.ActiveLanguage() == "esES", "a Mexican Spanish client uses the Spanish pack")
locale = "enGB"; ns.SetLanguage("auto")
OK(ns.ActiveLanguage() == "enUS" and ns.L["Whisper"] == "Whisper", "British English uses English")
ns.SetLanguage("frFR")
OK(ns.L["Whisper"] == "Chuchoter", "a picked language (French) wins over the game language")
OK(ns.L["Not a key"] == "Not a key", "a missing key falls back to English")

io.write(string.format("locales: %d checks, %d failure(s)\n", checks, failures))
if failures > 0 then os.exit(1) end
