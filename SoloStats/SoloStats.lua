-- SoloStats: FPS, latency, levelling and info readout (SoloLevel merged in).
-- Layouts: stacked (one item per line), row (one line, movable), top bar (full width, top of screen).
-- Each item can be turned off in the options panel (/ss or right-click).
-- Session survives /reload, resets on login or /ss session. Shift + left-drag to move.

local _, ns = ...

local KILL_SAMPLES = 10

-- group: items sharing a group sit on one line in the stacked layout.
-- default = false: off until turned on.
ns.LINES = {
    { key = "fps",        label = "FPS", group = "net" },
    { key = "latency",    label = "Latency (home / world)", group = "net" },
    { key = "level",      label = "Level and XP" },
    { key = "rate",       label = "XP per hour, time to level" },
    { key = "kills",      label = "Kills to level" },
    { key = "rested",     label = "Rested XP" },
    { key = "session",    label = "Session time and XP" },
    { key = "gold",       label = "Gold", info = true },
    { key = "bags",       label = "Bag space", info = true },
    { key = "durability", label = "Durability (lowest item)", info = true },
    { key = "time",       label = "Time", info = true, group = "clock" },
    { key = "date",       label = "Date", info = true, group = "clock", default = false },
    { key = "zone",       label = "Zone", info = true, default = false },
    { key = "coords",     label = "Coordinates", info = true, default = false },
}

ns.LAYOUTS = {
    { key = "stack", name = "Stacked" },
    { key = "row",   name = "Row" },
    { key = "bar",   name = "Top bar" },
}

-- Where the text sits in the top bar
ns.ALIGNS = {
    { key = "left",   name = "Left",   point = "LEFT",   x = 8 },
    { key = "center", name = "Centre", point = "CENTER", x = 0 },
    { key = "right",  name = "Right",  point = "RIGHT",  x = -8 },
}

local DEFAULTS = { theme = "classic", layout = "stack", align = "center", background = true, locked = false, shown = true }

local BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
ns.BACKDROP = BACKDROP

local GetNumSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
local GetFreeSlots = C_Container and C_Container.GetContainerNumFreeSlots or GetContainerNumFreeSlots
local BAG_COUNT = NUM_BAG_SLOTS or 4

local db, session
local lastXP, lastMax

local frame = CreateFrame("Frame", "SoloStatsFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
frame:SetSize(170, 20)
frame:SetFrameStrata("HIGH")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")

local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
text:SetSpacing(2)

local FONT_PATH, DEFAULT_SIZE, FONT_FLAGS = text:GetFont()
ns.DEFAULT_SIZE = DEFAULT_SIZE

function ns.Theme()
    return ns.THEMES[db and db.theme] or ns.THEMES.classic
end

local lineByKey = {}
for _, line in ipairs(ns.LINES) do lineByKey[line.key] = line end

function ns.IsOn(key)
    local v = db.lines[key]
    if v == nil then return lineByKey[key].default ~= false end
    return v
end

-- Formatting --------------------------------------------------------------

local function Commas(n)
    local s = tostring(math.floor(n + 0.5))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end

local function Short(n)
    if n >= 1000000 then return string.format("%.1fm", n / 1000000) end
    if n >= 10000 then return string.format("%.1fk", n / 1000) end
    return Commas(n)
end

local function Duration(seconds)
    if not seconds or seconds == math.huge then return "--" end
    seconds = math.floor(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    if h > 0 then return string.format("%dh %02dm", h, m) end
    return string.format("%dm", m)
end

local function C(hex, s)
    return "|cff" .. hex .. s .. "|r"
end

-- Theme colour for a value where low is good (latency)
local function LowIsGood(t, value, good, ok)
    if value <= good then return t.good end
    if value <= ok then return t.ok end
    return t.bad
end

-- Theme colour for a value where high is good (fps, free slots, durability)
local function HighIsGood(t, value, good, ok)
    if value >= good then return t.good end
    if value >= ok then return t.ok end
    return t.bad
end

local function Money(copper)
    local g = math.floor(copper / 10000)
    local s = math.floor(copper / 100) % 100
    local c = copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = C("ffd700", Commas(g) .. "g") end
    if g > 0 or s > 0 then parts[#parts + 1] = C("c7c7cf", s .. "s") end
    parts[#parts + 1] = C("eda55f", c .. "c")
    return table.concat(parts, " ")
end

-- Levelling ---------------------------------------------------------------

local function NewSession()
    session.start = time()
    session.gained = 0
    session.kills = {}
end

local function AtMaxLevel()
    local maxLevel = (GetMaxLevelForPlayerExpansion or GetMaxPlayerLevel)()
    return UnitLevel("player") >= maxLevel or UnitXPMax("player") == 0
end

local function AvgKill()
    local kills = session.kills
    if #kills == 0 then return nil end
    local sum = 0
    for _, v in ipairs(kills) do sum = sum + v end
    return sum / #kills
end

local function PerHour()
    local elapsed = time() - session.start
    return elapsed >= 60 and session.gained / elapsed * 3600 or nil
end

-- Items: SEGMENT[key](theme, compact) returns a string, or nil to skip.
-- compact is true for the row and top bar layouts.

local SEGMENT = {}

function SEGMENT.fps(t)
    local fps = GetFramerate()
    return C(HighIsGood(t, fps, 100, 50), string.format("%d", fps)) .. " fps"
end

function SEGMENT.latency(t)
    local _, _, home, world = GetNetStats()
    return string.format("%s / %s ms", C(LowIsGood(t, home, 150, 250), home), C(LowIsGood(t, world, 150, 250), world))
end

function SEGMENT.level(t, compact)
    if AtMaxLevel() then return C(t.title, "Max level") end
    local cur, max = UnitXP("player"), UnitXPMax("player")
    local s = string.format("%s  %.1f%%", C(t.title, "Level " .. UnitLevel("player")), cur / max * 100)
    if compact then return s end
    return s .. "  " .. C(t.muted, Commas(cur) .. " / " .. Commas(max))
end

function SEGMENT.rate(t)
    if AtMaxLevel() then return nil end
    local perHour = PerHour()
    local remaining = UnitXPMax("player") - UnitXP("player")
    local ttl = perHour and perHour > 0 and remaining / perHour * 3600 or nil
    return string.format("XP/h: %s   To level: %s", C(t.value, perHour and Short(perHour) or "--"), C(t.value, Duration(ttl)))
end

function SEGMENT.kills(t, compact)
    if AtMaxLevel() then return nil end
    local avg = AvgKill()
    local remaining = UnitXPMax("player") - UnitXP("player")
    local kills = C("ffffff", avg and tostring(math.ceil(remaining / avg)) or "--")
    if compact then return "Kills to level: " .. kills end
    return string.format("Kills to level: %s  %s", kills, C(t.muted, "(avg " .. (avg and Commas(avg) or "--") .. ")"))
end

function SEGMENT.rested(t, compact)
    if AtMaxLevel() then return nil end
    local rested = GetXPExhaustion() or 0
    if rested == 0 then return "Rested: " .. C(t.muted, "none") end
    local pct = rested / UnitXPMax("player") * 100
    if compact then return string.format("Rested: %s", C(t.rested, string.format("%d%%", pct))) end
    return string.format("Rested: %s (%d%%)", C(t.rested, Commas(rested)), pct)
end

function SEGMENT.session(t, compact)
    local elapsed = time() - session.start
    if compact or AtMaxLevel() then return C(t.muted, "Session " .. Duration(elapsed)) end
    return C(t.muted, string.format("Session %s, %s XP", Duration(elapsed), Commas(session.gained)))
end

function SEGMENT.gold()
    return Money(GetMoney())
end

function SEGMENT.bags(t)
    local free, total = 0, 0
    for bag = 0, BAG_COUNT do
        local slots = GetNumSlots(bag) or 0
        if slots > 0 then
            local n, bagType = GetFreeSlots(bag)
            if (bagType or 0) == 0 then   -- skip quivers, ammo and soul bags
                free = free + (n or 0)
                total = total + slots
            end
        end
    end
    return string.format("Bags: %s / %d", C(HighIsGood(t, free, 6, 3), free), total)
end

function SEGMENT.durability(t)
    local lowest
    for slot = 1, 18 do
        local cur, max = GetInventoryItemDurability(slot)
        if cur and max and max > 0 then
            local pct = cur / max * 100
            if not lowest or pct < lowest then lowest = pct end
        end
    end
    if not lowest then return nil end
    return "Durability: " .. C(HighIsGood(t, lowest, 50, 20), string.format("%d%%", lowest))
end

function SEGMENT.time()
    return date("%H:%M")
end

function SEGMENT.date()
    return date("%a %d %b")
end

function SEGMENT.zone(t)
    local zone, sub = GetZoneText() or "", GetSubZoneText() or ""
    if sub ~= "" and sub ~= zone then zone = zone .. ", " .. sub end
    return C(t.title, zone)
end

function SEGMENT.coords(t)
    -- No position in instances; may also be hidden ("secret") on this client
    local ok, s = pcall(function()
        local map = C_Map.GetBestMapForUnit("player")
        local pos = map and C_Map.GetPlayerMapPosition(map, "player")
        if not pos then return nil end
        local x, y = pos:GetXY()
        if issecretvalue and (issecretvalue(x) or issecretvalue(y)) then return nil end
        return string.format("%.1f, %.1f", x * 100, y * 100)
    end)
    return ok and s or C(t.muted, "--, --")
end

-- Copy coordinates (addons cannot write to the clipboard: the text is shown selected, Ctrl+C copies it)

local copyBox
local function ShowCopy(text)
    if not copyBox then
        copyBox = CreateFrame("Frame", "SoloStatsCopy", UIParent)
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
                print("SoloStats: copied")
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

function ns.CopyCoords()
    local ok, s = pcall(function()
        local map = C_Map.GetBestMapForUnit("player")
        local pos = map and C_Map.GetPlayerMapPosition(map, "player")
        if not pos then return nil end
        local x, y = pos:GetXY()
        if issecretvalue and (issecretvalue(x) or issecretvalue(y)) then return nil end
        local info = C_Map.GetMapInfo(map)
        return string.format("%s%.1f, %.1f", info and (info.name .. " ") or "", x * 100, y * 100)
    end)
    if ok and s then ShowCopy(s) else print("SoloStats: no position here") end
end

-- Readout -----------------------------------------------------------------

local function Pad()
    if db.layout == "bar" then return 4 end
    return db.background and 6 or 0
end

function ns.Refresh()
    if not db then return end
    local t = ns.Theme()
    local compact = db.layout ~= "stack"

    local out, lastGroup = {}, nil
    for _, line in ipairs(ns.LINES) do
        if ns.IsOn(line.key) then
            local s = SEGMENT[line.key](t, compact)
            if s then
                if not compact and line.group and line.group == lastGroup then
                    out[#out] = out[#out] .. "   " .. s
                else
                    out[#out + 1] = s
                end
                lastGroup = line.group
            end
        end
    end

    -- All items off: keep a label so the frame can still be right-clicked
    if #out == 0 then out[1] = C(t.muted, "SoloStats") end

    text:SetText(table.concat(out, compact and C(t.muted, "   |   ") or "\n"))
    local pad = Pad()
    local h = math.max(text:GetStringHeight(), 10) + pad * 2
    if db.layout == "bar" then
        frame:SetHeight(h)   -- width comes from the screen anchors
    else
        frame:SetSize(math.max(text:GetStringWidth(), 40) + pad * 2, h)
    end
end

local function DefaultPosition()
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 8, -6)
end

local function ApplyPosition()
    frame:ClearAllPoints()
    if db.layout == "bar" then
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
        frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
    elseif db.pos then
        local pos = db.pos
        frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        DefaultPosition()
    end
end

function ns.ApplyLook()
    local t = ns.Theme()
    text:SetFont(FONT_PATH, db.size or DEFAULT_SIZE, FONT_FLAGS)
    text:SetTextColor(ns.RGB(t.text))
    text:ClearAllPoints()
    if db.layout == "bar" then
        local align = ns.ALIGNS[2]
        for _, a in ipairs(ns.ALIGNS) do
            if a.key == db.align then align = a end
        end
        text:SetJustifyH(align.point)
        text:SetPoint(align.point, align.x, 0)
    else
        text:SetJustifyH("LEFT")
        text:SetPoint("TOPLEFT", Pad(), -Pad())
    end
    ApplyPosition()

    if db.background then
        frame:SetBackdrop(BACKDROP)
        frame:SetBackdropColor(unpack(t.bg))
        if t.border then
            frame:SetBackdropBorderColor(unpack(t.border))
        else
            frame:SetBackdropBorderColor(0, 0, 0, 0)
        end
    else
        frame:SetBackdrop(nil)
    end

    frame:SetShown(db.shown)
    ns.Refresh()
    if ns.SyncOptions then ns.SyncOptions() end
end

function ns.ResetPosition()
    db.pos = nil
    ApplyPosition()
end

function ns.ResetSession()
    NewSession()
    lastXP, lastMax = UnitXP("player"), UnitXPMax("player")
    ns.Refresh()
end

frame:SetScript("OnDragStart", function(self)
    if not db.locked and db.layout ~= "bar" and IsShiftKeyDown() then self:StartMoving() end
end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if db.layout == "bar" then return end
    local point, _, relPoint, x, y = self:GetPoint()
    db.pos = { point, relPoint, x, y }
end)

frame:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then ns.ToggleOptions()
    elseif button == "LeftButton" and IsControlKeyDown() then ns.CopyCoords() end
end)

frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, db.layout == "bar" and "ANCHOR_BOTTOM" or "ANCHOR_BOTTOMRIGHT")
    GameTooltip:AddLine("SoloStats")
    GameTooltip:AddLine("Kills to level uses the last " .. KILL_SAMPLES .. " kills.", 1, 1, 1)
    if db.layout ~= "bar" then
        GameTooltip:AddLine(db.locked and "Position locked." or "Shift-drag to move.", 0.7, 0.7, 0.7)
    end
    GameTooltip:AddLine("Right-click for options.", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Ctrl-click to copy your coordinates.", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)
frame:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Events ------------------------------------------------------------------

local function OnXPUpdate()
    local cur, max = UnitXP("player"), UnitXPMax("player")
    if lastXP then
        local gained
        if cur < lastXP then
            gained = (lastMax - lastXP) + cur   -- levelled up
        else
            gained = cur - lastXP
        end
        if gained > 0 then session.gained = session.gained + gained end
    end
    lastXP, lastMax = cur, max
    ns.Refresh()
end

local function OnKillXP(msg)
    -- enUS: "Ragged Scavenger dies, you gain 90 experience. (+45 exp Rested bonus)"
    if not msg:find("dies") then return end
    local xp = tonumber(msg:match("gain (%d+)"))
    if not xp then return end
    table.insert(session.kills, xp)
    if #session.kills > KILL_SAMPLES then table.remove(session.kills, 1) end
end

frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_XP_UPDATE")
frame:RegisterEvent("UPDATE_EXHAUSTION")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN")
frame:RegisterEvent("PLAYER_MONEY")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        local isLogin = arg1
        if db then ns.Refresh() return end   -- zoning, already set up

        SoloStatsDB = SoloStatsDB or {}
        db = SoloStatsDB
        for k, v in pairs(DEFAULTS) do
            if db[k] == nil then db[k] = v end
        end
        db.lines = db.lines or {}
        if not ns.THEMES[db.theme] then db.theme = DEFAULTS.theme end

        SoloStatsSession = SoloStatsSession or {}
        session = SoloStatsSession
        if isLogin or not session.start then NewSession() end

        lastXP, lastMax = UnitXP("player"), UnitXPMax("player")
        ns.ApplyLook()
        C_Timer.NewTicker(1, ns.Refresh)
    elseif not db then
        return
    elseif event == "PLAYER_XP_UPDATE" then
        OnXPUpdate()
    elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
        OnKillXP(arg1)
    else
        ns.Refresh()
    end
end)

-- Slash commands ----------------------------------------------------------

local function SetLayout(key)
    for _, l in ipairs(ns.LAYOUTS) do
        if l.key == key then
            db.layout = key
            ns.ApplyLook()
            return true
        end
    end
end
ns.SetLayout = SetLayout

local function SetAlign(key)
    if key == "centre" then key = "center" end
    for _, a in ipairs(ns.ALIGNS) do
        if a.key == key then
            db.align = key
            ns.ApplyLook()
            return true
        end
    end
end
ns.SetAlign = SetAlign

local HELP = "SoloStats: /ss (options) | pos | session | size <6-32|reset> | layout <stack|row|bar>"
    .. " | align <left|centre|right> | theme <"
    .. table.concat(ns.THEME_ORDER, "|") .. "> | copy | hide | show"

SLASH_SOLOSTATS1 = "/ss"
SLASH_SOLOSTATS2 = "/solostats"
SlashCmdList.SOLOSTATS = function(msg)
    if not db then return end
    msg = strlower(strtrim(msg or ""))
    local size = msg:match("^size%s+(%S+)$")
    local theme = msg:match("^theme%s+(%S+)$")
    local layout = msg:match("^layout%s+(%S+)$")
    local align = msg:match("^align%s+(%S+)$")
    if msg == "" or msg == "options" then
        ns.ToggleOptions()
    elseif size then
        local n = tonumber(size)
        if size == "reset" then
            db.size = nil
        elseif n and n >= 6 and n <= 32 then
            db.size = math.floor(n)
        else
            print("SoloStats: size must be 6-32, or reset")
            return
        end
        ns.ApplyLook()
        print(string.format("SoloStats: text size %d%s", db.size or DEFAULT_SIZE, db.size and "" or " (default)"))
    elseif theme then
        if not ns.THEMES[theme] then
            print("SoloStats: themes are " .. table.concat(ns.THEME_ORDER, ", "))
            return
        end
        db.theme = theme
        ns.ApplyLook()
    elseif layout then
        if not SetLayout(layout) then print("SoloStats: layouts are stack, row, bar") end
    elseif align then
        if not SetAlign(align) then print("SoloStats: align left, centre or right") end
    elseif msg == "pos" or msg == "reset" then
        ns.ResetPosition()
        print("SoloStats: position reset.")
    elseif msg == "copy" then
        ns.CopyCoords()
    elseif msg == "session" then
        ns.ResetSession()
        print("SoloStats: session reset.")
    elseif msg == "hide" or msg == "show" then
        db.shown = msg == "show"
        ns.ApplyLook()
    else
        print(HELP)
    end
end
