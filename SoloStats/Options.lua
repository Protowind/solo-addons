-- SoloStats options panel. Built on first open. /ss or right-click the readout. Esc closes.

local _, ns = ...

local WIDTH = 420
local COL2 = 214   -- x of the second column
local ROW = 24

local panel
local checks = {}      -- checkboxes, each with :Sync()
local themed = {}      -- { fontstring, colour key } pairs recoloured on theme change
local choiceButtons = {}   -- layout and theme buttons, each with .isSelected()
local sizeText

local function Db() return SoloStatsDB end

local function Themed(fs, key)
    themed[#themed + 1] = { fs, key }
    return fs
end

local function Header(label, x, y)
    local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(label)
    return Themed(fs, "title")
end

local function CheckBox(label, x, y, get, set)
    local cb = CreateFrame("CheckButton", nil, panel)
    cb:SetSize(22, 22)
    cb:SetPoint("TOPLEFT", x - 2, y)
    cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")

    local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    fs:SetText(label)
    Themed(fs, "text")

    cb:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        ns.ApplyLook()
    end)
    cb.Sync = function(self) self:SetChecked(get()) end
    checks[#checks + 1] = cb
    return cb
end

local function Button(label, width, x, y, onClick)
    local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetPoint("TOPLEFT", x, y)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
end

-- A button that stays highlighted while its option is the current one
local function Choice(label, width, x, y, isSelected, onClick)
    local b = Button(label, width, x, y, onClick)
    b.isSelected = isSelected
    choiceButtons[#choiceButtons + 1] = b
    return b
end

local function LineCheck(line, x, y)
    local key = line.key
    CheckBox(line.label, x, y,
        function() return ns.IsOn(key) end,
        function(on) Db().lines[key] = on end)
end

local function Build()
    panel = CreateFrame("Frame", "SoloStatsOptions", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    panel:SetFrameStrata("DIALOG")
    panel:SetPoint("CENTER")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:Hide()
    tinsert(UISpecialFrames, "SoloStatsOptions")   -- Esc closes it

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText("SoloStats")
    Themed(title, "title")

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    -- Two columns: readout items left, info items right
    local top = -44
    Header("Readout", 16, top)
    Header("Info", COL2, top)
    local yLeft, yRight = top - 20, top - 20
    for _, line in ipairs(ns.LINES) do
        if line.info then
            LineCheck(line, COL2, yRight)
            yRight = yRight - ROW
        else
            LineCheck(line, 16, yLeft)
            yLeft = yLeft - ROW
        end
    end
    local y = math.min(yLeft, yRight) - 8

    Header("Layout", 16, y)
    y = y - 22
    for i, layout in ipairs(ns.LAYOUTS) do
        local key = layout.key
        Choice(layout.name, 124, 16 + (i - 1) * 130, y,
            function() return Db().layout == key end,
            function() ns.SetLayout(key) end)
    end
    y = y - 22 - 6

    -- Top bar text position
    local alignLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    alignLabel:SetPoint("TOPLEFT", 18, y - 4)
    alignLabel:SetText("Top bar text")
    Themed(alignLabel, "text")
    for i, align in ipairs(ns.ALIGNS) do
        local key = align.key
        Choice(align.name, 90, 130 + (i - 1) * 96, y,
            function() return Db().align == key end,
            function() ns.SetAlign(key) end)
    end
    y = y - 22 - 12

    Header("Display", 16, y)
    y = y - 20
    CheckBox("Show readout", 16, y, function() return Db().shown end, function(on) Db().shown = on end)
    CheckBox("Background", COL2, y, function() return Db().background end, function(on) Db().background = on end)
    y = y - ROW
    CheckBox("Lock position", 16, y, function() return Db().locked end, function(on) Db().locked = on end)
    y = y - ROW - 6

    -- Text size: - / + buttons (sliders vary too much between client versions)
    local sizeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sizeLabel:SetPoint("TOPLEFT", 18, y - 4)
    sizeLabel:SetText("Text size")
    Themed(sizeLabel, "text")
    local function Step(delta)
        local db = Db()
        db.size = math.max(6, math.min(32, (db.size or ns.DEFAULT_SIZE) + delta))
        ns.ApplyLook()
    end
    Button("-", 26, 110, y, function() Step(-1) end)
    sizeText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sizeText:SetPoint("TOPLEFT", 142, y - 4)
    sizeText:SetWidth(24)
    Themed(sizeText, "text")
    Button("+", 26, 170, y, function() Step(1) end)
    Button("Default", 64, 202, y, function() Db().size = nil; ns.ApplyLook() end)
    y = y - ROW - 10

    Header("Theme", 16, y)
    y = y - 22
    for i, key in ipairs(ns.THEME_ORDER) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        Choice(ns.THEMES[key].name, 190, 16 + col * 198, y - row * 26,
            function() return Db().theme == key end,
            function() Db().theme = key; ns.ApplyLook() end)
    end
    y = y - 2 * 26 - 12

    Button("Reset position", 190, 16, y, function() ns.ResetPosition() end)
    Button("Reset session", 190, 214, y, function() ns.ResetSession() end)
    y = y - 22 - 16

    panel:SetSize(WIDTH, -y)
end

function ns.SyncOptions()
    if not panel then return end
    local db = Db()
    local t = ns.Theme()

    panel:SetBackdrop(ns.BACKDROP)
    panel:SetBackdropColor(t.bg[1], t.bg[2], t.bg[3], 0.95)
    if t.border then
        panel:SetBackdropBorderColor(unpack(t.border))
    else
        panel:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    end
    for _, pair in ipairs(themed) do
        pair[1]:SetTextColor(ns.RGB(t[pair[2]]))
    end

    for _, cb in ipairs(checks) do cb:Sync() end
    sizeText:SetText(db.size or ns.DEFAULT_SIZE)
    for _, b in ipairs(choiceButtons) do
        if b.isSelected() then b:LockHighlight() else b:UnlockHighlight() end
    end
end

function ns.ToggleOptions()
    if not SoloStatsDB then return end
    if not panel then Build() end
    if panel:IsShown() then
        panel:Hide()
    else
        ns.SyncOptions()
        panel:Show()
    end
end
