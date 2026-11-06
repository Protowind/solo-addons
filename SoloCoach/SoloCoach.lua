-- SoloCoach: the bridge between the game and Claude.
-- Game -> Claude: a snapshot of the character is kept in SoloCoachChar.snapshot, taken every
--   minute and a few seconds after quests, levels, gold, gear or bags change, and the game saves
--   it on /reload or logout. On this client the character data is already gone when
--   PLAYER_LOGOUT fires on logout, so a blank snapshot never replaces the last good one.
--   Claude reads it from WTF\Account\<account>\<realm>\<character>\SavedVariables\SoloCoach.lua
-- Claude -> game: Claude writes Advice.lua in this folder; /reload loads it and the notes
--   panel opens when the notes are new. /coach toggles the panel.

local GetItemLevel = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo
local GetSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots

local SLOT_NAMES = {
    [1] = "Head", [2] = "Neck", [3] = "Shoulder", [4] = "Shirt", [5] = "Chest", [6] = "Waist",
    [7] = "Legs", [8] = "Feet", [9] = "Wrist", [10] = "Hands", [11] = "Finger 1", [12] = "Finger 2",
    [13] = "Trinket 1", [14] = "Trinket 2", [15] = "Back", [16] = "Main Hand", [17] = "Off Hand",
    [18] = "Ranged", [19] = "Tabard",
}

local session   -- SoloCoachChar.session: survives /reload, resets on a fresh login

-- Snapshot ----------------------------------------------------------------

local function ItemEntry(link)
    if not link then return nil end
    local id = tonumber(link:match("item:(%d+)"))
    local name = link:match("%[(.-)%]")
    local ilvl = GetItemLevel and GetItemLevel(link)
    return { id = id, name = name, ilvl = ilvl }
end

local function Equipment()
    local gear = {}
    for slot, slotName in pairs(SLOT_NAMES) do
        gear[slotName] = ItemEntry(GetInventoryItemLink("player", slot)) or "empty"
    end
    return gear
end

local function BagItem(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        return info and info.hyperlink, info and info.stackCount
    end
    local _, count, _, _, _, _, link = GetContainerItemInfo(bag, slot)
    return link, count
end

local function Bags()
    local items, free = {}, 0
    for bag = 0, 4 do
        for slot = 1, (GetSlots(bag) or 0) do
            local link, count = BagItem(bag, slot)
            if link then
                local entry = ItemEntry(link)
                entry.count = count
                table.insert(items, entry)
            else
                free = free + 1
            end
        end
    end
    return { items = items, free = free }
end

local function Quests()
    local quests = {}
    if C_QuestLog and C_QuestLog.GetInfo then
        for i = 1, C_QuestLog.GetNumQuestLogEntries() do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader then
                local objectives = {}
                for _, o in ipairs(C_QuestLog.GetQuestObjectives(info.questID) or {}) do
                    table.insert(objectives, o.text)
                end
                table.insert(quests, {
                    id = info.questID, title = info.title, level = info.level,
                    complete = C_QuestLog.IsComplete and C_QuestLog.IsComplete(info.questID) or false,
                    objectives = objectives,
                })
            end
        end
    else
        for i = 1, GetNumQuestLogEntries() do
            local title, level, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(i)
            if title and not isHeader then
                local objectives = {}
                for j = 1, GetNumQuestLeaderBoards(i) do
                    table.insert(objectives, (GetQuestLogLeaderBoard(j, i)))
                end
                table.insert(quests, { id = questID, title = title, level = level,
                    complete = isComplete == 1, objectives = objectives })
            end
        end
    end
    return quests
end

local function Skills()
    local skills = {}
    if GetNumSkillLines then
        for i = 1, GetNumSkillLines() do
            local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
            if name and not isHeader then skills[name] = string.format("%d/%d", rank, maxRank) end
        end
    elseif GetProfessions then
        -- Forever beta (12.x engine) has no skill line API: professions only, no weapon skills
        for _, index in pairs({ GetProfessions() }) do
            local name, _, rank, maxRank = GetProfessionInfo(index)
            if name then skills[name] = string.format("%d/%d", rank, maxRank) end
        end
    else
        return nil
    end
    return skills
end

local function Position()
    if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
    local mapID = C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return nil end
    local x, y = pos:GetXY()
    return string.format("%.1f, %.1f", x * 100, y * 100)
end

local function Snapshot()
    local _, classFile = UnitClass("player")
    local snap = {
        taken = date("%Y-%m-%d %H:%M:%S"),
        name = UnitName("player"),
        realm = GetRealmName(),
        race = UnitRace("player"),
        class = classFile,
        level = UnitLevel("player"),
        xp = UnitXP("player"), xpMax = UnitXPMax("player"),
        rested = GetXPExhaustion() or 0,
        money = GetMoney(),
        zone = GetZoneText(), subzone = GetSubZoneText(),
        session = {
            minutes = math.floor((time() - (session.start or time())) / 60),
            deaths = session.deaths,
            moneyChange = GetMoney() - (session.money or GetMoney()),
            levelStart = session.level,
        },
    }
    -- Each part is optional: one failing API must not lose the rest
    local parts = { gear = Equipment, bags = Bags, quests = Quests, skills = Skills, position = Position }
    for key, fn in pairs(parts) do
        local ok, value = pcall(fn)
        if not ok then
            snap[key] = "error: " .. tostring(value)
        elseif value == nil then
            snap[key] = "not available on this client"
        else
            snap[key] = value
        end
    end
    -- Blank snapshot (logout, or data not loaded yet): keep the last good one
    local hasGear = false
    if type(snap.gear) == "table" then
        for _, v in pairs(snap.gear) do
            if v ~= "empty" then hasGear = true break end
        end
    end
    if (snap.xpMax or 0) == 0 and (snap.money or 0) == 0 and not hasGear then return false end
    SoloCoachChar.snapshot = snap
    return true
end

-- Several change events arrive at once (a quest hand-in moves XP, gold, bags and the log):
-- take one snapshot a few seconds after the first
local snapshotPending = false
local function SnapshotSoon()
    if snapshotPending or not session then return end
    snapshotPending = true
    C_Timer.After(3, function()
        snapshotPending = false
        Snapshot()
    end)
end

-- Notes panel -------------------------------------------------------------

local panel = CreateFrame("Frame", "SoloCoachPanel", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
panel:SetSize(380, 260)
panel:SetPoint("CENTER", 300, 80)
panel:SetFrameStrata("DIALOG")
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
panel:SetClampedToScreen(true)
panel:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
panel:SetBackdropColor(0, 0, 0, 0.85)
panel:Hide()

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", 12, -10)

local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)

local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 12, -30)
scroll:SetPoint("BOTTOMRIGHT", -30, 12)

local content = CreateFrame("Frame", nil, scroll)
content:SetSize(330, 10)
scroll:SetScrollChild(content)

local body = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
body:SetPoint("TOPLEFT")
body:SetWidth(330)
body:SetJustifyH("LEFT")
body:SetSpacing(3)

local function ShowAdvice()
    local advice = SoloCoachAdvice
    if not advice or not advice.lines then
        title:SetText("SoloCoach")
        body:SetText("No notes yet. Do /reload, then ask Claude.")
    else
        title:SetText("Notes from Claude  |cff888888" .. (advice.updated or "") .. "|r")
        body:SetText(table.concat(advice.lines, "\n"))
    end
    content:SetHeight(body:GetStringHeight() + 10)
    panel:Show()
end

-- Events ------------------------------------------------------------------

local CHANGE_EVENTS = {
    "PLAYER_LEVEL_UP", "PLAYER_MONEY", "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_DELAYED",
    "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_LOG_UPDATE", "ZONE_CHANGED_NEW_AREA", "SKILL_LINES_CHANGED",
}

panel:RegisterEvent("PLAYER_ENTERING_WORLD")
panel:RegisterEvent("PLAYER_LOGOUT")
panel:RegisterEvent("PLAYER_DEAD")
for _, event in ipairs(CHANGE_EVENTS) do panel:RegisterEvent(event) end
panel:SetScript("OnEvent", function(_, event, isLogin)
    if event == "PLAYER_ENTERING_WORLD" then
        if session then return end   -- zoning, already set up
        SoloCoachDB = SoloCoachDB or {}
        SoloCoachChar = SoloCoachChar or {}
        if isLogin or not SoloCoachChar.session then
            SoloCoachChar.session = { start = time(), money = GetMoney(), level = UnitLevel("player"), deaths = 0 }
        end
        session = SoloCoachChar.session
        -- First snapshot once the data has loaded, then one a minute while playing
        C_Timer.After(5, Snapshot)
        C_Timer.NewTicker(60, Snapshot)
        -- Open the panel once for each new set of notes
        local updated = SoloCoachAdvice and SoloCoachAdvice.updated
        if updated and SoloCoachDB.seen ~= updated then
            SoloCoachDB.seen = updated
            C_Timer.After(2, ShowAdvice)
        end
    elseif not session then
        return
    elseif event == "PLAYER_LOGOUT" then
        Snapshot()   -- full on /reload; blank on logout (ignored), the last timed one is saved
    elseif event == "PLAYER_DEAD" then
        session.deaths = session.deaths + 1
    else
        SnapshotSoon()
    end
end)

SLASH_SOLOCOACH1 = "/coach"
SlashCmdList.SOLOCOACH = function(msg)
    msg = strlower(strtrim(msg or ""))
    if msg == "snap" then
        if Snapshot() then
            print("SoloCoach: snapshot taken. /reload to save it for Claude.")
        else
            print("SoloCoach: the client gave no character data; kept the last snapshot ("
                .. (SoloCoachChar.snapshot and SoloCoachChar.snapshot.taken or "none") .. ").")
        end
    elseif panel:IsShown() then
        panel:Hide()
    else
        ShowAdvice()
    end
end
