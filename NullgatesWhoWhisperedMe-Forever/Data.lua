-- Nullgate's Who Whispered Me: class facts used by the filters. Armor and roles follow the
-- Classic rules; check them against Forever's data before a full release.
local _, ns = ...

local Data = {}
ns.Data = Data

Data.CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
Data.ARMORS = { "CLOTH", "LEATHER", "MAIL", "PLATE" }
Data.ROLES = { "TANK", "HEALER", "DAMAGE" }

-- Hunters and Shamans learn Mail, Warriors and Paladins learn Plate, at this level.
Data.ARMOR_LEVEL = 40

-- Best armor before and from ARMOR_LEVEL.
local ARMOR = {
    MAGE = { "CLOTH" }, PRIEST = { "CLOTH" }, WARLOCK = { "CLOTH" },
    ROGUE = { "LEATHER" }, DRUID = { "LEATHER" },
    HUNTER = { "LEATHER", "MAIL" }, SHAMAN = { "LEATHER", "MAIL" },
    WARRIOR = { "MAIL", "PLATE" }, PALADIN = { "MAIL", "PLATE" },
}

-- The best armor the class wears at that level, as a list. With the level unknown, a class
-- that changes armor at 40 gives both, so it matches either armor filter.
function Data.Armor(class, level)
    local armor = ARMOR[class or ""]
    if not armor then return {} end
    if #armor == 1 then return { armor[1] } end
    if not level then return { armor[1], armor[2] } end
    return { level >= Data.ARMOR_LEVEL and armor[2] or armor[1] }
end

local CAN = {
    WARRIOR = { TANK = true, DAMAGE = true },
    PALADIN = { TANK = true, HEALER = true, DAMAGE = true },
    DRUID = { TANK = true, HEALER = true, DAMAGE = true },
    PRIEST = { HEALER = true, DAMAGE = true },
    SHAMAN = { HEALER = true, DAMAGE = true },
    HUNTER = { DAMAGE = true }, ROGUE = { DAMAGE = true }, MAGE = { DAMAGE = true }, WARLOCK = { DAMAGE = true },
}

-- Whether the class can fill the role at all (talents can't be seen from a whisper).
function Data.CanDo(class, role)
    local can = CAN[class or ""]
    return can ~= nil and can[role] == true
end

-- Words players use for their role, in the 10 languages. Latin words match whole words,
-- any case; the others match anywhere in the message.
Data.KEYWORDS = {
    TANK = { "tank", "tanks", "tanking", "tanque", "танк", "Танк", "ТАНК", "탱", "坦" },
    HEALER = { "heal", "heals", "healer", "healz", "healing", "heiler", "soigneur", "soin", "sanador",
        "curandero", "guaritore", "curatore", "curador", "хил", "Хил", "ХИЛ", "лекарь", "Лекарь",
        "힐", "治疗", "治療", "奶", "補" },
    DAMAGE = { "dps", "dd", "damage", "schaden", "degats", "dégâts", "дд", "ДД", "дпс", "ДПС", "딜", "输出", "輸出" },
}

-- The roles a whisper names, as a set, or nil when it names none.
function Data.StatedRoles(message)
    if type(message) ~= "string" or message == "" then return nil end
    local lower = string.lower(message)
    local roles
    for _, role in ipairs(Data.ROLES) do
        for _, word in ipairs(Data.KEYWORDS[role]) do
            local found
            if word:find("^[%a]+$") then
                found = lower:find("%f[%a]" .. word .. "%f[%A]") ~= nil
            else
                found = message:find(word, 1, true) ~= nil
            end
            if found then
                roles = roles or {}
                roles[role] = true
                break
            end
        end
    end
    return roles
end

-- The class token (e.g. "PRIEST") for a class name in the game's language.
function Data.ClassToken(localized)
    if type(localized) ~= "string" then return nil end
    for _, list in ipairs({ LOCALIZED_CLASS_NAMES_MALE, LOCALIZED_CLASS_NAMES_FEMALE }) do
        if type(list) == "table" then
            for token, name in pairs(list) do
                if name == localized then return token end
            end
        end
    end
    local upper = string.upper(localized)
    if CAN[upper] then return upper end
    return nil
end

-- The class name in the game's language.
function Data.ClassName(token)
    local list = LOCALIZED_CLASS_NAMES_MALE
    return (type(list) == "table" and list[token]) or token
end
