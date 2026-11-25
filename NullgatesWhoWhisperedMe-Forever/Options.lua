-- Nullgate's Who Whispered Me: settings. Options.Build(container) lays out every setting and
-- is used both by the addon's own window and by Nullgate's Addon Config when installed.
local addonName, ns = ...

local L = ns.L
local Options = {}
ns.Options = Options

local FULL_TITLE = "Nullgate's Who Whispered Me - Forever"
local window

local function Header(parent, text, y)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, y)
    label:SetText(text)
    return y - 28
end

local function Check(parent, text, get, set, y)
    local box = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    box:SetSize(24, 24)
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, y)
    box:SetChecked(get())
    box:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", box, "RIGHT", 4, 0)
    label:SetText(text)
    return y - 28
end

-- A number with - and + buttons (works on every client, unlike slider templates).
local function Stepper(parent, text, get, set, min, max, step, y)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, y - 4)
    label:SetText(text)
    local value = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    value:SetPoint("TOPLEFT", parent, "TOPLEFT", 314, y - 4)
    local function Show() value:SetText(tostring(get())) end
    local function Change(delta) set(math.max(min, math.min(max, get() + delta))); Show() end
    local minus = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    minus:SetSize(24, 20)
    minus:SetPoint("TOPLEFT", parent, "TOPLEFT", 284, y)
    minus:SetText("-")
    minus:SetScript("OnClick", function() Change(-step) end)
    local plus = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    plus:SetSize(24, 20)
    plus:SetPoint("TOPLEFT", parent, "TOPLEFT", 340, y)
    plus:SetText("+")
    plus:SetScript("OnClick", function() Change(step) end)
    Show()
    return y - 28
end

-- Lays out every setting inside container; returns the height used.
function Options.Build(container)
    local db = ns.db
    local y = -12
    y = Header(container, L["Listening"], y)
    y = Check(container, L["Listen for whispers now"], function() return db.listening end, function(v) ns.SetListening(v) end, y)
    y = Check(container, L["Open the window on the first whisper"], function() return db.autoOpen end, function(v) db.autoOpen = v end, y)
    y = Stepper(container, L["Keep the list after listening stops (minutes)"], function() return db.keepMinutes end,
        function(v) db.keepMinutes = v end, 5, 60, 5, y)
    y = Stepper(container, L["Remember looked-up levels (hours)"], function() return db.memoryHours end,
        function(v) db.memoryHours = v end, 1, 72, 1, y)
    y = y - 8

    y = Header(container, L["Language"], y)
    local function LanguageName()
        if db.language == "auto" then return L["Automatic (game language)"] end
        for _, entry in ipairs(ns.LANGUAGES) do
            if entry.code == db.language then return entry.name end
        end
        return db.language
    end
    local picker = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
    picker:SetSize(230, 22)
    picker:SetPoint("TOPLEFT", container, "TOPLEFT", 16, y)
    picker:SetText(LanguageName())
    picker:SetScript("OnClick", function(self)
        -- auto, then every language in order, then back to auto
        local nextCode = ns.LANGUAGES[1].code
        if db.language ~= "auto" then
            nextCode = "auto"
            for i, entry in ipairs(ns.LANGUAGES) do
                if entry.code == db.language and ns.LANGUAGES[i + 1] then nextCode = ns.LANGUAGES[i + 1].code end
            end
        end
        db.language = nextCode
        self:SetText(LanguageName())
        ns.Print(L["The language changes after you type /reload."])
    end)
    y = y - 32

    local note = container:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", container, "TOPLEFT", 16, y - 8)
    note:SetWidth(360)
    note:SetJustifyH("LEFT")
    note:SetText(L["Commands: /nwho (window), /nwho listen, /nwho options, /nwho check. Key bindings are under Key Bindings > AddOns."])
    return -y + 50
end

local function OwnWindow()
    if not window then
        window = CreateFrame("Frame", "NullgatesWhoWhisperedMeOptions", UIParent, "BasicFrameTemplateWithInset")
        window:SetSize(400, 300)
        window:SetPoint("CENTER")
        window:SetMovable(true)
        window:EnableMouse(true)
        window:SetClampedToScreen(true)
        window:RegisterForDrag("LeftButton")
        window:SetScript("OnDragStart", window.StartMoving)
        window:SetScript("OnDragStop", window.StopMovingOrSizing)
        if type(window.SetTitle) == "function" then window:SetTitle(FULL_TITLE)
        elseif type(window.TitleText) == "table" then window.TitleText:SetText(FULL_TITLE) end
        local content = CreateFrame("Frame", nil, window)
        content:SetPoint("TOPLEFT", window, "TOPLEFT", 4, -26)
        content:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -4, 4)
        window:SetHeight(Options.Build(content) + 30)
        if UISpecialFrames then table.insert(UISpecialFrames, "NullgatesWhoWhisperedMeOptions") end
    end
    window:Show()
end

-- Opens the settings inside Nullgate's Addon Config when it's installed, otherwise in our own window.
function Options.Open(standalone)
    local hub = NullgatesAddonConfigForever
    if not standalone and hub and hub.ShowUI and hub.SelectModule and Options.registered then
        hub:ShowUI()
        hub:SelectModule(addonName)
    else
        OwnWindow()
    end
end

function Options.RegisterHub()
    local hub = NullgatesAddonConfigForever
    if Options.registered or not (hub and hub.RegisterModule and ns.db) then return end
    hub:RegisterModule(addonName, {
        name = FULL_TITLE,
        sidebarName = "Who Whispered Me",
        author = "Nullgate Studios",
        isNullgate = true,
        description = L["Lists everyone who whispers you while you form a group, with level and class."],
        db = ns.db,
        buildUI = function(container) Options.Build(container) end,
    })
    Options.registered = true
end
