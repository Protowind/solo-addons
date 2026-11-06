-- SoloLoot: dungeon and raid boss drops and item sets, in the style of AtlasLoot.
-- Data.lua is written by tools\lootdata.py: instances from the game tables (wago.tools), bosses and
-- their own drops from QuestieDB's Forever data, sets from the game's ItemSet table.
-- Pick an instance, then a boss. Item rows: hover for the tooltip, Shift-click to link in chat,
-- Ctrl-click to preview. A green + marks an upgrade (needs SoloGear).
-- Minimap button: click to open, drag to move. /sloot or /loot toggles; /sloot minimap shows or hides the button.

local W, H = 820, 520
local TOP, BOTTOM = 70, 48                 -- space above and below the panels
local PANEL_H = H - TOP - BOTTOM
local HEADER = 24                          -- panel title strip
local ROW, ITEM_ROW = 18, 36
local LIST_ROWS = math.floor((PANEL_H - HEADER - 8) / ROW)
local ITEM_ROWS = math.floor((PANEL_H - HEADER - 8) / ITEM_ROW)

local GOLD = { 1, 0.82, 0 }
local db
local tab = "dungeons"
local selInstance, selBoss, selSet = 1, 1, 1
local myClassOnly = true

-- Newer clients move these into C_Item; use whichever exists
local GetInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
local QualityColor = GetItemQualityColor or (C_Item and C_Item.GetItemQualityColor)

local function ClassMask()
    local _, _, classID = UnitClass("player")
    return classID and bit.lshift(1, classID - 1) or 0
end

local function Backdrop(f, bg, edge, edgeSize, inset)
    if not f.SetBackdrop then Mixin(f, BackdropTemplateMixin) end
    f:SetBackdrop({ bgFile = bg, edgeFile = edge, tile = true, tileSize = 16, edgeSize = edgeSize,
        insets = { left = inset, right = inset, top = inset, bottom = inset } })
end

-- Window ------------------------------------------------------------------

local frame = CreateFrame("Frame", "SoloLootFrame", UIParent, "BackdropTemplate")
frame:SetSize(W, H)
frame:SetPoint("CENTER")
frame:SetFrameStrata("HIGH")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:SetClampedToScreen(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    if db then db.pos = { point, relPoint, x, y } end
end)
Backdrop(frame, "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    "Interface\\DialogFrame\\UI-DialogBox-Border", 32, 8)
frame:Hide()
tinsert(UISpecialFrames, "SoloLootFrame")

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -6, -6)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 22, -18)
title:SetText("SoloLoot")
local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
subtitle:SetPoint("LEFT", title, "RIGHT", 10, -1)
subtitle:SetText("Dungeon and raid drops, item sets")

local footer = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
footer:SetPoint("BOTTOMLEFT", 22, 16)
footer:SetPoint("BOTTOMRIGHT", -22, 16)
footer:SetJustifyH("LEFT")
footer:SetText("Bosses, levels, notable loot: Data from ForeverDB.net (https://foreverdb.net). Drops: QuestieDB. "
    .. "|cffffd040Shift-click|r link  |cffffd040Ctrl-click|r preview  |cff33ff33+|r upgrade")

-- Panels ------------------------------------------------------------------

local function Panel(x, width, label)
    local p = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    p:SetPoint("TOPLEFT", x, -TOP)
    p:SetSize(width, PANEL_H)
    Backdrop(p, "Interface\\Tooltips\\UI-Tooltip-Background", "Interface\\Tooltips\\UI-Tooltip-Border", 14, 3)
    p:SetBackdropColor(0, 0, 0, 0.55)
    p:SetBackdropBorderColor(0.6, 0.5, 0.25, 0.9)
    local strip = p:CreateTexture(nil, "ARTWORK")
    strip:SetPoint("TOPLEFT", 4, -4)
    strip:SetPoint("TOPRIGHT", -4, -4)
    strip:SetHeight(HEADER - 4)
    strip:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.12)
    local line = p:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", strip, "BOTTOMLEFT")
    line:SetPoint("TOPRIGHT", strip, "BOTTOMRIGHT")
    line:SetHeight(1)
    line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.45)
    p.label = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    p.label:SetPoint("LEFT", strip, "LEFT", 6, 0)
    p.label:SetPoint("RIGHT", strip, "RIGHT", -6, 0)
    p.label:SetJustifyH("LEFT")
    p.label:SetWordWrap(false)
    p.label:SetText(label)
    return p
end

local panelA = Panel(18, 240, "Instances")
local panelB = Panel(264, 240, "Bosses")
local panelC = Panel(510, 292, "Loot")

-- Scrolling lists (mouse wheel) -------------------------------------------

local function MakeList(panel, rows, rowHeight, makeRow)
    local box = CreateFrame("Frame", nil, panel)
    box:SetPoint("TOPLEFT", 5, -(HEADER + 2))
    box:SetPoint("TOPRIGHT", -5, -(HEADER + 2))
    box:SetHeight(rows * rowHeight)
    box.rows, box.offset, box.data = {}, 0, {}
    local width = panel:GetWidth() - 10
    for i = 1, rows do
        local r = makeRow(box, width, rowHeight)
        r:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)
        r.stripe = r:CreateTexture(nil, "BACKGROUND", nil, -1)
        r.stripe:SetAllPoints()
        r.stripe:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.035 or 0)
        box.rows[i] = r
    end
    box:EnableMouseWheel(true)
    box:SetScript("OnMouseWheel", function(self, delta)
        local maxOff = math.max(0, #self.data - rows)
        self.offset = math.min(maxOff, math.max(0, self.offset - delta * 3))
        self:Refresh()
    end)
    return box
end

local function TextRow(box, width, height)
    local b = CreateFrame("Button", nil, box)
    b:SetSize(width, height)
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    b.sel = b:CreateTexture(nil, "BACKGROUND")
    b.sel:SetAllPoints()
    b.sel:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.22)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("LEFT", 6, 0)
    b.text:SetPoint("RIGHT", -40, 0)
    b.text:SetJustifyH("LEFT")
    b.text:SetWordWrap(false)
    b.right = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    b.right:SetPoint("RIGHT", -6, 0)
    b.rule = b:CreateTexture(nil, "ARTWORK")
    b.rule:SetPoint("BOTTOMLEFT", 4, 2)
    b.rule:SetPoint("BOTTOMRIGHT", -4, 2)
    b.rule:SetHeight(1)
    b.rule:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.35)
    return b
end

-- data rows: { text, right, selected, onClick } or { heading = "Raids" }
local function RefreshText(box)
    for i, b in ipairs(box.rows) do
        local d = box.data[i + box.offset]
        if d then
            if d.heading then
                b.text:SetText("|cffffd040" .. d.heading .. "|r")
                b.right:SetText("")
                b.sel:Hide()
                b.rule:Show()
                b:SetScript("OnClick", nil)
                b:EnableMouse(false)
            else
                b.text:SetText(d.text)
                b.right:SetText(d.right or "")
                b.sel:SetShown(d.selected or false)
                b.rule:Hide()
                b:SetScript("OnClick", d.onClick)
                b:EnableMouse(true)
            end
            b:Show()
        else
            b:Hide()
        end
    end
end

-- Item rows -----------------------------------------------------------------

local function ItemRow(box, width, height)
    local b = CreateFrame("Button", nil, box)
    b:SetSize(width, height)
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(height - 6, height - 6)
    b.icon:SetPoint("LEFT", 3, 0)
    b.border = b:CreateTexture(nil, "OVERLAY")
    b.border:SetPoint("TOPLEFT", b.icon, -1, 1)
    b.border:SetPoint("BOTTOMRIGHT", b.icon, 1, -1)
    b.border:SetColorTexture(1, 1, 1, 0)
    b.border:SetDrawLayer("BORDER")
    b.name = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.name:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 7, -2)
    b.name:SetPoint("RIGHT", -20, 0)
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)
    b.sub = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    b.sub:SetPoint("BOTTOMLEFT", b.icon, "BOTTOMRIGHT", 7, 2)
    b.sub:SetJustifyH("LEFT")
    b.mark = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    b.mark:SetTextColor(0.2, 1, 0.2)
    b.mark:SetPoint("RIGHT", -6, 0)
    b.mark:SetText("+")
    b:SetScript("OnEnter", function(self)
        if not self.itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.itemID)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self)
        local link = self.itemID and select(2, GetInfo(self.itemID))
        if not link then return end
        if IsShiftKeyDown() then
            ChatEdit_InsertLink(link)
        elseif IsControlKeyDown() and DressUpItemLink then
            DressUpItemLink(link)
        end
    end)
    return b
end

local function SlotName(loc) return loc and loc ~= "" and _G[loc] or nil end

local function RefreshItems(box)
    for i, b in ipairs(box.rows) do
        local id = box.data[i + box.offset]
        b.itemID = id
        if id then
            local name, link, quality, ilvl, req, _, _, _, equipLoc, icon = GetInfo(id)
            b.icon:SetTexture(icon or (GetIcon and GetIcon(id)) or "Interface\\Icons\\INV_Misc_QuestionMark")
            if name then
                local r, g, bl = QualityColor(quality or 1)
                b.name:SetText(name)
                b.name:SetTextColor(r, g, bl)
                b.border:SetColorTexture(r, g, bl, 0.8)
                local bits = { "ilvl " .. (ilvl or "?") }
                if req and req > 0 then bits[#bits + 1] = "req " .. req end
                local slot = SlotName(equipLoc)
                if slot then bits[#bits + 1] = slot end
                b.sub:SetText(table.concat(bits, ", "))
                local up = SoloGear_Compare and select(2, pcall(SoloGear_Compare, link))
                b.mark:SetShown(type(up) == "number" and up > 0)
            else
                b.name:SetText("Loading item " .. id .. "...")
                b.name:SetTextColor(0.6, 0.6, 0.6)
                b.border:SetColorTexture(1, 1, 1, 0)
                b.sub:SetText("")
                b.mark:Hide()
                if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
            end
            b:Show()
        else
            b:Hide()
        end
    end
end

-- Columns ---------------------------------------------------------------------

local colA = MakeList(panelA, LIST_ROWS, ROW, TextRow)
colA.Refresh = RefreshText
local colB = MakeList(panelB, LIST_ROWS - 3, ROW, TextRow)
colB.Refresh = RefreshText
local colItems = MakeList(panelC, ITEM_ROWS, ITEM_ROW, ItemRow)
colItems.Refresh = RefreshItems

-- Entrance (bottom of the boss panel) ---------------------------------------
-- Classic instances: the Map table's corpse point (just outside the entrance), turned into zone
-- coordinates by the client. New Forever dungeons: Blizzard's description only.

local entrance = CreateFrame("Frame", nil, panelB)
entrance:SetPoint("BOTTOMLEFT", 5, 5)
entrance:SetPoint("BOTTOMRIGHT", -5, 5)
entrance:SetHeight(48)
local entLine = entrance:CreateTexture(nil, "ARTWORK")
entLine:SetPoint("TOPLEFT")
entLine:SetPoint("TOPRIGHT")
entLine:SetHeight(1)
entLine:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.35)
local entText = entrance:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
entText:SetPoint("TOPLEFT", 6, -6)
entText:SetPoint("RIGHT", -6, 0)
entText:SetJustifyH("LEFT")
entText:SetSpacing(2)
local entButton = CreateFrame("Button", nil, entrance, "UIPanelButtonTemplate")
entButton:SetSize(110, 20)
entButton:SetPoint("BOTTOMRIGHT", -2, 2)
entButton:SetText("Show on map")

local function EntranceSpot(inst)
    local e = inst and inst.entrance
    if not (e and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return end
    local world = CreateVector2D(e[2], e[3])
    local ok, mapID, pos = pcall(C_Map.GetMapPosFromWorldPos, e[1], world)
    if not (ok and mapID and pos) then return end
    -- Narrow a continent answer down to the zone at that spot
    local x, y = pos:GetXY()
    local child = C_Map.GetMapInfoAtPosition and C_Map.GetMapInfoAtPosition(mapID, x, y)
    if child and child.mapID and child.mapID ~= mapID then
        local ok2, _, zpos = pcall(C_Map.GetMapPosFromWorldPos, e[1], world, child.mapID)
        if ok2 and zpos then mapID, pos = child.mapID, zpos x, y = pos:GetXY() end
    end
    local info = C_Map.GetMapInfo(mapID)
    return mapID, x, y, info and info.name or "?"
end

local function ShowEntrance(inst)
    local mapID, x, y, zone = EntranceSpot(inst)
    if mapID then
        entText:SetText("|cffffd040Entrance|r  " .. zone .. string.format("  %.1f, %.1f", x * 100, y * 100))
        entButton:Show()
        entButton:SetScript("OnClick", function()
            if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(mapID) then
                print("|cff40c0ffSoloLoot|r: this map takes no pin") return
            end
            local ok = pcall(function()
                C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
                if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
            end)
            print("|cff40c0ffSoloLoot|r: " .. (ok and ("pin set: " .. inst.name .. ", " .. zone .. string.format(" %.1f, %.1f", x * 100, y * 100))
                or "could not set a map pin here"))
        end)
    elseif inst and inst.where then
        entText:SetText("|cffffd040Entrance|r  " .. inst.where .. "\n|cff999999(Blizzard's description; no exact spot yet)|r")
        entButton:Hide()
    else
        entText:SetText("|cffffd040Entrance|r  |cff999999unknown|r")
        entButton:Hide()
    end
end

local emptyText = panelC:CreateFontString(nil, "OVERLAY", "GameFontDisable")
emptyText:SetPoint("TOPLEFT", 12, -(HEADER + 14))
emptyText:SetPoint("RIGHT", -12, 0)
emptyText:SetJustifyH("LEFT")

local classCheck = CreateFrame("CheckButton", nil, panelB, "UICheckButtonTemplate")
classCheck:SetSize(24, 24)
classCheck:SetPoint("TOPLEFT", 8, -(HEADER + 6))
classCheck.label = classCheck:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
classCheck.label:SetPoint("LEFT", classCheck, "RIGHT", 2, 0)
classCheck.label:SetText("Only sets my class can wear")
local setInfo = panelB:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
setInfo:SetPoint("TOPLEFT", 14, -(HEADER + 40))
setInfo:SetPoint("RIGHT", -14, 0)
setInfo:SetJustifyH("LEFT")
setInfo:SetSpacing(3)

local Refresh

local function LevelText(lo, hi)
    if lo == hi then return tostring(lo) end
    return lo .. "-" .. hi
end

local function BuildDungeons()
    local data, heading = {}, nil
    for i, inst in ipairs(SoloLootInstances) do
        local h = inst.announced == false and "Not announced for Forever yet" or (inst.raid and "Raids" or "Dungeons")
        if h ~= heading then
            data[#data + 1] = { heading = h }
            heading = h
        end
        local name = inst.name
        if inst.new then name = name .. " |cff40ff40new|r" end
        if inst.announced == false then name = "|cff9d9d9d" .. inst.name .. "|r" end
        data[#data + 1] = {
            text = name, right = LevelText(inst.min, inst.max), selected = i == selInstance,
            onClick = function() selInstance, selBoss = i, 1 colB.offset, colItems.offset = 0, 0 Refresh() end,
        }
    end
    colA.data = data

    local inst = SoloLootInstances[selInstance]
    local bosses = {}
    for j, boss in ipairs(inst and inst.bosses or {}) do
        local notable = boss[1] == 0 and boss[2]:find("^Notable")
        bosses[#bosses + 1] = {
            text = notable and ("|cff66ccff" .. boss[2] .. "|r") or boss[2],
            right = #boss[4] == 0 and "|cff777777?|r" or (boss[3] > 0 and tostring(boss[3]) or ""),
            selected = j == selBoss,
            onClick = function() selBoss = j colItems.offset = 0 Refresh() end,
        }
    end
    colB.data = bosses
    local boss = inst and inst.bosses[selBoss]
    colItems.data = boss and boss[4] or {}
    ShowEntrance(inst)
    panelA.label:SetText("Instances")
    panelB.label:SetText(inst and (inst.name .. "  |cff999999" .. LevelText(inst.min, inst.max) .. "|r") or "Bosses")
    panelC.label:SetText(boss and boss[2] or "Loot")
    emptyText:SetText(boss and #boss[4] == 0 and "No loot for this boss in the data yet." or "")
end

local function VisibleSets()
    local mask, out = ClassMask(), {}
    for _, s in ipairs(SoloLootSets) do
        if not myClassOnly or s[4] == 0 or bit.band(s[4], mask) ~= 0 then out[#out + 1] = s end
    end
    return out
end

local function BuildSets()
    local sets = VisibleSets()
    if selSet > #sets then selSet = 1 end
    local data = {}
    for i, s in ipairs(sets) do
        data[#data + 1] = {
            text = s[2], right = s[3] > 0 and tostring(s[3]) or "", selected = i == selSet,
            onClick = function() selSet = i colItems.offset = 0 Refresh() end,
        }
    end
    colA.data = data
    colB.data = {}
    local s = sets[selSet]
    colItems.data = s and s[5] or {}
    panelA.label:SetText("Item sets  |cff999999" .. #sets .. "|r")
    panelB.label:SetText("Filter")
    panelC.label:SetText(s and s[2] or "Pieces")
    setInfo:SetText(s and ("|cffffd040" .. s[2] .. "|r\n" .. #s[5] .. " pieces"
        .. (s[3] > 0 and (", requires level " .. s[3]) or "")
        .. "\n\nHover a piece to see the set bonuses.") or "")
    emptyText:SetText(#sets == 0 and "No sets." or "")
end

-- Tabs ----------------------------------------------------------------------

local tabs = {}
local function StyleTabs()
    for key, b in pairs(tabs) do
        local on = key == tab
        b.bg:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], on and 0.28 or 0.06)
        b.text:SetTextColor(on and 1 or 0.75, on and 0.82 or 0.75, on and 0 or 0.75)
    end
end

function Refresh()
    if tab == "dungeons" then BuildDungeons() else BuildSets() end
    entrance:SetShown(tab == "dungeons")
    classCheck:SetShown(tab == "sets")
    setInfo:SetShown(tab == "sets")
    colB:SetShown(tab == "dungeons")
    StyleTabs()
    colA:Refresh()
    colB:Refresh()
    colItems:Refresh()
end

local function TabButton(text, x, key)
    local b = CreateFrame("Button", nil, frame, "BackdropTemplate")
    b:SetSize(120, 24)
    b:SetPoint("TOPLEFT", x, -40)
    Backdrop(b, nil, "Interface\\Tooltips\\UI-Tooltip-Border", 10, 2)
    b:SetBackdropBorderColor(0.6, 0.5, 0.25, 0.9)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetPoint("TOPLEFT", 2, -2)
    b.bg:SetPoint("BOTTOMRIGHT", -2, 2)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.text:SetPoint("CENTER")
    b.text:SetText(text)
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    b:SetScript("OnClick", function()
        tab = key
        colA.offset, colItems.offset = 0, 0
        Refresh()
    end)
    tabs[key] = b
end
TabButton("Dungeons", 18, "dungeons")
TabButton("Item sets", 144, "sets")

classCheck:SetScript("OnClick", function(self)
    myClassOnly = self:GetChecked()
    selSet, colA.offset = 1, 0
    Refresh()
end)

-- Minimap button --------------------------------------------------------------

local mini = CreateFrame("Button", "SoloLootMinimapButton", Minimap)
mini:SetSize(31, 31)
mini:SetFrameStrata("MEDIUM")
mini:SetFrameLevel(8)
mini:RegisterForClicks("LeftButtonUp", "RightButtonUp")
mini:RegisterForDrag("LeftButton")
mini:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
local miniBg = mini:CreateTexture(nil, "BACKGROUND")
miniBg:SetSize(20, 20)
miniBg:SetPoint("TOPLEFT", 7, -5)
miniBg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
local miniIcon = mini:CreateTexture(nil, "ARTWORK")
miniIcon:SetSize(17, 17)
miniIcon:SetPoint("TOPLEFT", 7, -6)
miniIcon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10_Red")
miniIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
local miniBorder = mini:CreateTexture(nil, "OVERLAY")
miniBorder:SetSize(53, 53)
miniBorder:SetPoint("TOPLEFT")
miniBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local function PlaceMini()
    local angle = math.rad(db and db.minimapAngle or 200)
    local radius = (Minimap:GetWidth() / 2) + 5
    mini:ClearAllPoints()
    mini:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

mini:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        db.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
        PlaceMini()
    end)
end)
mini:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
mini:SetScript("OnClick", function() frame:SetShown(not frame:IsShown()) end)
mini:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("SoloLoot")
    GameTooltip:AddLine("Click: dungeon drops and item sets", 1, 1, 1)
    GameTooltip:AddLine("Drag: move this button", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)
mini:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Start ---------------------------------------------------------------------

-- Open on the dungeon that fits your level
local function PickInstance()
    local level = UnitLevel("player")
    for i, inst in ipairs(SoloLootInstances) do
        if not inst.raid and inst.max >= level then
            selInstance = i
            colA.offset = math.max(0, i - 3)
            return
        end
    end
end

local pending = false
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "SoloLoot" then
        SoloLootDB = SoloLootDB or {}
        db = SoloLootDB
        if db.pos then
            self:ClearAllPoints()
            self:SetPoint(db.pos[1], UIParent, db.pos[2], db.pos[3], db.pos[4])
        end
        PlaceMini()
        mini:SetShown(not db.hideMinimap)
        classCheck:SetChecked(myClassOnly)
        PickInstance()
        self:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    elseif event == "GET_ITEM_INFO_RECEIVED" and self:IsShown() and not pending then
        pending = true
        C_Timer.After(0.2, function() pending = false colItems:Refresh() end)
    end
end)
frame:SetScript("OnShow", Refresh)

SLASH_SOLOLOOT1 = "/sloot"
SLASH_SOLOLOOT2 = "/loot"
SlashCmdList.SOLOLOOT = function(msg)
    msg = (msg or ""):lower():match("^%s*(%S*)")
    if msg == "minimap" then
        db.hideMinimap = not db.hideMinimap
        mini:SetShown(not db.hideMinimap)
        print("|cff40c0ffSoloLoot|r: minimap button " .. (db.hideMinimap and "hidden" or "shown"))
    else
        frame:SetShown(not frame:IsShown())
    end
end
