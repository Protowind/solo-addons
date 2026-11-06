-- SoloUI unit frames: flat ElvUI-style player, target, target of target and party frames.
-- Secure unit buttons: left-click targets, right-click opens the unit menu, also in combat.
-- Health and power may be "secret" in combat on this client: bars take the raw values (allowed),
-- text is only shown when the client lets us format it.
-- Shift-drag a frame to move it (out of combat). Settings live in the SoloUI window (/sui).

local _, ns = ...
ns.frames = {}

local FLAT = "Interface\\Buttons\\WHITE8X8"
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

ns.DEFAULTS = {
    frames = true, hideBlizzard = true, scale = 1, healthText = true, classColour = true,
    pos = {},
}

local LAYOUT = {
    player = { w = 220, h = 34, point = { "CENTER", "UIParent", "CENTER", -250, -170 } },
    target = { w = 220, h = 34, point = { "CENTER", "UIParent", "CENTER", 250, -170 } },
    targettarget = { w = 120, h = 20, point = { "TOPRIGHT", "SoloUI_target", "BOTTOMRIGHT", 0, -8 } },
    party = { w = 170, h = 28, point = { "TOPLEFT", "UIParent", "TOPLEFT", 20, -180 }, gap = 14 },
}

local function Secret(v) return issecretvalue and issecretvalue(v) end

-- Errors in frame updates: caught so a bad frame cannot stop the others. With SoloErrors loaded
-- the message goes to the game's error handler (SoloErrors records and counts it); without it,
-- shown once in chat and kept in SoloUIDB.errors (read after /reload).
local seenErrors = {}
function ns.Safe(fn, ...)
    local ok, err = pcall(fn, ...)
    if ok then return end
    err = tostring(err)
    if SoloErrorsDB and geterrorhandler then
        pcall(geterrorhandler(), "SoloUI: " .. err)
        return
    end
    if seenErrors[err] then return end
    seenErrors[err] = true
    print("|cff40c0ffSoloUI|r error (shown once): " .. err)
    if ns.db then
        ns.db.errors = ns.db.errors or {}
        if #ns.db.errors < 30 then ns.db.errors[#ns.db.errors + 1] = date("%H:%M:%S ") .. err end
    end
end
local UpdateAuras   -- defined with the target debuffs below

-- Bars --------------------------------------------------------------------

local function Edge(f)
    local edge = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    edge:SetColorTexture(0, 0, 0, 1)
    local fill = f:CreateTexture(nil, "BACKGROUND", nil, -7)
    fill:SetAllPoints()
    fill:SetColorTexture(0.08, 0.08, 0.08, 0.9)
end

local function Bar(parent)
    local b = CreateFrame("StatusBar", nil, parent)
    b:SetStatusBarTexture(FLAT)
    b:SetMinMaxValues(0, 1)
    b:SetValue(1)
    return b
end

local function Text(parent, size, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT, size, "OUTLINE")
    fs:SetJustifyH(justify)
    fs:SetWordWrap(false)
    return fs
end

-- Short numbers: 12345 -> 12.3k
local function Short(n)
    if n >= 1e6 then return string.format("%.1fm", n / 1e6) end
    if n >= 1e4 then return string.format("%.1fk", n / 1e3) end
    return tostring(n)
end

-- Colours -------------------------------------------------------------------

local function UnitColour(unit)
    if UnitIsPlayer(unit) and ns.db.classColour then
        local _, class = UnitClass(unit)
        local c = class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
        if c then return c.r, c.g, c.b end
    end
    if UnitIsTapDenied and UnitIsTapDenied(unit) then return 0.5, 0.5, 0.5 end
    local reaction = UnitReaction(unit, "player")
    if reaction and not Secret(reaction) then
        if reaction >= 5 then return 0.25, 0.75, 0.25 end
        if reaction == 4 then return 0.9, 0.8, 0.2 end
        return 0.8, 0.2, 0.2
    end
    return 0.4, 0.6, 0.9
end

local function PowerColour(unit)
    local _, token = UnitPowerType(unit)
    local c = token and PowerBarColor and PowerBarColor[token]
    if c then return c.r, c.g, c.b end
    return 0.3, 0.5, 0.9
end

-- Updates -------------------------------------------------------------------

local function UpdateHealth(f)
    local unit = f.unit
    if not UnitExists(unit) then return end
    local hp, max = UnitHealth(unit), UnitHealthMax(unit)
    f.health:SetMinMaxValues(0, max)
    f.health:SetValue(hp)
    local ok, r, g, b = pcall(UnitColour, unit)
    if ok and r then f.health:SetStatusBarColor(r, g, b) end
    if not f.hpText then return end
    if UnitIsDeadOrGhost(unit) then
        f.hpText:SetText(UnitIsGhost(unit) and "Ghost" or "Dead")
    elseif not UnitIsConnected(unit) then
        f.hpText:SetText("Offline")
    elseif not ns.db.healthText then
        f.hpText:SetText("")
    elseif Secret(hp) or Secret(max) then
        if not pcall(f.hpText.SetText, f.hpText, hp) then f.hpText:SetText("") end
    elseif max > 0 then
        f.hpText:SetText(f.short and (math.floor(hp / max * 100) .. "%")
            or (Short(hp) .. "  |cffcccccc" .. math.floor(hp / max * 100) .. "%|r"))
    end
end

local function UpdatePower(f)
    if not f.power then return end
    local unit = f.unit
    if not UnitExists(unit) then return end
    f.power:SetMinMaxValues(0, UnitPowerMax(unit))
    f.power:SetValue(UnitPower(unit))
    f.power:SetStatusBarColor(PowerColour(unit))
end

local CLASSIFICATION = { elite = " |cffffd040Elite|r", rareelite = " |cffc0c0ffRare Elite|r", rare = " |cffc0c0ffRare|r",
    worldboss = " |cffff4040Boss|r" }

local function UpdateName(f)
    local unit = f.unit
    if not UnitExists(unit) then return end
    local name = UnitName(unit) or ""
    local prefix = ""
    if f.showLevel then
        local lvl = UnitLevel(unit)
        if Secret(lvl) then lvl = nil end
        local lvlText = (lvl and lvl > 0) and tostring(lvl) or "??"
        local c = GetQuestDifficultyColor and lvl and lvl > 0 and GetQuestDifficultyColor(lvl)
        prefix = (c and string.format("|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, lvlText) or lvlText) .. "  "
    end
    -- string.format, not "..": a creature name can be secret (instances), and secrets refuse ".."
    local cls = f.showClass and UnitClassification(unit)
    local tag = (cls and not Secret(cls) and CLASSIFICATION[cls]) or ""
    f.name:SetText(string.format("%s%s%s", prefix, name, tag))
end

local function UpdateAll(f)
    if not UnitExists(f.unit) then return end
    UpdateName(f)
    UpdateHealth(f)
    UpdatePower(f)
    UpdateAuras(f)
end
ns.UpdateAll = UpdateAll

-- Target debuffs ------------------------------------------------------------
-- Icons above the target frame, yours first. Timers use a Cooldown spiral; if the client keeps the
-- aura's times secret the spiral is skipped (the icon and stack count still show).

local AURA_SIZE, AURA_MAX = 22, 8

local function AuraIcons(f)
    f.auras = {}
    for i = 1, AURA_MAX do
        local a = CreateFrame("Frame", nil, f)
        a:SetSize(AURA_SIZE, AURA_SIZE)
        a:SetPoint("BOTTOMLEFT", f, "TOPLEFT", (i - 1) * (AURA_SIZE + 3), 5)
        Edge(a)
        a.icon = a:CreateTexture(nil, "ARTWORK")
        a.icon:SetAllPoints()
        a.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        a.cd = CreateFrame("Cooldown", nil, a, "CooldownFrameTemplate")
        a.cd:SetAllPoints()
        a.cd:SetReverse(true)
        a.count = Text(a, 10, "RIGHT")
        a.count:SetPoint("BOTTOMRIGHT", 1, 0)
        a:Hide()
        f.auras[i] = a
    end
end

UpdateAuras = function(f)
    if not f.auras then return end
    local list = {}
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 40 do
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, f.unit, i, "HARMFUL")
            if not ok or not aura then break end
            -- the source can be secret in combat: comparing a secret errors, so test it first
            local src = aura.sourceUnit
            local mine = src ~= nil and not Secret(src) and src == "player"
            if mine then table.insert(list, 1, aura) else list[#list + 1] = aura end
        end
    end
    for i, a in ipairs(f.auras) do
        local aura = list[i]
        if aura then
            a.icon:SetTexture(aura.icon)
            local n = aura.applications
            a.count:SetText((not Secret(n) and n and n > 1) and n or "")
            if not pcall(function() a.cd:SetCooldown(aura.expirationTime - aura.duration, aura.duration) end) then
                a.cd:Clear()
            end
            a:Show()
        else
            a:Hide()
        end
    end
end

-- Frame factory ---------------------------------------------------------------

local function SavePos(f)
    local point, rel, relPoint, x, y = f:GetPoint()
    ns.db.pos[f.key] = { point, rel and rel:GetName() or "UIParent", relPoint, x, y }
end

local function Place(f)
    f:ClearAllPoints()
    local p = ns.db.pos[f.key] or f.layout.point
    if f.partyIndex and f.partyIndex > 1 and not ns.db.pos[f.key] then
        local prev = ns.frames["party" .. (f.partyIndex - 1)]
        f:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -f.layout.gap)
        return
    end
    f:SetPoint(p[1], _G[p[2]] or UIParent, p[3], p[4], p[5])
end

local function Create(unit, key, layout, opts)
    local f = CreateFrame("Button", "SoloUI_" .. key, UIParent, "SecureUnitButtonTemplate")
    f.unit, f.key, f.layout = unit, key, layout
    f:SetSize(layout.w, layout.h)
    f:SetAttribute("unit", unit)
    f:SetAttribute("*type1", "target")
    f:SetAttribute("*type2", "togglemenu")
    f:RegisterForClicks("AnyUp")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() and not InCombatLockdown() then self:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() SavePos(self) end)
    f:SetScript("OnEnter", function(self)
        GameTooltip_SetDefaultAnchor(GameTooltip, self)
        GameTooltip:SetUnit(self.unit)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local powerH = opts.power and math.max(4, math.floor(layout.h * 0.22)) or 0
    f.health = Bar(f)
    f.health:SetPoint("TOPLEFT")
    f.health:SetPoint("TOPRIGHT")
    f.health:SetHeight(layout.h - (powerH > 0 and powerH + 1 or 0))
    Edge(f.health)
    if opts.power then
        f.power = Bar(f)
        f.power:SetPoint("BOTTOMLEFT")
        f.power:SetPoint("BOTTOMRIGHT")
        f.power:SetHeight(powerH)
        Edge(f.power)
    end

    local size = layout.h >= 30 and 12 or 10
    f.name = Text(f.health, size, "LEFT")
    f.name:SetPoint("LEFT", 4, 0)
    f.name:SetPoint("RIGHT", f.health, "CENTER", 40, 0)
    if opts.hpText then
        f.hpText = Text(f.health, size, "RIGHT")
        f.hpText:SetPoint("RIGHT", -4, 0)
    end
    f.short, f.showClass, f.showLevel = opts.short, opts.showClass, opts.level

    f:RegisterUnitEvent("UNIT_HEALTH", unit)
    f:RegisterUnitEvent("UNIT_MAXHEALTH", unit)
    if opts.power then
        f:RegisterUnitEvent("UNIT_POWER_FREQUENT", unit)
        f:RegisterUnitEvent("UNIT_MAXPOWER", unit)
        f:RegisterUnitEvent("UNIT_DISPLAYPOWER", unit)
    end
    f:RegisterUnitEvent("UNIT_NAME_UPDATE", unit)
    f:RegisterUnitEvent("UNIT_LEVEL", unit)
    f:RegisterUnitEvent("UNIT_FACTION", unit)
    f:RegisterUnitEvent("UNIT_CONNECTION", unit)
    if opts.auras then
        AuraIcons(f)
        f:RegisterUnitEvent("UNIT_AURA", unit)
    end
    f:SetScript("OnEvent", function(self, event) ns.Safe(self.OnUnitEvent, self, event) end)
    f.OnUnitEvent = function(self, event)
        if event == "UNIT_AURA" then UpdateAuras(self)
        elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_CONNECTION" then UpdateHealth(self)
        elseif event == "UNIT_NAME_UPDATE" or event == "UNIT_LEVEL" or event == "UNIT_FACTION" then UpdateName(self) UpdateHealth(self)
        else UpdatePower(self) end
    end
    f:SetScript("OnShow", function(self) ns.Safe(UpdateAll, self) end)
    if unit ~= "player" then RegisterUnitWatch(f) end
    ns.frames[key] = f
    return f
end

-- Hide Blizzard's frames (once, out of combat) ---------------------------------

local hidden = CreateFrame("Frame")
hidden:Hide()

local function Kill(frame)
    if not frame or frame.soloKilled then return end
    frame.soloKilled = true
    pcall(frame.UnregisterAllEvents, frame)
    pcall(frame.SetParent, frame, hidden)
    pcall(frame.Hide, frame)
end

-- Children of the killed frames that must stay: the target's cast bar and the pet frame would go
-- with their parents, so they are moved to UIParent and anchored under the SoloUI frames first.
local function Rescue(frame, anchorKey, yOffset)
    if not frame or frame.soloRescued then return end
    frame.soloRescued = true
    local anchor = ns.frames[anchorKey]
    pcall(function()
        frame:SetParent(UIParent)
        if anchor then
            frame:ClearAllPoints()
            frame:SetPoint("TOP", anchor, "BOTTOM", 0, yOffset)
        end
    end)
end

local function HideBlizzard()
    Rescue(TargetFrameSpellBar, "target", -36)   -- below the target of target frame
    Rescue(PetFrame, "player", -8)
    Kill(PlayerFrame)
    Kill(TargetFrame)
    Kill(TargetFrameToT)
    Kill(PartyFrame)
    for i = 1, 4 do Kill(_G["PartyMemberFrame" .. i]) end
end

-- Start ---------------------------------------------------------------------

function ns.ApplyScale()
    if InCombatLockdown() then return end
    for _, f in pairs(ns.frames) do f:SetScale(ns.db.scale) end
end

function ns.ResetPositions()
    if InCombatLockdown() then return end
    wipe(ns.db.pos)
    for _, f in pairs(ns.frames) do Place(f) end
end

function ns.StartFrames()
    if not ns.db.frames then return end
    Create("player", "player", LAYOUT.player, { power = true, hpText = true, level = true })
    Create("target", "target", LAYOUT.target, { power = true, hpText = true, level = true, showClass = true, auras = true })
    Create("targettarget", "targettarget", LAYOUT.targettarget, { hpText = true, short = true })
    for i = 1, 4 do
        local f = Create("party" .. i, "party" .. i, LAYOUT.party, { power = true, hpText = true, short = true })
        f.partyIndex = i
    end
    for _, f in pairs(ns.frames) do Place(f) end
    ns.ApplyScale()
    if ns.db.hideBlizzard then HideBlizzard() end

    -- Target and party changes; target of target has no event of its own, so poll it
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("PLAYER_TARGET_CHANGED")
    watcher:RegisterEvent("GROUP_ROSTER_UPDATE")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:RegisterUnitEvent("UNIT_TARGET", "target")
    watcher:SetScript("OnEvent", function()
        for _, f in pairs(ns.frames) do ns.Safe(UpdateAll, f) end
    end)
    local wait = 0
    watcher:SetScript("OnUpdate", function(_, elapsed)
        wait = wait - elapsed
        if wait > 0 then return end
        wait = 0.25
        local tot = ns.frames.targettarget
        if tot and tot:IsShown() then ns.Safe(UpdateAll, tot) end
    end)
end
