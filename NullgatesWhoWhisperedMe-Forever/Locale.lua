-- Nullgate's Who Whispered Me: text lookup. Every user-facing string goes through ns.L["English text"].
-- Language packs (Locales\<code>.lua) register a table keyed by the English text; a missing
-- key falls back to English. The game's own language is used automatically ("auto"); the
-- Language setting can pick any registered language instead (it applies after /reload).
local _, ns = ...

local packs = { enUS = {} }
ns.LANGUAGES = { { code = "enUS", name = "English" } } -- the order shown in the Language setting
local active

function ns.RegisterLanguagePack(code, name, strings)
    if not packs[code] then ns.LANGUAGES[#ns.LANGUAGES + 1] = { code = code, name = name } end
    packs[code] = strings
end

-- The pack for the game's language: British English uses English, Mexican Spanish uses Spanish.
local function ClientLanguage()
    local locale = (GetLocale and GetLocale()) or "enUS"
    if locale == "esMX" and not packs.esMX then return "esES" end
    if packs[locale] then return locale end
    return "enUS"
end

-- code is a registered language, or "auto"/nil for the game's language.
function ns.SetLanguage(code)
    active = (code and code ~= "auto" and packs[code]) and code or ClientLanguage()
end

function ns.ActiveLanguage()
    if not active then ns.SetLanguage("auto") end
    return active
end

ns.L = setmetatable({}, { __index = function(_, key)
    local pack = packs[ns.ActiveLanguage()]
    return (pack and pack[key]) or key
end })
