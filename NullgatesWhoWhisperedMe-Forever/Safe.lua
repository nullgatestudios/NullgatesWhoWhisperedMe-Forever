-- Nullgate's Who Whispered Me: guards for Forever's secret values. Chat and unit calls can
-- return secret values (usually in combat); they must never be compared, joined or used as
-- table keys, so every outside string and number passes through here first.
local _, ns = ...

local Safe = {}
ns.Safe = Safe

-- issecretvalue is missing on older clients; missing means "not secret".
function Safe.IsSecret(value)
    if type(issecretvalue) ~= "function" then return false end
    return issecretvalue(value) and true or false
end

-- The value when it is a non-secret, non-empty string, else nil.
function Safe.Str(value)
    if type(value) ~= "string" or Safe.IsSecret(value) or value == "" then return nil end
    return value
end

-- The value when it is a non-secret number above 0, else nil (UnitLevel says -1 or 0 when unknown).
function Safe.Level(value)
    if type(value) ~= "number" or Safe.IsSecret(value) or value <= 0 then return nil end
    return value
end

-- A player name without its realm ("Name-Realm" -> "Name" on the player's own realm).
function Safe.Name(value)
    local name = Safe.Str(value)
    if not name then return nil end
    if type(Ambiguate) == "function" then
        local ok, short = pcall(Ambiguate, name, "none")
        if ok and Safe.Str(short) then return short end
    end
    return name
end
