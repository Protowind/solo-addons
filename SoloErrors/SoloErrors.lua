-- SoloErrors: catches every uncaught Lua error from any addon (seterrorhandler) and the
-- ADDON_ACTION_FORBIDDEN / ADDON_ACTION_BLOCKED events (taint and protected functions, which do not
-- raise Lua errors), and keeps them in SoloErrorsDB.errors for reading after a /reload.
-- Loads before the other Solo addons (their toc has OptionalDeps: SoloErrors) so load-time errors
-- are caught too. Syntax errors (a file that fails to parse) never reach Lua: Logs\FrameXML.log has those.
-- Errors inside a pcall are swallowed by the addon that called it and never arrive here.
--
-- Each distinct message is stored once with a count, first and last time and the first stack.
-- One chat line per new error. /errors lists them, /errors <n> shows one with its stack,
-- /errors clear wipes, /errors popup toggles Blizzard's own error window as well.

local ADDON = ...
local MAX = 50
local db
local chain                    -- Blizzard's handler, called after ours when the popup is on
local printed = 0
local Secret = issecretvalue or function() return false end

local function Print(msg) DEFAULT_CHAT_FRAME:AddMessage("|cffff6060SoloErrors|r: " .. msg) end

-- Message to a plain string, safe if it is a secret value or not a string at all.
local function Plain(v)
    if v == nil then return "nil" end
    if Secret(v) then return "(secret value)" end
    local ok, s = pcall(tostring, v)
    return ok and s or "(unprintable)"
end

-- The addon name is the first path part: "Interface/AddOns/SoloUI/Frames.lua:120: ..."
local function AddonOf(msg)
    return msg:match("AddOns[/\\]([^/\\]+)[/\\]") or msg:match("^([%w_]+):") or "?"
end

local early = {}               -- errors caught before our SavedVariables are loaded (other addons' load errors)

local function Record(kind, msg, stack)
    if not db then
        early[#early + 1] = { kind = kind, message = msg, stack = stack }
        return false
    end
    db.errors = db.errors or {}
    local key = kind .. " " .. msg
    for _, e in ipairs(db.errors) do
        if e.key == key then
            e.count = e.count + 1
            e.last = date("%Y-%m-%d %H:%M:%S")
            return false
        end
    end
    if #db.errors >= MAX then table.remove(db.errors, 1) end
    db.errors[#db.errors + 1] = {
        key = key, kind = kind, addon = AddonOf(msg), message = msg, stack = stack,
        count = 1, first = date("%Y-%m-%d %H:%M:%S"), last = date("%Y-%m-%d %H:%M:%S"),
        session = db.session,
    }
    return true
end

local function Notify(e)
    if printed >= 10 then return end   -- a flood still gets counted, not printed
    printed = printed + 1
    Print(string.format("new error in %s (%d so far, /errors to list): %s", e.addon, #db.errors, e.message:sub(1, 160)))
end

-- Lua errors --------------------------------------------------------------------

local inHandler = false
local function Handler(msg)
    if inHandler then return end     -- an error inside our own handler must not loop
    inHandler = true
    local text = Plain(msg)
    local ok, stack = pcall(debugstack, 3, 12, 4)
    if not ok or Secret(stack) then stack = nil end
    local okRec, new = pcall(Record, "lua", text, stack)
    if okRec and new then pcall(Notify, db.errors[#db.errors]) end
    inHandler = false
    if db and db.popup and chain and chain ~= Handler then
        return chain(msg)
    end
end

-- Forbidden and blocked actions -------------------------------------------------

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("ADDON_ACTION_FORBIDDEN")
ev:RegisterEvent("ADDON_ACTION_BLOCKED")
ev:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        SoloErrorsDB = SoloErrorsDB or {}
        db = SoloErrorsDB
        if db.popup == nil then db.popup = false end
        db.errors = db.errors or {}
        db.session = (db.session or 0) + 1
        db.build = select(4, GetBuildInfo())
        for _, e in ipairs(early) do
            if Record(e.kind, e.message, e.stack) then Notify(db.errors[#db.errors]) end
        end
        early = {}
        local n = #db.errors
        if n > 0 then
            local unseen = 0
            for _, e in ipairs(db.errors) do if e.session == db.session then unseen = unseen + 1 end end
            Print(string.format("%d saved error%s (%d from this load). /errors lists them", n, n == 1 and "" or "s", unseen))
        end
        return
    end
    local msg = string.format("%s called %s", Plain(arg1), Plain(arg2))
    local ok, new = pcall(Record, event == "ADDON_ACTION_FORBIDDEN" and "forbidden" or "blocked", msg, nil)
    if ok and new then Notify(db.errors[#db.errors]) end
end)

chain = geterrorhandler and geterrorhandler()
if seterrorhandler then
    seterrorhandler(Handler)
else
    -- No seterrorhandler on this client: nothing to hook, only the two events are watched.
    chain = nil
end

-- Slash -------------------------------------------------------------------------

SLASH_SOLOERRORS1 = "/errors"
SLASH_SOLOERRORS2 = "/soloerrors"
SlashCmdList.SOLOERRORS = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    local n = tonumber(msg)
    if msg == "" then
        if #db.errors == 0 then Print("no errors saved" .. (seterrorhandler and "" or " (no seterrorhandler on this client: only forbidden and blocked events are caught)")) return end
        for i, e in ipairs(db.errors) do
            Print(string.format("%d. [%s] %s x%d, last %s: %s", i, e.kind, e.addon, e.count, e.last, e.message:sub(1, 120)))
        end
        Print("/errors <n> for the stack, /errors clear, /errors popup (" .. (db.popup and "on" or "off") .. ")")
    elseif n and db.errors[n] then
        local e = db.errors[n]
        Print(string.format("%d. [%s] %s x%d, first %s, last %s", n, e.kind, e.addon, e.count, e.first, e.last))
        Print(e.message)
        if e.stack then for line in e.stack:gmatch("[^\n]+") do Print("  " .. line) end end
    elseif msg == "clear" then
        wipe(db.errors)
        printed = 0
        Print("cleared")
    elseif msg == "popup" then
        db.popup = not db.popup
        Print("Blizzard's error popup " .. (db.popup and "on" or "off"))
    elseif msg == "test" then
        error("SoloErrors test error")
    else
        Print("/errors, /errors <n>, clear, popup, test")
    end
end
