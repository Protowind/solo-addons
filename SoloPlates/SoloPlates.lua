-- SoloPlates: a flat, ElvUI-style skin for the game's own nameplates.
-- It only restyles Blizzard's nameplate (textures, border, font); it never reads health, so the
-- client's secret combat values do not matter. Colours (red hostile, yellow neutral...) stay Blizzard's.
-- Forbidden plates (friendly plates inside instances) are left alone.
-- /splates: status | height <4-20> | size <8-16> | dump (saves the target's plate layout for Claude) | off

local FLAT = "Interface\\Buttons\\WHITE8X8"
local DEFAULTS = { enabled = true, height = 9, size = 10 }
local db

local function Print(msg) print("|cff40c0ffSoloPlates|r: " .. msg) end

local function HealthBar(uf)
    return uf.healthBar or uf.HealthBar or (uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar)
end

local function CastBar(uf)
    return uf.castBar or uf.CastBar
end

-- Blizzard's border pieces: hide them by alpha so Blizzard's own Show calls do not bring them back
local function HideBorder(bar)
    for _, key in ipairs({ "border", "Border", "BorderShield", "TextBorder" }) do
        local b = bar[key]
        if b and b.SetAlpha and key ~= "BorderShield" then b:SetAlpha(0) end
    end
end

-- 1 px black edge and a dark fill behind the bar, drawn on the bar itself (no extra frames)
local function FlatBackground(bar)
    if bar.soloEdge then return end
    bar.soloEdge = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
    bar.soloEdge:SetPoint("TOPLEFT", -1, 1)
    bar.soloEdge:SetPoint("BOTTOMRIGHT", 1, -1)
    bar.soloEdge:SetColorTexture(0, 0, 0, 1)
    bar.soloFill = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
    bar.soloFill:SetAllPoints()
    bar.soloFill:SetColorTexture(0.1, 0.1, 0.1, 0.9)
    if bar.background and bar.background.SetAlpha then bar.background:SetAlpha(0) end
    if bar.Background and bar.Background.SetAlpha then bar.Background:SetAlpha(0) end
end

local function FlatBar(bar)
    if not bar or not bar.SetStatusBarTexture then return end
    bar:SetStatusBarTexture(FLAT)
    HideBorder(bar)
    FlatBackground(bar)
end

local function Outline(fs, size)
    if not (fs and fs.GetFont) then return end
    local font = fs:GetFont()
    if font then
        fs:SetFont(font, size, "OUTLINE")
        fs:SetShadowOffset(0, 0)
    end
end

local function Skin(uf)
    if not (db and db.enabled and uf) then return end
    local hb = HealthBar(uf)
    FlatBar(hb)
    if hb and not InCombatLockdown() then pcall(hb.SetHeight, hb, db.height) end
    local cb = CastBar(uf)
    FlatBar(cb)
    if cb then Outline(cb.Text or cb.text, db.size - 1) end
    Outline(uf.name or uf.Name, db.size)
    if uf.LevelFrame then
        Outline(uf.LevelFrame.levelText, db.size)
        if uf.LevelFrame.highLevelTexture then uf.LevelFrame.highLevelTexture:SetAlpha(0) end
    end
    Outline(uf.levelText or uf.LevelText, db.size)
end

local function PlateFor(unit)
    local plate = C_NamePlate.GetNamePlateForUnit(unit, issecure and issecure())
    if not plate or (plate.IsForbidden and plate:IsForbidden()) then return end
    return plate
end

local function SkinUnit(unit)
    local plate = PlateFor(unit)
    if plate then pcall(Skin, plate.UnitFrame) end
end

local function SkinAll()
    for _, plate in ipairs(C_NamePlate.GetNamePlates(issecure and issecure()) or {}) do
        if not (plate.IsForbidden and plate:IsForbidden()) then pcall(Skin, plate.UnitFrame) end
    end
end

-- Layout dump: frames and regions of the target's plate, saved on /reload for Claude to read
local function Describe(obj, depth, out, prefix)
    if depth > 3 or type(obj) ~= "table" then return end
    for k, v in pairs(obj) do
        if type(v) == "table" and v.GetObjectType and type(k) == "string" then
            local ok, kind = pcall(v.GetObjectType, v)
            out[#out + 1] = prefix .. k .. " = " .. (ok and kind or "?")
            if ok and (kind == "Frame" or kind == "StatusBar" or kind == "Button") then
                Describe(v, depth + 1, out, prefix .. k .. ".")
            end
        end
    end
end

local function Dump()
    local plate = PlateFor("target")
    if not plate then Print("target a mob with a nameplate first") return end
    local out = {}
    Describe(plate.UnitFrame, 1, out, "UnitFrame.")
    table.sort(out)
    db.dump = out
    Print("saved " .. #out .. " lines. /reload so Claude can read them")
end

SLASH_SOLOPLATES1 = "/splates"
SlashCmdList.SOLOPLATES = function(msg)
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(%S*)")
    local n = tonumber(arg)
    if cmd == "height" and n and n >= 4 and n <= 20 then
        db.height = math.floor(n)
        SkinAll()
        Print("bar height " .. db.height)
    elseif cmd == "size" and n and n >= 8 and n <= 16 then
        db.size = math.floor(n)
        SkinAll()
        Print("text size " .. db.size)
    elseif cmd == "dump" then
        Dump()
    elseif cmd == "off" or cmd == "on" then
        db.enabled = cmd == "on"
        Print(db.enabled and "on" or "off: /reload to get Blizzard's look back")
        SkinAll()
    else
        Print((db.enabled and "on" or "off") .. ", height " .. db.height .. ", text " .. db.size)
        Print("/splates height <4-20> | size <8-16> | on | off | dump")
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "SoloPlates" then
        SoloPlatesDB = SoloPlatesDB or {}
        db = SoloPlatesDB
        for k, v in pairs(DEFAULTS) do if db[k] == nil then db[k] = v end end
        self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        SkinUnit(arg1)
    else
        SkinAll()   -- after combat: apply heights skipped during it
    end
end)
