-- SoloMeter: a damage meter for WoW Forever, read from the game's own meter (C_DamageMeter).
-- The combat log is forbidden to addons on this client, so the server-side meter is the only source.
-- In combat the numbers are "secret values": they can be shown (string.format, AbbreviateNumbers,
-- StatusBar:SetValue) but not compared or used in maths. Sorting, percentages and the spell
-- breakdown therefore wait until the fight ends (ADDON_RESTRICTION_STATE_CHANGED), except for
-- your own bar, whose GUID is always readable.
--
-- Flat bars in the SoloUI style. Left-click the header for the menu (modes, current or overall,
-- reset), right-click it to swap current and overall, mouse wheel on it to cycle the modes.
-- Click a bar for that player's spells, click the header to go back. Shift-drag to move.
-- The menu also lists the last six past fights (GetAvailableCombatSessions, by mob name) to look at.
-- Field names, enum values and what is secret in combat were confirmed from a live capture on 2026-11-06.
-- After each fight the raw meter data is saved to SoloMeterDB.fights (see Fight capture below).
-- /meter, /meter mode <damage|healing|taken|interrupts|deaths>, current|overall, reset, test,
-- scale <0.5-2>, rows <3-20>, pos, hide|show, fights, capture [now|clear], debug.

local ADDON = ...
local FLAT = "Interface\\Buttons\\WHITE8X8"
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local Secret = issecretvalue or function() return false end
local Meter = C_DamageMeter

local SESSION_OVERALL, SESSION_CURRENT = 0, 1

-- Modes: key, label and the Enum.DamageMeterType number (numbers from the live client, build 1.60.1.70790).
local MODES = {
    { key = "damage",     label = "Damage",       type = 0 },
    { key = "healing",    label = "Healing",      type = 2 },
    { key = "taken",      label = "Damage taken", type = 7 },
    { key = "interrupts", label = "Interrupts",   type = 5 },
    { key = "deaths",     label = "Deaths",       type = 9 },
}
local MODE_BY_KEY = {}
for i, m in ipairs(MODES) do MODE_BY_KEY[m.key] = i end

local DEFAULTS = {
    mode = "damage", session = "current", rows = 8, width = 240, barHeight = 18, scale = 1,
    shown = true, classColour = true, pos = nil, capture = true,
}
local db

local function Print(msg) DEFAULT_CHAT_FRAME:AddMessage("|cff40c0ffSoloMeter|r: " .. msg) end

-- Numbers ---------------------------------------------------------------------

-- Readable numbers: 12345 -> 12.3k
local function Short(n)
    n = n or 0
    if n >= 1e6 then return string.format("%.2fm", n / 1e6) end
    if n >= 1e4 then return string.format("%.1fk", n / 1e3) end
    if n >= 100 then return string.format("%.0f", n) end
    return string.format("%.1f", n)
end

-- A secret number can only be formatted. AbbreviateNumbers takes a secret; %.0f too (%d does not).
local function ShowSecret(n)
    if AbbreviateNumbers then
        local ok, text = pcall(AbbreviateNumbers, n)
        if ok and text then return text end
    end
    local ok, text = pcall(string.format, "%.0f", n)
    return ok and text or "?"
end

local function Clock(sec)
    sec = math.floor(sec or 0)
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

-- Reading the meter -----------------------------------------------------------

local function ModeInfo() return MODES[MODE_BY_KEY[db.mode] or 1] end
local function SessionID() return db.session == "overall" and SESSION_OVERALL or SESSION_CURRENT end

local function Available()
    if not Meter or not Meter.GetCombatSessionFromType then return false end
    if Meter.IsDamageMeterAvailable then
        local ok, yes = pcall(Meter.IsDamageMeterAvailable)
        if ok and yes == false then return false end
    end
    return true
end

-- A past fight chosen from the menu (not saved): { id, name, duration } from GetAvailableCombatSessions.
local pastFight

local function ReadSession()
    local ok, session
    if pastFight and Meter.GetCombatSessionFromID then
        ok, session = pcall(Meter.GetCombatSessionFromID, pastFight.id, ModeInfo().type)
    else
        ok, session = pcall(Meter.GetCombatSessionFromType, SessionID(), ModeInfo().type)
    end
    return ok and session or nil
end

local function ReadSource(guid)
    local ok, source
    if pastFight and Meter.GetCombatSessionSourceFromID then
        ok, source = pcall(Meter.GetCombatSessionSourceFromID, pastFight.id, ModeInfo().type, guid)
    elseif Meter.GetCombatSessionSourceFromType then
        ok, source = pcall(Meter.GetCombatSessionSourceFromType, SessionID(), ModeInfo().type, guid)
    end
    return ok and source or nil
end

-- Past fights, newest first: { id, name, duration }, readable only out of combat.
local function PastFights(max)
    local out = {}
    if not Meter or not Meter.GetAvailableCombatSessions then return out end
    local ok, list = pcall(Meter.GetAvailableCombatSessions)
    if not ok or type(list) ~= "table" then return out end
    for i = #list, 1, -1 do
        local s = list[i]
        if not Secret(s.sessionID) and not Secret(s.name) and not Secret(s.durationSeconds) then
            out[#out + 1] = { id = s.sessionID, name = s.name or "?", duration = s.durationSeconds }
            if #out >= max then break end
        end
    end
    return out
end

-- Session length in seconds, nil when unknown or secret.
local function Duration(session)
    local d = session and session.durationSeconds
    if d == nil and pastFight then d = pastFight.duration end
    if d == nil and not pastFight and Meter.GetSessionDurationSeconds then
        local ok, v = pcall(Meter.GetSessionDurationSeconds, SessionID())
        if ok then d = v end
    end
    if d == nil or Secret(d) or d <= 0 then return nil end
    return d
end

-- Per second of a source or spell. Out of combat, if the API gives 0 for a non-zero total, total / duration.
local function PerSecond(entry, session, secret)
    local ps = entry.amountPerSecond or 0
    if secret then return ps end
    if ps == 0 and (entry.totalAmount or 0) > 0 then
        local d = Duration(session)
        if d then ps = entry.totalAmount / d end
    end
    return ps
end

-- The API's list is already sorted; re-sort only when the totals are readable.
local function Sorted(list)
    list = list or {}
    local first = list[1]
    local secret = first and Secret(first.totalAmount) or false
    if first and not secret then
        table.sort(list, function(a, b) return (a.totalAmount or 0) > (b.totalAmount or 0) end)
    end
    return list, secret
end

-- Right-hand text of a bar: total (per second, share).
local function RowText(entry, session, secret, groupTotal)
    local total, ps = entry.totalAmount, PerSecond(entry, session, secret)
    if secret then
        local ok, text = pcall(string.format, "%s (%.0f)", ShowSecret(total), ps)
        return ok and text or ShowSecret(total)
    end
    total = total or 0
    local pct = groupTotal and groupTotal > 0 and (total / groupTotal * 100) or nil
    if ModeInfo().key == "deaths" or ModeInfo().key == "interrupts" then
        return pct and string.format("%d (%.0f%%)", total, pct) or string.format("%d", total)
    end
    return pct and string.format("%s (%s, %.0f%%)", Short(total), Short(ps), pct)
        or string.format("%s (%s)", Short(total), Short(ps))
end

-- Frame -----------------------------------------------------------------------

local HEADER = 20
local GetSpellName = (C_Spell and C_Spell.GetSpellName) or function(id) return (GetSpellInfo(id)) end
local GetSpellIcon = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture

local function Edge(f)
    local edge = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    edge:SetColorTexture(0, 0, 0, 1)
    local fill = f:CreateTexture(nil, "BACKGROUND", nil, -7)
    fill:SetAllPoints()
    fill:SetColorTexture(0.08, 0.08, 0.08, 0.9)
    return fill
end

local function Text(parent, size, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT, size, "OUTLINE")
    fs:SetJustifyH(justify)
    fs:SetWordWrap(false)
    return fs
end

local frame = CreateFrame("Frame", "SoloMeterFrame", UIParent)
frame:SetFrameStrata("MEDIUM")
frame:SetMovable(true)
frame:SetClampedToScreen(true)
frame:Hide()
Edge(frame)

local header = CreateFrame("Button", nil, frame)
header:SetPoint("TOPLEFT")
header:SetPoint("TOPRIGHT")
header:SetHeight(HEADER)
header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
header:RegisterForDrag("LeftButton")
header:EnableMouseWheel(true)
local headerBg = header:CreateTexture(nil, "BACKGROUND")
headerBg:SetAllPoints()
headerBg:SetColorTexture(0.16, 0.16, 0.16, 1)
header.text = Text(header, 11, "LEFT")
header.text:SetPoint("LEFT", 5, 0)
header.text:SetPoint("RIGHT", -46, 0)
header.text:SetTextColor(1, 0.82, 0)

local resetButton = CreateFrame("Button", nil, header)
resetButton:SetSize(40, HEADER)
resetButton:SetPoint("RIGHT")
resetButton.text = Text(resetButton, 10, "CENTER")
resetButton.text:SetAllPoints()
resetButton.text:SetText("reset")
resetButton.text:SetTextColor(0.7, 0.7, 0.7)
resetButton:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
resetButton:SetScript("OnLeave", function(self) self.text:SetTextColor(0.7, 0.7, 0.7) end)

local bars = {}
local view = { spells = false, guid = nil, name = nil }   -- spell breakdown of one source, or the source list
local testMode = false
local dirty = true
local pollUntil = 0

-- Bars: a StatusBar per row, text left (rank and name) and right (numbers), optional spell icon.
local function MakeBar(i)
    local b = CreateFrame("StatusBar", nil, frame)
    b:SetStatusBarTexture(FLAT)
    b:SetMinMaxValues(0, 1)
    b:SetValue(0)
    b.fill = Edge(b)
    b:EnableMouse(true)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("LEFT", 1, 0)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.icon:Hide()
    b.left = Text(b, 11, "LEFT")
    b.left:SetPoint("LEFT", 4, 0)
    b.right = Text(b, 11, "RIGHT")
    b.right:SetPoint("RIGHT", -4, 0)
    b.left:SetPoint("RIGHT", b.right, "LEFT", -4, 0)
    b:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            if view.spells then view.spells = false dirty = true end
            return
        end
        if view.spells or testMode then return end
        if self.guid then
            view.spells, view.guid, view.name = true, self.guid, self.name
            dirty = true
        elseif self.inList then
            Print("that player's spells can be read after the fight")
        end
    end)
    b:SetScript("OnEnter", function(self)
        if self.tip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tip)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    bars[i] = b
    return b
end

local function Layout()
    local h, w, rows = db.barHeight, db.width, db.rows
    frame:SetSize(w, HEADER + 1 + rows * (h + 1))
    frame:SetScale(db.scale)
    local size = math.max(9, math.min(13, h - 6))
    header.text:SetFont(FONT, size, "OUTLINE")
    for i = 1, math.max(rows, #bars) do
        local b = bars[i] or MakeBar(i)
        b:SetPoint("TOPLEFT", 1, -(HEADER + 1 + (i - 1) * (h + 1)))
        b:SetPoint("TOPRIGHT", -1, -(HEADER + 1 + (i - 1) * (h + 1)))
        b:SetHeight(h)
        b.icon:SetSize(h - 2, h - 2)
        b.left:SetFont(FONT, size, "OUTLINE")
        b.right:SetFont(FONT, size, "OUTLINE")
        b:Hide()
    end
    dirty = true
end

local function Place()
    frame:ClearAllPoints()
    local p = db.pos
    if p then frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -30, 180) end
end

local function SavePosition()
    local point, _, rel, x, y = frame:GetPoint()
    db.pos = { point, rel, x, y }
end

header:SetScript("OnDragStart", function()
    if IsShiftKeyDown() then frame:StartMoving() end
end)
header:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    SavePosition()
end)

-- Colours ---------------------------------------------------------------------

local function ClassColour(class)
    if db.classColour and not Secret(class) and class then
        local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
        if c then return c.r, c.g, c.b end
    end
    return 0.45, 0.45, 0.5
end

-- Title text set only when it changed (a secret text cannot be compared: always set).
local function SetHeader(text)
    local current = header.text:GetText()
    if Secret(text) or Secret(current) or current ~= text then header.text:SetText(text) end
end

-- Drawing ---------------------------------------------------------------------

local function HideFrom(i)
    for j = i, #bars do
        bars[j]:Hide()
        bars[j].guid, bars[j].name, bars[j].tip, bars[j].inList = nil, nil, nil, nil
    end
end

local function FillBar(b, value, max, r, g, bl)
    b:SetMinMaxValues(0, max)
    b:SetValue(value)
    b:SetStatusBarColor(r, g, bl, 0.85)
    b:Show()
end

-- Test bars: layout check without a fight.
local TEST = {
    { "You", "ROGUE", 18230, 61.2, true }, { "Grimtotem", "SHAMAN", 15100, 50.7 },
    { "Ashenvale", "DRUID", 12040, 40.4 }, { "Vexxa", "WARLOCK", 9800, 32.9 }, { "Durak", "WARRIOR", 7600, 25.5 },
    { "Nimbly", "MAGE", 5400, 18.1 }, { "Thessa", "PRIEST", 2100, 7.0 }, { "Korrak", "HUNTER", 1500, 5.0 },
}

local function DrawTest()
    SetHeader(string.format("%s · test", ModeInfo().label))
    local total = 0
    for _, t in ipairs(TEST) do total = total + t[3] end
    for i = 1, db.rows do
        local t, b = TEST[i], bars[i]
        if t then
            FillBar(b, t[3], TEST[1][3], ClassColour(t[2]))
            b.icon:Hide()
            b.left:SetPoint("LEFT", 4, 0)
            b.left:SetText(string.format("%d. %s", i, t[5] and (UnitName("player") or t[1]) or t[1]))
            b.right:SetText(string.format("%s (%s, %.0f%%)", Short(t[3]), Short(t[4]), t[3] / total * 100))
            if t[5] then b.left:SetTextColor(1, 0.9, 0.5) else b.left:SetTextColor(1, 1, 1) end
        else
            b:Hide()
        end
    end
    HideFrom(db.rows + 1)
end

local function DrawSpells(session)
    local source = ReadSource(view.guid)
    local spells, secret = Sorted(source and source.combatSpells)
    local label = view.name or "?"
    SetHeader(string.format("%s · %s%s", label, ModeInfo().label:lower(), secret and " (in combat)" or ""))
    -- In combat the spell IDs are secret too (seen in the capture), so no names or icons: one line instead.
    if not spells[1] or secret then
        bars[1].left:SetText(secret and "spells readable after the fight" or "no spells read")
        bars[1].right:SetText("")
        bars[1].icon:Hide()
        bars[1].left:SetPoint("LEFT", 4, 0)
        FillBar(bars[1], 0, 1, 0.3, 0.3, 0.3)
        HideFrom(2)
        return
    end
    local max = (source and source.totalAmount) or spells[1].totalAmount or 1
    local groupTotal = (not secret and source and not Secret(source.totalAmount)) and source.totalAmount or nil
    for i = 1, db.rows do
        local s, b = spells[i], bars[i]
        if s then
            local id = (not Secret(s.spellID)) and s.spellID or nil
            local ok, name = pcall(GetSpellName, id)
            if not ok or Secret(name) then name = nil end
            name = name or (s.creatureName and not Secret(s.creatureName) and s.creatureName) or (id and ("spell " .. id)) or "?"
            local okIcon, icon = pcall(GetSpellIcon, id)
            if okIcon and icon and not Secret(icon) then
                b.icon:SetTexture(icon)
                b.icon:Show()
                b.left:SetPoint("LEFT", db.barHeight + 3, 0)
            else
                b.icon:Hide()
                b.left:SetPoint("LEFT", 4, 0)
            end
            -- combatSpellDetails names the unit behind the spell: in damage taken, who hit you with it
            -- (unitName, classification "elite", isMob, isPet); blank for your own damage. Seen live 2026-11-06.
            local det = s.combatSpellDetails
            local who = type(det) == "table" and not Secret(det) and det.unitName
            if Secret(who) or who == "" then who = nil end
            local tag = ""
            if who then
                local cls = det.classification
                if not Secret(cls) and cls == "elite" then who = who .. " (elite)" end
                tag = " |cffaaaaaa" .. who .. "|r"
            end
            FillBar(b, s.totalAmount or 0, spells[1].totalAmount or max, 0.35, 0.55, 0.85)
            b.left:SetText(string.format("%d. %s%s", i, name, tag))
            b.left:SetTextColor(1, 1, 1)
            b.right:SetText(RowText(s, session, secret, groupTotal))
            b.guid, b.name, b.inList = nil, nil, nil
            local tips = {}
            if who then tips[#tips + 1] = "From " .. who end
            if not secret and s.isAvoidable and not Secret(s.isAvoidable) then tips[#tips + 1] = "Avoidable" end
            if not secret and s.isDeadly and not Secret(s.isDeadly) then tips[#tips + 1] = "Deadly" end
            b.tip = tips[1] and table.concat(tips, "\n") or nil
        else
            b:Hide()
        end
    end
    HideFrom(db.rows + 1)
end

local function DrawSources(session)
    local info = ModeInfo()
    local inCombat = UnitAffectingCombat("player")
    local sessionText = pastFight and pastFight.name or (db.session == "overall" and "overall" or "current")
    local d = pastFight and pastFight.duration or (db.session == "current" and inCombat and Duration(session))
    SetHeader(string.format("%s · %s%s", info.label, sessionText, d and (" " .. Clock(d)) or ""))

    local list, secret = Sorted(session and session.combatSources)
    if not list[1] then
        bars[1].left:SetText(inCombat and "waiting for data" or "no data yet")
        bars[1].right:SetText("")
        bars[1].icon:Hide()
        bars[1].left:SetPoint("LEFT", 4, 0)
        FillBar(bars[1], 0, 1, 0.3, 0.3, 0.3)
        HideFrom(2)
        return
    end
    local max = (session and session.maxAmount) or list[1].totalAmount or 1
    local groupTotal = (not secret and session and not Secret(session.totalAmount)) and session.totalAmount or nil

    -- Your own bar takes the last row when you are below the visible rows (isLocalPlayer is never secret).
    local myIndex
    for i, src in ipairs(list) do
        if not Secret(src.isLocalPlayer) and src.isLocalPlayer then myIndex = i break end
    end
    for i = 1, db.rows do
        local index = i
        if i == db.rows and myIndex and myIndex > i then index = myIndex end
        local src, b = list[index], bars[i]
        if src then
            local mine = not Secret(src.isLocalPlayer) and src.isLocalPlayer
            FillBar(b, src.totalAmount or 0, max, ClassColour(src.classFilename))
            b.icon:Hide()
            b.left:SetPoint("LEFT", 4, 0)
            b.left:SetText(string.format("%d. %s", index, src.name or "?"))
            if mine then b.left:SetTextColor(1, 0.9, 0.5) else b.left:SetTextColor(1, 1, 1) end
            if info.key == "deaths" and not secret and src.deathTimeSeconds and not Secret(src.deathTimeSeconds) then
                b.right:SetText(string.format("%d at %s", src.totalAmount or 0, Clock(src.deathTimeSeconds)))
            else
                b.right:SetText(RowText(src, session, secret, groupTotal))
            end
            b.inList = true
            if mine then
                b.guid, b.name = UnitGUID("player"), UnitName("player")
            elseif not Secret(src.sourceGUID) and not Secret(src.name) then
                b.guid, b.name = src.sourceGUID, src.name
            else
                b.guid, b.name = nil, nil
            end
            b.tip = b.guid and "Click for spells" or nil
        else
            b:Hide()
        end
    end
    HideFrom(db.rows + 1)
end

local function Draw()
    dirty = false
    if testMode then DrawTest() return end
    if not Available() then
        SetHeader("SoloMeter · meter not available")
        bars[1].left:SetText(Meter and "game meter off or not yet unlocked" or "no C_DamageMeter on this client")
        bars[1].right:SetText("")
        bars[1].icon:Hide()
        FillBar(bars[1], 0, 1, 0.3, 0.3, 0.3)
        HideFrom(2)
        return
    end
    local session = ReadSession()
    if view.spells then DrawSpells(session) else DrawSources(session) end
end

-- Menu ------------------------------------------------------------------------
-- Own small popup: no dependency on EasyMenu or MenuUtil, which differ between clients.

local menu = CreateFrame("Frame", nil, frame)
menu:SetFrameStrata("DIALOG")
menu:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -1)
Edge(menu)
menu:Hide()
menu.items = {}

local function MenuItem(i, label, onClick)
    local b = menu.items[i]
    if not b then
        b = CreateFrame("Button", nil, menu)
        b:SetHeight(18)
        b:SetPoint("TOPLEFT", 1, -1 - (i - 1) * 19)
        b:SetPoint("TOPRIGHT", -1, -1 - (i - 1) * 19)
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.bg:SetColorTexture(1, 1, 1, 0)
        b.text = Text(b, 11, "LEFT")
        b.text:SetPoint("LEFT", 6, 0)
        b.text:SetPoint("RIGHT", -6, 0)
        b:SetScript("OnEnter", function(self) self.bg:SetColorTexture(1, 1, 1, 0.1) end)
        b:SetScript("OnLeave", function(self) self.bg:SetColorTexture(1, 1, 1, 0) end)
        menu.items[i] = b
    end
    b.text:SetText(label)
    b:SetScript("OnClick", function() menu:Hide() onClick() end)
    b:Show()
    return b
end

local function OpenMenu()
    local n = 0
    local function Add(label, fn) n = n + 1 MenuItem(n, label, fn) end
    for _, m in ipairs(MODES) do
        local on = db.mode == m.key
        Add((on and "|cffffd200> |r" or "   ") .. m.label, function() db.mode = m.key view.spells = false dirty = true end)
    end
    Add("|cff999999----------|r", function() end)
    Add((not pastFight and db.session == "current" and "|cffffd200> |r" or "   ") .. "Current fight",
        function() db.session = "current" pastFight = nil view.spells = false dirty = true end)
    Add((not pastFight and db.session == "overall" and "|cffffd200> |r" or "   ") .. "Overall",
        function() db.session = "overall" pastFight = nil view.spells = false dirty = true end)
    local fights = PastFights(6)
    if fights[1] then
        Add("|cff999999---- past fights ----|r", function() end)
        for _, f in ipairs(fights) do
            local on = pastFight and pastFight.id == f.id
            -- The game names boss sessions "(!) Bazzalan": shown in red without the mark.
            local label = f.name
            local boss = label:match("^%(!%)%s*(.+)$")
            if boss then label = "|cffff5050" .. boss .. "|r" end
            Add(string.format("%s%s %s", on and "|cffffd200> |r" or "   ", label, Clock(f.duration)),
                function() pastFight = f view.spells = false dirty = true end)
        end
    elseif UnitAffectingCombat("player") then
        Add("|cff999999   past fights: after combat|r", function() end)
    end
    Add("|cff999999----------|r", function() end)
    Add("   Reset data", function() SlashCmdList.SOLOMETER("reset") end)
    Add("   Hide (/meter shows it)", function() SlashCmdList.SOLOMETER("hide") end)
    for i = n + 1, #menu.items do menu.items[i]:Hide() end
    menu:SetSize(200, n * 19 + 2)
    menu:Show()
end

local function CycleMode(step)
    local i = MODE_BY_KEY[db.mode] or 1
    db.mode = MODES[((i - 1 + step) % #MODES) + 1].key
    view.spells = false
    dirty = true
end

header:SetScript("OnClick", function(_, button)
    if menu:IsShown() then menu:Hide() return end
    if view.spells then view.spells = false dirty = true return end
    if button == "RightButton" then
        if pastFight then pastFight = nil else db.session = db.session == "current" and "overall" or "current" end
        dirty = true
    else
        OpenMenu()
    end
end)
header:SetScript("OnMouseWheel", function(_, delta) CycleMode(delta > 0 and -1 or 1) end)
resetButton:SetScript("OnClick", function() SlashCmdList.SOLOMETER("reset") end)

-- Debug: raw C_DamageMeter values to chat and SavedVariables (print is not logged on this client).

local function Raw(v)
    if v == nil then return "nil" end
    if Secret(v) then return "(secret)" end
    if type(v) == "number" then return string.format("%.3f", v) end
    return tostring(v)
end

local function Keys(t)
    local list = {}
    for k in pairs(t or {}) do list[#list + 1] = tostring(k) end
    table.sort(list)
    return table.concat(list, ", ")
end

local function Debug()
    local lines = {}
    local function L(s) lines[#lines + 1] = s Print(s) end
    L(string.format("%s build %s mode=%s type=%d session=%s combat=%s", date("%Y-%m-%d %H:%M:%S"),
        tostring(select(4, GetBuildInfo())), db.mode, ModeInfo().type, db.session, tostring(UnitAffectingCombat("player"))))
    L("C_DamageMeter: " .. (Meter and Keys(Meter) or "nil"))
    L("Enum.DamageMeterType: " .. (Enum and Enum.DamageMeterType and Keys(Enum.DamageMeterType) or "nil"))
    if Meter and Meter.IsDamageMeterAvailable then L("IsDamageMeterAvailable: " .. Raw(select(2, pcall(Meter.IsDamageMeterAvailable)))) end
    local session = Meter and ReadSession()
    if not session then L("session: nil") else
        L("session fields: " .. Keys(session))
        L(string.format("durationSeconds=%s totalAmount=%s maxAmount=%s sources=%d", Raw(session.durationSeconds),
            Raw(session.totalAmount), Raw(session.maxAmount), #(session.combatSources or {})))
        for i, src in ipairs(session.combatSources or {}) do
            if i == 1 then L("source fields: " .. Keys(src)) end
            L(string.format("%d. name=%s class=%s total=%s ps=%s guid=%s me=%s", i, Raw(src.name), Raw(src.classFilename),
                Raw(src.totalAmount), Raw(src.amountPerSecond), Raw(src.sourceGUID), Raw(src.isLocalPlayer)))
            if i >= 5 then break end
        end
        local me = ReadSource(UnitGUID("player"))
        if me then
            L("own source fields: " .. Keys(me) .. " spells=" .. #(me.combatSpells or {}))
            for i, s in ipairs(me.combatSpells or {}) do
                if i == 1 then L("spell fields: " .. Keys(s)) end
                L(string.format("  spell %s total=%s ps=%s", Raw(s.spellID), Raw(s.totalAmount), Raw(s.amountPerSecond)))
                if i >= 5 then break end
            end
        end
    end
    if Meter and Meter.GetAvailableCombatSessions then
        local ok, list = pcall(Meter.GetAvailableCombatSessions)
        L("sessions: " .. (ok and list and #list or "?"))
        if ok and list and list[1] then L("session list fields: " .. Keys(list[1])) end
    end
    db.debug = lines
    Print("saved to SoloMeterDB.debug (written on /reload)")
end

-- Fight capture -----------------------------------------------------------------
-- After every fight the raw meter data is saved to SoloMeterDB.fights (last 20): every mode's
-- sources for the current session, your own spells, the session list and the field names, with
-- secret values marked. Read after a /reload: real data to improve the meter with, and a fight log.
-- One in-combat probe per login (SoloMeterDB.probe) records which fields are secret while fighting.

local CAPTURE_TYPES = {
    { "damage", 0 }, { "healing", 2 }, { "absorbs", 4 }, { "interrupts", 5 }, { "dispels", 6 },
    { "taken", 7 }, { "deaths", 9 },
}
local MAX_FIGHTS = 20
local fightStart, fightTarget
local probed = false

-- Plain copy of a value for SavedVariables: numbers rounded, secrets marked, tables copied one level.
local function Val(v)
    if v == nil then return nil end
    if Secret(v) then return "(secret)" end
    local t = type(v)
    if t == "number" then return math.floor(v * 1000 + 0.5) / 1000 end
    if t == "boolean" or t == "string" then return v end
    if t == "table" then
        local out = {}
        for k, x in pairs(v) do if type(x) ~= "table" and type(x) ~= "function" then out[k] = Val(x) end end
        return out
    end
    return tostring(v)
end

local function CopyEntry(e)
    local out = {}
    for k, x in pairs(e) do
        if type(x) ~= "table" and type(x) ~= "function" then out[k] = Val(x) end
    end
    return out
end

local function Capture(reason)
    if not db or not Meter or not Meter.GetCombatSessionFromType then return nil end
    local rec = {
        time = date("%Y-%m-%d %H:%M:%S"), reason = reason, build = select(4, GetBuildInfo()),
        zone = GetZoneText and GetZoneText() or "?", target = fightTarget,
        length = fightStart and math.floor(GetTime() - fightStart + 0.5) or nil,
        level = UnitLevel("player"), inCombat = UnitAffectingCombat("player") and true or false,
        api = Keys(Meter), enum = Enum and Enum.DamageMeterType and Val(Enum.DamageMeterType) or nil,
        modes = {}, fields = {},
    }
    local myGuid = UnitGUID("player")
    for _, m in ipairs(CAPTURE_TYPES) do
        local key, t = m[1], m[2]
        local ok, session = pcall(Meter.GetCombatSessionFromType, SESSION_CURRENT, t)
        if ok and session then
            local mode = {
                duration = Val(session.durationSeconds), total = Val(session.totalAmount), max = Val(session.maxAmount),
                sources = {},
            }
            rec.fields.session = rec.fields.session or Keys(session)
            for i, src in ipairs(session.combatSources or {}) do
                if i > 10 then break end
                rec.fields.source = rec.fields.source or Keys(src)
                mode.sources[i] = CopyEntry(src)
            end
            local okS, mine = pcall(Meter.GetCombatSessionSourceFromType, SESSION_CURRENT, t, myGuid)
            if okS and mine then
                rec.fields.mine = rec.fields.mine or Keys(mine)
                mode.me = CopyEntry(mine)
                mode.spells = {}
                for i, s in ipairs(mine.combatSpells or {}) do
                    if i > 15 then break end
                    rec.fields.spell = rec.fields.spell or Keys(s)
                    local sp = CopyEntry(s)
                    local okN, name = pcall(GetSpellName, (not Secret(s.spellID)) and s.spellID or nil)
                    if okN and name and not Secret(name) then sp.name = name end
                    -- combatSpellDetails: nested table seen in the first capture, contents unknown: copy two levels.
                    local det = s.combatSpellDetails
                    if type(det) == "table" and not Secret(det) then
                        sp.details = {}
                        local n = 0
                        for k, x in pairs(det) do
                            n = n + 1
                            if n > 20 then break end
                            sp.details[k] = type(x) == "table" and Val(x) or Val(x)
                        end
                        rec.fields.spellDetails = rec.fields.spellDetails or Keys(det)
                        local first = det[1]
                        if type(first) == "table" then rec.fields.spellDetail = rec.fields.spellDetail or Keys(first) end
                    end
                    mode.spells[i] = sp
                end
            end
            if mode.sources[1] or mode.me then rec.modes[key] = mode end
        elseif not ok then
            rec.modes[key] = { error = tostring(session) }
        end
    end
    if Meter.GetSessionDurationSeconds then
        local ok, d = pcall(Meter.GetSessionDurationSeconds, SESSION_CURRENT)
        rec.currentDuration = ok and Val(d) or ("error " .. tostring(d))
        ok, d = pcall(Meter.GetSessionDurationSeconds, SESSION_OVERALL)
        rec.overallDuration = ok and Val(d) or ("error " .. tostring(d))
    end
    if Meter.GetAvailableCombatSessions then
        local ok, list = pcall(Meter.GetAvailableCombatSessions)
        if ok and type(list) == "table" then
            rec.sessions = {}
            for i, s in ipairs(list) do
                if i > 10 then break end
                rec.fields.sessionList = rec.fields.sessionList or Keys(s)
                rec.sessions[i] = CopyEntry(s)
            end
        else
            rec.sessions = "error " .. tostring(list)
        end
    end
    return rec
end

local function SaveFight()
    if db.capture == false then return end
    local rec = Capture("fight end")
    if not rec then return end
    local dmg = rec.modes.damage
    if not dmg or not (dmg.sources[1] or dmg.me) then return end   -- nothing happened
    -- The target's name is secret in combat (dungeons): the newest session's name is the mob, readable now.
    if rec.target == nil or rec.target == "(secret)" then
        local last = PastFights(1)[1]
        if last then rec.target = last.name rec.sessionID = last.id end
    end
    db.fights = db.fights or {}
    if #db.fights >= MAX_FIGHTS then table.remove(db.fights, 1) end
    db.fights[#db.fights + 1] = rec
end

local function Later(seconds, fn)
    if C_Timer and C_Timer.After then C_Timer.After(seconds, fn) else fn() end
end

local function FightStarted()
    fightStart = GetTime()
    fightTarget = UnitExists("target") and UnitName("target") or nil
    if Secret(fightTarget) then fightTarget = "(secret)" end
    if not probed and db.capture ~= false then
        probed = true
        Later(2, function()
            if UnitAffectingCombat("player") then
                local rec = Capture("in combat probe")
                if rec then db.probe = rec end
            else
                probed = false   -- too short a fight: probe the next one
            end
        end)
    end
end

local function FightEnded()
    if UnitExists("target") and not Secret(UnitName("target")) then fightTarget = fightTarget or UnitName("target") end
    Later(3, function()
        if UnitAffectingCombat("player") then return end   -- a new fight began: that one saves later
        SaveFight()
        fightStart, fightTarget = nil, nil
    end)
end

local function ListFights()
    local fights = db.fights or {}
    if #fights == 0 then Print("no fights saved yet (saved 3 s after each fight, written to disk on /reload)") return end
    for i, f in ipairs(fights) do
        local dmg = f.modes.damage or {}
        local me = dmg.me or {}
        Print(string.format("%d. %s %s%s: %ss, you %s (%s/s)", i, f.time, f.zone or "?",
            f.target and (" vs " .. tostring(f.target)) or "", tostring(f.length or dmg.duration or "?"),
            tostring(me.totalAmount or "?"), tostring(me.amountPerSecond or "?")))
    end
end

-- Slash -----------------------------------------------------------------------

SLASH_SOLOMETER1 = "/meter"
SLASH_SOLOMETER2 = "/solometer"
SlashCmdList.SOLOMETER = function(msg)
    msg = (msg or ""):lower()
    local cmd, arg = msg:match("^(%S+)%s*(.*)$")
    if not cmd then
        db.shown = not frame:IsShown()
        frame:SetShown(db.shown)
        dirty = true
    elseif cmd == "show" or cmd == "hide" then
        db.shown = cmd == "show"
        frame:SetShown(db.shown)
        dirty = true
    elseif cmd == "mode" then
        local key = ({ dmg = "damage", damage = "damage", heal = "healing", healing = "healing", taken = "taken",
            int = "interrupts", interrupts = "interrupts", deaths = "deaths", death = "deaths" })[arg]
        if key then db.mode = key view.spells = false dirty = true
        else Print("modes: damage, healing, taken, interrupts, deaths") end
    elseif cmd == "current" or cmd == "overall" then
        db.session = cmd
        pastFight = nil
        view.spells = false
        dirty = true
    elseif cmd == "reset" then
        if Meter and Meter.ResetAllCombatSessions then
            local ok, err = pcall(Meter.ResetAllCombatSessions)
            Print(ok and "data reset" or ("reset failed: " .. tostring(err)))
        else
            Print("no reset on this client")
        end
        view.spells = false
        dirty = true
    elseif cmd == "test" then
        testMode = not testMode
        view.spells = false
        dirty = true
        if testMode then frame:Show() end
        Print(testMode and "test bars on" or "test bars off")
    elseif cmd == "scale" then
        local n = tonumber(arg)
        if n and n >= 0.5 and n <= 2 then db.scale = n Layout() else Print("scale 0.5 to 2") end
    elseif cmd == "rows" then
        local n = tonumber(arg)
        if n and n >= 3 and n <= 20 then db.rows = math.floor(n) Layout() else Print("rows 3 to 20") end
    elseif cmd == "width" then
        local n = tonumber(arg)
        if n and n >= 120 and n <= 600 then db.width = math.floor(n) Layout() else Print("width 120 to 600") end
    elseif cmd == "height" then
        local n = tonumber(arg)
        if n and n >= 10 and n <= 30 then db.barHeight = math.floor(n) Layout() else Print("height 10 to 30") end
    elseif cmd == "pos" then
        db.pos = nil
        Place()
    elseif cmd == "class" then
        db.classColour = not db.classColour
        dirty = true
    elseif cmd == "debug" then
        Debug()
    elseif cmd == "fights" then
        ListFights()
    elseif cmd == "capture" then
        if arg == "now" then
            local rec = Capture("manual")
            if rec then
                db.fights = db.fights or {}
                if #db.fights >= MAX_FIGHTS then table.remove(db.fights, 1) end
                db.fights[#db.fights + 1] = rec
                Print("captured now (fight " .. #db.fights .. "), written on /reload")
            else
                Print("nothing to capture: no C_DamageMeter")
            end
        elseif arg == "clear" then
            db.fights, db.probe = nil, nil
            probed = false
            Print("fight log cleared")
        else
            db.capture = not (db.capture ~= false)
            Print("fight capture " .. (db.capture and "on" or "off"))
        end
    else
        Print("/meter (toggle), mode <damage|healing|taken|interrupts|deaths>, current, overall, reset, test, scale <0.5-2>, rows <3-20>, width <n>, height <n>, pos, class, show, hide, fights, capture [now|clear], debug")
    end
end

-- Events ----------------------------------------------------------------------

local ev = CreateFrame("Frame")
local function Register(event)
    local ok = pcall(ev.RegisterEvent, ev, event)
    if not ok then Print("event not on this client: " .. event) end
end

ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        ev:UnregisterEvent("ADDON_LOADED")
        SoloMeterDB = SoloMeterDB or {}
        db = SoloMeterDB
        for k, v in pairs(DEFAULTS) do if db[k] == nil then db[k] = v end end
        if not MODE_BY_KEY[db.mode] then db.mode = "damage" end
        Layout()
        Place()
        frame:SetShown(db.shown)
        Register("PLAYER_ENTERING_WORLD")
        Register("PLAYER_REGEN_DISABLED")
        Register("PLAYER_REGEN_ENABLED")
        Register("DAMAGE_METER_CURRENT_SESSION_UPDATED")
        Register("DAMAGE_METER_COMBAT_SESSION_UPDATED")
        Register("DAMAGE_METER_RESET")
        Register("ADDON_RESTRICTION_STATE_CHANGED")
        if not Meter then Print("this client has no C_DamageMeter: nothing to read") end
    elseif event == "PLAYER_REGEN_DISABLED" then
        FightStarted()
        dirty = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        pollUntil = GetTime() + 3   -- values can stay secret for a moment after the fight
        FightEnded()
        dirty = true
    elseif event == "DAMAGE_METER_RESET" then
        view.spells = false
        pastFight = nil
        dirty = true
    else
        dirty = true
    end
end)

-- Redraw at most four times a second, and for a few seconds after a fight.
local acc = 0
frame:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.25 then return end
    acc = 0
    if dirty or GetTime() < pollUntil or UnitAffectingCombat("player") then Draw() end
end)
