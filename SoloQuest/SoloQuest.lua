-- SoloQuest: auto accept quests and auto turn in finished ones.
-- Stops when there is a reward to choose or gold to pay. Hold Shift to do it by hand.

local frame = CreateFrame("Frame")

local function Enabled()
    return SoloQuestDB.enabled and not IsShiftKeyDown()
end

local function GossipPick()
    if not C_GossipInfo then return end
    for _, q in ipairs(C_GossipInfo.GetActiveQuests() or {}) do
        if q.isComplete then
            C_GossipInfo.SelectActiveQuest(q.questID)
            return
        end
    end
    local available = C_GossipInfo.GetAvailableQuests() or {}
    if available[1] then
        C_GossipInfo.SelectAvailableQuest(available[1].questID)
    end
end

local function GreetingPick()
    for i = 1, GetNumActiveQuests() do
        local _, isComplete = GetActiveTitle(i)
        if isComplete then
            SelectActiveQuest(i)
            return
        end
    end
    if GetNumAvailableQuests() > 0 then
        SelectAvailableQuest(1)
    end
end

local handlers = {
    QUEST_DETAIL = function()
        AcceptQuest()
    end,
    QUEST_PROGRESS = function()
        if IsQuestCompletable() and GetQuestMoneyToGet() == 0 then
            CompleteQuest()
        end
    end,
    QUEST_COMPLETE = function()
        local choices = GetNumQuestChoices()
        if choices <= 1 then
            GetQuestReward(choices)
        end
    end,
    GOSSIP_SHOW = GossipPick,
    QUEST_GREETING = GreetingPick,
}

frame:RegisterEvent("PLAYER_LOGIN")
for event in pairs(handlers) do frame:RegisterEvent(event) end

frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        SoloQuestDB = SoloQuestDB or { enabled = true }
        return
    end
    if Enabled() then handlers[event]() end
end)

SLASH_SOLOQUEST1 = "/sq"
SLASH_SOLOQUEST2 = "/soloquest"
SlashCmdList.SOLOQUEST = function(msg)
    msg = strlower(strtrim(msg or ""))
    if msg == "on" then
        SoloQuestDB.enabled = true
    elseif msg == "off" then
        SoloQuestDB.enabled = false
    end
    print("SoloQuest: " .. (SoloQuestDB.enabled and "|cff40ff40on|r" or "|cffff4040off|r")
        .. "  (/sq on | off, hold Shift to pause)")
end
