-- SoloPlus: small quality-of-life helpers.
-- Vendors: sells grey items when a merchant window opens, with one chat line (what was sold).
--   Auto repair is off by default (low levels rarely need it): /sp repair turns it on.
--   /sp sell and /sp repair toggle them.
-- Leatherworking: /sp lw prints the step of the plan (Leatherworking.lua, made by
--   tools\lw_plan.py) for your current skill, and again when your skill reaches the next step.
-- Logout: a warning if you log out away from an inn or city (no rested XP).

local GetSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
local UseItem = (C_Container and C_Container.UseContainerItem) or UseContainerItem

local function ItemInfo(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if not info then return nil end
        return info.hyperlink, info.quality, info.stackCount
    end
    local _, count, _, quality, _, _, link = GetContainerItemInfo(bag, slot)
    return link, quality, count
end

local function Money(copper)
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    if g > 0 then return string.format("%dg %ds %dc", g, s, c) end
    if s > 0 then return string.format("%ds %dc", s, c) end
    return c .. "c"
end

-- Vendor -------------------------------------------------------------------

local function SellGreys()
    local total, count = 0, 0
    for bag = 0, 4 do
        for slot = 1, (GetSlots(bag) or 0) do
            local link, quality, stack = ItemInfo(bag, slot)
            if link and quality == 0 then
                local price = select(11, (C_Item and C_Item.GetItemInfo or GetItemInfo)(link))
                UseItem(bag, slot)
                total = total + (price or 0) * (stack or 1)
                count = count + 1
            end
        end
    end
    if count > 0 then
        print(string.format("SoloPlus: sold %d grey item%s for %s.", count, count == 1 and "" or "s", Money(total)))
    end
end

local function Repair()
    if not CanMerchantRepair() then return end
    local cost, needed = GetRepairAllCost()
    if not needed or cost == 0 then return end
    if cost > GetMoney() then
        print("SoloPlus: repair costs " .. Money(cost) .. ", not enough gold.")
        return
    end
    RepairAllItems()
    print("SoloPlus: repaired for " .. Money(cost) .. ".")
end

-- Leatherworking -------------------------------------------------------------

local function LeatherworkingSkill()
    if not GetProfessions then return nil end
    for _, index in pairs({ GetProfessions() }) do
        local name, _, rank, maxRank = GetProfessionInfo(index)
        if name == "Leatherworking" then return rank, maxRank end
    end
end

local function LwStep(skill)
    for i, s in ipairs(SoloPlusLeatherworking or {}) do
        if skill >= s.from and skill < s.to then return s, SoloPlusLeatherworking[i + 1] end
    end
end

local lastLwStep

local function PrintLw(onlyIfChanged)
    local skill, max = LeatherworkingSkill()
    if not skill then
        if not onlyIfChanged then print("SoloPlus: you have no Leatherworking yet.") end
        return
    end
    local step, nextStep = LwStep(skill)
    if onlyIfChanged and step == lastLwStep then return end
    lastLwStep = step
    if not step then
        print(string.format("SoloPlus: Leatherworking %d/%d is past the plan (ends at 150).", skill, max))
        return
    end
    local gain = step.net >= 0 and ("|cff40ff40+" .. Money(step.net) .. "|r") or ("|cffff6060-" .. Money(-step.net) .. "|r")
    print(string.format("SoloPlus: Leatherworking %d/%d: make |cffffd040%s|r (%s) until %d, about %d crafts, %s each at the vendor.",
        skill, max, step.recipe, step.mats, step.to, math.max(1, math.ceil(step.crafts * (step.to - skill) / (step.to - step.from))), gain))
    if nextStep then
        print(string.format("   then %s (%s) %d-%d", nextStep.recipe, nextStep.mats, nextStep.from, nextStep.to))
    end
end

-- Events ----------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("SKILL_LINES_CHANGED")
frame:RegisterEvent("PLAYER_CAMPING")
frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        SoloPlusDB = SoloPlusDB or {}
        if SoloPlusDB.sell == nil then SoloPlusDB.sell = true end
        if SoloPlusDB.repair == nil then SoloPlusDB.repair = false end   -- off until /sp repair
    elseif not SoloPlusDB then
        return
    elseif event == "MERCHANT_SHOW" then
        if SoloPlusDB.sell then SellGreys() end
        if SoloPlusDB.repair then Repair() end
    elseif event == "SKILL_LINES_CHANGED" then
        PrintLw(true)
    elseif event == "PLAYER_CAMPING" then
        if not IsResting() then
            print("|cffff6060SoloPlus: you are not at an inn or in a city: no rested XP while logged out.|r")
        end
    end
end)

SLASH_SOLOPLUS1 = "/sp"
SLASH_SOLOPLUS2 = "/soloplus"
SlashCmdList.SOLOPLUS = function(msg)
    msg = strlower(strtrim(msg or ""))
    if msg == "sell" then
        SoloPlusDB.sell = not SoloPlusDB.sell
    elseif msg == "repair" then
        SoloPlusDB.repair = not SoloPlusDB.repair
    elseif msg == "lw" then
        PrintLw(false)
        return
    else
        print("SoloPlus: /sp sell | repair | lw")
    end
    print(string.format("SoloPlus: sell greys %s, repair %s",
        SoloPlusDB.sell and "|cff40ff40on|r" or "|cffff4040off|r",
        SoloPlusDB.repair and "|cff40ff40on|r" or "|cffff4040off|r"))
end
