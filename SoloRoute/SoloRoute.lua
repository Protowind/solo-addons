-- SoloRoute: a levelling route, one step at a time, with a map pin for the current step.
-- Routes live in Routes.lua (written by Claude). Accept / do / turn-in steps tick themselves
-- off from the quest log; note steps need the Done button. The pin is the game's own map
-- waypoint (the arrow at the top of the screen), which addons may set out of combat.
-- /route toggles the panel; /route next | back | pin | auto | reset | list | use <key>.

local WIDTH = 300

local route, mapID
local db, char

-- Route and map lookup ---------------------------------------------------

local function RaceRoute()
    local _, raceFile = UnitRace("player")
    for _, r in ipairs(SoloRoutes) do
        if r.races and r.races[raceFile] then return r end
    end
    return SoloRoutes[1]
end

local function FindRoute(key)
    for _, r in ipairs(SoloRoutes) do
        if r.key == key then return r end
    end
end

-- Zone map IDs differ between the Classic and retail numbering: check the candidates by name,
-- else use the map we stand on when the zone matches
local function ResolveMap()
    mapID = nil
    if not (route and C_Map and C_Map.GetMapInfo) then return end
    for _, id in ipairs(route.maps or {}) do
        local info = C_Map.GetMapInfo(id)
        if info and info.name == route.zone then mapID = id return end
    end
    if GetZoneText() == route.zone then mapID = C_Map.GetBestMapForUnit("player") end
end

-- Quest log state --------------------------------------------------------

local onQuest, complete = {}, {}   -- by ID and by title

local function ReadLog()
    wipe(onQuest) wipe(complete)
    if not (C_QuestLog and C_QuestLog.GetInfo) then return end
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader then
            onQuest[info.questID], onQuest[info.title] = true, true
            if C_QuestLog.IsComplete and C_QuestLog.IsComplete(info.questID) then
                complete[info.questID], complete[info.title] = true, true
            end
            char.seen[info.title] = true   -- for turn-in steps whose ID is missing or wrong
        end
    end
end

local function Flagged(id)
    return id and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(id)
end

-- Quest title for log matching: "do" steps carry the objective after a colon
local function Title(step)
    if step[1] == "d" then return (step[3]:match("^(.*):") or step[3]) end   -- greedy: keeps "WANTED: Maggot Eye"
    return step[3]
end

local function StepDone(step)
    local kind, id = step[1], step[2]
    local title = Title(step)
    if kind == "n" then return false end
    if Flagged(id) then return true end
    if kind == "a" then return onQuest[id] or onQuest[title] or false end
    if kind == "d" then return complete[id] or complete[title] or false end
    if kind == "t" then
        -- Flag check failed (no ID): the quest was in the log earlier and is gone now
        return (id == nil or not Flagged(id)) and char.seen[title] and not onQuest[title] or false
    end
    return false
end

-- Panel --------------------------------------------------------------------

local KIND = { a = "Accept", d = "Do", t = "Turn in", n = "Note" }
local KIND_COLOUR = { a = "40c0ff", d = "ffd040", t = "40ff40", n = "c0c0c0" }

local panel = CreateFrame("Frame", "SoloRoutePanel", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
panel:SetSize(WIDTH, 110)
panel:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -200, -120)
panel:SetClampedToScreen(true)
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
panel:SetBackdropColor(0.04, 0.04, 0.04, 0.85)
panel:Hide()

local header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
header:SetPoint("TOPLEFT", 10, -8)

local progress = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
progress:SetPoint("TOPRIGHT", -10, -9)

local stepText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
stepText:SetPoint("TOPLEFT", 10, -28)
stepText:SetWidth(WIDTH - 20)
stepText:SetJustifyH("LEFT")

local whereText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
whereText:SetPoint("TOPLEFT", stepText, "BOTTOMLEFT", 0, -3)
whereText:SetWidth(WIDTH - 20)
whereText:SetJustifyH("LEFT")
whereText:SetTextColor(0.7, 0.7, 0.7)

local nextText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
nextText:SetPoint("TOPLEFT", whereText, "BOTTOMLEFT", 0, -6)
nextText:SetWidth(WIDTH - 20)
nextText:SetJustifyH("LEFT")
nextText:SetTextColor(0.5, 0.5, 0.5)

local buttons = CreateFrame("Frame", nil, panel)
buttons:SetSize(WIDTH - 20, 22)
buttons:SetPoint("TOPLEFT", nextText, "BOTTOMLEFT", 0, -8)

local function Button(label, x, width, onClick)
    local b = CreateFrame("Button", nil, buttons, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetPoint("LEFT", x, 0)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
end

local Refresh, Pin

local function Step(n)
    return route and route.steps[n]
end

local function SetStep(n, why)
    if not route then return end
    n = math.max(1, math.min(n, #route.steps + 1))
    local changed = char.step ~= n
    char.step = n
    if changed and why then print(string.format("SoloRoute: step %d (%s)", n, why)) end
    if changed and char.autopin ~= false then Pin(true) end
    Refresh()
end

-- Advance past every finished step, from the quest log
local function Advance()
    if not route then return end
    ReadLog()
    local n = char.step
    while Step(n) and StepDone(Step(n)) do n = n + 1 end
    if n ~= char.step then SetStep(n, "done") end
end

function Pin(quiet)
    local step = Step(char.step)
    if not step or not step[5] then
        if not quiet then print("SoloRoute: this step has no map position.") end
        return
    end
    if not mapID then ResolveMap() end
    if not mapID then
        if not quiet then print("SoloRoute: not in " .. route.zone .. ", no pin set.") end
        return
    end
    local ok, err = pcall(function()
        if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(mapID) then
            error("the map does not take waypoints")
        end
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, step[5] / 100, step[6] / 100))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end
    end)
    if not ok and not quiet then print("SoloRoute: pin failed: " .. tostring(err)) end
end

function Refresh()
    if not route then
        header:SetText("SoloRoute")
        stepText:SetText("No route for this character. /route list")
        whereText:SetText("") nextText:SetText("") progress:SetText("")
        return
    end
    header:SetText(route.name)
    local step = Step(char.step)
    if not step then
        progress:SetText(#route.steps .. " / " .. #route.steps)
        stepText:SetText("|cff40ff40Route finished.|r Ask Claude for the next zone.")
        whereText:SetText("") nextText:SetText("")
    else
        progress:SetText(char.step .. " / " .. #route.steps)
        stepText:SetText(string.format("|cff%s%s:|r %s", KIND_COLOUR[step[1]] or "ffffff", KIND[step[1]] or "?", step[3]))
        local where = step[4] or ""
        if step[5] then where = where .. string.format("  |cff888888(%.0f, %.0f)|r", step[5], step[6]) end
        whereText:SetText(where)
        local nxt = Step(char.step + 1)
        nextText:SetText(nxt and ("Next: " .. (KIND[nxt[1]] or "?") .. " " .. nxt[3]) or "")
    end
    local h = 28 + stepText:GetStringHeight() + 3 + whereText:GetStringHeight() + 6
        + nextText:GetStringHeight() + 8 + 22 + 10
    panel:SetHeight(h)
end

Button("Pin", 0, 60, function() Pin(false) end)
Button("Done", 66, 60, function() SetStep(char.step + 1, "done by hand") end)
Button("Back", 132, 60, function() SetStep(char.step - 1) end)
Button("Hide", WIDTH - 20 - 60, 60, function() panel:Hide() db.shown = false end)

panel:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown() then self:StartMoving() end
end)
panel:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    db.pos = { point, relPoint, x, y }
end)

-- Events -------------------------------------------------------------------

local pending = false
local function AdvanceSoon()
    if pending or not route then return end
    pending = true
    C_Timer.After(1, function() pending = false Advance() end)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("QUEST_ACCEPTED")
frame:RegisterEvent("QUEST_TURNED_IN")
frame:RegisterEvent("QUEST_LOG_UPDATE")
frame:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        if db then AdvanceSoon() return end
        SoloRouteDB = SoloRouteDB or {}
        SoloRouteChar = SoloRouteChar or {}
        db, char = SoloRouteDB, SoloRouteChar
        char.step = char.step or 1
        char.seen = char.seen or {}
        route = (char.route and FindRoute(char.route)) or RaceRoute()
        if route then char.route = route.key end
        ResolveMap()
        if db.pos then
            panel:ClearAllPoints()
            panel:SetPoint(db.pos[1], UIParent, db.pos[2], db.pos[3], db.pos[4])
        end
        Refresh()
        if db.shown ~= false then panel:Show() end
        C_Timer.After(3, Advance)
    elseif not db then
        return
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        ResolveMap()
    else
        AdvanceSoon()
    end
end)

-- Slash ----------------------------------------------------------------------

SLASH_SOLOROUTE1 = "/route"
SLASH_SOLOROUTE2 = "/soloroute"
SlashCmdList.SOLOROUTE = function(msg)
    if not db then return end
    msg = strlower(strtrim(msg or ""))
    local use = msg:match("^use%s+(%S+)$")
    local goto_ = tonumber(msg:match("^step%s+(%d+)$") or "")
    if msg == "" then
        db.shown = not panel:IsShown()
        panel:SetShown(db.shown)
    elseif msg == "next" then
        SetStep(char.step + 1, "skipped")
    elseif msg == "back" then
        SetStep(char.step - 1)
    elseif goto_ then
        SetStep(goto_, "jumped")
    elseif msg == "pin" then
        Pin(false)
    elseif msg == "auto" then
        char.autopin = char.autopin == false
        print("SoloRoute: pin on each new step " .. (char.autopin == false and "off" or "on"))
    elseif msg == "reset" then
        char.step = 1
        wipe(char.seen)
        Advance()
        print("SoloRoute: back to step 1.")
    elseif msg == "list" then
        for _, r in ipairs(SoloRoutes) do
            print(string.format("SoloRoute: %s = %s (%d steps)%s", r.key, r.name, #r.steps,
                route and r.key == route.key and "  <- in use" or ""))
        end
    elseif use then
        local r = FindRoute(use)
        if not r then print("SoloRoute: no route " .. use .. ". /route list") return end
        route, char.route, char.step = r, r.key, 1
        wipe(char.seen)
        ResolveMap()
        Advance()
        Refresh()
        panel:Show()
    else
        print("SoloRoute: /route (toggle) | next | back | step <n> | pin | auto | reset | list | use <key>")
    end
end
