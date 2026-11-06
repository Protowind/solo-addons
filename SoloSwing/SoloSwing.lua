-- SoloSwing: melee swing timer.
-- Main hand bar, off hand bar when dual wielding. Bars restart on every swing (hit or miss),
-- rescale on haste changes, and react to parry haste.
-- Swings are read from UNIT_COMBAT, not the combat log: this client forbids addons from
-- registering COMBAT_LOG_EVENT_UNFILTERED (ADDON_ACTION_FORBIDDEN popup).
-- Warrior extras: bar turns orange while Heroic Strike / Cleave is queued; a green zone marks
-- the Slam window just after a swing.
-- Shift + left-drag to move. /sw for commands.

local WIDTH, HEIGHT = 220, 12
local SLAM_WINDOW = 0.4          -- seconds after a swing where Slam loses least
local TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"

-- Abilities that replace the next main hand swing (all ranks)
local NEXT_SWING_IDS = {
    78, 284, 285, 1608, 11564, 11565, 11566, 11567, 25286,   -- Heroic Strike
    845, 7369, 11608, 11609, 20569,                          -- Cleave
    2973, 14260, 14261, 14262, 14263, 14264, 14265, 14266,   -- Raptor Strike
    6807, 6808, 6809, 8972, 9745, 9880, 9881,                -- Maul
}
local QUEUE_IDS = { 78, 284, 285, 1608, 11564, 11565, 11566, 11567, 25286, 845, 7369, 11608, 11609, 20569 }
local SLAM_IDS = { 1464, 8820, 11604, 11605 }

local GetName = (C_Spell and C_Spell.GetSpellName) or function(id) return (GetSpellInfo(id)) end
local IsCurrent = (C_Spell and C_Spell.IsCurrentSpell) or IsCurrentSpell
local IsKnown = IsPlayerSpell or IsSpellKnown

local nextSwingNames, slamNames = {}, {}
for _, id in ipairs(NEXT_SWING_IDS) do
    local name = GetName(id)
    if name then nextSwingNames[name] = true end
end
for _, id in ipairs(SLAM_IDS) do
    local name = GetName(id)
    if name then slamNames[name] = true end
end

local classFile
local hands = {}   -- hands.main / hands.off: { start, speed }

-- Frames -----------------------------------------------------------------

local anchor = CreateFrame("Frame", "SoloSwingFrame", UIParent)
anchor:SetSize(WIDTH, HEIGHT * 2 + 3)
anchor:SetClampedToScreen(true)
anchor:SetMovable(true)
anchor:EnableMouse(true)
anchor:RegisterForDrag("LeftButton")

local function MakeBar(label, yOffset, r, g, b)
    local bar = CreateFrame("StatusBar", nil, anchor)
    bar:SetSize(WIDTH, HEIGHT)
    bar:SetPoint("TOPLEFT", 0, yOffset)
    bar:SetStatusBarTexture(TEXTURE)
    bar:SetMinMaxValues(0, 1)
    bar.colour = { r, g, b }
    bar:SetStatusBarColor(r, g, b)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.5)

    bar.label = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.label:SetPoint("LEFT", 4, 0)
    bar.label:SetText(label)

    bar.time = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.time:SetPoint("RIGHT", -4, 0)

    bar:Hide()
    return bar
end

local mainBar = MakeBar("MH", 0, 0.85, 0.85, 0.85)
local offBar = MakeBar("OH", -(HEIGHT + 3), 0.6, 0.6, 0.85)

-- Slam window: green zone at the start of the main hand bar
local slamZone = mainBar:CreateTexture(nil, "ARTWORK", nil, 2)
slamZone:SetPoint("TOPLEFT")
slamZone:SetPoint("BOTTOMLEFT")
slamZone:SetColorTexture(0.2, 1, 0.2, 0.35)
slamZone:Hide()

-- Timer logic ------------------------------------------------------------

-- In combat this client returns UnitAttackSpeed as a "secret" value that addons cannot
-- compare or do maths with. So speeds are cached whenever they are readable, with the
-- weapon's tooltip "Speed" line as a fallback. Haste changes in combat are not seen.
local IsSecret = issecretvalue or function() return false end
local GetInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local WEAPON_CLASS = 2
local speedCache = {}

local function TooltipSpeed(slot)
    if not (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) then return nil end
    local ok, speed = pcall(function()
        local data = C_TooltipInfo.GetInventoryItem("player", slot)
        for _, line in ipairs(data and data.lines or {}) do
            for _, text in ipairs({ line.leftText or "", line.rightText or "" }) do
                local value = text:match("(%d+[%.,]%d+)")
                if value and text:find("Speed") then
                    return tonumber((value:gsub(",", ".")))
                end
            end
        end
    end)
    return ok and speed or nil
end

local function HasWeapon(slot)
    local link = GetInventoryItemLink("player", slot)
    if not link then return false end
    local classID = select(6, GetInfoInstant(link))
    return classID == WEAPON_CLASS
end

local function Speeds()
    local main, off = UnitAttackSpeed("player")
    if main and not IsSecret(main) then speedCache.main = main end
    if off and not IsSecret(off) then speedCache.off = off end
    if not speedCache.main then speedCache.main = TooltipSpeed(16) end
    if HasWeapon(17) then
        if not speedCache.off then speedCache.off = TooltipSpeed(17) end
    else
        speedCache.off = nil
    end
    return speedCache.main, speedCache.off
end

local function ForgetSpeeds()
    speedCache.main, speedCache.off = nil, nil
end

local function StartSwing(hand)
    local main, off = speedCache.main, speedCache.off
    if not main then main, off = Speeds() end   -- cache filled on login, equipment and combat events
    local speed = hand == "off" and off or main
    if not speed or speed <= 0 then return end
    hands[hand] = { start = GetTime(), speed = speed }
end

-- Haste changed mid-swing: keep the same progress, new length
local function Rescale()
    local main, off = Speeds()
    local now = GetTime()
    for hand, speed in pairs({ main = main, off = off }) do
        local t = hands[hand]
        if t and speed and speed > 0 and speed ~= t.speed then
            local progress = (now - t.start) / t.speed
            t.speed = speed
            t.start = now - progress * speed
        end
    end
end

-- When you parry, your next swing comes 40% sooner, but not below 20% of the swing left
local function ParryHaste()
    local t = hands.main
    if not t then return end
    local now = GetTime()
    local remaining = t.start + t.speed - now
    local minimum = t.speed * 0.2
    if remaining > minimum then
        local newRemaining = math.max(remaining - t.speed * 0.4, minimum)
        t.start = t.start - (remaining - newRemaining)
    end
end

local function SlamKnown()
    if classFile ~= "WARRIOR" then return false end
    for _, id in ipairs(SLAM_IDS) do
        if IsKnown(id) then return true end
    end
    return false
end

-- Heroic Strike / Cleave queued? Warriors only; IsCurrentSpell is pcall-wrapped since a hidden
-- (secret) answer in combat would otherwise error every frame. After one failure it stays off.
local queuedBroken = false
local function Queued()
    if classFile ~= "WARRIOR" or queuedBroken then return false end
    local ok, queued = pcall(function()
        for _, id in ipairs(QUEUE_IDS) do
            if IsCurrent(id) then return true end
        end
        return false
    end)
    if not ok then
        queuedBroken = true   -- Debug is defined further down: plain print here
        if SoloSwingDB and SoloSwingDB.debug then print("SoloSwing debug: queue check failed, off for this session: " .. tostring(queued)) end
        return false
    end
    return queued == true
end

local function UpdateBar(bar, t, now)
    if not t then
        bar:Hide()
        return false
    end
    local elapsed = now - t.start
    if elapsed >= t.speed and not UnitAffectingCombat("player") then
        bar:Hide()
        return false
    end
    bar:SetValue(math.min(elapsed / t.speed, 1))
    bar.time:SetFormattedText("%.1f", math.max(t.speed - elapsed, 0))
    bar:Show()
    return true
end

local showSlam = false
local attacking = false        -- auto attack on (PLAYER_ENTER_COMBAT / PLAYER_LEAVE_COMBAT)
local seenTargetEvents = false -- set once UNIT_COMBAT swings are seen; until then bars free-run

-- Debug lines go to chat and to SoloSwingDB.log (last 300), which the game writes to
-- WTF\Account\<account>\SavedVariables\SoloSwing.lua on /reload or logout
local LOG_MAX = 300

local function Debug(fmt, ...)
    if not (SoloSwingDB and SoloSwingDB.debug) then return end
    local line = string.format(fmt, ...)
    print("SoloSwing debug: " .. line)
    SoloSwingDB.log = SoloSwingDB.log or {}
    table.insert(SoloSwingDB.log, string.format("%s %.2f %s", date("%H:%M:%S"), GetTime(), line))
    while #SoloSwingDB.log > LOG_MAX do table.remove(SoloSwingDB.log, 1) end
end

-- Fallback: if no target events arrive, keep each bar cycling at weapon speed while attacking
local function FreeRun(now)
    if not attacking or seenTargetEvents then return end
    for _, hand in ipairs({ "main", "off" }) do
        local t = hands[hand]
        if t and now >= t.start + t.speed then
            t.start = t.start + t.speed
        end
    end
end

anchor:SetScript("OnUpdate", function()
    local now = GetTime()
    FreeRun(now)
    if UpdateBar(mainBar, hands.main, now) then
        if Queued() then
            mainBar:SetStatusBarColor(1, 0.55, 0.1)
        else
            mainBar:SetStatusBarColor(unpack(mainBar.colour))
        end
        if showSlam then
            slamZone:SetWidth(math.max(math.min(SLAM_WINDOW / hands.main.speed, 1) * WIDTH, 1))
            slamZone:Show()
        end
    else
        slamZone:Hide()
    end
    -- Cached speed only: Speeds() reads the attack speed and scans a tooltip, not per-frame work
    if speedCache.off then
        UpdateBar(offBar, hands.off, now)
    else
        offBar:Hide()
    end
end)

-- Events -----------------------------------------------------------------

-- This client forbids addons from reading the combat log, so swings are read from
-- UNIT_COMBAT on your target instead: any physical hit, miss, dodge, parry or block
-- that lands while a hand is due (or idle) counts as that hand's swing.
local TOLERANCE = 0.3        -- network jitter seen in tests: about +-0.15 s
local ABILITY_WINDOW = 0.5   -- a hit this soon after an instant ability is that ability's damage
local lastAbility = 0
local SWING_ACTIONS = { WOUND = true, MISS = true, DODGE = true, PARRY = true, BLOCK = true, RESIST = true, IMMUNE = true, EVADE = true, ABSORB = true }
local PHYSICAL = 1

local function DueIn(hand, now)
    local t = hands[hand]
    if not t then return nil end
    return t.start + t.speed - now
end

local function OnTargetCombat(action, school)
    if not SWING_ACTIONS[action] then return end
    if school and school ~= PHYSICAL and action == "WOUND" then return end
    if not attacking then return end
    seenTargetEvents = true

    local now = GetTime()
    local offSpeed = speedCache.off
    local mainDue = DueIn("main", now)
    local offDue = offSpeed and DueIn("off", now)

    -- Just after an instant ability (Rend, Thunder Clap, Strike...): that hit is the ability,
    -- unless a swing was due right then anyway
    local onTime = (mainDue and math.abs(mainDue) <= TOLERANCE) or (offDue and math.abs(offDue) <= TOLERANCE)
    if now - lastAbility < ABILITY_WINDOW and not onTime then
        Debug("  -> ignored, ability hit (%.2f s after cast)", now - lastAbility)
        return
    end

    -- Idle hand (never started or already overdue) or one due within the tolerance
    -- A guessed start (auto attack just switched on) is replaced by the first real swing
    local mainReady = not mainDue or mainDue <= TOLERANCE or hands.main.guess
    local offReady = offSpeed and (not offDue or offDue <= TOLERANCE or hands.off.guess)

    local hand
    if mainReady and offReady then
        -- Both could fit: give it to the one that is most overdue
        hand = (mainDue or -math.huge) <= (offDue or -math.huge) and "main" or "off"
    elseif mainReady then
        hand = "main"
    elseif offReady then
        hand = "off"
    end
    if hand then StartSwing(hand) end
    Debug("  -> %s (main due %s, speed %s)", hand or "ignored",
        mainDue and string.format("%.2f", mainDue) or "-", tostring(speedCache.main))
end

local function OnPlayerCombat(action)
    if action == "PARRY" then ParryHaste() end
end

local function DefaultPosition()
    anchor:ClearAllPoints()
    anchor:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
end

anchor:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown() then self:StartMoving() end
end)
anchor:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    SoloSwingDB.pos = { point, relPoint, x, y }
end)

anchor:RegisterEvent("PLAYER_LOGIN")
anchor:RegisterUnitEvent("UNIT_COMBAT", "target", "player")
anchor:RegisterEvent("PLAYER_ENTER_COMBAT")
anchor:RegisterEvent("PLAYER_REGEN_ENABLED")
anchor:RegisterEvent("PLAYER_LEAVE_COMBAT")
anchor:RegisterEvent("UNIT_ATTACK_SPEED")
anchor:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
anchor:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
anchor:RegisterEvent("SPELLS_CHANGED")

anchor:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4, arg5)
    if event == "UNIT_COMBAT" then
        -- arg2 = action (WOUND, MISS, PARRY...), arg5 = school
        -- pcall: on newer clients these values can be hidden from addons and error on use
        local ok, err = pcall(function()
            Debug("%s %s school %s at %.2f", tostring(arg1), tostring(arg2), tostring(arg5), GetTime())
            if arg1 == "target" then
                OnTargetCombat(arg2, arg5)
            elseif arg1 == "player" then
                OnPlayerCombat(arg2)
            end
        end)
        if not ok then Debug("UNIT_COMBAT unreadable: %s", tostring(err)) end
    elseif event == "PLAYER_ENTER_COMBAT" then
        -- Auto attack switched on: the first swing goes out straight away if a hand is ready
        attacking = true
        local now = GetTime()
        local _, offSpeed = Speeds()
        if not DueIn("main", now) or DueIn("main", now) <= 0 then
            StartSwing("main")
            if hands.main then hands.main.guess = true end
        end
        if offSpeed and (not DueIn("off", now) or DueIn("off", now) <= 0) then
            StartSwing("off")
            if hands.off then hands.off.guess = true end
        end
        Debug("auto attack on")
    elseif event == "PLAYER_LEAVE_COMBAT" then
        -- Auto attack switched off (or target changed). The swing timer keeps running in the
        -- game, so keep the bars; a hand that is still mid-swing carries on when attack resumes
        attacking = false
        Debug("auto attack off")
    elseif event == "UNIT_ATTACK_SPEED" then
        if arg1 == "player" then Rescale() end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if arg1 ~= "player" then return end
        local ok, err = pcall(function()
            local name = GetName(arg3) or ""
            Debug("cast %s (%s)", name, tostring(arg3))
            if arg3 == 6603 or nextSwingNames[name] then
                return   -- Auto Attack, or Heroic Strike/Cleave: those land as the swing itself
            elseif slamNames[name] then
                StartSwing("main")   -- Slam restarts the main hand swing when its cast finishes
            else
                lastAbility = GetTime()
            end
        end)
        if not ok then Debug("cast unreadable: %s", tostring(err)) end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        if arg1 == 16 then hands.main = nil end
        if arg1 == 17 then hands.off = nil end
        if arg1 == 16 or arg1 == 17 then
            ForgetSpeeds()
            Speeds()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        Speeds()   -- out of combat: values are readable again, refresh the cache
    elseif event == "SPELLS_CHANGED" then
        showSlam = SlamKnown()
    elseif event == "PLAYER_LOGIN" then
        SoloSwingDB = SoloSwingDB or {}
        _, classFile = UnitClass("player")
        Speeds()
        Debug("weapon speed main %s off %s", tostring(speedCache.main), tostring(speedCache.off))
        showSlam = SlamKnown()
        anchor:SetScale(SoloSwingDB.scale or 1)
        local pos = SoloSwingDB.pos
        if pos then
            anchor:ClearAllPoints()
            anchor:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
        else
            DefaultPosition()
        end
    end
end)

SLASH_SOLOSWING1 = "/sw"
SLASH_SOLOSWING2 = "/soloswing"
SlashCmdList.SOLOSWING = function(msg)
    msg = strlower(strtrim(msg or ""))
    local scale = tonumber(msg:match("^scale%s+(%S+)$") or "")
    if scale and scale >= 0.5 and scale <= 3 then
        SoloSwingDB.scale = scale
        anchor:SetScale(scale)
        print(string.format("SoloSwing: scale %.2f", scale))
    elseif msg == "reset" then
        SoloSwingDB.pos, SoloSwingDB.scale = nil, nil
        anchor:SetScale(1)
        DefaultPosition()
        print("SoloSwing: position and scale reset.")
    elseif msg == "debug" then
        SoloSwingDB.debug = not SoloSwingDB.debug
        if SoloSwingDB.debug then SoloSwingDB.log = {} end   -- fresh log for each debug run
        print("SoloSwing: debug " .. (SoloSwingDB.debug and "on" or "off"))
    elseif msg == "test" then
        -- Show both bars for 5 seconds so you can place them out of combat
        local now = GetTime()
        hands.main = { start = now, speed = 5 }
        hands.off = { start = now, speed = 5 }
        print("SoloSwing: test bars for 5 s. Shift-drag to move.")
    else
        print("SoloSwing: /sw test | scale <0.5-3> | reset | debug")
    end
end
