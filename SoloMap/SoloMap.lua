-- SoloMap: world map extras.
-- 1. Coordinates: your position and the cursor's, under the map.
-- 2. Flight masters: every one for your faction (Data.lua, from the game tables). Coloured when
--    known, grey when not. Known ones are learned when you open a flight map or find a new path.
-- 3. Services: vendors, repair, trainers, innkeepers, bank, auction house, mailboxes. Saved
--    (account-wide) each time you use one, then shown on that map.
-- 4. Fog: unexplored parts of the map drawn dimmed (Data.lua overlays).
-- 5. Copy: click the coordinate bar (or /smap copy) for your position, right-click for the
--    cursor's last spot on the map. Shown selected in a box: press Ctrl+C.
-- /smap: status; /smap coords | flights | services | fog (toggle) | copy | list | clear

local DEFAULTS = { coords = true, flights = true, services = true, fog = true }
local PIN = "SoloMapPinTemplate"
local NEAR = 80                      -- yards: flight master you are standing at

local db, char, side
local provider, fogPins = nil, {}

local function Print(msg) print("|cff40c0ffSoloMap|r: " .. msg) end

local function Secret(v) return issecretvalue and issecretvalue(v) end

-- Map geometry ------------------------------------------------------------

-- World bounds of a map: continent, top (world X), left (world Y), bottom, right
local bounds = {}
local function Bounds(mapID)
    if bounds[mapID] ~= nil then return bounds[mapID] end
    local b = false
    if C_Map.GetWorldPosFromMapPos and CreateVector2D then
        local cont, tl = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(0, 0))
        local _, br = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(1, 1))
        if cont and tl and br then
            local top, left = tl:GetXY()
            local bottom, right = br:GetXY()
            if top ~= bottom and left ~= right then b = { cont, top, left, bottom, right } end
        end
    end
    bounds[mapID] = b
    return b
end

-- World position to 0-1 map position, nil when off this map
local function ToMap(mapID, cont, wx, wy)
    local b = Bounds(mapID)
    if not b or b[1] ~= cont then return end
    local x = (b[3] - wy) / (b[3] - b[5])
    local y = (b[2] - wx) / (b[2] - b[4])
    if x >= 0 and x <= 1 and y >= 0 and y <= 1 then return x, y end
end

local function PlayerPos()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return end
    local x, y = pos:GetXY()
    if Secret(x) or not x or (x == 0 and y == 0) then return end
    return mapID, x, y, pos
end

local function PlayerWorld()
    local mapID, _, _, pos = PlayerPos()
    if not mapID or not C_Map.GetWorldPosFromMapPos then return end
    local cont, w = C_Map.GetWorldPosFromMapPos(mapID, pos)
    if not (cont and w) then return end
    local wx, wy = w:GetXY()
    return cont, wx, wy
end

-- Flight masters ------------------------------------------------------------

local function OurNode(n) return n[6] == "B" or n[6] == side end

local function Known(n) return char.known[n[1]] or char.knownName[n[2]] end

local function MarkNearest()
    local cont, wx, wy = PlayerWorld()
    if not cont then return end
    local best, bestD
    for _, n in ipairs(SoloMapTaxi) do
        if n[3] == cont and OurNode(n) then
            local d = math.sqrt((n[4] - wx) ^ 2 + (n[5] - wy) ^ 2)
            if not bestD or d < bestD then best, bestD = n, d end
        end
    end
    if best and bestD <= NEAR and not char.known[best[1]] then
        char.known[best[1]] = true
        return best
    end
end

local function ReadTaxiMap()
    if C_TaxiMap and C_TaxiMap.GetAllTaxiNodes then
        local mapID = (GetTaxiMapID and GetTaxiMapID()) or C_Map.GetBestMapForUnit("player")
        local ok, nodes = pcall(C_TaxiMap.GetAllTaxiNodes, mapID)
        if ok and type(nodes) == "table" then
            for _, node in ipairs(nodes) do
                if node.nodeID and node.state ~= 2 then char.known[node.nodeID] = true end   -- 2 = unreachable
            end
        end
    end
    if NumTaxiNodes then
        for i = 1, NumTaxiNodes() do
            local kind = TaxiNodeGetType(i)
            if kind == "CURRENT" or kind == "REACHABLE" then char.knownName[TaxiNodeName(i)] = true end
        end
    end
    MarkNearest()
end

-- Services ------------------------------------------------------------------

local scan = CreateFrame("GameTooltip", "SoloMapScan", nil, "GameTooltipTemplate")

local function Subtitle()
    scan:SetOwner(WorldFrame, "ANCHOR_NONE")
    scan:SetUnit("npc")
    local line = _G.SoloMapScanTextLeft2 and _G.SoloMapScanTextLeft2:GetText()
    scan:Hide()
    if not line or Secret(line) or line:find(LEVEL or "Level") then return end
    return line
end

local function NpcID()
    local guid = UnitGUID("npc")
    if not guid or Secret(guid) then return end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind == "Creature" then return tonumber(id) end
end

local function Record(kind, npc)
    local mapID, x, y = PlayerPos()
    if not mapID then return end
    local entry = { map = mapID, x = x, y = y, kind = kind, side = side }
    local key
    if npc then
        local name = UnitName("npc")
        if not name or Secret(name) then return end
        entry.name, entry.sub = name, Subtitle()
        key = (NpcID() or name) .. ":" .. mapID
    else
        key = kind .. ":" .. mapID .. ":" .. math.floor(x * 200) .. ":" .. math.floor(y * 200)
    end
    if entry.sub == "Flight Master" then return end   -- drawn from Data.lua already
    local isNew = not db.places[key]
    db.places[key] = entry
    if isNew and provider then provider:RefreshAllData() end
end

local function OnGossip()
    local sub = UnitExists("npc") and Subtitle()
    if not sub then return end
    if sub:find("Innkeeper") then Record("inn", true)
    elseif sub:find("Stable") then Record("stable", true)
    else Record("other", true) end
end

-- Icons ---------------------------------------------------------------------

local T = "Interface\\Minimap\\Tracking\\"
local ICONS = {
    flight = T .. "FlightMaster", repair = T .. "Repair", inn = T .. "Innkeeper",
    bank = T .. "Banker", auction = T .. "Auctioneer", mail = T .. "Mailbox",
    stable = T .. "StableMaster", class = T .. "Class", profession = T .. "Profession",
    poison = T .. "Poisons", food = T .. "Food",
    vendor = "Interface\\GossipFrame\\VendorGossipIcon",
    other = "Interface\\GossipFrame\\GossipGossipIcon",
}
local LABELS = {
    repair = "Repair", inn = "Innkeeper", bank = "Bank", auction = "Auction House", mail = "Mailbox",
    stable = "Stable Master", vendor = "Vendor", trainer = "Trainer", other = "",
}

local function IsClassTrainer(sub)
    if not sub then return false end
    for _, name in pairs(LOCALIZED_CLASS_NAMES_MALE or {}) do
        if sub:find(name) then return true end
    end
    return false
end

local function PlaceIcon(p)
    local sub = p.sub or ""
    if p.kind == "trainer" then return IsClassTrainer(p.sub) and ICONS.class or ICONS.profession end
    if p.kind == "vendor" then
        if sub:find("Poison") then return ICONS.poison end
        if sub:find("Food") or sub:find("Drink") or sub:find("Bak") or sub:find("Butcher") then return ICONS.food end
    end
    return ICONS[p.kind] or ICONS.other
end

-- Map pins ------------------------------------------------------------------

SoloMapPinMixin = SoloMapPinMixin or {}
local Pin = SoloMapPinMixin

function Pin:OnLoad()
    if self.ready then return end
    self.ready = true
    if self.UseFrameLevelType then self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI") end
    if self.SetScalingLimits then self:SetScalingLimits(1, 1.0, 1.2) end
end

function Pin:OnAcquired(info)
    self:OnLoad()
    self.info = info
    self:SetSize(info.size, info.size)
    self.Icon:SetTexture(info.icon)
    self.Icon:SetDesaturated(info.grey or false)
    self.Icon:SetAlpha(info.grey and 0.75 or 1)
    self:SetPosition(info.x, info.y)
end

function Pin:OnMouseEnter()
    local info = self.info
    if not info then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(info.title, 1, 1, 1)
    if info.sub and info.sub ~= "" then GameTooltip:AddLine(info.sub, 1, 0.82, 0) end
    if info.note then GameTooltip:AddLine(info.note, info.noteR or 0.7, info.noteG or 0.7, info.noteB or 0.7) end
    GameTooltip:AddLine(string.format("%.1f, %.1f", info.x * 100, info.y * 100), 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

function Pin:OnMouseLeave() GameTooltip:Hide() end

local function AddFlights(map, mapID)
    for _, n in ipairs(SoloMapTaxi) do
        if OurNode(n) then
            local x, y = ToMap(mapID, n[3], n[4], n[5])
            if x then
                local known = Known(n)
                local place = n[2]:match("^[^,]+") or n[2]
                map:AcquirePin(PIN, {
                    x = x, y = y, size = 18, icon = ICONS.flight, grey = not known,
                    title = place, sub = "Flight Master",
                    note = known and "Known" or "Not known yet",
                    noteR = known and 0.25 or 1, noteG = known and 1 or 0.4, noteB = known and 0.25 or 0.4,
                })
            end
        end
    end
end

local function AddPlaces(map, mapID)
    for _, p in pairs(db.places) do
        if p.map == mapID and (p.side == nil or p.side == side) then
            map:AcquirePin(PIN, {
                x = p.x, y = p.y, size = 16, icon = PlaceIcon(p),
                title = p.name or LABELS[p.kind] or p.kind,
                sub = p.sub or (p.name and LABELS[p.kind]) or nil,
            })
        end
    end
end

local function MakeProvider()
    provider = CreateFromMixins(MapCanvasDataProviderMixin)
    function provider:RemoveAllData() self:GetMap():RemoveAllPinsByTemplate(PIN) end
    function provider:RefreshAllData()
        self:RemoveAllData()
        local map = self:GetMap()
        local mapID = map and map:GetMapID()
        if not mapID then return end
        if db.flights then AddFlights(map, mapID) end
        if db.services then AddPlaces(map, mapID) end
    end
    WorldMapFrame:AddDataProvider(provider)
end

-- Fog (unexplored areas) ----------------------------------------------------

local function Reveal(pin)
    local tex = fogPins[pin]
    if not tex then tex = {} fogPins[pin] = tex end
    for _, t in ipairs(tex) do t:Hide() end
    if not db.fog then return end
    local map = pin:GetMap()
    local mapID = map and map:GetMapID()
    if not mapID then return end
    local zone = SoloMapReveal[C_Map.GetMapArtID(mapID) or 0]
    if not zone then return end

    local explored = {}
    for _, e in ipairs(C_MapExplorationInfo.GetExploredMapTextures(mapID) or {}) do
        explored[e.textureWidth .. ":" .. e.textureHeight .. ":" .. e.offsetX .. ":" .. e.offsetY] = true
    end
    local layers = C_Map.GetMapArtLayers(mapID)
    local layer = layers and layers[map:GetCanvasContainer():GetCurrentLayerIndex()]
    if not layer then return end
    local TW, TH = layer.tileWidth, layer.tileHeight

    local used = 0
    for key, files in pairs(zone) do
        if not explored[key] then
            local w, h, ox, oy = strsplit(":", key)
            w, h, ox, oy = tonumber(w), tonumber(h), tonumber(ox), tonumber(oy)
            local ids = { strsplit(",", files) }
            local nw, nh = math.ceil(w / TW), math.ceil(h / TH)
            for j = 1, nh do
                local ph, fh = TH, TH
                if j == nh then
                    ph = h % TH
                    if ph == 0 then ph = TH end
                    fh = 16
                    while fh < ph do fh = fh * 2 end
                end
                for k = 1, nw do
                    local pw, fw = TW, TW
                    if k == nw then
                        pw = w % TW
                        if pw == 0 then pw = TW end
                        fw = 16
                        while fw < pw do fw = fw * 2 end
                    end
                    local id = tonumber(ids[(j - 1) * nw + k])
                    if id then
                        used = used + 1
                        local t = tex[used]
                        if not t then
                            t = pin:CreateTexture(nil, "ARTWORK")
                            tex[used] = t
                        end
                        t:ClearAllPoints()
                        t:SetSize(pw, ph)
                        t:SetTexCoord(0, pw / fw, 0, ph / fh)
                        t:SetPoint("TOPLEFT", ox + TW * (k - 1), -(oy + TH * (j - 1)))
                        t:SetTexture(id, nil, nil, "TRILINEAR")
                        t:SetVertexColor(0.55, 0.55, 0.55)
                        t:Show()
                    end
                end
            end
        end
    end
end

local hookedMixin = false
local function HookFog()
    if not hookedMixin and MapExplorationPinMixin and MapExplorationPinMixin.RefreshOverlays then
        hooksecurefunc(MapExplorationPinMixin, "RefreshOverlays", Reveal)
        hookedMixin = true
    end
    if not WorldMapFrame.EnumeratePinsByTemplate then return end
    for pin in WorldMapFrame:EnumeratePinsByTemplate("MapExplorationPinTemplate") do
        if not pin.soloMapHooked then
            pin.soloMapHooked = true
            -- Pins made before the mixin hook keep the old function: hook them directly
            if not (hookedMixin and pin.RefreshOverlays == MapExplorationPinMixin.RefreshOverlays) then
                hooksecurefunc(pin, "RefreshOverlays", Reveal)
            end
        end
    end
end

local function RefreshFog()
    HookFog()
    if not WorldMapFrame.EnumeratePinsByTemplate then return end
    for pin in WorldMapFrame:EnumeratePinsByTemplate("MapExplorationPinTemplate") do
        pcall(pin.RefreshOverlays, pin, true)
    end
end

-- Copy box (addons cannot write to the clipboard: show the text selected, you press Ctrl+C)

local copyBox
local function ShowCopy(text)
    if not copyBox then
        copyBox = CreateFrame("Frame", "SoloMapCopy", UIParent)
        copyBox:SetFrameStrata("DIALOG")
        copyBox:SetSize(300, 58)
        copyBox:SetPoint("CENTER", 0, 120)
        local bg = copyBox:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.85)
        local hint = copyBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("TOP", 0, -6)
        hint:SetText("Ctrl+C to copy, Esc to close")
        local edit = CreateFrame("EditBox", nil, copyBox, "InputBoxTemplate")
        edit:SetSize(270, 20)
        edit:SetPoint("BOTTOM", 0, 8)
        edit:SetAutoFocus(false)
        edit:SetScript("OnEscapePressed", function() copyBox:Hide() end)
        edit:SetScript("OnEnterPressed", function() copyBox:Hide() end)
        edit:SetScript("OnKeyUp", function(_, key)
            if key == "C" and IsControlKeyDown() then
                copyBox:Hide()
                Print("copied")
            end
        end)
        edit:SetScript("OnTextChanged", function(self, user)
            if user then self:SetText(copyBox.text) self:HighlightText() end   -- read-only
        end)
        copyBox.edit = edit
        copyBox:SetScript("OnHide", function() edit:ClearFocus() end)
    end
    copyBox.text = text
    copyBox:Show()
    copyBox.edit:SetText(text)
    copyBox.edit:SetFocus()
    copyBox.edit:HighlightText()
end

local function PlaceText(mapID, x, y)
    local info = mapID and C_Map.GetMapInfo(mapID)
    return string.format("%s%.1f, %.1f", info and (info.name .. " ") or "", x * 100, y * 100)
end

local function CopyPlayer()
    local mapID, x, y = PlayerPos()
    if mapID then ShowCopy(PlaceText(mapID, x, y)) else Print("no position here") end
end

-- Coordinates ---------------------------------------------------------------

local lastCursor   -- { mapID, x, y }: last spot the cursor was on the map
local coordFrame
local function MakeCoords()
    local sc = WorldMapFrame.ScrollContainer or WorldMapFrame
    coordFrame = CreateFrame("Frame", nil, sc)
    coordFrame:SetFrameStrata("HIGH")
    coordFrame:SetSize(320, 20)
    coordFrame:SetPoint("BOTTOM", sc, "BOTTOM", 0, 4)
    local bg = coordFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.55)
    local text = coordFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER")
    local wait = 0
    coordFrame:SetScript("OnUpdate", function(_, elapsed)
        wait = wait - elapsed
        if wait > 0 then return end
        wait = 0.1
        local mapID = WorldMapFrame:GetMapID()
        local you = "--"
        local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
        if pos then
            local x, y = pos:GetXY()
            if x and not Secret(x) and (x > 0 or y > 0) then you = string.format("%.1f, %.1f", x * 100, y * 100) end
        end
        local cursor = "--"
        if sc.GetNormalizedCursorPosition and sc:IsMouseOver() then
            local x, y = sc:GetNormalizedCursorPosition()
            if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                cursor = string.format("%.1f, %.1f", x * 100, y * 100)
                lastCursor = { mapID, x, y }
            end
        end
        text:SetText("You: |cffffffff" .. you .. "|r     Cursor: |cffffffff" .. cursor .. "|r")
        coordFrame:SetWidth(text:GetStringWidth() + 24)
    end)
    coordFrame:EnableMouse(true)
    coordFrame:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            if lastCursor then ShowCopy(PlaceText(lastCursor[1], lastCursor[2], lastCursor[3])) end
        else
            CopyPlayer()
        end
    end)
    coordFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Click: copy your position", 1, 1, 1)
        GameTooltip:AddLine("Right-click: copy the last spot the cursor was on the map", 1, 1, 1)
        GameTooltip:Show()
    end)
    coordFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    coordFrame:SetShown(db.coords)
end

-- Setup and commands ---------------------------------------------------------

local function Setup()
    if provider or not WorldMapFrame then return end
    for k, v in pairs(MapCanvasPinMixin or {}) do
        if Pin[k] == nil then Pin[k] = v end
    end
    local ok, err = pcall(MakeProvider)
    if not ok then Print("map icons failed: " .. tostring(err)) end
    ok, err = pcall(MakeCoords)
    if not ok then Print("coordinates failed: " .. tostring(err)) end
    ok, err = pcall(HookFog)
    if not ok then Print("fog failed: " .. tostring(err)) end
    WorldMapFrame:HookScript("OnShow", function() pcall(HookFog) end)
end

local function Refresh()
    if provider then provider:RefreshAllData() end
    if coordFrame then coordFrame:SetShown(db.coords) end
    pcall(RefreshFog)
end

local function OnOff(v) return v and "|cff40ff40on|r" or "|cffff4040off|r" end

SLASH_SOLOMAP1 = "/smap"
SlashCmdList.SOLOMAP = function(msg)
    msg = (msg or ""):lower():match("^%s*(%S*)")
    if DEFAULTS[msg] ~= nil then
        db[msg] = not db[msg]
        Print(msg .. " " .. OnOff(db[msg]))
        Refresh()
    elseif msg == "list" then
        local count = {}
        for _, p in pairs(db.places) do
            local info = C_Map.GetMapInfo(p.map)
            local name = info and info.name or tostring(p.map)
            count[name] = (count[name] or 0) + 1
        end
        local known = 0
        for _, n in ipairs(SoloMapTaxi) do if OurNode(n) and Known(n) then known = known + 1 end end
        Print("flight paths known: " .. known)
        for name, c in pairs(count) do Print(name .. ": " .. c .. " places") end
    elseif msg == "copy" then
        CopyPlayer()
    elseif msg == "clear" then
        wipe(db.places)
        Print("saved places cleared")
        Refresh()
    else
        Print("coords " .. OnOff(db.coords) .. ", flights " .. OnOff(db.flights) .. ", services " ..
            OnOff(db.services) .. ", fog " .. OnOff(db.fog))
        Print("/smap coords | flights | services | fog (toggle) | copy | list | clear")
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 == "SoloMap" then
            SoloMapDB = SoloMapDB or {}
            SoloMapChar = SoloMapChar or {}
            db, char = SoloMapDB, SoloMapChar
            for k, v in pairs(DEFAULTS) do if db[k] == nil then db[k] = v end end
            db.places = db.places or {}
            char.known = char.known or {}
            char.knownName = char.knownName or {}
        elseif arg1 == "Blizzard_WorldMap" and side then
            Setup()
        end
    elseif event == "PLAYER_LOGIN" then
        side = UnitFactionGroup("player") == "Alliance" and "A" or "H"
        Setup()
        for _, e in ipairs({ "TAXIMAP_OPENED", "UI_INFO_MESSAGE", "MERCHANT_SHOW", "TRAINER_SHOW",
            "BANKFRAME_OPENED", "AUCTION_HOUSE_SHOW", "MAIL_SHOW", "GOSSIP_SHOW" }) do
            pcall(f.RegisterEvent, f, e)
        end
    elseif event == "TAXIMAP_OPENED" then
        ReadTaxiMap()
        if provider then provider:RefreshAllData() end
    elseif event == "UI_INFO_MESSAGE" then
        if ERR_NEWTAXIPATH and (arg1 == ERR_NEWTAXIPATH or arg2 == ERR_NEWTAXIPATH) then
            local node = MarkNearest()
            if node then Print("flight path added: " .. node[2]) end
            if provider then provider:RefreshAllData() end
        end
    elseif event == "MERCHANT_SHOW" then
        Record(CanMerchantRepair and CanMerchantRepair() and "repair" or "vendor", true)
    elseif event == "TRAINER_SHOW" then
        Record("trainer", true)
    elseif event == "BANKFRAME_OPENED" then
        Record("bank", true)
    elseif event == "AUCTION_HOUSE_SHOW" then
        Record("auction", true)
    elseif event == "MAIL_SHOW" then
        Record("mail", false)
    elseif event == "GOSSIP_SHOW" then
        OnGossip()
    end
end)
