-- SoloStats colour themes. Text colours are hex (for |cff codes), bg and border are RGBA.

local _, ns = ...

ns.THEME_ORDER = { "classic", "forsaken", "minimal", "horde" }

ns.THEMES = {
    classic = {
        name = "Blizzard classic",
        bg = { 0.04, 0.04, 0.04, 0.85 }, border = { 0.54, 0.43, 0.17, 1 },
        title = "ffd100", text = "eeeeee", muted = "999999",
        good = "40ff40", ok = "ffd040", bad = "ff4040",
        value = "40ff40", rested = "4da6ff",
    },
    forsaken = {
        name = "Forsaken",
        bg = { 0.07, 0.055, 0.094, 0.88 }, border = { 0.36, 0.48, 0.23, 1 },
        title = "9fe05a", text = "d8d4c8", muted = "8a8578",
        good = "9fe05a", ok = "d9c25a", bad = "ff5a4a",
        value = "c8f08a", rested = "a68cff",
    },
    minimal = {
        name = "Minimal dark",
        bg = { 0, 0, 0, 0.55 }, border = nil,
        title = "ffffff", text = "ffffff", muted = "888888",
        good = "5ee08a", ok = "f2c94c", bad = "ff6b6b",
        value = "6cb6ff", rested = "6cb6ff",
    },
    horde = {
        name = "Horde",
        bg = { 0.12, 0.03, 0.024, 0.88 }, border = { 0.64, 0.23, 0.12, 1 },
        title = "e8b04a", text = "efe2d0", muted = "9a8a78",
        good = "7fdc5a", ok = "e8b04a", bad = "ff5040",
        value = "ff8a5c", rested = "7fb8ff",
    },
}

function ns.RGB(hex)
    return tonumber(hex:sub(1, 2), 16) / 255,
           tonumber(hex:sub(3, 4), 16) / 255,
           tonumber(hex:sub(5, 6), 16) / 255
end
