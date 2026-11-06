-- SoloUI window: one place for every Solo addon. Each row shows whether the addon is loaded,
-- what it does, a button that opens its own options (its slash command) and an on/off tick
-- (takes effect after a reload). Below: the SoloUI unit frame settings.
-- /sui toggles the window.

local _, ns = ...

local ADDONS = {
    { "SoloStats", "SOLOSTATS", "/ss" }, { "SoloUI", nil, "/sui" }, { "SoloPlates", "SOLOPLATES", "/splates" },
    { "SoloMap", "SOLOMAP", "/smap" }, { "SoloLoot", "SOLOLOOT", "/sloot" }, { "SoloRoute", "SOLOROUTE", "/route" },
    { "SoloQuest", "SOLOQUEST", "/sq" }, { "SoloGear", "SOLOGEAR", "/sg" }, { "SoloSwing", "SOLOSWING", "/sw" },
    { "SoloCombo", "SOLOCOMBO", "/sc" }, { "SoloMeter", "SOLOMETER", "/meter" }, { "SoloPlus", "SOLOPLUS", "/sp" },
    { "SoloCoach", "SOLOCOACH", "/coach" }, { "SoloErrors", "SOLOERRORS", "/errors" },
}

local W, ROW = 640, 26
local GOLD = { 1, 0.82, 0 }
local reloadNeeded = false

local Loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
local Meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
local Enable = (C_AddOns and C_AddOns.EnableAddOn) or EnableAddOn
local Disable = (C_AddOns and C_AddOns.DisableAddOn) or DisableAddOn
local EnableState = (C_AddOns and C_AddOns.GetAddOnEnableState) or GetAddOnEnableState

local function IsEnabled(name)
    local ok, state = pcall(EnableState, name, UnitName("player"))
    if not ok then ok, state = pcall(EnableState, UnitName("player"), name) end   -- older argument order
    return ok and state and state > 0
end

local function Backdrop(f, bg, edge, edgeSize, inset)
    if not f.SetBackdrop then Mixin(f, BackdropTemplateMixin) end
    f:SetBackdrop({ bgFile = bg, edgeFile = edge, tile = true, tileSize = 16, edgeSize = edgeSize,
        insets = { left = inset, right = inset, top = inset, bottom = inset } })
end

-- Window ------------------------------------------------------------------

local frame = CreateFrame("Frame", "SoloUIFrame", UIParent, "BackdropTemplate")
local H = 112 + #ADDONS * ROW + 150
frame:SetSize(W, H)
frame:SetPoint("CENTER")
frame:SetFrameStrata("HIGH")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:SetClampedToScreen(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
Backdrop(frame, "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", "Interface\\DialogFrame\\UI-DialogBox-Border", 32, 8)
frame:Hide()
tinsert(UISpecialFrames, "SoloUIFrame")

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -6, -6)
local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 22, -18)
title:SetText("Solo addons")
local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
subtitle:SetPoint("LEFT", title, "RIGHT", 10, -1)
subtitle:SetText("one place for all of them")

local function Section(y, height, label)
    local p = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    p:SetPoint("TOPLEFT", 18, y)
    p:SetPoint("TOPRIGHT", -18, y)
    p:SetHeight(height)
    Backdrop(p, "Interface\\Tooltips\\UI-Tooltip-Background", "Interface\\Tooltips\\UI-Tooltip-Border", 14, 3)
    p:SetBackdropColor(0, 0, 0, 0.55)
    p:SetBackdropBorderColor(0.6, 0.5, 0.25, 0.9)
    local strip = p:CreateTexture(nil, "ARTWORK")
    strip:SetPoint("TOPLEFT", 4, -4)
    strip:SetPoint("TOPRIGHT", -4, -4)
    strip:SetHeight(20)
    strip:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.12)
    local text = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", strip, "LEFT", 6, 0)
    text:SetText(label)
    return p
end

local function SmallButton(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 20)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

local function Check(parent, label, get, set)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(24, 24)
    c.label = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.label:SetPoint("LEFT", c, "RIGHT", 2, 0)
    c.label:SetText(label)
    c:SetScript("OnShow", function(self) self:SetChecked(get()) end)
    c:SetScript("OnClick", function(self) set(self:GetChecked()) end)
    return c
end

-- Addon list ----------------------------------------------------------------

local listPanel = Section(-46, 30 + #ADDONS * ROW, "Addons   |cff999999tick = on for this character (after a reload)|r")
local rows = {}
local reloadButton

for i, a in ipairs(ADDONS) do
    local name, slashKey, slash = a[1], a[2], a[3]
    local r = CreateFrame("Frame", nil, listPanel)
    r:SetPoint("TOPLEFT", 6, -26 - (i - 1) * ROW)
    r:SetPoint("TOPRIGHT", -6, -26 - (i - 1) * ROW)
    r:SetHeight(ROW)
    local stripe = r:CreateTexture(nil, "BACKGROUND")
    stripe:SetAllPoints()
    stripe:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.035 or 0)
    r.check = Check(r, "", function() return IsEnabled(name) end, function(on)
        if name == "SoloUI" and not on then return end
        if on then Enable(name, UnitName("player")) else Disable(name, UnitName("player")) end
        reloadNeeded = true
        reloadButton:Show()
    end)
    r.check:SetPoint("LEFT", 0, 0)
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.name:SetPoint("LEFT", 28, 0)
    r.name:SetWidth(90)
    r.name:SetJustifyH("LEFT")
    r.name:SetText(name)
    r.notes = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.notes:SetPoint("LEFT", 122, 0)
    r.notes:SetPoint("RIGHT", -150, 0)
    r.notes:SetJustifyH("LEFT")
    r.notes:SetWordWrap(false)
    r.state = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.state:SetPoint("RIGHT", -96, 0)
    r.open = SmallButton(r, slash, 86, function()
        if name == "SoloUI" then return end
        local fn = slashKey and SlashCmdList[slashKey]
        if fn then fn("") end
    end)
    r.open:SetPoint("RIGHT", -2, 0)
    r.addon, r.slashKey = name, slashKey
    rows[i] = r
end

local function RefreshRows()
    for _, r in ipairs(rows) do
        local loaded = Loaded(r.addon)
        local notes = Meta(r.addon, "Notes") or ""
        notes = notes:gsub("%s*/%a+.*$", "")
        r.notes:SetText(notes)
        r.state:SetText(loaded and "|cff40ff40loaded|r" or "|cffff6060off|r")
        r.open:SetEnabled(loaded and r.slashKey ~= nil)
        r.check:SetChecked(IsEnabled(r.addon))
        r.check:SetEnabled(r.addon ~= "SoloUI")
    end
end

-- Unit frame settings ---------------------------------------------------------

local uf = Section(-46 - (30 + #ADDONS * ROW) - 8, 120, "Unit frames (SoloUI)")

local function Restart() reloadNeeded = true reloadButton:Show() end

local c1 = Check(uf, "Flat unit frames (player, target, target of target, party)",
    function() return ns.db.frames end, function(v) ns.db.frames = v Restart() end)
c1:SetPoint("TOPLEFT", 10, -28)
local c2 = Check(uf, "Hide Blizzard's player, target and party frames",
    function() return ns.db.hideBlizzard end, function(v) ns.db.hideBlizzard = v Restart() end)
c2:SetPoint("TOPLEFT", 10, -52)
local c3 = Check(uf, "Health numbers",
    function() return ns.db.healthText end, function(v) ns.db.healthText = v for _, f in pairs(ns.frames) do ns.UpdateAll(f) end end)
c3:SetPoint("TOPLEFT", 330, -28)
local c4 = Check(uf, "Class colours for players",
    function() return ns.db.classColour end, function(v) ns.db.classColour = v for _, f in pairs(ns.frames) do ns.UpdateAll(f) end end)
c4:SetPoint("TOPLEFT", 330, -52)

local scaleText = uf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
scaleText:SetPoint("TOPLEFT", 16, -88)
local function ShowScale() scaleText:SetText("Scale: " .. string.format("%.0f%%", ns.db.scale * 100)) end
local minus = SmallButton(uf, "-", 24, function()
    ns.db.scale = math.max(0.6, ns.db.scale - 0.05) ns.ApplyScale() ShowScale()
end)
minus:SetPoint("LEFT", scaleText, "RIGHT", 10, 0)
local plus = SmallButton(uf, "+", 24, function()
    ns.db.scale = math.min(1.6, ns.db.scale + 0.05) ns.ApplyScale() ShowScale()
end)
plus:SetPoint("LEFT", minus, "RIGHT", 4, 0)
local reset = SmallButton(uf, "Reset positions", 120, function() ns.ResetPositions() end)
reset:SetPoint("LEFT", plus, "RIGHT", 16, 0)
local hint = uf:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
hint:SetPoint("LEFT", reset, "RIGHT", 12, 0)
hint:SetText("Shift-drag a frame to move it")

reloadButton = SmallButton(frame, "Reload to apply", 130, function() ReloadUI() end)
reloadButton:SetPoint("BOTTOMRIGHT", -22, 16)
reloadButton:Hide()

local footer = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
footer:SetPoint("BOTTOMLEFT", 22, 20)
footer:SetText("/sui opens this window")

frame:SetScript("OnShow", function()
    RefreshRows()
    ShowScale()
    reloadButton:SetShown(reloadNeeded)
end)

-- Start ---------------------------------------------------------------------

SLASH_SOLOUI1 = "/sui"
SLASH_SOLOUI2 = "/soloui"
SlashCmdList.SOLOUI = function() frame:SetShown(not frame:IsShown()) end

local started = false
local function Start()
    if started then return end
    if InCombatLockdown() then return end   -- secure frames: wait for the end of combat
    started = true
    local ok, err = pcall(ns.StartFrames)
    if not ok then print("|cff40c0ffSoloUI|r: unit frames failed: " .. tostring(err)) end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "SoloUI" then
        SoloUIDB = SoloUIDB or {}
        ns.db = SoloUIDB
        for k, v in pairs(ns.DEFAULTS) do
            if ns.db[k] == nil then ns.db[k] = type(v) == "table" and {} or v end
        end
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_REGEN_ENABLED" then
        Start()
    end
end)
