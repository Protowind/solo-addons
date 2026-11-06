-- SoloCombo: rogue strip. Five combo point pips with a big count, an energy bar, and timers for
-- Slice and Dice (own buff) and Rupture, Garrote, Expose Armor (your debuffs on the target).
-- Sits under the SoloSwing bars when that addon is loaded, else on its own; Shift-drag to move.
--
-- This client (12.x engine) can hand addons "secret" values in combat: energy and aura times may
-- not be read, compared or used in maths. Every read is wrapped: when a value is secret the
-- energy bar is fed the value directly (StatusBar accepts secrets) and a timer falls back to a
-- Blizzard Cooldown frame, which can draw a secret time. /sc debug logs what was secret.

local WIDTH, PIP_H, ENERGY_H, TIMER_H, GAP = 220, 14, 6, 14, 2
local TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local MAX_COMBO = 5

local GetName = (C_Spell and C_Spell.GetSpellName) or function(id) return (GetSpellInfo(id)) end
local IsSecret = issecretvalue or function() return false end
local COMBO_TYPE = (Enum and Enum.PowerType and Enum.PowerType.ComboPoints) or 4
local ENERGY_TYPE = (Enum and Enum.PowerType and Enum.PowerType.Energy) or 3

-- Timers: own buffs and own debuffs on the target, matched by name (all ranks share one name)
local TIMERS = {
    { key = "snd",     ids = { 5171, 6774 },                         unit = "player", filter = "HELPFUL|PLAYER", colour = { 0.95, 0.75, 0.2 } },
    { key = "rupture", ids = { 1943, 8639, 8640, 11273, 11274, 11275 }, unit = "target", filter = "HARMFUL|PLAYER", colour = { 0.85, 0.25, 0.2 } },
    { key = "garrote", ids = { 703, 8631, 8632, 8633, 11289, 11290 },   unit = "target", filter = "HARMFUL|PLAYER", colour = { 0.6, 0.3, 0.5 } },
    { key = "expose",  ids = { 8647, 8649, 8650, 11197, 11198 },        unit = "target", filter = "HARMFUL|PLAYER", colour = { 0.4, 0.55, 0.85 } },
}
for _, t in ipairs(TIMERS) do
    t.names, t.idSet = {}, {}
    for _, id in ipairs(t.ids) do
        t.idSet[id] = true
        local name = GetName(id)
        if name then t.names[name] = true end
    end
    t.label = GetName(t.ids[1]) or t.key
end

-- Debug log: chat and SoloComboDB.log (last 200), saved on /reload or logout
local LOG_MAX = 200
local function Debug(fmt, ...)
    if not (SoloComboDB and SoloComboDB.debug) then return end
    local line = string.format(fmt, ...)
    print("SoloCombo debug: " .. line)
    SoloComboDB.log = SoloComboDB.log or {}
    table.insert(SoloComboDB.log, string.format("%s %s", date("%H:%M:%S"), line))
    while #SoloComboDB.log > LOG_MAX do table.remove(SoloComboDB.log, 1) end
end

-- Does this aura belong to a timer? Spell ID first (the known Classic ranks), then the name
-- (Forever adds new rank IDs). Secret values (combat) cannot index a table, so they are skipped.
local warnedSecret = false
local function Matches(t, aura)
    local id, name = aura.spellId, aura.name
    if id ~= nil and not IsSecret(id) and t.idSet[id] then return true end
    if name ~= nil and not IsSecret(name) and t.names[name] then return true end
    if not warnedSecret and (IsSecret(id) or IsSecret(name)) then
        warnedSecret = true
        Debug("aura id and name are secret in combat: timers only match by readable values")
    end
    return false
end

-- Frames -----------------------------------------------------------------

local anchor = CreateFrame("Frame", "SoloComboFrame", UIParent)
anchor:SetSize(WIDTH, PIP_H + GAP + ENERGY_H)
anchor:SetClampedToScreen(true)
anchor:SetMovable(true)
anchor:EnableMouse(true)
anchor:RegisterForDrag("LeftButton")

-- Combo pips and the big count
local pips = {}
local pipWidth = (WIDTH - 44 - (MAX_COMBO - 1) * GAP) / MAX_COMBO
for i = 1, MAX_COMBO do
    local pip = anchor:CreateTexture(nil, "ARTWORK")
    pip:SetSize(pipWidth, PIP_H)
    pip:SetPoint("TOPLEFT", (i - 1) * (pipWidth + GAP), 0)
    pip:SetColorTexture(0.2, 0.2, 0.2, 0.6)
    pips[i] = pip
end
local count = anchor:CreateFontString(nil, "OVERLAY", "NumberFontNormalHuge")
count:SetPoint("RIGHT", anchor, "TOPRIGHT", -2, -PIP_H / 2)
count:SetText("0")

-- Energy bar
local energy = CreateFrame("StatusBar", nil, anchor)
energy:SetSize(WIDTH, ENERGY_H)
energy:SetPoint("TOPLEFT", 0, -(PIP_H + GAP))
energy:SetStatusBarTexture(TEXTURE)
energy:SetStatusBarColor(1, 0.95, 0.3)
energy:SetMinMaxValues(0, 100)
local energyBg = energy:CreateTexture(nil, "BACKGROUND")
energyBg:SetAllPoints()
energyBg:SetColorTexture(0, 0, 0, 0.5)
energy.text = energy:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
energy.text:SetPoint("LEFT", energy, "RIGHT", 4, 0)

-- Timer bars, stacked under the energy bar in TIMERS order; hidden when the aura is absent
local function MakeTimer(t, index)
    local bar = CreateFrame("StatusBar", nil, anchor)
    bar:SetSize(WIDTH - TIMER_H - GAP, TIMER_H)
    bar:SetPoint("TOPLEFT", TIMER_H + GAP, -(PIP_H + GAP + ENERGY_H + GAP + (index - 1) * (TIMER_H + GAP)))   -- re-stacked by Layout
    bar:SetStatusBarTexture(TEXTURE)
    bar:SetStatusBarColor(unpack(t.colour))
    bar:SetMinMaxValues(0, 1)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.5)

    bar.icon = bar:CreateTexture(nil, "ARTWORK")
    bar.icon:SetSize(TIMER_H, TIMER_H)
    bar.icon:SetPoint("RIGHT", bar, "LEFT", -GAP, 0)
    bar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    bar.label = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.label:SetPoint("LEFT", 4, 0)
    bar.label:SetText(t.label)
    bar.time = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.time:SetPoint("RIGHT", -4, 0)

    -- Fallback for secret times: a Cooldown frame over the bar draws the sweep and numbers itself
    bar.cd = CreateFrame("Cooldown", nil, bar, "CooldownFrameTemplate")
    bar.cd:SetAllPoints()
    bar.cd:SetDrawEdge(false)
    bar.cd:SetHideCountdownNumbers(false)
    bar.cd:Hide()

    bar:Hide()
    t.bar = bar
end
for i, t in ipairs(TIMERS) do MakeTimer(t, i) end

-- Stack the shown timers under the energy bar with no gaps, and size the frame to fit
local function Layout()
    local y = -(PIP_H + GAP + ENERGY_H + GAP)
    for _, t in ipairs(TIMERS) do
        if t.bar:IsShown() then
            t.bar:ClearAllPoints()
            t.bar:SetPoint("TOPLEFT", TIMER_H + GAP, y)
            y = y - (TIMER_H + GAP)
        end
    end
    anchor:SetHeight(-y - GAP)
end

-- Reads ------------------------------------------------------------------

local energySecret = false

local function UpdateCombo()
    local ok, cp = pcall(function()
        if UnitPower then return UnitPower("player", COMBO_TYPE) end
        return GetComboPoints("player", "target")
    end)
    if not ok or cp == nil or IsSecret(cp) then
        Debug("combo points unreadable: %s", tostring(cp))
        cp = 0
    end
    for i = 1, MAX_COMBO do
        if i <= cp then
            pips[i]:SetColorTexture(cp == MAX_COMBO and 1 or 0.95, cp == MAX_COMBO and 0.3 or 0.65, 0.15, 0.95)
        else
            pips[i]:SetColorTexture(0.2, 0.2, 0.2, 0.6)
        end
    end
    count:SetText(cp)
    if cp == MAX_COMBO then count:SetTextColor(1, 0.3, 0.15) else count:SetTextColor(1, 1, 1) end
end

local function UpdateEnergy()
    if not SoloComboDB.energy then energy:Hide() return end
    energy:Show()
    local ok, err = pcall(function()
        local cur, max = UnitPower("player", ENERGY_TYPE), UnitPowerMax("player", ENERGY_TYPE)
        energy:SetMinMaxValues(0, max)   -- StatusBar takes secret numbers; only our own maths cannot
        energy:SetValue(cur)
        if IsSecret(cur) then
            if not energySecret then Debug("energy is secret now") end
            energySecret = true
            energy.text:SetText("")
        else
            energySecret = false
            energy.text:SetText(cur)
        end
    end)
    if not ok then
        Debug("energy error: %s", tostring(err))
        energy:Hide()
    end
end

-- Iterate auras on a unit, old and new API
local function EachAura(unit, filter, fn)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 40 do
            local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
            if not aura then break end
            if fn(aura) then return end
        end
    elseif UnitAura then
        for i = 1, 40 do
            local name, icon, _, _, duration, expirationTime, _, _, _, spellId = UnitAura(unit, i, filter)
            if not name then break end
            if fn({ name = name, icon = icon, duration = duration, expirationTime = expirationTime, spellId = spellId }) then return end
        end
    end
end

local function SetTimer(t, aura)
    local bar = t.bar
    bar.icon:SetTexture(aura.icon)
    t.expiration, t.duration = aura.expirationTime, aura.duration
    -- Can we do maths on the time? If not, hand it to the Cooldown frame
    local readable = pcall(function() return (aura.expirationTime - GetTime()) > 0 end)
    if readable then
        t.secret = false
        bar.cd:Hide()
    else
        if not t.secret then Debug("%s time is secret, using a cooldown frame", t.label) end
        t.secret = true
        local ok, err = pcall(function()
            if bar.cd.SetCooldownFromExpirationTime then
                bar.cd:SetCooldownFromExpirationTime(aura.expirationTime, aura.duration)
            else
                bar.cd:SetCooldownUNIX(aura.expirationTime - aura.duration, aura.duration)
            end
        end)
        if ok then
            bar:SetValue(1)
            bar.time:SetText("")
            bar.cd:Show()
        else
            Debug("%s cooldown frame failed too: %s", t.label, tostring(err))
            bar:SetValue(1)
            bar.time:SetText("?")
            bar.cd:Hide()
        end
    end
    bar:Show()
end

local function ClearTimer(t)
    t.expiration, t.duration, t.secret = nil, nil, nil
    t.bar.cd:Hide()
    t.bar:Hide()
end

local function ScanAuras(unit)
    local found = {}
    local ok, err = pcall(function()
        for _, t in ipairs(TIMERS) do
            if t.unit == unit then
                EachAura(unit, t.filter, function(aura)
                    if Matches(t, aura) then
                        found[t.key] = aura
                        return true
                    end
                end)
            end
        end
    end)
    if not ok then Debug("aura scan %s error: %s", unit, tostring(err)) end
    for _, t in ipairs(TIMERS) do
        if t.unit == unit then
            if found[t.key] then SetTimer(t, found[t.key]) else ClearTimer(t) end
        end
    end
    Layout()
end

-- Per frame: readable timers count down here; secret ones are drawn by their Cooldown frame
anchor:SetScript("OnUpdate", function()
    local now = GetTime()
    for _, t in ipairs(TIMERS) do
        if t.expiration and not t.secret then
            local remaining = t.expiration - now
            if remaining <= 0 then
                ClearTimer(t)
                Layout()
            else
                t.bar:SetValue(t.duration and t.duration > 0 and remaining / t.duration or 1)
                t.bar.time:SetFormattedText("%.1f", remaining)
            end
        end
    end
end)

-- Position ---------------------------------------------------------------

local function DefaultPosition()
    anchor:ClearAllPoints()
    if SoloComboDB.follow ~= false and _G.SoloSwingFrame then
        anchor:SetPoint("TOP", _G.SoloSwingFrame, "BOTTOM", 0, -6)
    else
        anchor:SetPoint("CENTER", UIParent, "CENTER", 0, -215)
    end
end

local function ApplyPosition()
    local pos = SoloComboDB.pos
    if pos then
        anchor:ClearAllPoints()
        anchor:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        DefaultPosition()
    end
end

anchor:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown() then self:StartMoving() end
end)
anchor:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    SoloComboDB.pos = { point, relPoint, x, y }
    SoloComboDB.follow = false
end)

-- Events -----------------------------------------------------------------

anchor:RegisterEvent("PLAYER_LOGIN")
anchor:RegisterEvent("PLAYER_TARGET_CHANGED")
anchor:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
anchor:RegisterUnitEvent("UNIT_MAXPOWER", "player")
anchor:RegisterUnitEvent("UNIT_AURA", "player", "target")

anchor:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then
        SoloComboDB = SoloComboDB or {}
        if SoloComboDB.energy == nil then SoloComboDB.energy = true end
        anchor:SetScale(SoloComboDB.scale or 1)
        ApplyPosition()
        UpdateCombo()
        UpdateEnergy()
        ScanAuras("player")
        ScanAuras("target")
    elseif not SoloComboDB then
        return
    elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
        UpdateCombo()
        UpdateEnergy()
    elseif event == "PLAYER_TARGET_CHANGED" then
        UpdateCombo()
        ScanAuras("target")
    elseif event == "UNIT_AURA" then
        ScanAuras(unit)
    end
end)

-- Energy drains between power events while a secret value hides them, so poll a little too
C_Timer.NewTicker(0.2, function() if SoloComboDB then UpdateEnergy() end end)

-- Slash ------------------------------------------------------------------

SLASH_SOLOCOMBO1 = "/sc"
SLASH_SOLOCOMBO2 = "/solocombo"
SlashCmdList.SOLOCOMBO = function(msg)
    msg = strlower(strtrim(msg or ""))
    local scale = tonumber(msg:match("^scale%s+(%S+)$") or "")
    if scale and scale >= 0.5 and scale <= 3 then
        SoloComboDB.scale = scale
        anchor:SetScale(scale)
        print(string.format("SoloCombo: scale %.2f", scale))
    elseif msg == "reset" then
        SoloComboDB.pos, SoloComboDB.scale, SoloComboDB.follow = nil, nil, nil
        anchor:SetScale(1)
        DefaultPosition()
        print("SoloCombo: position and scale reset" .. (_G.SoloSwingFrame and " (under SoloSwing)." or "."))
    elseif msg == "energy" then
        SoloComboDB.energy = not SoloComboDB.energy
        UpdateEnergy()
        print("SoloCombo: energy bar " .. (SoloComboDB.energy and "on" or "off"))
    elseif msg == "debug" then
        SoloComboDB.debug = not SoloComboDB.debug
        if SoloComboDB.debug then SoloComboDB.log = {} end
        print("SoloCombo: debug " .. (SoloComboDB.debug and "on" or "off"))
    elseif msg == "test" then
        -- Show every bar for 8 seconds so you can place the strip out of combat
        local now = GetTime()
        for i, t in ipairs(TIMERS) do
            SetTimer(t, { icon = 136000 + i, expirationTime = now + 8, duration = 8 })
        end
        Layout()
        print("SoloCombo: test bars for 8 s. Shift-drag to move.")
    else
        print("SoloCombo: /sc test | scale <0.5-3> | reset | energy | debug")
    end
end
