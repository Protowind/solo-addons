-- SoloGear: green "+" on bag items that beat what you wear, and a score line in item tooltips.
-- Covers armour, cloaks, rings, necks, trinkets, shields, off-hands and weapons.
-- Score = stat x weight. Weapons add damage per second x a DPS weight.
-- Primary stat comes from your class; change it with /sg primary str|agi|int.

local GetInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local GetInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetStats = (C_Item and C_Item.GetItemStats) or GetItemStats
local GetBagLink = (C_Container and C_Container.GetContainerItemLink) or GetContainerItemLink

local WEAPON_CLASS, ARMOR_CLASS = 2, 4
local CLOTH, LEATHER, MAIL, PLATE, SHIELD = 1, 2, 3, 4, 6
local MAIN_HAND, OFF_HAND, RANGED = 16, 17, 18

-- Equip location -> inventory slot(s)
local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 },
    INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 },
    INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 },
    INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { MAIN_HAND }, INVTYPE_WEAPONMAINHAND = { MAIN_HAND },
    INVTYPE_2HWEAPON = { MAIN_HAND },
    INVTYPE_WEAPONOFFHAND = { OFF_HAND }, INVTYPE_SHIELD = { OFF_HAND }, INVTYPE_HOLDABLE = { OFF_HAND },
    INVTYPE_RANGED = { RANGED }, INVTYPE_RANGEDRIGHT = { RANGED }, INVTYPE_THROWN = { RANGED },
}

local RANGED_LOCS = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true }

-- Weapon subclasses each class can learn (Classic rules, plus Forever changes: rogues use 1H axes).
-- 0 1H axe, 1 2H axe, 2 bow, 3 gun, 4 1H mace, 5 2H mace, 6 polearm, 7 1H sword, 8 2H sword,
-- 10 staff, 13 fist, 14 misc, 15 dagger, 16 thrown, 18 crossbow, 19 wand
local function Set(list)
    local s = {}
    for _, v in ipairs(list) do s[v] = true end
    return s
end
local CLASS_WEAPONS = {
    WARRIOR = Set({ 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 14, 15, 16, 18 }),
    PALADIN = Set({ 0, 1, 4, 5, 6, 7, 8, 14 }),
    HUNTER = Set({ 0, 1, 2, 3, 6, 7, 8, 10, 13, 14, 15, 16, 18 }),
    ROGUE = Set({ 0, 2, 3, 4, 7, 13, 14, 15, 16, 18 }),
    SHAMAN = Set({ 0, 1, 4, 5, 10, 13, 14, 15 }),
    DRUID = Set({ 4, 5, 6, 10, 13, 14, 15 }),
    PRIEST = Set({ 4, 10, 14, 15, 19 }),
    MAGE = Set({ 7, 10, 14, 15, 19 }),
    WARLOCK = Set({ 7, 10, 14, 15, 19 }),
}
local SHIELD_CLASSES = { WARRIOR = true, PALADIN = true, SHAMAN = true }

local CLASS_PRIMARY = {
    WARRIOR = "str", PALADIN = "str", DEATHKNIGHT = "str",
    ROGUE = "agi", HUNTER = "agi", DEMONHUNTER = "agi", MONK = "agi",
    MAGE = "int", PRIEST = "int", WARLOCK = "int", SHAMAN = "int", DRUID = "int", EVOKER = "int",
}

-- Best armour type each class can wear: { type, from level }, checked top down
local CLASS_ARMOR = {
    WARRIOR = { { PLATE, 40 }, { MAIL, 1 } }, PALADIN = { { PLATE, 40 }, { MAIL, 1 } },
    DEATHKNIGHT = { { PLATE, 1 } },
    HUNTER = { { MAIL, 40 }, { LEATHER, 1 } }, SHAMAN = { { MAIL, 40 }, { LEATHER, 1 } },
    EVOKER = { { MAIL, 1 } },
    ROGUE = { { LEATHER, 1 } }, DRUID = { { LEATHER, 1 } }, MONK = { { LEATHER, 1 } },
    DEMONHUNTER = { { LEATHER, 1 } },
    MAGE = { { CLOTH, 1 } }, PRIEST = { { CLOTH, 1 } }, WARLOCK = { { CLOTH, 1 } },
}

local PRIMARY_KEY = {
    str = "ITEM_MOD_STRENGTH_SHORT", agi = "ITEM_MOD_AGILITY_SHORT", int = "ITEM_MOD_INTELLECT_SHORT",
}

local classFile
local weights = {}
local meleeDps, rangedDps = 0, 0   -- score per point of weapon damage per second
local scoreCache = {}

local function BuildWeights()
    local primary = SoloGearChar.primary or CLASS_PRIMARY[classFile] or "str"
    weights = {
        ITEM_MOD_STAMINA_SHORT = 0.5,
        ITEM_MOD_SPIRIT_SHORT = primary == "int" and 0.3 or 0.05,
        RESISTANCE0_NAME = 0.02,   -- armour value
        ITEM_MOD_CRIT_RATING_SHORT = 0.4, ITEM_MOD_HASTE_RATING_SHORT = 0.4,
        ITEM_MOD_MASTERY_RATING_SHORT = 0.4, ITEM_MOD_VERSATILITY = 0.4,
        ITEM_MOD_HIT_RATING_SHORT = 0.4,
        ITEM_MOD_ATTACK_POWER_SHORT = primary == "int" and 0 or 0.4,
        ITEM_MOD_SPELL_POWER_SHORT = primary == "int" and 0.8 or 0,
    }
    weights[PRIMARY_KEY[primary]] = 1
    -- Plate wearers still get some value from the other physical stat
    if primary == "str" then weights.ITEM_MOD_AGILITY_SHORT = 0.1 end
    if primary == "agi" then weights.ITEM_MOD_STRENGTH_SHORT = 0.05 end
    -- 1 DPS is worth about 7 Strength in Classic (14 AP); 5 keeps stats in the picture.
    -- Casters barely melee; hunters live on the ranged slot; wands matter to casters.
    meleeDps = primary == "int" and 0.3 or 5
    if classFile == "HUNTER" then
        rangedDps = 5
    elseif primary == "int" then
        rangedDps = 2
    else
        rangedDps = 0.5
    end
    wipe(scoreCache)
end

local function CanWear(classID, subclassID, equipLoc)
    if classID == WEAPON_CLASS then
        local allowed = CLASS_WEAPONS[classFile]
        return not allowed or allowed[subclassID] == true
    end
    if classID ~= ARMOR_CLASS then return false end
    if equipLoc == "INVTYPE_SHIELD" or subclassID == SHIELD then return SHIELD_CLASSES[classFile] == true end
    if equipLoc == "INVTYPE_CLOAK" or subclassID == 0 then return true end   -- cloaks, jewellery, off-hands
    local level = UnitLevel("player")
    for _, entry in ipairs(CLASS_ARMOR[classFile] or {}) do
        if level >= entry[2] then return subclassID <= entry[1] end
    end
    return subclassID == CLOTH
end

-- Weapon DPS from the tooltip, for clients whose item stats leave it out
local function TooltipDps(link)
    if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return nil end
    local data = C_TooltipInfo.GetHyperlink(link)
    for _, line in ipairs(data and data.lines or {}) do
        local dps = line.leftText and line.leftText:match("%(([%d%.]+) damage per second%)")
        if dps then return tonumber(dps) end
    end
end

-- Returns score, or nil if the item cannot be scored (not cached yet, not gear)
local function Score(link)
    if not link then return 0 end
    local cached = scoreCache[link]
    if cached then return cached end
    local stats = GetStats(link)
    if not stats then return nil end
    local total = 0
    for key, value in pairs(stats) do
        total = total + value * (weights[key] or 0)
    end

    local _, _, _, equipLoc, _, classID = GetInfoInstant(link)
    if classID == WEAPON_CLASS then
        local dps = stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT or TooltipDps(link) or 0
        total = total + dps * (RANGED_LOCS[equipLoc] and rangedDps or meleeDps)
    end

    scoreCache[link] = total
    return total
end

local function EquippedScore(slot)
    return Score(GetInventoryItemLink("player", slot))
end

-- What the hands hold now: main hand plus off hand (a two-hander fills both)
local function HandsScore()
    local main, off = EquippedScore(MAIN_HAND), EquippedScore(OFF_HAND)
    if main == nil or off == nil then return nil end
    return main + off
end

-- Returns diff vs the weakest equipped item in that slot, or nil / "cant"
local function Compare(link)
    if not link then return nil end
    local _, _, _, equipLoc, _, classID, subclassID = GetInfoInstant(link)
    local slots = equipLoc and SLOTS[equipLoc]
    if not slots then return nil end
    if not CanWear(classID, subclassID, equipLoc) then return "cant" end
    local minLevel = select(5, GetInfo(link))
    if minLevel and minLevel > UnitLevel("player") then return "cant" end
    local score = Score(link)
    if not score then return nil end

    -- A two-hander replaces main hand and off hand together
    if equipLoc == "INVTYPE_2HWEAPON" then
        local hands = HandsScore()
        return hands and score - hands
    end

    -- An off-hand item while wielding a two-hander means giving the two-hander up
    if slots[1] == OFF_HAND then
        local mainLink = GetInventoryItemLink("player", MAIN_HAND)
        if mainLink and select(4, GetInfoInstant(mainLink)) == "INVTYPE_2HWEAPON" then
            local main = EquippedScore(MAIN_HAND)
            return main and score - main
        end
    end

    -- A one-hander may go in either hand once you can dual wield
    if equipLoc == "INVTYPE_WEAPON" and CanDualWield and CanDualWield() then
        local offLink = GetInventoryItemLink("player", OFF_HAND)
        local offIsWeapon = offLink and select(6, GetInfoInstant(offLink)) == WEAPON_CLASS
        if offIsWeapon then slots = { MAIN_HAND, OFF_HAND } end
    end

    local worst
    for _, slot in ipairs(slots) do
        local equipped = EquippedScore(slot)
        if equipped == nil then return nil end
        if not worst or equipped < worst then worst = equipped end
    end
    return score - worst
end
SoloGear_Compare = Compare   -- for SoloLoot's upgrade marks

-- Bag overlay ------------------------------------------------------------

local function Mark(button, bag, slot)
    local diff = Compare(GetBagLink(bag, slot))
    local show = type(diff) == "number" and diff > 0.01
    if show and not button.SoloGearMark then
        local fs = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
        fs:SetPoint("TOPLEFT", 2, -1)
        fs:SetTextColor(0.25, 1, 0.25)
        fs:SetText("+")
        button.SoloGearMark = fs
    end
    if button.SoloGearMark then button.SoloGearMark:SetShown(show) end
end

local function ButtonBag(button, frame)
    if button.GetBagID then return button:GetBagID() end
    return frame:GetID()
end

local function ScanFrame(frame, name)
    if not frame or not frame:IsShown() then return end
    if frame.EnumerateValidItems then
        for _, button in frame:EnumerateValidItems() do
            Mark(button, ButtonBag(button, frame), button:GetID())
        end
    else
        for i = 1, 40 do
            local button = _G[name .. "Item" .. i]
            if not button then break end
            Mark(button, ButtonBag(button, frame), button:GetID())
        end
    end
end

local function ScanBags()
    ScanFrame(_G.ContainerFrameCombinedBags, "ContainerFrameCombinedBags")
    for i = 1, 13 do
        local name = "ContainerFrame" .. i
        ScanFrame(_G[name], name)
    end
end

-- Tooltip ----------------------------------------------------------------

local function AddTooltipLine(tooltip)
    if not tooltip.GetItem then return end
    local _, link = tooltip:GetItem()
    local diff = Compare(link)
    if diff == "cant" then
        tooltip:AddLine("SoloGear: can't wear yet", 0.5, 0.5, 0.5)
    elseif type(diff) == "number" then
        if diff > 0.01 then
            tooltip:AddLine(string.format("SoloGear: +%.1f upgrade", diff), 0.25, 1, 0.25)
        elseif diff < -0.01 then
            tooltip:AddLine(string.format("SoloGear: %.1f worse", diff), 1, 0.35, 0.35)
        else
            tooltip:AddLine("SoloGear: same as worn", 1, 1, 1)
        end
    end
end

if TooltipDataProcessor and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
        if tooltip == GameTooltip or tooltip == ItemRefTooltip then AddTooltipLine(tooltip) end
    end)
else
    GameTooltip:HookScript("OnTooltipSetItem", AddTooltipLine)
    ItemRefTooltip:HookScript("OnTooltipSetItem", AddTooltipLine)
end

-- Quest reward pick -------------------------------------------------------
-- 1. If any choice is an upgrade, pick the biggest upgrade.
-- 2. Otherwise pick the one that sells for the most gold.

local function RewardButton(i)
    if QuestInfo_GetRewardButton and QuestInfoFrame and QuestInfoFrame.rewardsFrame then
        local button = QuestInfo_GetRewardButton(QuestInfoFrame.rewardsFrame, i)
        if button then return button end
    end
    return _G["QuestInfoRewardsFrameQuestInfoItem" .. i]
end

local function ClearRewardLabels()
    for i = 1, 10 do
        local button = RewardButton(i)
        if button and button.SoloGearPick then button.SoloGearPick:Hide() end
    end
end

local function LabelReward(i, label)
    local button = RewardButton(i)
    if not button then return end
    if not button.SoloGearPick then
        local fs = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, -2)
        button.SoloGearPick = fs
    end
    button.SoloGearPick:SetText(label)
    button.SoloGearPick:Show()
end

-- Returns true if item data was missing and nothing was shown yet
local function PickReward(final, announce)
    ClearRewardLabels()
    local count = GetNumQuestChoices()
    if count < 2 then return false end

    local bestUpgrade, bestUpgradeIndex = 0.01, nil
    local bestPrice, bestPriceIndex = -1, nil
    local missing = false
    for i = 1, count do
        local link = GetQuestItemLink("choice", i)
        local diff = Compare(link)
        if type(diff) == "number" and diff > bestUpgrade then
            bestUpgrade, bestUpgradeIndex = diff, i
        end
        local price = link and select(11, GetInfo(link))
        if price == nil then missing = true end
        if price and price > bestPrice then
            bestPrice, bestPriceIndex = price, i
        end
    end

    if missing and not final then return true end

    local index, label, why
    if bestUpgradeIndex then
        index = bestUpgradeIndex
        label = string.format("|cff40ff40Upgrade +%.1f|r", bestUpgrade)
        why = string.format("upgrade +%.1f", bestUpgrade)
    elseif bestPriceIndex and bestPrice > 0 then
        index = bestPriceIndex
        label = "|cffffd040Best gold|r"
        why = "no upgrade, sells for " .. GetCoinTextureString(bestPrice)
    end
    if index then
        LabelReward(index, label)
        if announce then
            print("SoloGear pick: " .. GetQuestItemLink("choice", index) .. " (" .. why .. ")")
        end
    end
    return false
end

local function PickRewardWhenReady(announce)
    -- Item data may not be cached on first open; try again shortly
    if PickReward(false, announce) then
        C_Timer.After(0.5, function() PickReward(true, announce) end)
    end
end

-- Events -----------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("QUEST_COMPLETE")
frame:RegisterEvent("QUEST_DETAIL")
frame:SetScript("OnEvent", function(_, event)
    if event == "QUEST_COMPLETE" or event == "QUEST_DETAIL" then
        -- Run after Blizzard has laid out the reward buttons
        local announce = event == "QUEST_COMPLETE"
        C_Timer.After(0, function() PickRewardWhenReady(announce) end)
    elseif event == "PLAYER_LOGIN" then
        SoloGearChar = SoloGearChar or {}
        _, classFile = UnitClass("player")
        BuildWeights()
        C_Timer.NewTicker(0.5, ScanBags)   -- cheap: only open bags are scanned
    else
        wipe(scoreCache)
    end
end)

-- Slot overview: what you wear and its score, weakest first, with upgrade sources from
-- Upgrades.lua (SoloGearUpgrades[class], kept by Claude) for your level
local SLOT_NAMES = {
    [1] = "Head", [2] = "Neck", [3] = "Shoulder", [5] = "Chest", [6] = "Waist", [7] = "Legs", [8] = "Feet",
    [9] = "Wrist", [10] = "Hands", [11] = "Finger 1", [12] = "Finger 2", [13] = "Trinket 1", [14] = "Trinket 2",
    [15] = "Back", [16] = "Main Hand", [17] = "Off Hand", [18] = "Ranged",
}
local SLOT_ORDER = { 16, 17, 18, 5, 7, 1, 3, 10, 8, 6, 9, 15, 2, 11, 12, 13, 14 }

local function PrintBis()
    local level = UnitLevel("player")
    local rows = {}
    for _, slot in ipairs(SLOT_ORDER) do
        local link = GetInventoryItemLink("player", slot)
        local score = link and Score(link) or 0
        table.insert(rows, { slot = slot, link = link, score = score or 0 })
    end
    table.sort(rows, function(a, b) return a.score < b.score end)
    print("SoloGear: your slots, weakest first (score):")
    for _, r in ipairs(rows) do
        print(string.format("  %s: %s  |cff888888%.1f|r", SLOT_NAMES[r.slot], r.link or "|cffff6060empty|r", r.score))
    end
    local hints = SoloGearUpgrades and SoloGearUpgrades[classFile]
    if not hints then return end
    print("SoloGear: upgrade sources near your level (" .. level .. "):")
    local any = false
    for _, h in ipairs(hints) do
        if h.level <= level + 4 and h.level >= level - 6 then
            print(string.format("  |cffffd040%s|r (%s, level %d): %s", h.item, h.slot, h.level, h.source))
            any = true
        end
    end
    if not any then print("  nothing listed for this level yet; ask Claude to extend Upgrades.lua") end
end

SLASH_SOLOGEAR1 = "/sg"
SLASH_SOLOGEAR2 = "/sologear"
SlashCmdList.SOLOGEAR = function(msg)
    local cmd, arg = strsplit(" ", strlower(strtrim(msg or "")))
    if cmd == "bis" then
        PrintBis()
        return
    elseif cmd == "primary" and PRIMARY_KEY[arg] then
        SoloGearChar.primary = arg
        BuildWeights()
    elseif cmd == "primary" and arg == "auto" then
        SoloGearChar.primary = nil
        BuildWeights()
    end
    local primary = SoloGearChar.primary or CLASS_PRIMARY[classFile] or "str"
    print(string.format("SoloGear: %s, primary stat |cff40ff40%s|r%s  (/sg primary str | agi | int | auto, /sg bis)",
        classFile, primary, SoloGearChar.primary and " (set by you)" or " (class default)"))
end
