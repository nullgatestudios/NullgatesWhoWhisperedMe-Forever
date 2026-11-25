-- Nullgate's Who Whispered Me: the window. A filter bar, the sortable player table, and the
-- Look up next button (a click, so it may send a /who) with the queue and cooldown.
local _, ns = ...

local L = ns.L
local Data, Roster, Sources, Who = ns.Data, ns.Roster, ns.Sources, ns.Who

local UI = {}
ns.UI = UI

local FULL_TITLE = "Nullgate's Who Whispered Me - Forever"
local ROWS, ROW_HEIGHT, LIST_TOP = 16, 18, -112
local frame, rows, headers, lookup, statusText, countText, listenBox
local controls = {} -- every filter control, refreshed together
local offset, shown = 0, {}
local menu, copyBox

local function Columns()
    return {
        { key = "name", label = L["Name"], width = 118 },
        { key = "level", label = L["Level"], width = 44, justify = "CENTER" },
        { key = "class", label = L["Class"], width = 80 },
        { key = "armor", label = L["Armor"], width = 74 },
        { key = "race", label = L["Race"], width = 72 },
        { key = "guild", label = L["Guild"], width = 116 },
        { key = "zone", label = L["Zone"], width = 108 },
        { key = "message", label = L["Message"], width = 196 },
        { key = "time", label = L["Time"], width = 48, justify = "RIGHT" },
        { key = "status", label = L["Status"], width = 80 },
    }
end

local ARMOR_NAMES, ROLE_NAMES
local function Names()
    ARMOR_NAMES = { CLOTH = L["Cloth"], LEATHER = L["Leather"], MAIL = L["Mail"], PLATE = L["Plate"] }
    ROLE_NAMES = { TANK = L["Tank"], HEALER = L["Healer"], DAMAGE = L["Damage"] }
end

local function Filters() return ns.db.filters end

local function SetTitle(f, text)
    if type(f.SetTitle) == "function" then f:SetTitle(text)
    elseif type(f.TitleText) == "table" then f.TitleText:SetText(text)
    elseif f.TitleContainer and f.TitleContainer.TitleText then f.TitleContainer.TitleText:SetText(text) end
end

local function Label(parent, text, x, y, template)
    local label = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(text)
    return label
end

local function ClassColor(token)
    local c = token and RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
    if not c then return "|cffffffff" end
    return string.format("|cff%02x%02x%02x", math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255))
end

-- --- Actions ----------------------------------------------------------------------

function UI.Whisper(name)
    if type(ChatFrame_SendTell) == "function" then ChatFrame_SendTell(name)
    elseif type(ChatFrame_OpenChat) == "function" then ChatFrame_OpenChat("/w " .. name .. " ") end
end

function UI.Invite(name)
    local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
    if type(invite) == "function" then invite(name) end
end

-- A click: sends the next queued lookup, or says why it can't.
function UI.LookupNext()
    local now = GetTime()
    if not Who.Available() then
        ns.Print(L["This game client has no /who for addons."])
    elseif Who.Pending() then
        ns.Print(string.format(L["Still waiting for the answer about %s."], Who.Pending().name))
    elseif Who.Wait(now) > 0 then
        if not (frame and frame:IsShown()) then
            ns.Print(string.format(L["Next lookup in %d s."], math.ceil(Who.Wait(now))))
        end
    elseif not Who.Next(now, time()) then
        if not (frame and frame:IsShown()) then ns.Print(L["Nobody is waiting for a lookup."]) end
    end
    UI.Refresh()
end

local function LookupNow(entry)
    if Who.Ready(GetTime()) then
        if entry.status ~= "looking" then Who.Send(entry, GetTime()) end
    else
        ns.Print(string.format(L["Next lookup in %d s."], math.max(1, math.ceil(Who.Wait(GetTime())))))
    end
    UI.Refresh()
end

local function ShowCopy(name)
    if not copyBox then
        local f = CreateFrame("Frame", "NullgatesWhoWhisperedMeCopy", UIParent, "BasicFrameTemplateWithInset")
        f:SetSize(260, 80)
        f:SetFrameStrata("DIALOG")
        f:SetPoint("CENTER")
        SetTitle(f, L["Copy name"])
        local box = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        box:SetSize(200, 20)
        box:SetPoint("CENTER", f, "CENTER", 0, -8)
        box:SetAutoFocus(true)
        box:SetScript("OnEscapePressed", function() f:Hide() end)
        box:SetScript("OnEnterPressed", function() f:Hide() end)
        f.box = box
        copyBox = f
        if UISpecialFrames then table.insert(UISpecialFrames, "NullgatesWhoWhisperedMeCopy") end
    end
    copyBox:Show()
    copyBox.box:SetText(name)
    copyBox.box:SetFocus()
    copyBox.box:HighlightText()
end

local function ShowMenu(entry)
    if not menu then
        menu = CreateFrame("Frame", "NullgatesWhoWhisperedMeMenu", UIParent, "BasicFrameTemplateWithInset")
        menu:SetSize(160, 182)
        menu:SetFrameStrata("DIALOG")
        menu:SetClampedToScreen(true)
        menu.buttons = {}
        local items = {
            { L["Whisper"], function(e) UI.Whisper(e.name) end },
            { L["Invite"], function(e) UI.Invite(e.name) end },
            { L["Look up now"], LookupNow },
            { L["Copy name"], function(e) ShowCopy(e.name) end },
            { L["Dismiss"], function(e) Roster.Remove(e.name); UI.Refresh() end },
        }
        for i, item in ipairs(items) do
            local button = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
            button:SetSize(136, 22)
            button:SetPoint("TOP", menu, "TOP", 0, -28 - (i - 1) * 28)
            button:SetText(item[1])
            button:SetScript("OnClick", function()
                menu:Hide()
                if menu.entry then item[2](menu.entry) end
            end)
        end
        if UISpecialFrames then table.insert(UISpecialFrames, "NullgatesWhoWhisperedMeMenu") end
    end
    menu.entry = entry
    SetTitle(menu, entry.name)
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    menu:Show()
end

-- --- Building -----------------------------------------------------------------------

local function Toggle(parent, text, width, x, y, isOn, flip)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 20)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", function() flip(); UI.Refresh() end)
    function button.Update()
        local on = isOn()
        if on then button:LockHighlight() else button:UnlockHighlight() end
        local label = button:GetFontString()
        if label then label:SetTextColor(on and 1 or 0.6, on and 0.82 or 0.6, on and 0 or 0.6) end
    end
    controls[#controls + 1] = button
    return button
end

local function SetFlag(set, key) set[key] = (not set[key]) or nil end

local function ClassButton(parent, token, x, y)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(24, 24)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[token]
    if coords then
        icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
        icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    else
        icon:SetColorTexture(0.3, 0.3, 0.3)
    end
    button:SetScript("OnClick", function() SetFlag(Filters().classes, token); UI.Refresh() end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(Data.ClassName(token))
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    function button.Update()
        local classes = Filters().classes
        button:SetAlpha((classes[token] or not next(classes)) and 1 or 0.3)
    end
    controls[#controls + 1] = button
end

local function Input(parent, width, x, y, field)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width, 20)
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    box:SetAutoFocus(false)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    box:SetScript("OnEnterPressed", box.ClearFocus)
    box:SetScript("OnTextChanged", function(self, userInput)
        if userInput then Filters()[field] = self:GetText() or ""; offset = 0; UI.Refresh() end
    end)
    function box.Update()
        if not box:HasFocus() then box:SetText(Filters()[field] or "") end
    end
    controls[#controls + 1] = box
    return box
end

local function Checkbox(parent, text, x, y, field)
    local box = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    box:SetSize(22, 22)
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    box:SetScript("OnClick", function(self) Filters()[field] = self:GetChecked() and true or false; UI.Refresh() end)
    Label(parent, text, x + 24, y - 5, "GameFontHighlightSmall")
    function box.Update() box:SetChecked(Filters()[field] and true or false) end
    controls[#controls + 1] = box
end

local GUILD_STEPS = { any = "yes", yes = "no", no = "any" }

local function BuildFilters()
    local f = Filters()
    Label(frame, L["Class"], 14, -36)
    for i, token in ipairs(Data.CLASSES) do ClassButton(frame, token, 70 + (i - 1) * 26, -30) end
    Label(frame, L["Levels"], 318, -36)
    local levels = Input(frame, 104, 378, -32, "levels")
    levels:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L["Levels, e.g. 20-29, 58-60 or 55+"])
        GameTooltip:Show()
    end)
    levels:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Label(frame, L["Armor"], 496, -36)
    for i, armor in ipairs(Data.ARMORS) do
        Toggle(frame, ARMOR_NAMES[armor], 64, 556 + (i - 1) * 66, -32, function() return f.armor[armor] end,
            function() SetFlag(f.armor, armor) end)
    end
    local clear = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clear:SetSize(116, 20)
    clear:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -32)
    clear:SetText(L["Clear filters"])
    clear:SetScript("OnClick", function()
        ns.db.filters = { classes = {}, levels = "", armor = {}, roles = {}, guild = "any", text = "",
            hideUnknown = false, hideNotFound = false }
        f = ns.db.filters
        offset = 0
        UI.Refresh()
    end)

    Label(frame, L["Role"], 14, -66)
    for i, role in ipairs(Data.ROLES) do
        Toggle(frame, ROLE_NAMES[role], 76, 70 + (i - 1) * 78, -62, function() return f.roles[role] end,
            function() SetFlag(f.roles, role) end)
    end
    local guildButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    guildButton:SetSize(150, 20)
    guildButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 318, -62)
    guildButton:SetScript("OnClick", function()
        f.guild = GUILD_STEPS[f.guild] or "any"
        UI.Refresh()
    end)
    function guildButton.Update()
        local names = { any = L["Guild: any"], yes = L["Guild: in a guild"], no = L["Guild: none"] }
        guildButton:SetText(names[f.guild] or names.any)
    end
    controls[#controls + 1] = guildButton
    Label(frame, L["Search"], 484, -66)
    Input(frame, 120, 546, -62, "text")
    Checkbox(frame, L["Hide unknown levels"], 680, -61, "hideUnknown")
    Checkbox(frame, L["Hide not found"], 822, -61, "hideNotFound")
end

local function SortBy(key)
    local sort = ns.db.sort
    if IsShiftKeyDown and IsShiftKeyDown() and sort[1] and sort[1].key ~= key then
        -- Shift-click: a second sort under the first
        if sort[2] and sort[2].key == key then sort[2].desc = not sort[2].desc
        else sort[2] = { key = key, desc = false } end
    elseif sort[1] and sort[1].key == key then
        sort[1].desc = not sort[1].desc
    else
        ns.db.sort = { { key = key, desc = key == "level" or key == "time" } }
    end
    UI.Refresh()
end

local function BuildTable()
    headers, rows = {}, {}
    local columns = Columns()
    local x = 12
    for _, col in ipairs(columns) do
        local header = CreateFrame("Button", nil, frame)
        header:SetSize(col.width, 18)
        header:SetPoint("TOPLEFT", frame, "TOPLEFT", x, LIST_TOP + 20)
        local text = header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        text:SetAllPoints()
        text:SetJustifyH(col.justify or "LEFT")
        header.text, header.col = text, col
        header:SetScript("OnClick", function() SortBy(col.key) end)
        header:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        headers[#headers + 1] = header
        x = x + col.width + 2
    end
    for i = 1, ROWS do
        local row = CreateFrame("Button", nil, frame)
        row:SetSize(x - 12, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, LIST_TOP - (i - 1) * ROW_HEIGHT)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row.cells = {}
        local cx = 0
        for _, col in ipairs(columns) do
            local cell = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            cell:SetPoint("LEFT", row, "LEFT", cx, 0)
            cell:SetSize(col.width, ROW_HEIGHT)
            cell:SetJustifyH(col.justify or "LEFT")
            if cell.SetWordWrap then cell:SetWordWrap(false) end
            row.cells[col.key] = cell
            cx = cx + col.width + 2
        end
        row:SetScript("OnClick", function(self, button)
            if not self.entry then return end
            if button == "RightButton" then ShowMenu(self.entry) else UI.Whisper(self.entry.name) end
        end)
        row:SetScript("OnDoubleClick", function(self) if self.entry then UI.Invite(self.entry.name) end end)
        row:SetScript("OnEnter", function(self) UI.Tooltip(self) end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        rows[i] = row
    end
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        offset = math.max(0, math.min(math.max(0, #shown - ROWS), offset - delta * 3))
        UI.Refresh()
    end)
end

local function BuildBottom()
    listenBox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    listenBox:SetSize(24, 24)
    listenBox:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 10)
    listenBox:SetScript("OnClick", function(self) ns.SetListening(self:GetChecked()) end)
    local listenLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    listenLabel:SetPoint("LEFT", listenBox, "RIGHT", 2, 0)
    listenLabel:SetText(L["Listening for whispers"])

    lookup = CreateFrame("Button", "NullgatesWhoWhisperedMeLookup", frame, "UIPanelButtonTemplate")
    lookup:SetSize(150, 24)
    lookup:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 250, 10)
    lookup:SetText(L["Look up next"])
    lookup:SetScript("OnClick", UI.LookupNext)
    lookup:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Look up next"])
        GameTooltip:AddLine(L["Sends one /who for the newest player without a level. The game only allows a /who from a click or key press, and a short wait between them."], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    lookup:SetScript("OnLeave", function() GameTooltip:Hide() end)
    statusText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    statusText:SetPoint("LEFT", lookup, "RIGHT", 10, 0)

    local clearList = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clearList:SetSize(110, 24)
    clearList:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 10)
    clearList:SetText(L["Clear list"])
    clearList:SetScript("OnClick", function() Roster.Clear(); offset = 0; UI.Refresh() end)
    countText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    countText:SetPoint("RIGHT", clearList, "LEFT", -10, 0)
end

-- Built at login (hidden) so the Look up next key binding works before the window opens.
function UI.Create()
    if frame then return end
    Names()
    frame = CreateFrame("Frame", "NullgatesWhoWhisperedMeFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(980, 460)
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        ns.db.window = { point = point, relPoint = relPoint, x = x, y = y }
    end)
    local pos = ns.db.window
    if pos and pos.point then frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else frame:SetPoint("CENTER") end
    SetTitle(frame, FULL_TITLE)
    frame:SetScript("OnShow", function() UI.Refresh() end)
    frame:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "NullgatesWhoWhisperedMeFrame") end
    BuildFilters()
    BuildTable()
    BuildBottom()
end

function UI.Show() UI.Create(); frame:Show(); UI.Refresh() end
function UI.Hide() if frame then frame:Hide() end end
function UI.IsShown() return frame ~= nil and frame:IsShown() end
function UI.Toggle() if UI.IsShown() then UI.Hide() else UI.Show() end end

-- --- Showing ------------------------------------------------------------------------

local function Ago(seconds)
    if seconds < 60 then return L["now"] end
    if seconds < 3600 then return string.format(L["%d min"], math.floor(seconds / 60)) end
    return string.format(L["%d h"], math.floor(seconds / 3600))
end

local function StatusName(entry)
    local names = { new = L["New"], queued = L["Queued"], looking = L["Looking up"], found = L["Found"], notfound = L["Not found"] }
    return names[entry.status] or entry.status
end

local function ArmorText(entry)
    local list = Data.Armor(entry.class, entry.level)
    if not list[1] then return "?" end
    local names = {}
    for i, armor in ipairs(list) do names[i] = ARMOR_NAMES[armor] end
    return table.concat(names, "/")
end

local function RoleTags(entry)
    if not entry.roles then return "" end
    local tags = {}
    for _, role in ipairs(Data.ROLES) do
        if entry.roles[role] then tags[#tags + 1] = ROLE_NAMES[role] end
    end
    return "|cff40c0ff[" .. table.concat(tags, ", ") .. "]|r "
end

local function Fill(row, entry, now)
    local c = row.cells
    local dim = row.inGroup and "|cff808080" or ""
    c.name:SetText((row.inGroup and dim or ClassColor(entry.class)) .. entry.name .. "|r")
    local level
    if entry.level then
        level = (entry.levelSource == "memory" and "|cff808080" or dim) .. entry.level .. "|r"
    else
        level = entry.status == "looking" and "..." or "?"
    end
    c.level:SetText(level)
    c.class:SetText(dim .. (entry.class and Data.ClassName(entry.class) or "?"))
    c.armor:SetText(dim .. ArmorText(entry))
    c.race:SetText(dim .. (entry.race or ""))
    c.guild:SetText(dim .. (entry.guild or ""))
    c.zone:SetText(dim .. (entry.zone or ""))
    c.message:SetText(RoleTags(entry) .. dim .. (entry.message or ""))
    c.time:SetText(dim .. Ago(now - (entry.time or now)))
    c.status:SetText(dim .. StatusName(entry))
end

function UI.Tooltip(row)
    local entry = row.entry
    if not entry then return end
    GameTooltip:SetOwner(row, "ANCHOR_CURSOR")
    GameTooltip:SetText(entry.name)
    if entry.message and entry.message ~= "" then GameTooltip:AddLine(entry.message, 1, 1, 1, true) end
    if entry.level then
        local sources = { who = L["/who"], unit = L["seen in game"], guild = L["guild list"], friend = L["friends list"],
            memory = L["remembered"] }
        local text = string.format(L["Level from: %s"], sources[entry.levelSource] or "?")
        if entry.levelSource == "memory" then
            text = text .. " (" .. string.format(L["%s ago"], Ago(time() - (entry.levelAt or time()))) .. ")"
        end
        GameTooltip:AddLine(text, 0.7, 0.7, 0.7)
    end
    if entry.count and entry.count > 1 then
        GameTooltip:AddLine(string.format(L["%d whispers"], entry.count), 0.7, 0.7, 0.7)
    end
    GameTooltip:AddLine(L["Click: whisper. Double-click: invite. Right-click: more."], 0.5, 0.8, 1)
    GameTooltip:Show()
end

local function UpdateLookup(now)
    local wall = time()
    local queue = Roster.QueueSize(wall)
    local text
    if not Who.Available() then
        text = L["Lookups unavailable in this client."]
    elseif Who.Pending() then
        text = string.format(L["Looking up %s..."], Who.Pending().name)
    elseif Who.Wait(now) > 0 then
        text = string.format(L["Waiting: %d s"], math.ceil(Who.Wait(now)))
    elseif queue > 0 then
        text = L["Ready"]
    else
        text = L["Nobody waiting"]
    end
    statusText:SetText(string.format(L["Queue: %d"], queue) .. "  |  " .. text)
    local ready = queue > 0 and Who.Ready(now)
    lookup:SetAlpha(ready and 1 or 0.5)
end

function UI.Refresh()
    if not frame then return end
    listenBox:SetChecked(ns.db.listening)
    if not frame:IsShown() then return end
    for _, control in ipairs(controls) do control.Update() end
    local sort = ns.db.sort
    for _, header in ipairs(headers) do
        local mark = ""
        if sort[1] and sort[1].key == header.col.key then mark = sort[1].desc and " v" or " ^"
        elseif sort[2] and sort[2].key == header.col.key then mark = sort[2].desc and " v2" or " ^2" end
        header.text:SetText(header.col.label .. mark)
    end
    local all = Roster.All()
    shown = Roster.Sort(Roster.Filter(all, Filters()), sort)
    -- Players already in your group drop to the bottom.
    local others, members = {}, {}
    for _, entry in ipairs(shown) do
        if Sources.InGroup(entry.name) then members[#members + 1] = entry else others[#others + 1] = entry end
    end
    for _, entry in ipairs(members) do others[#others + 1] = entry end
    shown = others
    local grouped = {}
    for _, entry in ipairs(members) do grouped[entry] = true end
    offset = math.max(0, math.min(offset, #shown - ROWS))
    local now = time()
    for i, row in ipairs(rows) do
        local entry = shown[i + offset]
        row.entry = entry
        row.inGroup = entry and grouped[entry] or false
        if entry then Fill(row, entry, now); row:Show() else row:Hide() end
    end
    countText:SetText(string.format(L["Showing %d of %d"], #shown, #all))
    UpdateLookup(GetTime())
end

-- Called twice a second by Core while the window is open (times and the cooldown change).
function UI.Tick()
    if frame and frame:IsShown() then UI.Refresh() end
end

-- Key binding: open or close the window.
function NullgatesWhoWhisperedMe_Toggle() UI.Toggle() end
