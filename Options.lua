local ADDON, ns = ...
local C = ns.COLORS

local BASE_ACCENT = { C.accent[1], C.accent[2], C.accent[3], C.accent[4] }
local BASE_BLUE = { C.blue[1], C.blue[2], C.blue[3], C.blue[4] }
local BASE_BORDER = { C.border[1], C.border[2], C.border[3], C.border[4] }
local BASE_TEAL = { C.teal[1], C.teal[2], C.teal[3], C.teal[4] }

local function PlayerClassFile()
    local ok, _, classFile = pcall(UnitClass, "player")
    if not ok or classFile == nil or (issecretvalue and issecretvalue(classFile)) then return nil end
    return classFile
end

-- Cinematic is always the suite's warm orange identity, including for Druids
-- whose normal class accent is orange.  Keeping this independent from the
-- appearance palette makes entering, leaving, and repainting the scene
-- unmistakable and stable across theme changes.
local CINEMATIC_ACCENT = { 0.90, 0.52, 0.24, 1 }
local CINEMATIC_BORDER = { 0.52, 0.29, 0.13, 0.88 }
local CINEMATIC_BUTTON = { 0.14, 0.085, 0.045, 1 }
local REMOVE_RED = { 0.88, 0.31, 0.34, 1 }
local NORMAL_HEADER = { 0.043, 0.051, 0.067, 1 }
local BUTTON_HOVER = { 0.095, 0.108, 0.129, 1 }
-- Blizzard's tooltip remains a dark host surface regardless of the selected
-- editor palette. Keep its ink readable instead of sending light-theme muted
-- values into the host tooltip.
local TOOLTIP_TITLE_COLOR = { 0.96, 0.88, 0.58, 1 }
local TOOLTIP_BODY_COLOR = { 0.84, 0.86, 0.90, 1 }
local themeObjects = setmetatable({}, { __mode = "k" })
local euiSkin
local euiObjects = {
    shell = {}, panel = {}, button = {}, font = {}, close = {}, edit = {},
}
local euiSeen = setmetatable({}, { __mode = "k" })
local euiOwned = setmetatable({}, { __mode = "k" })

-- Frame Gambit owns the complete suite appearance set. Ellesmere intentionally
-- keeps the original public skin contract, while every other theme uses
-- addon-owned shell art and a complete local surface palette.
local SKIN_FONT = "Fonts\\FRIZQT__.TTF"
local bundledShadowFont
local SKIN_CLASS_COLORS = {
    DEATHKNIGHT = { 0.77, 0.12, 0.23 }, DEMONHUNTER = { 0.64, 0.19, 0.79 },
    DRUID = { 1.00, 0.49, 0.04 }, EVOKER = { 0.20, 0.58, 0.50 },
    HUNTER = { 0.67, 0.83, 0.45 }, MAGE = { 0.25, 0.78, 0.92 },
    MONK = { 0.00, 1.00, 0.60 }, PALADIN = { 0.96, 0.55, 0.73 },
    PRIEST = { 1.00, 1.00, 1.00 }, ROGUE = { 1.00, 0.96, 0.41 },
    SHAMAN = { 0.00, 0.44, 0.87 }, WARLOCK = { 0.53, 0.53, 0.93 },
    WARRIOR = { 0.78, 0.61, 0.43 },
}
local function CloneColor(color)
    return { color[1], color[2], color[3], color[4] or 1 }
end

local function RGB(hex)
    return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255,
        tonumber(hex:sub(5, 6), 16) / 255, 1 }
end

-- BindCards' facade is the palette source of truth. Frame Gambit copies the
-- values into its own compact surface vocabulary so the addon remains fully
-- standalone at runtime: window → shell, paper → cards, paperAlt → inset,
-- slot → inputs, blueSoft/tabSelection → selected, blue → focus, teal → live.
local function PaletteTheme(label, palette, opts)
    opts = opts or {}
    local theme = {
        label = label, art = opts.art or "Interface\\Buttons\\WHITE8X8",
        wash = opts.wash or 0, base = opts.base or (not opts.art and palette.window), crop = opts.crop or { 0, 1, 0, 1 },
        classAccent = opts.classAccent,
        accent = opts.accent or (not opts.classAccent and palette.blue or nil), teal = palette.teal,
        window = palette.window, panel = palette.panel, card = palette.paper,
        cardAlt = palette.paperAlt, input = opts.input or palette.slot, raised = palette.raised,
        border = palette.border, faint = palette.faint, blue = palette.blue,
        blueSoft = palette.blueSoft, selected = opts.selected or palette.blueSoft,
        selectedText = opts.selectedText or palette.topText or palette.text,
        text = palette.text, muted = palette.muted,
        inputText = opts.inputText or palette.text, hover = palette.hover,
        primaryHover = opts.primaryHover or palette.drop,
        amber = palette.amber, red = palette.red,
    }
    return theme
end

local function ConsoleTheme(label, spec, opts)
    local palette = {}
    for key, color in pairs(spec) do palette[key] = type(color) == "string" and RGB(color) or CloneColor(color) end
    opts = opts or {}
    opts.base = opts.base or palette.window
    opts.selected = opts.selected or palette.blueSoft
    opts.selectedText = opts.selectedText or palette.topText
    return PaletteTheme(label, palette, opts)
end

local APPEARANCE_THEMES = {
    legacy = ConsoleTheme("Blizzard Legacy", {
        window="17110B", panel="21190F", paper="21190F", paperAlt="17110B",
        slot="100C08", raised="302314", hover="46321C", border="79603A",
        faint="40301D", blue="FFD100", blueSoft="59401B", teal="FFD100",
        drop="735325", amber="FFCC66", red="E55B50", text="EEE3CE",
        muted="BBA98C", topText="FFF3CC",
    }, { accent={1, .82, 0, 1} }),
    eui = PaletteTheme("Ellesmere", {
        window = { 0.015, 0.015, 0.015, 0.985 }, panel = { 0.08, 0.08, 0.08, 0.92 },
        paper = { 0.08, 0.08, 0.08, 0.92 }, paperAlt = { 0.04, 0.04, 0.04, 0.85 },
        slot = { 0.02, 0.02, 0.02, 1 }, raised = { 0.08, 0.08, 0.08, 0.92 },
        border = { 0.20, 0.20, 0.20, 1 }, faint = { 0.20, 0.20, 0.20, 0.25 },
        blueSoft = { 0.025, 0.20, 0.15, 1 }, drop = { 0.25, 0.90, 0.55, 1 },
        amber = { 0.93, 0.66, 0.25, 1 }, red = { 0.88, 0.31, 0.34, 1 },
        text = { 0.91, 0.93, 0.96, 1 }, muted = { 0.59, 0.64, 0.71, 1 },
    }, { art = "Interface\\AddOns\\FrameGambit\\Assets\\SuiteWindowBackdrop.png", wash = 0.62,
        crop = { 0.25, 1, 0, 0.75 }, classAccent = true, input = { 0.02, 0.02, 0.02, 1 }, selected = { 0.025, 0.20, 0.15, 1 }, primaryHover = { 1, 1, 1, 0.10 } }),
    mimezu = PaletteTheme("Mimezu", {
        window = { 0.035, 0.041, 0.052, 0.985 }, panel = { 0.055, 0.063, 0.078, 1 },
        paper = { 0.073, 0.082, 0.098, 1 }, paperAlt = { 0.060, 0.069, 0.084, 1 },
        slot = { 0.060, 0.069, 0.084, 1 }, raised = { 0.095, 0.108, 0.129, 1 },
        border = { 0.20, 0.235, 0.28, 0.72 }, faint = { 0.18, 0.21, 0.25, 0.25 },
        blue = { 0.27, 0.58, 0.82, 1 }, blueSoft = { 0.18, 0.36, 0.52, 1 },
        drop = { 0.25, 0.90, 0.55, 1 }, teal = { 0.18, 0.76, 0.70, 1 },
        amber = { 0.93, 0.66, 0.25, 1 }, red = { 0.88, 0.31, 0.34, 1 },
        text = { 0.91, 0.93, 0.96, 1 }, muted = { 0.59, 0.64, 0.71, 1 },
    }, { art = "Interface\\AddOns\\FrameGambit\\Assets\\SuiteWindowBackdropMimezu.png", wash = 0.44, primaryHover = { 1, 1, 1, 0.10 } }),
    luminous = PaletteTheme("Luminous", {
        window = { 0.115, 0.125, 0.15, 0.98 }, panel = { 0.14, 0.15, 0.18, 0.94 },
        paper = { 0.14, 0.15, 0.18, 0.94 }, paperAlt = { 0.105, 0.115, 0.14, 0.94 },
        slot = { 0.105, 0.115, 0.14, 0.94 }, raised = { 0.18, 0.195, 0.23, 0.98 },
        border = { 0.36, 0.39, 0.46, 0.92 }, faint = { 0.36, 0.39, 0.46, 0.30 },
        blueSoft = { 0.105, 0.115, 0.14, 1 }, drop = { 0.25, 0.90, 0.55, 1 },
        amber = { 0.96, 0.72, 0.31, 1 }, red = { 0.94, 0.38, 0.42, 1 },
        text = { 0.96, 0.97, 0.99, 1 }, muted = { 0.72, 0.75, 0.81, 1 },
    }, { art = "Interface\\AddOns\\FrameGambit\\Assets\\SuiteWindowBackdropLuminous.png", wash = 0.30,
        classAccent = true, input = { 0.07, 0.075, 0.095, 1 }, primaryHover = { 1, 1, 1, 0.10 } }),
    charcoal = PaletteTheme("Charcoal", {
        window={0.208,0.212,0.188,0.99}, panel={0.290,0.267,0.271,0.98}, paper={0.286,0.282,0.306,0.98}, paperAlt={0.251,0.235,0.239,0.98}, slot={0.251,0.235,0.239,0.98}, raised={0.357,0.318,0.329,1}, border={0.616,0.608,0.671,0.82}, faint={0.737,0.737,0.718,0.26}, hover={0.529,0.463,0.490,1}, blue={0.616,0.608,0.671,1}, blueSoft={0.529,0.463,0.490,1}, teal={0.616,0.608,0.671,1}, drop={0.74,0.78,0.68,1}, amber={0.737,0.737,0.718,1}, red={0.90,0.42,0.43,1}, text={0.929,0.933,0.933,1}, muted={0.737,0.737,0.718,1}, topText={0.929,0.933,0.933,1},
    }, { input={0.141,0.145,0.129,1} }),
    chalk = PaletteTheme("Chalk", {
        window={0.929,0.933,0.933,1}, panel={0.851,0.855,0.835,0.99}, paper={0.965,0.968,0.965,1}, paperAlt={0.737,0.737,0.718,1}, slot={0.737,0.737,0.718,1}, raised={0.80,0.785,0.835,1}, border={0.529,0.463,0.490,0.82}, faint={0.208,0.212,0.188,0.22}, hover={0.73,0.71,0.78,1}, blue={0.408,0.396,0.459,1}, blueSoft={0.77,0.75,0.82,1}, teal={0.30,0.28,0.36,1}, drop={0.23,0.48,0.32,1}, amber={0.435,0.396,0.416,1}, red={0.67,0.18,0.21,1}, text={0.208,0.212,0.188,1}, muted={0.28,0.25,0.29,1}, topText={0.98,0.98,0.98,1},
    }, { input={0.965,0.968,0.965,1}, inputText={0.208,0.212,0.188,1}, selected={0.39,0.36,0.46,1}, selectedText={0.98,0.98,0.98,1} }),
    tungsten = PaletteTheme("Tungsten", {
        window={0.020,0.020,0.008,0.99}, panel={0.23,0.215,0.20,1}, paper={0.105,0.105,0.092,0.98}, paperAlt={0.075,0.075,0.063,0.98}, slot={0.075,0.075,0.063,0.98}, raised={0.29,0.26,0.25,1}, border={0.588,0.475,0.502,0.86}, faint={0.875,0.882,0.855,0.18}, hover={0.35,0.29,0.31,1}, blue={0.58,0.76,0.77,1}, blueSoft={0.210,0.310,0.330,1}, teal={0.58,0.76,0.77,1}, drop={0.46,0.67,0.58,1}, amber={0.79,0.63,0.33,1}, red={0.82,0.34,0.38,1}, text={0.875,0.882,0.855,1}, muted={0.86,0.80,0.81,1}, topText={0.025,0.025,0.02,1},
    }, { input={0.020,0.020,0.008,1}, selected={0.40,0.55,0.57,1}, selectedText={0.025,0.025,0.02,1} }),
    editorial = PaletteTheme("Editorial", {
        window={0.086,0.106,0.114,0.99}, panel={0.125,0.149,0.157,0.98}, paper={0.157,0.180,0.184,0.98}, paperAlt={0.105,0.129,0.137,0.99}, slot={0.105,0.129,0.137,0.99}, raised={0.27,0.28,0.25,1}, border={0.745,0.741,0.702,0.84}, faint={0.745,0.741,0.702,0.20}, hover={0.30,0.29,0.25,1}, blue={0.82,0.74,0.60,1}, blueSoft={0.322,0.282,0.224,1}, teal={0.82,0.74,0.60,1}, drop={0.66,0.76,0.62,1}, amber={0.78,0.62,0.34,1}, red={0.83,0.36,0.38,1}, text={0.929,0.922,0.918,1}, muted={0.745,0.741,0.702,1}, topText={0.055,0.065,0.065,1},
    }, { input={0.055,0.067,0.071,1}, selected={0.647,0.569,0.455,1}, selectedText={0.055,0.065,0.065,1} }),
    snes = ConsoleTheme("Super NES", { window={0.690,0.690,0.720,1}, panel={0.770,0.770,0.790,1}, paper={0.830,0.830,0.840,1}, paperAlt={0.700,0.700,0.730,1}, slot={0.245,0.239,0.255,1}, raised={0.680,0.650,0.810,1}, hover={0.596,0.565,0.765,1}, border={0.430,0.430,0.480,1}, faint={0.430,0.430,0.480,0.45}, text={0.125,0.118,0.145,1}, muted={0.290,0.280,0.340,1}, shortcutInactive={0.455,0.396,0.690,1}, blue={0.275,0.196,0.565,1}, blueSoft={0.275,0.196,0.565,1}, topText={0.980,0.980,1,1}, drop={0.250,0.480,0.340,1}, teal={0.275,0.196,0.565,1}, amber={0.455,0.396,0.690,1}, red={0.660,0.180,0.250,1} }, { base={0.83,0.83,0.84,1}, inputText={0.98,0.98,1,1}, selected={0.275,0.196,0.565,1}, selectedText={0.98,0.98,1,1}, primaryHover={0.36,0.27,0.64,1} }),
    famicom = ConsoleTheme("Famicom", { window={0.945,0.890,0.775,1}, panel={0.910,0.842,0.710,1}, paper={0.965,0.920,0.825,1}, paperAlt={0.860,0.780,0.645,1}, slot={0.125,0.120,0.110,1}, raised={0.920,0.860,0.750,1}, hover={0.860,0.770,0.630,1}, border={0.570,0.480,0.360,1}, faint={0.350,0.035,0.065,0.24}, text={0.250,0.055,0.055,1}, muted={0.390,0.285,0.225,1}, shortcutInactive={0.390,0.285,0.225,1}, blue={0.545,0.055,0.105,1}, blueSoft={0.545,0.055,0.105,1}, topText={0.985,0.940,0.835,1}, drop={0.260,0.520,0.310,1}, teal={0.180,0.390,0.245,1}, amber={0.690,0.455,0.120,1}, red={0.690,0.080,0.105,1} }, { base={0.945,0.890,0.775,1}, inputText={0.985,0.940,0.835,1}, selected={0.545,0.055,0.105,1}, selectedText={0.985,0.940,0.835,1}, primaryHover={0.64,0.09,0.15,1} }),
    gamecube = ConsoleTheme("GameCube", { window="30244F", panel="49376F", paper="382956", paperAlt="292236", slot="17151D", raised="554578", hover="665188", border="9A94AD", text="F0EFF4", muted="E0DCE8", shortcutInactive="C7C3D2", blue="B9ACEE", blueSoft="CBCBD1", topText="251D36", drop="DEDEE3", teal="7CC9AE", amber="F1CF58", red="F08E96", faint="625673" }),
    genesis = ConsoleTheme("Genesis", { window="050505", panel="111111", paper="090909", paperAlt="191919", slot="000000", raised="292929", hover="393939", border="626262", text="F4F4F4", muted="C7C7C7", shortcutInactive="C7C7C7", blue="CB6355", blueSoft="801C12", topText="FFF5F0", drop="9D291B", teal="D3D3D3", amber="E4BE65", red="FFA18C", faint="424242" }),
    ps1 = ConsoleTheme("PS1", { window="94959F", panel="A7A7B0", paper="B7B7BF", paperAlt="9697A1", slot="35363E", raised="A6A7B2", hover="B6B7C0", border="696A77", text="22232A", muted="2C2D35", shortcutInactive="C3C5D5", blue="4C6289", blueSoft="575863", topText="F4F4F7", drop="656671", teal="235A4F", amber="6B4918", red="913E4A", faint="777987" }, { inputText={0.95,0.96,0.98,1}, selectedText={0.96,0.96,0.98,1} }),
    ps2 = ConsoleTheme("PS2", { window="101112", panel="202123", paper="171719", paperAlt="27272B", slot="08090B", raised="333338", hover="42434B", border="60626B", text="F0F0F4", muted="C3C4CE", shortcutInactive="C3C4CE", blue="7D9CCF", blueSoft="303C63", topText="F2F3F7", drop="3C4B78", teal="83BFC3", amber="E9C06D", red="F092AE", faint="414248" }),
    xbox = ConsoleTheme("Xbox", { window="090C0A", panel="141A16", paper="101512", paperAlt="1D231F", slot="050706", raised="282F2A", hover="333D35", border="5C755E", text="EDF4EA", muted="BACDB5", shortcutInactive="BACDB5", blue="A3E743", blueSoft="8DD52D", topText="15200D", drop="B0EE50", teal="A3E743", amber="E7CB76", red="F0978A", faint="3C5140" }),
    xbox360 = ConsoleTheme("Xbox 360", { window="D7DAD5", panel="E8EBE5", paper="F2F4EF", paperAlt="CED4CA", slot="30382F", raised="CCD5C6", hover="B7C7AD", border="7A8970", text="253020", muted="43513B", shortcutInactive="C6D8BC", blue="647F25", blueSoft="9DBD48", topText="202812", drop="B0CE60", teal="356322", amber="78551B", red="9A3E39", faint="98A88C" }, { inputText={0.93,0.97,0.91,1}, selectedText={0.12,0.16,0.10,1} }),
    violetmist = PaletteTheme("Violet Mist", {
        window={45/255,34/255,55/255,1}, panel={57/255,44/255,67/255,1}, paper={45/255,34/255,55/255,1}, paperAlt={39/255,30/255,48/255,1}, slot={30/255,23/255,38/255,1}, raised={79/255,63/255,91/255,1}, border={186/255,175/255,196/255,0.48}, faint={186/255,175/255,196/255,0.20}, hover={89/255,59/255,82/255,1}, blue={182/255,105/255,160/255,1}, blueSoft={75/255,45/255,69/255,1}, teal={143/255,180/255,180/255,1}, drop={90/255,131/255,131/255,1}, amber={225/255,188/255,139/255,1}, red={231/255,139/255,153/255,1}, text={242/255,238/255,238/255,1}, muted={186/255,175/255,196/255,1}, topText={242/255,238/255,238/255,1},
    }, { base={45/255,34/255,55/255,1}, inputText={242/255,238/255,238/255,1}, selected={75/255,45/255,69/255,1}, selectedText={242/255,238/255,238/255,1} }),
    violetbloom = PaletteTheme("Violet Bloom", {
        window={45/255,34/255,55/255,1}, panel={45/255,67/255,71/255,1}, paper={45/255,34/255,55/255,1}, paperAlt={46/255,68/255,72/255,1}, slot={30/255,23/255,38/255,1}, raised={115/255,55/255,98/255,1}, border={90/255,131/255,131/255,1}, faint={186/255,175/255,196/255,0.20}, hover={130/255,63/255,111/255,1}, blue={182/255,105/255,160/255,1}, blueSoft={115/255,55/255,98/255,1}, teal={143/255,180/255,180/255,1}, drop={90/255,131/255,131/255,1}, amber={225/255,188/255,139/255,1}, red={231/255,139/255,153/255,1}, text={242/255,238/255,238/255,1}, muted={186/255,175/255,196/255,1}, topText={26/255,17/255,32/255,1},
    }, { base={45/255,34/255,55/255,1}, selected={182/255,105/255,160/255,1}, selectedText={26/255,17/255,32/255,1} }),
}
-- Keep light/secondary control ink readable without changing the palette identity.
APPEARANCE_THEMES.charcoal.selected = { 0.30, 0.28, 0.30, 1 }
APPEARANCE_THEMES.charcoal.hover = { 0.40, 0.35, 0.38, 1 }
APPEARANCE_THEMES.charcoal.muted = { 0.82, 0.82, 0.80, 1 }
APPEARANCE_THEMES.snes.muted = { 0.25, 0.24, 0.29, 1 }
APPEARANCE_THEMES.violetbloom.muted = { 0.82, 0.78, 0.86, 1 }
APPEARANCE_THEMES.famicom.cardAlt = { 0.92, 0.86, 0.75, 1 }
for _, id in ipairs({ "eui", "mimezu", "luminous", "violetmist", "violetbloom", "charcoal" }) do
    APPEARANCE_THEMES[id].primaryHover = APPEARANCE_THEMES[id].selected
end
local activeAppearanceID = "eui"
local bundledSkinState = setmetatable({}, { __mode = "k" })

local function ActiveAppearance()
    return APPEARANCE_THEMES[activeAppearanceID] or APPEARANCE_THEMES.eui
end

local function BundledAccent()
    local theme = ActiveAppearance()
    if theme.accent then return theme.accent[1], theme.accent[2], theme.accent[3] end
    local classFile = PlayerClassFile()
    local color = classFile and SKIN_CLASS_COLORS[classFile]
    if color then return color[1], color[2], color[3] end
    return 12 / 255, 210 / 255, 157 / 255
end

local function BundledState(object)
    local state = bundledSkinState[object]
    if not state then
        state = {}
        bundledSkinState[object] = state
    end
    return state
end

local function LegacyVisual(kind, frame, state, opts)
    if ns.LegacySkin then ns.LegacySkin:Apply(kind, frame, state, opts, activeAppearanceID == "legacy") end
end

local function FadeTextureRegions(frame, keep)
    if not frame or not frame.GetRegions then return end
    for index = 1, select("#", frame:GetRegions()) do
        local region = select(index, frame:GetRegions())
        if region and region.IsObjectType and region:IsObjectType("Texture")
            and not (keep and keep[region]) then
            region:SetAlpha(0)
        end
    end
end

local function ClearOwnedBackdrop(frame)
    if not frame or not frame.SetBackdropColor then return end
    frame:SetBackdropColor(0, 0, 0, 0)
    frame:SetBackdropBorderColor(0, 0, 0, 0)
end

local function Solid(parent, layer, color, sublevel)
    local texture = parent:CreateTexture(nil, layer, nil, sublevel)
    texture:SetColorTexture(unpack(color))
    return texture
end

local function BundledPhysicalPixel(frame)
    local physicalSize = GetPhysicalScreenSize
    local physicalHeight = physicalSize and select(2, physicalSize())
    local effectiveScale = frame and frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
    if issecretvalue and (issecretvalue(physicalHeight) or issecretvalue(effectiveScale)) then return 1 end
    if type(physicalHeight) ~= "number" or physicalHeight <= 0
        or type(effectiveScale) ~= "number" or effectiveScale <= 0 then
        return 1
    end
    return (768 / physicalHeight) / effectiveScale
end

local function AddBundledBorder(frame, state, color)
    local c = color or ActiveAppearance().border
    if not state.border then
        local pixel = BundledPhysicalPixel(frame)
        local top = Solid(frame, "BORDER", c, -7)
        local bottom = Solid(frame, "BORDER", c, -7)
        local left = Solid(frame, "BORDER", c, -7)
        local right = Solid(frame, "BORDER", c, -7)
        for _, texture in ipairs({ top, bottom, left, right }) do
            if texture.SetSnapToPixelGrid then
                texture:SetSnapToPixelGrid(false)
                texture:SetTexelSnappingBias(0)
            end
        end
        top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(pixel)
        bottom:SetPoint("BOTTOMLEFT"); bottom:SetPoint("BOTTOMRIGHT"); bottom:SetHeight(pixel)
        left:SetPoint("TOPLEFT", 0, -pixel); left:SetPoint("BOTTOMLEFT", 0, pixel); left:SetWidth(pixel)
        right:SetPoint("TOPRIGHT", 0, -pixel); right:SetPoint("BOTTOMRIGHT", 0, pixel); right:SetWidth(pixel)
        state.border = { top, bottom, left, right }
    end
    for _, texture in ipairs(state.border) do texture:SetColorTexture(unpack(c)) end
end

local function BundledPanel(frame, opts)
    if not frame then return end
    local state = BundledState(frame)
    opts = opts or {}
    if not state.panel then
        state.panel = true
        FadeTextureRegions(frame)
        ClearOwnedBackdrop(frame)
        if not opts.noBg then
            state.bg = Solid(frame, "BACKGROUND", ActiveAppearance().panel, -6)
            state.bg:SetAllPoints(frame)
        end
    end
    state.panelOpts = opts
    local theme = ActiveAppearance()
    if state.bg then state.bg:SetColorTexture(unpack(opts.inset and theme.cardAlt or theme.panel)) end
    if not opts.noBorder then AddBundledBorder(frame, state) end
    LegacyVisual("panel", frame, state, opts)
end

local function BundledButtonColors(button, hovered)
    local theme = ActiveAppearance()
    if button._cinematicAccent then return CINEMATIC_BUTTON, CINEMATIC_ACCENT end
    local selected = button._selected or button._primary
    if selected then
        local cinematic = ns.IsCinematicEditorTheme and ns:IsCinematicEditorTheme()
        if cinematic or button._selectedColor == CINEMATIC_BUTTON then
            return CINEMATIC_BUTTON, CINEMATIC_ACCENT
        end
        return (hovered and button._primary and theme.primaryHover) or theme.selected, theme.selectedText
    end
    return (hovered and theme.hover) or theme.raised, theme.text
end

local function BundledButton(button, keepKeys)
    if not button then return end
    local state = BundledState(button)
    if not state.button then
        state.button = true
        local keep = {}
        for _, key in ipairs(keepKeys or {}) do
            local region = button[key]
            if region then keep[region] = true end
        end
        FadeTextureRegions(button, keep)
        for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
            local fn = button[getter]
            local texture = fn and fn(button)
            if texture and not keep[texture] then texture:SetAlpha(0) end
        end
        for _, key in ipairs({ "Left", "Middle", "Right", "LeftSeparator", "RightSeparator" }) do
            local region = button[key]
            if region and not keep[region] and region.SetAlpha then region:SetAlpha(0) end
        end
        ClearOwnedBackdrop(button)
        local theme = ActiveAppearance()
        state.bg = Solid(button, "BACKGROUND", button._primary and theme.selected or theme.raised, -6)
        state.bg:SetAllPoints(button)
        state.hover = Solid(button, "HIGHLIGHT", button._primary and (ActiveAppearance().primaryHover or { 1, 1, 1, 0.10 }) or { 1, 1, 1, 0.10 }, 0)
        state.hover:SetAllPoints(button)
        if button.HookScript then
            button:HookScript("OnEnter", function()
                state.hovered = true
                BundledButton(button)
            end)
            button:HookScript("OnLeave", function()
                state.hovered = false
                BundledButton(button)
            end)
        end
    end
    state.buttonOpts = keepKeys
    local theme = ActiveAppearance()
    local fill, ink = BundledButtonColors(button, state.hovered)
    state.bg:SetColorTexture(unpack(fill))
    if state.hover then state.hover:SetColorTexture(0, 0, 0, 0) end
    local label = button.Text or (button.GetFontString and button:GetFontString())
    if label then label:SetTextColor(unpack(ink)) end
    AddBundledBorder(button, state, button._selected and C.accent or theme.border)
    LegacyVisual("button", button, state)
end

local function BundledFont(fontString)
    if not fontString or not fontString.GetFont then return end
    local _, size = fontString:GetFont()
    local justifyH = fontString:GetJustifyH()
    local justifyV = fontString:GetJustifyV()
    if issecretvalue and issecretvalue(size) then return end
    if not bundledShadowFont and CreateFont then
        bundledShadowFont = CreateFont("FrameGambitBundledSkinShadowFont")
        bundledShadowFont:SetFont(SKIN_FONT, 12, "")
        bundledShadowFont:SetShadowColor(0, 0, 0, 1)
        bundledShadowFont:SetShadowOffset(1, -1)
    end
    if bundledShadowFont and fontString.SetFontObject then
        fontString:SetFontObject(bundledShadowFont)
    end
    fontString:SetFont(SKIN_FONT, size or 12, "")
    fontString:SetJustifyH(justifyH)
    fontString:SetJustifyV(justifyV)
end

local function BundledCloseButton(button)
    if not button then return end
    local state = BundledState(button)
    if state.close then
        local ink = ActiveAppearance().text
        state.x:SetVertexColor(ink[1], ink[2], ink[3], 0.85)
        LegacyVisual("close", button, state)
        return
    end
    state.close = true
    if button.SetNormalTexture then button:SetNormalTexture("") end
    if button.SetPushedTexture then button:SetPushedTexture("") end
    if button.SetHighlightTexture then button:SetHighlightTexture("") end
    if button.SetDisabledTexture then button:SetDisabledTexture("") end
    ClearOwnedBackdrop(button)
    FadeTextureRegions(button)
    local x = button:CreateTexture(nil, "OVERLAY")
    x:SetAtlas("uitools-icon-close")
    x:SetSize(14, 14)
    x:SetPoint("CENTER", -2, 0)
    local function Tint(alpha)
        local ink = ActiveAppearance().text
        x:SetVertexColor(ink[1], ink[2], ink[3], alpha)
    end
    Tint(0.85)
    state.x = x
    button:HookScript("OnEnter", function() Tint(1) end)
    button:HookScript("OnLeave", function() Tint(0.85) end)
    LegacyVisual("close", button, state)
end

local function BundledEditBox(editBox)
    if not editBox then return end
    local state = BundledState(editBox)
    if not state.edit then
        state.edit = true
        FadeTextureRegions(editBox)
        for _, key in ipairs({ "Left", "Right", "Middle", "Mid" }) do
            local region = editBox[key]
            if region and region.SetAlpha then region:SetAlpha(0) end
        end
        ClearOwnedBackdrop(editBox)
        state.bg = Solid(editBox, "BACKGROUND", ActiveAppearance().input, -6)
        state.bg:SetAllPoints(editBox)
    end
    state.bg:SetColorTexture(unpack(ActiveAppearance().input))
    if editBox.SetTextColor then editBox:SetTextColor(unpack(ActiveAppearance().inputText)) end
    AddBundledBorder(editBox, state)
    LegacyVisual("edit", editBox, state)
end

local function BundledShell(frame, opts)
    if not frame then return end
    local state = BundledState(frame)
    opts = opts or {}
    if not state.shell then
        state.shell = true
        FadeTextureRegions(frame)
        ClearOwnedBackdrop(frame)

        local art = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        art:SetAllPoints(frame)
        state.art = art
        local overlay = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
        overlay:SetAllPoints(frame)
        state.overlay = overlay

        state.updateArtCrop = function()
            local width, height = frame:GetSize()
            if issecretvalue and (issecretvalue(width) or issecretvalue(height)) then return end
            if not width or width == 0 or not height or height == 0 then return end
            local crop = ActiveAppearance().crop
            local baseLeft, baseRight, baseTop, baseBottom = crop[1], crop[2], crop[3], crop[4]
            local baseWidth, baseHeight = baseRight - baseLeft, baseBottom - baseTop
            local imageAspect, frameAspect = 561 / 433, width / height
            if frameAspect > imageAspect then
                local visible = baseHeight * (imageAspect / frameAspect)
                local trim = (baseHeight - visible) / 2
                art:SetTexCoord(baseLeft, baseRight, baseTop + trim, baseBottom - trim)
            else
                local visible = baseWidth * (frameAspect / imageAspect)
                local trim = (baseWidth - visible) / 2
                art:SetTexCoord(baseLeft + trim, baseRight - trim, baseTop, baseBottom)
            end
        end
        frame:HookScript("OnSizeChanged", state.updateArtCrop)

        if not opts.noTopBar then
            local topBar = Solid(frame, "BACKGROUND", { 0, 0, 0, 0.50 }, -5)
            topBar:SetPoint("TOPLEFT"); topBar:SetPoint("TOPRIGHT"); topBar:SetHeight(25)
            state.topBar = topBar
        end
        if opts.bottomBar then
            local bottomBar = Solid(frame, "BACKGROUND", { 0, 0, 0, 0.50 }, -5)
            bottomBar:SetPoint("BOTTOMLEFT"); bottomBar:SetPoint("BOTTOMRIGHT")
            bottomBar:SetHeight(type(opts.bottomBar) == "number" and opts.bottomBar or 25)
            state.bottomBar = bottomBar
        end

        if not opts.noBorder and C_Texture and C_Texture.GetAtlasInfo
            and C_Texture.GetAtlasInfo("AdventureMap_TopBorder") then
            local borderFrame = CreateFrame("Frame", nil, frame)
            borderFrame:SetAllPoints(frame)
            borderFrame:SetFrameLevel(frame:GetFrameLevel() + 6)
            local border = borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
            border:SetAtlas("AdventureMap_TopBorder")
            border:SetAllPoints(borderFrame)
            state.atlasBorder = borderFrame
        elseif not opts.noBorder then
            AddBundledBorder(frame, state)
        end
    end
    state.shellOpts = opts
    local theme = ActiveAppearance()
    state.art:SetTexture(theme.art)
    state.art:SetVertexColor(unpack(theme.base or { 1, 1, 1, 1 }))
    state.overlay:SetColorTexture(0, 0, 0, theme.wash)
    state.updateArtCrop()
    if state.border then AddBundledBorder(frame, state) end
    for _, region in ipairs({ state.art, state.overlay }) do region:Show() end
    if state.topBar then state.topBar:Show() end
    if state.bottomBar then state.bottomBar:Show() end
    if state.atlasBorder then state.atlasBorder:Show() end
    for _, region in ipairs(state.border or {}) do region:Show() end
    LegacyVisual("shell", frame, state, opts)
end

local BUNDLED_SKIN = {
    Shell = BundledShell,
    Panel = BundledPanel,
    Button = BundledButton,
    Font = BundledFont,
    CloseButton = BundledCloseButton,
    EditBox = BundledEditBox,
    WhiteButtonLabel = function(button)
        local label = button and (button.Text or (button.GetFontString and button:GetFontString()))
        if not label then return end
        BundledButton(button)
        local state = BundledState(button)
        if not state.whiteLabelHook and button.HookScript then
            state.whiteLabelHook = true
            button:HookScript("OnEnable", function() BundledButton(button) end)
        end
    end,
}

local function EUIOwnsVisual(object)
    return object and (euiOwned[object] or object._frameGambitEUI) or false
end

local function SetFallbackBackdrop(frame, color, border)
    if not frame then return end
    if EUIOwnsVisual(frame) then
        if bundledSkinState[frame] and bundledSkinState[frame].button then BundledButton(frame) end
        return
    end
    if color and frame.SetBackdropColor then frame:SetBackdropColor(unpack(color)) end
    if border and frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(unpack(border)) end
end

local SELECTED_FILL_TEXT = { 0.02, 0.06, 0.07, 1 }
local function SelectedButtonText(button, selected, unselected, euiUnselected)
    if not selected then
        if EUIOwnsVisual(button) then return euiUnselected or C.text end
        return unselected or C.accent
    end
    -- Standalone buttons use each theme's selected fill and tab ink. EUI-owned
    -- controls deliberately stay neutral, so their active state remains the
    -- live suite accent supplied by the facade.
    if EUIOwnsVisual(button) then
        local _, ink = BundledButtonColors(button)
        return ink
    end
    return C.selectedText or SELECTED_FILL_TEXT
end

local function ClearShellBackdrop(frame)
    if not frame or not frame.SetBackdropColor then return end
    -- S.Shell owns the visible atlas/AdventureMap border. The fallback
    -- Backdrop must become transparent or it will cover that shell.
    frame:SetBackdropColor(0, 0, 0, 0)
    frame:SetBackdropBorderColor(0, 0, 0, 0)
end

local function ApplyEUIObject(kind, object, opts, record)
    if not object then return end
    local list = euiObjects[kind]
    if record ~= false and list and not euiSeen[object] then
        list[#list + 1] = { object = object, opts = opts }
        euiSeen[object] = kind
    end
    opts = opts or object._frameGambitEUIKeepKeys
    local skin = euiSkin
    local fn = skin and skin[kind == "shell" and "Shell" or kind == "panel" and "Panel" or
        kind == "button" and "Button" or kind == "font" and "Font" or
        kind == "close" and "CloseButton" or kind == "edit" and "EditBox"]
    if fn then
        local ok = pcall(fn, object, opts)
        if ok then
            euiOwned[object] = kind
            if kind == "button" or kind == "close" then object._frameGambitEUI = true end
            if kind == "shell" then ClearShellBackdrop(object) end
        end
        if kind == "button" and skin.WhiteButtonLabel then
            pcall(skin.WhiteButtonLabel, object)
        end
    end
end

function ns:TrackEUIObject(kind, object, opts)
    ApplyEUIObject(kind, object, opts)
end

local function UpdateEUIAccent()
    local theme = ActiveAppearance()
    local r, g, b = BundledAccent()
    local accent = theme.accent or { r, g, b, 1 }
    local teal = theme.teal or accent
    local function CopyColor(target, source)
        for index = 1, 4 do target[index] = source[index] end
    end
    for _, key in ipairs({ "window", "panel", "card", "cardAlt", "raised", "border", "faint", "text", "muted" }) do
        CopyColor(C[key], theme[key])
    end
    -- blue is focus, teal is live/active, and blueSoft/tabSelection is the
    -- selected navigation and primary-control fill.
    CopyColor(C.accent, accent); CopyColor(C.blue, theme.blue or accent)
    CopyColor(C.teal, teal); CopyColor(C.blueSoft, theme.selected or theme.blueSoft)
    CopyColor(C.amber, theme.amber or C.amber); CopyColor(C.red, theme.red or C.red)
    C.selectedText = CloneColor(theme.selectedText or theme.text)
    C.inputText = CloneColor(theme.inputText or theme.text)
    CopyColor(BASE_ACCENT, accent); CopyColor(BASE_BLUE, theme.blue or accent)
    CopyColor(BASE_BORDER, theme.border); CopyColor(BASE_TEAL, teal)
    CopyColor(NORMAL_HEADER, theme.panel); CopyColor(BUTTON_HOVER, theme.raised)

    -- Repaint every object already adopted by the bundled facade. New and
    -- lazy-created objects read ActiveAppearance when they are first skinned.
    for object, state in pairs(bundledSkinState) do
        if state.shell then BundledShell(object, state.shellOpts) end
        if state.panel then BundledPanel(object, state.panelOpts) end
        if state.button then BundledButton(object, state.buttonOpts) end
        if state.edit then BundledEditBox(object) end
        if state.font then BundledFont(object) end
        if state.close then BundledCloseButton(object) end
    end
    ns:ApplyEditorTheme()
    if ns.LegacySkin then ns.LegacySkin:RefreshDetails(activeAppearanceID == "legacy") end
end

function ns:SetEUITheme(skin)
    euiSkin = skin
    self.euiSkin = skin
    if not skin then return end
    for kind, list in pairs(euiObjects) do
        for _, entry in ipairs(list) do ApplyEUIObject(kind, entry.object, entry.opts, false) end
    end
    UpdateEUIAccent()
end

function ns:ApplyAppearanceTheme(themeID)
    activeAppearanceID = APPEARANCE_THEMES[themeID] and themeID or "eui"
    UpdateEUIAccent()
    if self.LegacySkin then
        for scroll in pairs(self.LegacySkin.scrolls) do
            if scroll._frameGambitUpdateScrollBar then scroll._frameGambitUpdateScrollBar() end
        end
    end
    if self.RefreshAppearanceControls then self:RefreshAppearanceControls() end
    if self.HelpCenter and self.HelpCenter.ShowTopic then
        self.HelpCenter:ShowTopic(self.HelpCenter.topic or 1)
    end
    if self.Options and self.Options:IsVisible() and self.RenderOptions then self:RenderOptions() end
end

function ns:HideAppearancePicker()
    local panel = self.Options
    if panel and panel.appearancePicker then panel.appearancePicker:Hide() end
end

local function TrackTheme(object, role)
    if not object then return end
    local roles = themeObjects[object] or {}
    roles[role] = true
    themeObjects[object] = roles
end

function ns:TrackAppearanceObject(object, role)
    TrackTheme(object, role)
end

local function SetTealTexture(texture)
    TrackTheme(texture, "tealTexture")
    texture:SetColorTexture(unpack(C.teal))
end

local function Backdrop(frame, color, border)
    local actualColor, actualBorder = color or C.card, border or C.border
    if actualColor == C.accent then TrackTheme(frame, "background") end
    if actualColor == C.teal then TrackTheme(frame, "tealBackground") end
    if actualColor == C.window then TrackTheme(frame, "windowBackground") end
    if actualColor == C.panel then TrackTheme(frame, "panelBackground") end
    if actualColor == C.card then TrackTheme(frame, "cardBackground") end
    if actualColor == C.cardAlt then TrackTheme(frame, "insetBackground") end
    if actualColor == C.raised then TrackTheme(frame, "raisedBackground") end
    if actualColor == C.blueSoft then TrackTheme(frame, "blueSoftBackground") end
    if actualBorder == C.accent then TrackTheme(frame, "accentBorder") end
    if actualBorder == C.teal then TrackTheme(frame, "tealBorder") end
    if actualBorder == C.border then TrackTheme(frame, "border") end
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    frame:SetBackdropColor(unpack(actualColor))
    frame:SetBackdropBorderColor(unpack(actualBorder))
end

-- BindCards-style scrollbars: a quiet inset rail with a slim, draggable
-- teal thumb. The stock template's oversized arrows are hidden, and the
-- replacement lives in the gutter already reserved inside each card so it
-- never paints across the card border.
local function SkinScrollFrame(scroll)
    if not scroll or scroll._frameGambitScrollBar then return end

    local stock = scroll.ScrollBar or scroll.scrollBar
    if not stock and scroll.GetName and scroll:GetName() then
        stock = _G[scroll:GetName() .. "ScrollBar"]
    end
    if stock then
        stock:SetAlpha(0)
        stock:EnableMouse(false)
        stock:Hide()
    end

    scroll:EnableMouseWheel(true)
    if scroll.SetClipsChildren then scroll:SetClipsChildren(true) end

    local track = CreateFrame("Button", nil, scroll:GetParent(), "BackdropTemplate")
    track:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 4, 0)
    track:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 4, 0)
    track:SetWidth(8)
    track:SetFrameLevel(scroll:GetFrameLevel() + 8)
    track:EnableMouse(true)
    Backdrop(track, C.panel, C.border)

    local rail = track:CreateTexture(nil, "BACKGROUND")
    rail:SetTexture("Interface\\Buttons\\WHITE8X8")
    rail:SetVertexColor(C.border[1], C.border[2], C.border[3], 0.44)
    rail:SetPoint("TOP", 0, -3)
    rail:SetPoint("BOTTOM", 0, 3)
    rail:SetWidth(2)

    local thumb = CreateFrame("Button", nil, track, "BackdropTemplate")
    thumb:SetSize(6, 28)
    thumb:SetPoint("TOP", track, "TOP", 0, -2)
    thumb:SetFrameLevel(track:GetFrameLevel() + 1)
    thumb:EnableMouse(true)
    thumb:RegisterForDrag("LeftButton")
    Backdrop(thumb, { C.teal[1], C.teal[2], C.teal[3], 0.88 }, C.teal)

    local dragging, dragStartY, dragStartScroll
    local function Range()
        return math.max(0, tonumber(scroll:GetVerticalScrollRange()) or 0)
    end
    local function UpdateThumb()
        if ns.LegacySkin and ns.LegacySkin:UpdateScroll(scroll, track) then return end
        local maxScroll = Range()
        local trackHeight = math.max(1, track:GetHeight() - 4)
        if maxScroll <= 0 or trackHeight <= 1 then
            track:Hide()
            return
        end
        track:Show()
        local visibleHeight = math.max(1, scroll:GetHeight())
        local thumbHeight = math.min(trackHeight, math.max(28, trackHeight * visibleHeight / (visibleHeight + maxScroll)))
        local travel = math.max(0, trackHeight - thumbHeight)
        local ratio = math.max(0, math.min(1, (tonumber(scroll:GetVerticalScroll()) or 0) / maxScroll))
        thumb:SetHeight(thumbHeight)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, -2 - ratio * travel)
    end
    local function StopDrag()
        if not dragging then return end
        dragging = false
        thumb:SetScript("OnUpdate", nil)
        thumb:SetBackdropColor(C.teal[1], C.teal[2], C.teal[3], 0.88)
        thumb:SetBackdropBorderColor(unpack(C.teal))
    end
    local function BeginDrag()
        local _, cursorY = GetCursorPosition()
        local scale = math.max(0.001, scroll:GetEffectiveScale())
        dragging = true
        dragStartY = cursorY / scale
        dragStartScroll = tonumber(scroll:GetVerticalScroll()) or 0
        thumb:SetBackdropColor(unpack(C.teal))
        thumb:SetBackdropBorderColor(unpack(C.teal))
        thumb:SetScript("OnUpdate", function()
            if not IsMouseButtonDown("LeftButton") then StopDrag(); return end
            local _, currentY = GetCursorPosition()
            local travel = math.max(1, track:GetHeight() - 4 - thumb:GetHeight())
            local delta = dragStartY - currentY / math.max(0.001, scroll:GetEffectiveScale())
            scroll:SetVerticalScroll(math.max(0, math.min(Range(), dragStartScroll + delta / travel * Range())))
            UpdateThumb()
        end)
    end

    thumb:SetScript("OnEnter", function(self)
        if not dragging then
            self:SetBackdropColor(C.teal[1], C.teal[2], C.teal[3], 0.88)
            self:SetBackdropBorderColor(unpack(C.teal))
        end
    end)
    thumb:SetScript("OnLeave", function(self)
        if not dragging then
            self:SetBackdropColor(C.teal[1], C.teal[2], C.teal[3], 0.88)
            self:SetBackdropBorderColor(unpack(C.teal))
        end
    end)
    thumb:SetScript("OnDragStart", BeginDrag)
    thumb:SetScript("OnDragStop", StopDrag)
    thumb:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then BeginDrag() end end)
    thumb:SetScript("OnMouseUp", StopDrag)

    track:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        local _, cursorY = GetCursorPosition()
        local scale = math.max(0.001, track:GetEffectiveScale())
        local offset = (track:GetTop() or 0) - cursorY / scale - thumb:GetHeight() * 0.5
        local travel = math.max(1, track:GetHeight() - 4 - thumb:GetHeight())
        scroll:SetVerticalScroll(math.max(0, math.min(Range(), offset / travel * Range())))
        UpdateThumb()
        BeginDrag()
    end)
    track:SetScript("OnMouseUp", StopDrag)

    scroll:SetScript("OnMouseWheel", function(self, delta)
        local nextScroll = (tonumber(self:GetVerticalScroll()) or 0) - delta * 50
        self:SetVerticalScroll(math.max(0, math.min(Range(), nextScroll)))
        UpdateThumb()
    end)
    scroll:HookScript("OnVerticalScroll", UpdateThumb)
    scroll:HookScript("OnScrollRangeChanged", UpdateThumb)
    scroll:HookScript("OnSizeChanged", UpdateThumb)
    scroll:HookScript("OnShow", function() C_Timer.After(0, UpdateThumb) end)
    scroll._frameGambitScrollBar = track
    scroll._frameGambitUpdateScrollBar = UpdateThumb
    -- Register even before the first Legacy selection so existing lists
    -- switch immediately, including hidden profile/connection dialogs.
    if ns.LegacySkin then ns.LegacySkin.scrolls[scroll] = false end
    C_Timer.After(0, UpdateThumb)
end

local function Text(parent, template, value, color)
    local label = parent:CreateFontString(nil, "ARTWORK", template or "GameFontHighlightSmall")
    label:SetText(value or "")
    local actualColor = color or C.muted
    if actualColor == C.accent then TrackTheme(label, "text") end
    if actualColor == C.teal then TrackTheme(label, "tealText") end
    if actualColor == C.text then TrackTheme(label, "primaryText") end
    if actualColor == C.muted then TrackTheme(label, "mutedText") end
    label:SetTextColor(unpack(actualColor))
    ApplyEUIObject("font", label)
    return label
end

local SetTooltip
local AddLayoutControls
local REQUIREMENT_BUTTON_SIZE = 22
local REQUIREMENT_BUTTON_GAP = REQUIREMENT_BUTTON_SIZE

local function StyleRequirementButton(button, hovered)
    if EUIOwnsVisual(button) then return end
    local strength = hovered and 0.24 or 0.15
    button:SetBackdropColor(C.accent[1] * strength, C.accent[2] * strength, C.accent[3] * strength, 1)
    button:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], hovered and 1 or 0.72)
end

local function SetRequirementButtonLabel(control, label)
    local text = control.GetFontString and control:GetFontString() or control.text
    local bareAdd = not label or label == "+"
    if not control.addStrokes then
        control.addStrokes = {}
        for index = 1, 2 do
            local stroke = control:CreateTexture(nil, "OVERLAY")
            stroke:SetTexture("Interface\\Buttons\\WHITE8X8")
            stroke:SetPoint("CENTER")
            stroke:SetSize(index == 1 and 12 or 2, index == 1 and 2 or 12)
            stroke:SetVertexColor(unpack(C.accent))
            TrackTheme(stroke, "accentTexture")
            control.addStrokes[index] = stroke
        end
        control.AddStrokeHorizontal = control.addStrokes[1]
        control.AddStrokeVertical = control.addStrokes[2]
        control._frameGambitEUIKeepKeys = { "AddStrokeHorizontal", "AddStrokeVertical" }
    end
    if text then
        text:SetText(bareAdd and "" or label)
        text:SetShown(not bareAdd)
    end
    for _, stroke in ipairs(control.addStrokes) do
        stroke:SetAlpha(1)
        stroke:SetVertexColor(unpack(C.accent))
        stroke:SetShown(bareAdd)
    end
end

local function Button(parent, label, width, callback, primary)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button._primary = primary
    button:SetSize(width or 92, 24)
    Backdrop(button, primary and C.blueSoft or C.raised, C.border)
    local text = Text(button, "GameFontNormalSmall", label, primary and (C.selectedText or C.text) or C.text)
    if primary then TrackTheme(text, "primaryButtonText") end
    text:SetPoint("CENTER")
    button:SetFontString(text)
    ApplyEUIObject("button", button)
    button:SetScript("OnEnter", function(self)
        if not self._frameGambitEUI then
            if self._selected and self._selectedColor then
                self:SetBackdropColor(unpack(self._selectedColor))
            else
                self:SetBackdropColor(unpack(BUTTON_HOVER))
            end
            self:SetBackdropBorderColor(unpack((self._selected and self._selectedColor) and C.teal or C.blue))
        end
        if self._tooltipTitle then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self._tooltipTitle, unpack(TOOLTIP_TITLE_COLOR))
            if self._tooltipBody then GameTooltip:AddLine(self._tooltipBody, TOOLTIP_BODY_COLOR[1], TOOLTIP_BODY_COLOR[2], TOOLTIP_BODY_COLOR[3], true) end
            if self._tooltipLines then
                for _, line in ipairs(self._tooltipLines) do
                    GameTooltip:AddLine("- " .. line, TOOLTIP_BODY_COLOR[1], TOOLTIP_BODY_COLOR[2], TOOLTIP_BODY_COLOR[3], true)
                end
            end
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function(self)
        if not self._frameGambitEUI then
            local fill = C.raised
            if self._primary then
                fill = C.blueSoft
            elseif self._selected then
                fill = self._selectedColor or C.teal
            end
            self:SetBackdropColor(unpack(fill))
            self:SetBackdropBorderColor(unpack(C.border))
        end
        if self._tooltipTitle then GameTooltip_Hide() end
    end)
    button:SetScript("OnClick", callback)
    return button
end

-- The compact suite font does not contain reliable arrow glyphs on every
-- Retail client. Every direction uses this one canonical mark; reversing the
-- segment positions is an exact 180-degree rotation with identical thickness.
local TRIANGLE_SEGMENTS = {
    { span = 10, offset = -3 },
    { span = 6, offset = 0 },
    { span = 2, offset = 3 },
}

local function DrawTriangle(control, direction)
    if control.GetFontString and control:GetFontString() then control:GetFontString():SetText("") end
    if control.text then control.text:SetText("") end
    control.arrowLines = control.arrowLines or {}
    local horizontal = direction == "left" or direction == "right"
    local rotation = (direction == "down" or direction == "left") and -1 or 1
    for index, segment in ipairs(TRIANGLE_SEGMENTS) do
        local line = control.arrowLines[index]
        if not line then
            line = control:CreateTexture(nil, "OVERLAY")
            control.arrowLines[index] = line
            TrackTheme(line, "accentTexture")
        end
        line:ClearAllPoints()
        if horizontal then
            line:SetSize(1, segment.span)
            line:SetPoint("CENTER", segment.offset * rotation, 0)
        else
            line:SetSize(segment.span, 1)
            line:SetPoint("CENTER", 0, segment.offset * rotation)
        end
        line:SetColorTexture(unpack(C.accent)); line:Show()
    end
    if ns.LegacySkin then ns.LegacySkin:Arrow(control, direction, activeAppearanceID == "legacy") end
end

local function DrawRemoveMark(control)
    if control.GetFontString and control:GetFontString() then control:GetFontString():SetText(""); control:GetFontString():Hide() end
    if control.text then control.text:SetText(""); control.text:Hide() end
    control.removeStrokes = control.removeStrokes or {}
    for index, angle in ipairs({ math.pi / 4, -math.pi / 4 }) do
        local stroke = control.removeStrokes[index]
        if not stroke then
            stroke = control:CreateTexture(nil, "OVERLAY")
            stroke:SetTexture("Interface\\Buttons\\WHITE8X8")
            stroke:SetSize(2, 11); stroke:SetPoint("CENTER"); stroke:SetRotation(angle)
            control.removeStrokes[index] = stroke
        end
        stroke:SetVertexColor(unpack(REMOVE_RED)); stroke:Show()
    end
end

local function DrawInspectorIcon(parent, kind)
    local icon = CreateFrame("Frame", nil, parent)
    icon:SetSize(42, 42); icon:EnableMouse(false)
    local index = ({ transition = 0, eye = 1, group = 2, link = 3, visibility = 4 })[kind] or 0
    local texture = icon:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints(); texture:SetTexture("Interface\\AddOns\\FrameGambit\\Assets\\InspectorIcons")
    texture:SetTexCoord(index / 5, (index + 1) / 5, 0, 1)
    if ns.LegacySkin then ns.LegacySkin:Icon(texture, activeAppearanceID == "legacy") end
    return icon
end

local function InspectorSwitch(parent, enabled)
    local toggle = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    toggle:SetSize(42, 20); Backdrop(toggle, enabled and { 0.03, 0.18, 0.17, 1 } or C.cardAlt, enabled and C.teal or C.border)
    if activeAppearanceID == "legacy" then
        ClearOwnedBackdrop(toggle)
        local check = CreateFrame("CheckButton", nil, toggle, "MinimalCheckboxTemplate")
        check:SetPoint("CENTER")
        check:SetChecked(enabled)
        check:EnableMouse(false)
        return toggle
    end
    toggle.thumb = toggle:CreateTexture(nil, "OVERLAY"); toggle.thumb:SetSize(14, 14); toggle.thumb:SetColorTexture(unpack(enabled and C.teal or C.muted))
    toggle.thumb:SetPoint(enabled and "RIGHT" or "LEFT", enabled and -3 or 3, 0)
    return toggle
end

local function InspectorActionCard(parent, anchor, iconKind, title, enabled, callback)
    local card = Button(parent, "", 206, callback)
    card:SetHeight(70); card:GetFontString():Hide(); card:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -7)
    card.icon = DrawInspectorIcon(card, iconKind); card.icon:SetSize(34, 34); card.icon:SetPoint("LEFT", 8, 0)
    card.title = Text(card, "GameFontNormal", title, C.accent)
    card.title:SetPoint("TOPLEFT", 52, -12); card.title:SetPoint("RIGHT", -24, 0)
    card.title:SetJustifyH("LEFT"); card.title:SetWordWrap(false)
    card.state = Text(card, "GameFontHighlightSmall", enabled and "On" or "Off", enabled and C.teal or C.muted)
    card.state:SetPoint("TOPLEFT", 52, -39); card.state:SetWidth(20); card.state:SetJustifyH("LEFT")
    card.switch = InspectorSwitch(card, enabled); card.switch:SetPoint("LEFT", 78, activeAppearanceID == "legacy" and -10 or -12)
    card.arrow = CreateFrame("Frame", nil, card); card.arrow:SetSize(12, 12); card.arrow:SetPoint("RIGHT", -10, 0); DrawTriangle(card.arrow, "right")
    return card
end

-- The configurable-card Boolean: one button that flips between Yes and No.
-- Yes is the filled (selected) look, No the dark one, like the other switches.
-- The tooltip follows the current answer (SetTips).
local function BooleanChoice(parent)
    local choice = CreateFrame("Frame", nil, parent)
    choice:SetSize(44, 22)
    choice.button = Button(choice, "No", 44, function()
        if choice._onChange then choice._onChange(not choice.value) end
    end)
    choice.button:SetAllPoints()
    function choice:UpdateTooltip()
        local tips = self.tips
        if not tips then return end
        local title, body = unpack(self.value and tips.yes or tips.no)
        SetTooltip(self.button, title, body)
    end
    function choice:SetTips(yesTitle, yesBody, noTitle, noBody)
        self.tips = { yes = { yesTitle, yesBody }, no = { noTitle, noBody } }
        self:UpdateTooltip()
    end
    function choice:SetValue(value)
        self.value = value == true
        local button, on = self.button, self.value
        button._primary, button._selected, button._selectedColor = on, nil, nil
        button:GetFontString():SetText(on and "Yes" or "No")
        SetFallbackBackdrop(button, on and C.accent or C.cardAlt, C.border)
        button:GetFontString():SetTextColor(unpack(on and { 1, 1, 1, 1 } or C.muted))
        self:UpdateTooltip()
    end
    function choice:SetCallback(callback) self._onChange = callback end
    return choice
end

local function CloseButton(parent, callback)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(26, 26)
    -- Match Resonance: the close control is a raised corner element, not part
    -- of the panel border.  The extra level keeps thick Cinematic borders and
    -- nested header cards from painting over it.
    button:SetFrameLevel(parent:GetFrameLevel() + 20)
    Backdrop(button, C.cardAlt, C.border)
    local strokes = {}
    for index, angle in ipairs({ math.pi / 4, -math.pi / 4 }) do
        local stroke = button:CreateTexture(nil, "ARTWORK")
        stroke:SetTexture("Interface\\Buttons\\WHITE8X8")
        stroke:SetSize(2, 13)
        stroke:SetPoint("CENTER")
        stroke:SetRotation(angle)
        stroke:SetVertexColor(unpack(C.text))
        strokes[index] = stroke
    end
    local function Tint(color)
        for _, stroke in ipairs(strokes) do stroke:SetVertexColor(unpack(color)) end
    end
    button:SetScript("OnEnter", function(self)
        if not self._frameGambitEUI then
            self:SetBackdropColor(C.teal[1] * 0.17, C.teal[2] * 0.20, C.teal[3] * 0.20, 1)
            self:SetBackdropBorderColor(unpack(C.teal))
            Tint(C.teal)
        end
    end)
    button:SetScript("OnLeave", function(self)
        if not self._frameGambitEUI then
            self:SetBackdropColor(unpack(C.cardAlt))
            self:SetBackdropBorderColor(unpack(C.border))
            Tint(C.text)
        end
    end)
    button:SetScript("OnClick", callback or function() parent:Hide() end)
    SetTooltip(button, "Close", nil)
    ApplyEUIObject("close", button)
    return button
end

function ns:IsCinematicEditorTheme()
    local panel = self.Options
    return panel and self:IsCinematicActive() or false
end

function ns:ApplyEditorTheme(force)
    local cinematic = force
    if cinematic == nil then cinematic = self:IsCinematicEditorTheme() end
    -- Cinematic replaces the character-class accent throughout the editor so
    -- the profile cannot be mistaken for a normal profile at a glance.
    for index = 1, 4 do
        C.accent[index], C.blue[index], C.border[index], C.teal[index] =
            BASE_ACCENT[index], BASE_BLUE[index], BASE_BORDER[index], BASE_TEAL[index]
        if cinematic then
            C.accent[index], C.blue[index], C.teal[index] =
                CINEMATIC_ACCENT[index], CINEMATIC_ACCENT[index], CINEMATIC_ACCENT[index]
        end
    end
    for object, roles in pairs(themeObjects) do
        if roles.text and object.SetTextColor then pcall(object.SetTextColor, object, unpack(C.accent)) end
        if roles.tealText and object.SetTextColor then pcall(object.SetTextColor, object, unpack(C.teal)) end
        if roles.primaryText and object.SetTextColor then pcall(object.SetTextColor, object, unpack(C.text)) end
        if roles.primaryButtonText and object.SetTextColor then pcall(object.SetTextColor, object, unpack(C.selectedText or C.text)) end
        if roles.inputText and object.SetTextColor then pcall(object.SetTextColor, object, unpack(C.inputText or C.text)) end
        if roles.mutedText and object.SetTextColor then pcall(object.SetTextColor, object, unpack(C.muted)) end
        if not EUIOwnsVisual(object) and roles.background and object.SetBackdropColor then pcall(object.SetBackdropColor, object, unpack(C.accent)) end
        if not EUIOwnsVisual(object) and roles.tealBackground and object.SetBackdropColor then pcall(object.SetBackdropColor, object, unpack(C.teal)) end
        if not EUIOwnsVisual(object) and roles.windowBackground and object.SetBackdropColor then pcall(object.SetBackdropColor, object, unpack(C.window)) end
        if not EUIOwnsVisual(object) and roles.panelBackground and object.SetBackdropColor then pcall(object.SetBackdropColor, object, unpack(C.panel)) end
        if not EUIOwnsVisual(object) and roles.cardBackground and object.SetBackdropColor then pcall(object.SetBackdropColor, object, unpack(C.card)) end
        if not EUIOwnsVisual(object) and roles.insetBackground and object.SetBackdropColor then pcall(object.SetBackdropColor, object, unpack(C.cardAlt)) end
        if not EUIOwnsVisual(object) and roles.raisedBackground and object.SetBackdropColor then pcall(object.SetBackdropColor, object, unpack(C.raised)) end
        if not EUIOwnsVisual(object) and roles.blueSoftBackground and object.SetBackdropColor then pcall(object.SetBackdropColor, object, unpack(C.blueSoft)) end
        if not EUIOwnsVisual(object) and roles.accentBorder and object.SetBackdropBorderColor then pcall(object.SetBackdropBorderColor, object, unpack(C.accent)) end
        if not EUIOwnsVisual(object) and roles.tealBorder and object.SetBackdropBorderColor then pcall(object.SetBackdropBorderColor, object, unpack(C.teal)) end
        if roles.accentTexture and object.SetColorTexture then pcall(object.SetColorTexture, object, unpack(C.accent)) end
        if roles.tealTexture and object.SetColorTexture then pcall(object.SetColorTexture, object, unpack(C.teal)) end
        if roles.borderVertex and object.SetVertexColor then pcall(object.SetVertexColor, object, unpack(C.border)) end
        if roles.mutedVertex and object.SetVertexColor then pcall(object.SetVertexColor, object, unpack(C.muted)) end
        if not EUIOwnsVisual(object) and roles.border and object.SetBackdropBorderColor then pcall(object.SetBackdropBorderColor, object, unpack(C.border)) end
        if not EUIOwnsVisual(object) and roles.requirementButton then StyleRequirementButton(object, false) end
    end
    -- Repaint after the mode accent and tracked fonts, not before them.
    for object, state in pairs(bundledSkinState) do
        if state.button then BundledButton(object) end
    end
    local panel = self.Options
    if panel then
        -- The outer boundary is the persistent Cinematic editing cue. Give it
        -- enough weight to read at a glance without recoloring every control.
        if euiSkin then
            -- The bundled shell owns both the backdrop texture and its atlas
            -- border. Replacing its Backdrop descriptor here would erase the
            -- suite artwork and Adventure Map treatment on every refresh.
            ClearShellBackdrop(panel)
        else
            panel:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = cinematic and 4 or 1,
            })
            panel:SetBackdropColor(unpack(C.window))
            panel:SetBackdropBorderColor(unpack(cinematic and CINEMATIC_BORDER or BASE_BORDER))
        end
    end
    if panel and panel.header and not EUIOwnsVisual(panel.header) then
        panel.header:SetBackdropColor(unpack(NORMAL_HEADER))
    end
    if panel and panel.cinematic then
        -- Off-state: this is a normal editor action with an amber name, not a
        -- second amber panel.  Active-state: it becomes the clear Cinematic
        -- editing identity marker while the scene controls live below.
        panel.cinematic._selected = cinematic
        panel.cinematic._selectedColor = cinematic and CINEMATIC_BUTTON or nil
        SetFallbackBackdrop(panel.cinematic, cinematic and CINEMATIC_BUTTON or C.cardAlt,
            cinematic and CINEMATIC_ACCENT or C.border)
        panel.cinematic:GetFontString():SetText(cinematic and "Exit Cinematic" or "Edit Cinematic")
        panel.cinematic:GetFontString():SetTextColor(unpack(CINEMATIC_ACCENT))
    end
    if panel and panel.subtitle then
        panel.subtitle:SetText(cinematic and "Editing Cinematic" or "")
        panel.subtitle:SetTextColor(unpack(cinematic and CINEMATIC_ACCENT or C.muted))
    end
    if ns.LegacySkin then ns.LegacySkin:RefreshDetails(activeAppearanceID == "legacy") end
end

local NORMAL_LIVE_STATE_FILL = { 0.05, 0.18, 0.17, 1 }

local function LiveStateFill()
    return ns:IsCinematicEditorTheme() and CINEMATIC_BUTTON or ActiveAppearance().selected or NORMAL_LIVE_STATE_FILL
end

local function LocalActiveReactionIndex(state)
    if not state or not state.reaction or state.inheritedFrom or not state.index or state.index < 1 then return nil end
    return state.index
end

local function SetReactionRowLiveState(row, isActive, isEnabled)
    row:SetAlpha(isEnabled and 1 or 0.42)
    local activeInk = ns:IsCinematicEditorTheme() and CINEMATIC_ACCENT or ActiveAppearance().selectedText
    row.handle.label:SetTextColor(unpack(isActive and activeInk or C.muted))
    row:SetBackdropColor(unpack(isActive and LiveStateFill() or C.cardAlt))
    -- Every configured, enabled Gambit reads as an active card in the same
    -- way a BindCards card does. The currently matching row still receives its
    -- stronger live fill; disabled rows alone recede to the neutral border.
    row:SetBackdropBorderColor(unpack(isEnabled and C.accent or C.border))
    row.label:SetTextColor(unpack(isActive and activeInk or C.text))
    if ns.LegacySkin then ns.LegacySkin:Row(row, isActive) end
end

local function ClearChildren(frame)
    if not frame._rows then return end
    for _, child in ipairs(frame._rows) do child:Hide() end
    wipe(frame._rows)
end

local function Percent(value)
    return ("%d%%"):format(math.floor((value or 0) * 100 + 0.5))
end

local function Seconds(value)
    value = math.floor((tonumber(value) or 0) * 100 + 0.5) / 100
    if value % 1 == 0 then return string.format("%ds", value) end
    if (value * 10) % 1 == 0 then return string.format("%.1fs", value) end
    return string.format("%.2fs", value)
end

local function ShortText(value, limit)
    value = tostring(value or "")
    if #value <= limit then return value end
    return value:sub(1, math.max(1, limit - 3)) .. "..."
end

local function NormalizedDuration(value)
    value = math.max(0.5, math.min(30, tonumber(value) or 3))
    return math.floor(value * 4 + 0.5) / 4
end

-- Experimental size and position line. Cards stay exactly as before until
-- their small toggle opens this second line.
local LAYOUT_CARD_HEIGHT = 70

local function DrawLayoutMark(control)
    if control.GetFontString and control:GetFontString() then control:GetFontString():SetText("") end
    control.layoutMarks = control.layoutMarks or {}
    -- A small frame inside a larger outline: "resize".
    local specs = {
        { 12, 1, 0, 5.5 }, { 12, 1, 0, -5.5 }, { 1, 12, -5.5, 0 }, { 1, 12, 5.5, 0 },
        { 5, 5, -3, -3 },
    }
    for index, spec in ipairs(specs) do
        local mark = control.layoutMarks[index]
        if not mark then
            mark = control:CreateTexture(nil, "OVERLAY")
            mark:SetTexture("Interface\\Buttons\\WHITE8X8")
            control.layoutMarks[index] = mark
            control["LayoutMark" .. index] = mark
        end
        mark:ClearAllPoints(); mark:SetSize(spec[1], spec[2]); mark:SetPoint("CENTER", spec[3], spec[4]); mark:Show()
    end
    -- Ellesmere's button skin keeps these when it repaints the button.
    control._frameGambitEUIKeepKeys = { "LayoutMark1", "LayoutMark2", "LayoutMark3", "LayoutMark4", "LayoutMark5" }
end

-- On/off switches look like the frame list: off is a dark row with muted
-- text (like an unmanaged frame), on is the accent-filled selected row with
-- white text (like the chosen frame).
local function SetLayoutToggleState(button, on)
    button._primary, button._selected, button._selectedColor = on and true or false, nil, nil
    SetFallbackBackdrop(button, on and C.accent or C.cardAlt, C.border)
    local ink = on and { 1, 1, 1, 1 } or C.muted
    for _, mark in ipairs(button.layoutMarks or {}) do mark:SetVertexColor(unpack(ink)) end
end

local function SetLayoutChoiceState(button, selected)
    button._primary, button._selected, button._selectedColor = selected and true or false, nil, nil
    SetFallbackBackdrop(button, selected and C.accent or C.cardAlt, C.border)
    button:GetFontString():SetTextColor(unpack(selected and { 1, 1, 1, 1 } or C.muted))
end


-- Live winner treatment for Size / Position: the same fill as the winning card.
local function SetLayoutLiveState(button, active)
    if not button or not button:IsShown() then return end
    if button._liveActive == (active and true or false) then return end
    button._liveActive = active and true or false
    button._selected, button._selectedColor = active and true or false, active and LiveStateFill() or nil
    SetFallbackBackdrop(button, active and LiveStateFill() or C.raised, active and C.teal or C.border)
end

-- Sizes read as a scale factor (x0.75, x1.25) so they are never mistaken for
-- an opacity percentage.
local function ScaleText(scale)
    local text = string.format("%.2f", math.floor((scale or 1) * 100 + 0.5) / 100):gsub("0+$", ""):gsub("%.$", "")
    return "x" .. text
end

local function LayoutSizeText(scale, isRest)
    if scale == nil or (isRest and math.abs(scale - 1) < 0.001) then return isRest and "Normal size" or "Size" end
    return ScaleText(scale)
end

local function LayoutPositionText(x, y, isRest)
    if x == nil then return isRest and "Normal place" or "Move" end
    if x == 0 and (y or 0) == 0 then return isRest and "Normal place" or "x 0" end
    local parts = {}
    if x ~= 0 then parts[#parts + 1] = "x " .. x end
    if (y or 0) ~= 0 then parts[#parts + 1] = "y " .. y end
    return table.concat(parts, ", ")
end

AddLayoutControls = function(row)
    row.layoutToggle = Button(row, "", REQUIREMENT_BUTTON_SIZE, nil)
    DrawLayoutMark(row.layoutToggle); row.layoutToggle:Hide()
    SetTooltip(row.layoutToggle, "Size and position",
        "Experimental. Protected frames: not in combat")
    row.position = Button(row, "", 108, nil); row.position:Hide()
    -- Anchored by ConfigureLayoutLine: beside the toggle, or on a second line.
    row.size = Button(row, "", 76, nil); row.size:SetPoint("RIGHT", row.position, "LEFT", -5, 0); row.size:Hide()
    -- Small "Instant" switch, first of the right-aligned group.
    row.instant = Button(row, "Instant", 46, nil)
    row.instant:SetPoint("RIGHT", row.size, "LEFT", -5, 0); row.instant:Hide()
    SetTooltip(row.instant, nil, nil)
end

-- Reaction rows are edited frequently.  Keep a small reusable set rather
-- than creating a new frame tree every time a value is nudged or reordered.

local function NewReactionRow(parent)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetSize(10, 39); Backdrop(row, C.cardAlt)
    -- Line one keeps the classic 39px card. The optional size and position
    -- line sits below it, so opening it never moves existing controls.
    row.line = CreateFrame("Frame", nil, row)
    row.line:SetPoint("TOPLEFT"); row.line:SetPoint("TOPRIGHT"); row.line:SetHeight(39); row.line:EnableMouse(false)
    row.handle = CreateFrame("Button", nil, row)
    row.handle:SetSize(24, 39); row.handle:SetPoint("LEFT", row.line, "LEFT", 0, 0); row.handle:RegisterForDrag("LeftButton")
    row.handle.label = Text(row.handle, "GameFontNormal", "::", C.muted); row.handle.label:SetPoint("CENTER")
    row.handle:SetScript("OnDragStart", function(self)
        if self._targetID and self._reaction and self._row then ns:StartReactionDrag(self._targetID, self._reaction, self._row) end
    end)
    row.handle:SetScript("OnDragStop", function() ns:FinishReactionDrag() end)
    row.handle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Reorder reaction", unpack(C.accent))
        GameTooltip:AddLine("First match wins", C.muted[1], C.muted[2], C.muted[3], true)
        GameTooltip:Show()
    end)
    row.handle:SetScript("OnLeave", GameTooltip_Hide)
    -- Order on the first line: handle, On, requirements "+", condition name.
    row.label = Text(row, "GameFontHighlight", "", C.accent)
    row.label:SetJustifyH("LEFT")
    -- One line: a long condition name is cut with "..." instead of wrapping
    -- or running under the buttons beside it.
    row.label:SetWordWrap(false)
    row.formPicker = Button(row, "", 132, nil); row.formPicker:Hide()
    row.formExpected = BooleanChoice(row); row.formExpected:SetPoint("LEFT", row.formPicker, "RIGHT", 5, 0); row.formExpected:Hide()
    SetTooltip(row.formPicker, nil, nil)
    row.formExpected:SetTips("Form is active", nil,
        "Form is inactive", nil)
    row.opacity = Button(row, "", 54, nil)
    row.opacity:RegisterForClicks("LeftButtonUp", "RightButtonUp"); row.opacity:SetPoint("RIGHT", row.line, "RIGHT", -87, 0)
    SetTooltip(row.opacity, "Opacity", nil)
    row.requirements = Button(row, "+", REQUIREMENT_BUTTON_SIZE, nil)
    TrackTheme(row.requirements, "requirementButton")
    StyleRequirementButton(row.requirements)
    row.requirements:HookScript("OnEnter", function(self) StyleRequirementButton(self, true) end)
    row.requirements:HookScript("OnLeave", function(self) StyleRequirementButton(self, false) end)
    SetRequirementButtonLabel(row.requirements, "+")
    SetTooltip(row.requirements, "Requirements", nil)
    -- Enable/disable is a row-level control, so it lives beside the drag
    -- handle rather than among the condition's value controls.
    row.enabled = Button(row, "On", 30, nil); row.enabled:SetPoint("LEFT", row.handle, "RIGHT", 5, 0)
    row.requirements:SetPoint("LEFT", row.enabled, "RIGHT", 5, 0)
    row.label:SetPoint("LEFT", row.requirements, "RIGHT", 6, 0)
    row.formPicker:SetPoint("LEFT", row.requirements, "RIGHT", 6, 0)
    SetTooltip(row.enabled, nil, nil)
    row.duration = Button(row, "", 40, nil); row.duration:SetPoint("RIGHT", row.opacity, "LEFT", -5); row.duration:Hide()
    SetTooltip(row.duration, "Duration", nil)
    row.up = Button(row, "", 22, nil); row.up:SetPoint("RIGHT", row.line, "RIGHT", -60, 0); DrawTriangle(row.up, "up")
    row.down = Button(row, "", 22, nil); row.down:SetPoint("RIGHT", row.line, "RIGHT", -34, 0); DrawTriangle(row.down, "down")
    row.remove = Button(row, "x", 22, nil); row.remove:SetPoint("RIGHT", row.line, "RIGHT", -8, 0)
    DrawRemoveMark(row.remove); SetFallbackBackdrop(row.remove, nil, REMOVE_RED)
    AddLayoutControls(row)
    return row
end

SetTooltip = function(frame, title, body)
    frame._tooltipTitle, frame._tooltipBody = title, body
end

local function ConditionLabel(condition)
    return (ns.CONDITION_INFO[condition] and ns.CONDITION_INFO[condition].label) or condition
end

local function ReactionLabel(reaction)
    if reaction and ns:IsPercentageCondition(reaction.condition) then
        local owner = reaction.condition:find("^party_") and "Party " or "Player "
        if owner == "Party " and reaction.partyMember then owner = "Party #" .. tostring(reaction.partyMember) .. " " end
        local resource = reaction.condition:find("health$") and "health " or "mana "
        return owner .. resource .. (reaction.percentageOperator or "<") .. tostring(reaction.percentageThreshold or 50) .. "%"
    end
    if reaction and reaction.condition == "chat_text" then
        local query = ns:NormalizeChatText(reaction.chatText)
        return query ~= "" and ("Chat: " .. query:gsub("|", "||")) or "Chat: no text"
    end
    if reaction and reaction.condition == "form" then
        local option = ns.FORM_BY_ID and ns.FORM_BY_ID[reaction.formKey]
        return "Form: " .. (option and option.label or "none")
    end
    if reaction and reaction.condition == "spec" then
        local option = ns.SPEC_BY_ID and ns.SPEC_BY_ID[reaction.specID]
        return "Build: " .. (option and option.label or "none")
    end
    return ConditionLabel(reaction and reaction.condition or "")
end

local function RequirementIndex(reaction, condition)
    for index, existing in ipairs(reaction.requirements or {}) do
        if existing == condition then return index end
    end
end

function ns:RefreshAppearanceControls()
    local panel = self.Options
    if not panel or not panel.appearance then return end
    local themeID = self:GetAppearanceTheme()
    panel.appearance:GetFontString():SetText("Appearance")
    for id, button in pairs(panel.appearanceChoices or {}) do
        local selected = id == themeID
        button._selected = selected
        button._selectedColor = selected and C.blueSoft or nil
        button:GetFontString():SetTextColor(unpack(selected and (C.selectedText or C.text) or C.text))
        button.appearanceIndicator:SetShown(selected)
        button.appearanceIndicator:SetColorTexture(unpack(C.accent))
        -- The bundled facade owns the button backdrop, so ask it to repaint
        -- after changing the selected state (including its one-pixel border).
        if euiSkin and euiSkin.Button then pcall(euiSkin.Button, button) end
    end

end

function ns:ApplyPanelLayout()
    local panel = self.Options
    if not panel then return end
    if panel.peeking then return end
    -- Never lower parent alpha: that would also wash out all child controls.
    BundledShell(panel, {})
    panel:EnableMouse(true)
    for _, card in ipairs({ panel.header, panel.targets, panel.center, panel.presence }) do
        card:EnableMouse(true)
    end
    self:FitWorkspaceCards()
    if self.LegacySkin then self.LegacySkin:Layout(panel, activeAppearanceID == "legacy") end
end

-- Pick on screen and Discover visible UI: equal widths whose visible edges line
-- up with the search box below (x 12 to 218). The Legacy button art sits about
-- 3 px inside the button, the search box art does not.
local function LayoutFrameListButtons(panel)
    local add, scan = panel.pickButton, panel.discoverButton
    if not add or not scan or not panel.targets then return end
    local inset = activeAppearanceID == "legacy" and 3 or 0
    local width = (206 - 8) / 2 + inset * 2
    add:ClearAllPoints(); add:SetPoint("TOPLEFT", panel.targets, "TOPLEFT", 12 - inset, -36); add:SetWidth(width)
    scan:ClearAllPoints(); scan:SetPoint("TOPRIGHT", panel.targets, "TOPLEFT", 218 + inset, -36); scan:SetWidth(width)
end

function ns:FitWorkspaceCards()
    local panel = self.Options
    if not panel or not panel.center or panel.peeking or panel._fittingWorkspaceCards then return end
    LayoutFrameListButtons(panel)
    panel._fittingWorkspaceCards = true
    local center = panel.center
    center:ClearAllPoints()
    center:SetPoint("TOPLEFT", panel.targets, "TOPRIGHT", 10, 0)
    center:SetPoint("BOTTOMRIGHT", panel.presence, "BOTTOMLEFT", -10, 0)
    panel.presence:ClearAllPoints()
    panel.presence:SetPoint("TOPRIGHT", panel.header, "BOTTOMRIGHT", 0, -12)
    panel.presence:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -12, 12)
    panel._fittingWorkspaceCards = nil
end

function ns:CreateOptions()
    if self.Options then return end
    local panel = CreateFrame("Frame", "FrameGambitOptions", UIParent, "BackdropTemplate")
    -- The editor is deliberately spacious: choosing a target, ordering its
    -- rules, and defining its relationships are three different jobs.
    panel:SetSize(math.min(1180, UIParent:GetWidth() - 40), math.min(680, UIParent:GetHeight() - 40))
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("FULLSCREEN_DIALOG")
    panel:SetFrameLevel(500)
    panel:SetToplevel(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function()
        if activeAppearanceID == "legacy" then panel:StartMoving() end
    end)
    panel:SetScript("OnDragStop", function() panel:StopMovingOrSizing() end)
    panel:SetResizable(true)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    if panel.SetResizeBounds then panel:SetResizeBounds(math.min(900, UIParent:GetWidth() - 20), math.min(560, UIParent:GetHeight() - 20), UIParent:GetWidth() - 20, UIParent:GetHeight() - 20) end
    Backdrop(panel, C.window, C.border)
    ApplyEUIObject("shell", panel, {})
    panel:Hide()
    self.Options = panel

    -- Keep the frame being edited visible in context without changing its
    -- alpha, mouse handling, or ownership. FULLSCREEN stays below this
    -- FULLSCREEN_DIALOG options panel, so the marker never paints over the UI.
    local selectionOutline = CreateFrame("Frame", "FrameGambitSelectionOutline", UIParent, "BackdropTemplate")
    selectionOutline:SetFrameStrata("FULLSCREEN"); selectionOutline:SetFrameLevel(850)
    selectionOutline:EnableMouse(false); selectionOutline:Hide()
    Backdrop(selectionOutline, { 0, 0, 0, 0 }, C.teal)
    selectionOutline.elapsed = 0
    selectionOutline._ticker = function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed >= 0.10 then self.elapsed = 0; ns:RefreshSelectionOutline() end
    end
    self.SelectionOutline = selectionOutline
    panel.selectionOutlineEnabled = true

    local peekBar = CreateFrame("Button", "FrameGambitPeekBar", UIParent, "BackdropTemplate")
    peekBar:SetSize(360, 38); peekBar:SetPoint("TOP", UIParent, "TOP", 0, -22)
    peekBar:SetFrameStrata("FULLSCREEN_DIALOG"); peekBar:SetFrameLevel(520)
    peekBar:EnableMouse(true); peekBar:RegisterForClicks("LeftButtonUp"); peekBar:Hide()
    Backdrop(peekBar, C.panel, C.teal)
    ApplyEUIObject("panel", peekBar)
    peekBar.label = Text(peekBar, "GameFontHighlightSmall", "", C.teal)
    peekBar.label:SetPoint("LEFT", 12, 0); peekBar.label:SetPoint("RIGHT", -112, 0)
    peekBar.label:SetJustifyH("LEFT"); peekBar.label:SetWordWrap(false)
    peekBar.returnText = Text(peekBar, "GameFontNormal", "Return to editor", C.accent)
    peekBar.returnText:SetPoint("RIGHT", -12, 0)
    peekBar:SetScript("OnEnter", function()
        if not EUIOwnsVisual(peekBar) then peekBar:SetBackdropBorderColor(unpack(C.accent)) end
    end)
    peekBar:SetScript("OnLeave", function()
        if not EUIOwnsVisual(peekBar) then peekBar:SetBackdropBorderColor(unpack(C.teal)) end
    end)
    peekBar:SetScript("OnClick", function() ns:ExitEditorPeek() end)
    self.PeekBar = peekBar

    local header = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    header:SetPoint("TOPLEFT", 12, -12); header:SetPoint("TOPRIGHT", -12, -12); header:SetHeight(74)
    Backdrop(header, NORMAL_HEADER, C.accent); panel.header = header
    header._legacyHeader = true
    ApplyEUIObject("panel", header)
    header:EnableMouse(true); header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() panel:StartMoving() end)
    header:SetScript("OnDragStop", function() panel:StopMovingOrSizing() end)
    local icon = header:CreateTexture(nil, "ARTWORK")
    icon:SetSize(42, 42); icon:SetPoint("TOPLEFT", 13, -14); icon:SetTexture(self.ICON_TEXTURE)
    local title = Text(header, "GameFontNormalLarge", "Frame Gambit", C.accent)
    panel.legacyTitle, panel.legacyIcon = title, icon
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -1)
    local subtitle = Text(header, "GameFontHighlightSmall", "", C.muted)
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    panel.subtitle = subtitle
    local version = Text(header, "GameFontHighlightSmall", "v" .. self.VERSION .. "  |  Forever Beta", C.teal)
    version:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -10, 9)
    panel.version = version
    local creator = Text(header, "GameFontHighlightSmall", "by Mimezu", C.muted)
    creator:Hide()
    local profile = Button(header, "Profile: Default", 150, function()
        ns:OpenProfilePicker()
    end)
    profile:SetPoint("TOPRIGHT", header, "TOPRIGHT", -154, -18); profile:GetFontString():SetText(""); profile:GetFontString():Hide()
    profile.arrow = CreateFrame("Frame", nil, profile)
    profile.arrow:SetSize(14, 10); profile.arrow:SetPoint("RIGHT", -8, 0); profile.arrow:EnableMouse(false)
    DrawTriangle(profile.arrow, "down")
    profile.label = Text(profile, "GameFontNormalSmall", "Profile: Default", C.accent)
    profile.label:SetPoint("LEFT", 8, 0); profile.label:SetPoint("RIGHT", profile.arrow, "LEFT", -2, 0); profile.label:SetJustifyH("CENTER"); profile.label:SetWordWrap(false)
    panel.profile = profile
    local cinematic = Button(header, "Edit Cinematic", 144, function()
        local ok, reason = ns:ToggleCinematic(true)
        if not ok then ns:ShowEditorNotice(reason or "Cinematic failed", "amber") end
        ns:RenderOptions()
    end)
    cinematic._cinematicAccent = true
    cinematic:SetPoint("TOPRIGHT", header, "TOPRIGHT", -58, -18); panel.cinematic = cinematic
    SetTooltip(cinematic, nil, nil)
    local peek = Button(header, "Preview", 76, function() ns:EnterEditorPeek() end)
    peek:SetPoint("RIGHT", profile, "LEFT", -7, 0)
    SetTooltip(peek, nil, nil)
    panel.peek = peek
    local helpButton = Button(header, "?  Help", 72, function()
        if ns.ToggleHelp then ns:ToggleHelp() elseif ns.OpenHelp then ns:OpenHelp() end
    end)
    helpButton:SetPoint("RIGHT", peek, "LEFT", -7, 0)
    SetTooltip(helpButton, nil, nil)
    panel.helpButton = helpButton
    local appearancePicker
    local appearance = Button(header, "Appearance", 104, function()
        appearancePicker:SetShown(not appearancePicker:IsShown())
    end)
    appearance:SetPoint("RIGHT", helpButton, "LEFT", -7, 0)
    -- Hairline between the view action (Preview) and the utilities.
    panel.headerDivider = header:CreateTexture(nil, "ARTWORK")
    panel.headerDivider:SetTexture("Interface\\Buttons\\WHITE8X8"); panel.headerDivider:SetVertexColor(unpack(C.border)); TrackTheme(panel.headerDivider, "borderVertex")
    SetTooltip(appearance, nil, nil)
    panel.appearance = appearance
    subtitle:SetPoint("RIGHT", appearance, "LEFT", -10, 0)
    subtitle:SetWordWrap(false)
    if subtitle.SetMaxLines then subtitle:SetMaxLines(1) end
    local function UpdateHeaderComposition()
        -- At the narrow resize breakpoint the descriptive sentence becomes a
        -- weak, floating fifth column. The identity and action cluster are
        -- clearer without it; the sentence returns automatically when space
        -- is available again.
        subtitle:SetShown(panel:GetWidth() >= 1080)
    end
    panel:HookScript("OnSizeChanged", UpdateHeaderComposition)
    C_Timer.After(0, UpdateHeaderComposition)
    local helpDot = helpButton:CreateTexture(nil, "OVERLAY")
    helpDot:SetSize(5, 5); helpDot:SetPoint("TOPRIGHT", -3, -3); SetTealTexture(helpDot); helpDot:Hide()
    helpButton.helpDot = helpDot
    if self.HasUnreadHelp then helpDot:SetShown(self:HasUnreadHelp()) end
    appearancePicker = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    -- Six compact rows mirror BindCards' appearance menu. Keep this above
    -- the editor content, but below every modal blocker/prompt (578+).
    appearancePicker:SetSize(252, 236)
    appearancePicker:SetPoint("TOP", appearance, "BOTTOM", 0, -6)
    appearancePicker:SetFrameStrata("FULLSCREEN_DIALOG")
    appearancePicker:SetFrameLevel(panel:GetFrameLevel() + 55)
    appearancePicker:SetClampedToScreen(true)
    appearancePicker:EnableMouse(true)
    appearancePicker:EnableKeyboard(true)
    Backdrop(appearancePicker, C.cardAlt, C.border)
    ApplyEUIObject("panel", appearancePicker, { inset = true })
    appearancePicker:Hide()
    panel.appearancePicker = appearancePicker
    panel.appearanceChoices = {}
    local appearanceOptions = {
        { "eui",  "Ellesmere", 70, 10, -25 }, { "mimezu", "Mimezu", 68, 86, -25 },
        { "luminous", "Luminous", 78, 160, -25 }, { "charcoal", "Charcoal", 70, 10, -53 },
        { "chalk", "Chalk", 68, 86, -53 }, { "tungsten", "Tungsten", 78, 160, -53 },
        { "editorial", "Editorial", 70, 10, -81 }, { "snes", "Super NES", 74, 86, -81 },
        { "famicom", "Famicom", 76, 166, -81 }, { "gamecube", "GameCube", 70, 10, -109 },
        { "genesis", "Genesis", 68, 86, -109 }, { "ps1", "PS1", 78, 160, -109 },
        { "ps2", "PS2", 70, 10, -137 }, { "xbox", "Xbox", 68, 86, -137 },
        { "xbox360", "Xbox 360", 78, 160, -137 }, { "violetmist", "Violet Mist", 100, 10, -165 },
        { "violetbloom", "Violet Bloom", 120, 116, -165 },
        { "legacy", "Blizzard Legacy", 228, 10, -193 },
    }
    for _, option in ipairs(appearanceOptions) do
        local themeID, label, width, x, y = option[1], option[2], option[3], option[4], option[5]
        local choice = Button(appearancePicker, label, width, function()
            ns:SetAppearanceTheme(themeID)
            end)
        choice:SetHeight(22); choice:SetFrameLevel(appearancePicker:GetFrameLevel() + 1)
        choice:SetPoint("TOPLEFT", x, y)
        local indicator = choice:CreateTexture(nil, "OVERLAY")
        indicator:SetPoint("BOTTOMLEFT", 4, 2); indicator:SetPoint("BOTTOMRIGHT", -4, 2); indicator:SetHeight(2)
        choice.appearanceIndicator = indicator
        panel.appearanceChoices[themeID] = choice
    end
    appearancePicker:SetScript("OnKeyDown", function(self, key)
        -- Protected in combat; the picker can still be open when a fight starts.
        if self.SetPropagateKeyboardInput and not InCombatLockdown() then self:SetPropagateKeyboardInput(key ~= "ESCAPE") end
        if key == "ESCAPE" then appearancePicker:Hide() end
    end)
    local function UpdateAppearancePickerScale()
        local width = UIParent and UIParent.GetWidth and UIParent:GetWidth()
        if issecretvalue and issecretvalue(width) then return end
        if type(width) ~= "number" or width <= 0 then return end
        local height = UIParent:GetHeight()
        if issecretvalue and issecretvalue(height) then return end
        if type(height) ~= "number" or height <= 0 then return end
        appearancePicker:SetScale(math.max(0.50, math.min(1, (width - 20) / 252, (height - 20) / 236)))
    end
    appearancePicker:SetScript("OnShow", function()
        UpdateAppearancePickerScale()
        appearancePicker:Raise()
    end)
    if UIParent and UIParent.HookScript then UIParent:HookScript("OnSizeChanged", UpdateAppearancePickerScale) end
    panel:HookScript("OnHide", function() appearancePicker:Hide() end)
    self:RefreshAppearanceControls()
    local cinematicControls = CreateFrame("Frame", nil, header, "BackdropTemplate")
    cinematicControls._legacyHeader = true
    -- Two compact rows keep the camera composition readable without turning
    -- the editor header into a second settings page.
    cinematicControls:SetPoint("BOTTOMLEFT", 8, 8); cinematicControls:SetPoint("BOTTOMRIGHT", -8, 8); cinematicControls:SetHeight(64)
    Backdrop(cinematicControls, C.cardAlt, CINEMATIC_BORDER); cinematicControls:Hide(); panel.cinematicControls = cinematicControls
    ApplyEUIObject("panel", cinematicControls, { inset = true })
    cinematicControls.fovGroup = CreateFrame("Frame", nil, cinematicControls)
    cinematicControls.fovGroup:SetPoint("TOPLEFT", 8, -5); cinematicControls.fovGroup:SetPoint("RIGHT", cinematicControls, "CENTER", -6, 0); cinematicControls.fovGroup:SetHeight(24)
    cinematicControls.fovLabel = Text(cinematicControls.fovGroup, "GameFontHighlightSmall", "FOV 90°", C.muted)
    cinematicControls.fovLabel:SetPoint("LEFT", 0, 0); cinematicControls.fovLabel:SetWidth(68); cinematicControls.fovLabel:SetJustifyH("LEFT"); cinematicControls.fovLabel:SetWordWrap(false)
    cinematicControls.fovSlider = CreateFrame("Slider", nil, cinematicControls.fovGroup, "BackdropTemplate")
    cinematicControls.fovSlider:SetPoint("LEFT", cinematicControls.fovLabel, "RIGHT", 8, 0); cinematicControls.fovSlider:SetPoint("RIGHT", -2, 0)
    cinematicControls.fovSlider:SetHeight(9); cinematicControls.fovSlider:SetOrientation("HORIZONTAL")
    cinematicControls.fovSlider:SetMinMaxValues(40, 100); cinematicControls.fovSlider:SetValueStep(1); cinematicControls.fovSlider:SetObeyStepOnDrag(true)
    Backdrop(cinematicControls.fovSlider, C.card, C.border)
    local fovThumb = cinematicControls.fovSlider:CreateTexture(nil, "OVERLAY")
    fovThumb:SetSize(8, 15); fovThumb:SetColorTexture(unpack(CINEMATIC_ACCENT)); cinematicControls.fovSlider:SetThumbTexture(fovThumb)
    if ns.LegacySkin then ns.LegacySkin:Slider(cinematicControls.fovSlider) end
    cinematicControls.fovSlider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        cinematicControls.fovLabel:SetText("FOV " .. value .. "°")
        if not cinematicControls.fovApplying then
            local ok, actual = ns:SetCinematicFOV(value)
            if ok and actual and actual ~= value then
                cinematicControls.fovApplying = true
                cinematicControls.fovSlider:SetValue(actual)
                cinematicControls.fovApplying = nil
                cinematicControls.fovLabel:SetText("FOV " .. actual .. "°")
            end
        end
    end)
    SetTooltip(cinematicControls.fovSlider, "Cinematic FOV", nil)

    cinematicControls.letterboxGroup = CreateFrame("Frame", nil, cinematicControls)
    cinematicControls.letterboxGroup:SetPoint("TOPLEFT", cinematicControls, "TOP", 6, -5); cinematicControls.letterboxGroup:SetPoint("TOPRIGHT", -8, -5); cinematicControls.letterboxGroup:SetHeight(24)
    cinematicControls.letterboxLabel = Text(cinematicControls.letterboxGroup, "GameFontHighlightSmall", "Bars 4%", C.muted)
    cinematicControls.letterboxLabel:SetPoint("LEFT", 0, 0); cinematicControls.letterboxLabel:SetWidth(76)
    cinematicControls.letterboxLabel:SetJustifyH("LEFT"); cinematicControls.letterboxLabel:SetWordWrap(false)
    cinematicControls.letterboxToggle = Button(cinematicControls.letterboxGroup, "Off", 48, function()
        local enabled = ns:GetCinematicLetterboxSettings()
        ns:SetCinematicLetterboxEnabled(not enabled)
        ns:RenderOptions()
    end)
    cinematicControls.letterboxToggle:SetPoint("RIGHT", 0, 0)
    SetTooltip(cinematicControls.letterboxToggle, "Black bars", nil)
    cinematicControls.letterboxSlider = CreateFrame("Slider", nil, cinematicControls.letterboxGroup, "BackdropTemplate")
    cinematicControls.letterboxSlider:SetPoint("LEFT", cinematicControls.letterboxLabel, "RIGHT", 8, 0)
    cinematicControls.letterboxSlider:SetPoint("RIGHT", cinematicControls.letterboxToggle, "LEFT", -8, 0)
    cinematicControls.letterboxSlider:SetHeight(9); cinematicControls.letterboxSlider:SetOrientation("HORIZONTAL")
    cinematicControls.letterboxSlider:SetMinMaxValues(0, 0.25); cinematicControls.letterboxSlider:SetValueStep(0.01); cinematicControls.letterboxSlider:SetObeyStepOnDrag(true)
    Backdrop(cinematicControls.letterboxSlider, C.card, C.border)
    local letterboxThumb = cinematicControls.letterboxSlider:CreateTexture(nil, "OVERLAY")
    letterboxThumb:SetSize(8, 15); letterboxThumb:SetColorTexture(unpack(CINEMATIC_ACCENT)); cinematicControls.letterboxSlider:SetThumbTexture(letterboxThumb)
    if ns.LegacySkin then ns.LegacySkin:Slider(cinematicControls.letterboxSlider) end
    cinematicControls.letterboxSlider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value * 100 + 0.5) / 100
        cinematicControls.letterboxLabel:SetText("Bars " .. math.floor(value * 100 + 0.5) .. "%")
        if not cinematicControls.letterboxApplying then ns:SetCinematicLetterboxHeight(value) end
    end)

    cinematicControls.actionsGroup = CreateFrame("Frame", nil, cinematicControls)
    cinematicControls.actionsGroup:SetPoint("BOTTOMLEFT", 8, 5); cinematicControls.actionsGroup:SetPoint("BOTTOMRIGHT", -8, 5); cinematicControls.actionsGroup:SetHeight(24)
    cinematicControls.cameraDefaultGroup = CreateFrame("Frame", nil, cinematicControls.actionsGroup)
    cinematicControls.cameraDefaultGroup:SetPoint("LEFT", 0, 0); cinematicControls.cameraDefaultGroup:SetSize(190, 24)
    cinematicControls.cameraDefaultLabel = Text(cinematicControls.cameraDefaultGroup, "GameFontHighlightSmall", "Left on entry", C.muted)
    cinematicControls.cameraDefaultLabel:SetPoint("LEFT", 0, 0)
    cinematicControls.cameraDefaultToggle = Button(cinematicControls.cameraDefaultGroup, "Off", 58, function()
        local _, enabled = ns:GetCinematicCameraSettings()
        ns:SetCinematicCameraOffsetDefault(not enabled)
        ns:RenderOptions()
    end)
    cinematicControls.cameraDefaultToggle:SetPoint("RIGHT", 0, 0)
    SetTooltip(cinematicControls.cameraDefaultToggle, "Left camera on entry", nil)

    cinematicControls.modeShortcutGroup = CreateFrame("Frame", nil, cinematicControls.actionsGroup)
    cinematicControls.modeShortcutGroup:SetPoint("LEFT", cinematicControls.cameraDefaultGroup, "RIGHT", 12, 0); cinematicControls.modeShortcutGroup:SetPoint("RIGHT", cinematicControls.actionsGroup, "CENTER", -4, 0); cinematicControls.modeShortcutGroup:SetHeight(24)
    cinematicControls.shortcut = Button(cinematicControls.modeShortcutGroup, "Mode: Set", 180, function() ns:OpenCinematicKeyCapture() end)
    cinematicControls.shortcut:SetPoint("LEFT", 0, 0); cinematicControls.shortcut:SetPoint("RIGHT", -50, 0)
    SetTooltip(cinematicControls.shortcut, nil, nil)
    cinematicControls.clear = Button(cinematicControls.modeShortcutGroup, "Clear", 43, function()
        local ok, reason = ns:SetCinematicBinding(nil)
        if not ok then ns:ShowEditorNotice(reason or "Shortcut not cleared", "amber") end
        ns:RenderOptions()
    end)
    cinematicControls.clear:SetPoint("RIGHT", 0, 0)

    cinematicControls.cameraShortcutGroup = CreateFrame("Frame", nil, cinematicControls.actionsGroup)
    cinematicControls.cameraShortcutGroup:SetPoint("LEFT", cinematicControls.actionsGroup, "CENTER", 4, 0); cinematicControls.cameraShortcutGroup:SetPoint("RIGHT", 0, 0); cinematicControls.cameraShortcutGroup:SetHeight(24)
    cinematicControls.cameraShortcut = Button(cinematicControls.cameraShortcutGroup, "Camera: Set", 180, function() ns:OpenCinematicCameraKeyCapture() end)
    cinematicControls.cameraShortcut:SetPoint("LEFT", 0, 0); cinematicControls.cameraShortcut:SetPoint("RIGHT", -50, 0)
    SetTooltip(cinematicControls.cameraShortcut, nil, nil)
    cinematicControls.cameraClear = Button(cinematicControls.cameraShortcutGroup, "Clear", 43, function()
        local ok, reason = ns:SetCinematicCameraBinding(nil)
        if not ok then ns:ShowEditorNotice(reason or "Shortcut not cleared", "amber") end
        ns:RenderOptions()
    end)
    cinematicControls.cameraClear:SetPoint("RIGHT", 0, 0)
    local close = CloseButton(panel)
    panel.closeButton = close
    close:SetPoint("TOPRIGHT", -4, -4)

    local resizer = CreateFrame("Button", nil, panel)
    resizer:SetSize(22, 22); resizer:SetPoint("BOTTOMRIGHT", -3, 3)
    resizer:SetFrameLevel(panel:GetFrameLevel() + 20)
    local resizeTexture = resizer:CreateTexture(nil, "ARTWORK")
    resizeTexture:SetAllPoints(); resizeTexture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizer:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizer:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizer:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then panel:StartSizing("BOTTOMRIGHT") end end)
    resizer:SetScript("OnMouseUp", function() panel:StopMovingOrSizing() end)
    SetTooltip(resizer, "Resize", nil)

    local targets = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    targets:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -12); targets:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 12, 12); targets:SetWidth(230)
    Backdrop(targets, C.card)
    ApplyEUIObject("panel", targets, { inset = true })
    panel.targets = targets; targets._rows = {}
    local targetsTitle = Text(targets, "GameFontNormal", "Frames", C.teal); targetsTitle:SetPoint("TOPLEFT", 12, -11)
    local add = Button(targets, "Pick on screen", 96, function() ns:StartPicker() end)
    add:SetPoint("TOPLEFT", 12, -36)
    panel.pickButton = add
    local scan = Button(targets, "Discover visible UI", 102, function()
        if InCombatLockdown() then
            panel.active:SetText("Not in combat"); panel.active:SetTextColor(unpack(C.amber))
            return
        end
        local added, firstID = ns:DiscoverVisibleFrameRoots()
        if firstID then panel.selected = firstID end
        panel.active:SetText(added > 0 and (added .. " added") or "Nothing new")
        panel.active:SetTextColor(unpack(added > 0 and C.teal or C.muted))
        ns:RenderOptions()
    end)
    scan:SetPoint("TOPLEFT", add, "TOPRIGHT", 8, 0)
    panel.discoverButton = scan
    local filter = CreateFrame("EditBox", nil, targets, "BackdropTemplate")
    filter:SetSize(206, 22); filter:SetPoint("TOPLEFT", 12, -66); filter:SetAutoFocus(false); filter:SetFontObject(GameFontHighlightSmall)
    filter:SetTextInsets(28, 8, 0, 0); filter:SetTextColor(unpack(C.inputText)); TrackTheme(filter, "inputText"); Backdrop(filter, C.cardAlt, C.border)
    ApplyEUIObject("edit", filter)
    filter.searchIcon = filter:CreateTexture(nil, "ARTWORK")
    filter.searchIcon:SetTexture("Interface\\COMMON\\UI-Searchbox-Icon")
    filter.searchIcon:SetSize(14, 14); filter.searchIcon:SetPoint("LEFT", 8, 0); filter.searchIcon:SetVertexColor(unpack(C.muted))
    TrackTheme(filter.searchIcon, "mutedVertex")
    local filterHint = Text(filter, "GameFontHighlightSmall", "Search frames...", C.muted)
    filterHint:SetPoint("LEFT", 28, 0); filter.hint = filterHint
    filter:SetScript("OnEditFocusGained", function() filterHint:Hide() end)
    filter:SetScript("OnEditFocusLost", function() if filter:GetText() == "" then filterHint:Show() end end)
    filter:SetScript("OnTextChanged", function(self)
        if self:GetText() == "" and not self:HasFocus() then filterHint:Show() else filterHint:Hide() end
        panel.targetQuery = self:GetText():lower()
        ns:RenderTargetRail()
    end)
    panel.targetFilter = filter
    local targetScroll = CreateFrame("ScrollFrame", nil, targets, "UIPanelScrollFrameTemplate")
    targetScroll:SetPoint("TOPLEFT", 8, -97); targetScroll:SetPoint("BOTTOMRIGHT", -26, 8); panel.targetScroll = targetScroll
    local targetContent = CreateFrame("Frame", nil, targetScroll)
    targetContent:SetSize(1, 1); targetScroll:SetScrollChild(targetContent)
    local function FitTargetContent()
        -- Cards belong to the viewport, not beneath the separate scrollbar
        -- gutter. Keeping the scroll child exactly as wide as the viewport
        -- preserves every right-hand card border at every panel/UI scale.
        targetContent:SetWidth(math.max(1, targetScroll:GetWidth()))
    end
    targetScroll:HookScript("OnSizeChanged", FitTargetContent)
    C_Timer.After(0, FitTargetContent)
    targetScroll:EnableMouseWheel(true)
    targetScroll:SetScript("OnMouseWheel", function(self, delta)
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - delta * 45)))
    end)
    SkinScrollFrame(targetScroll)
    targetContent._rows = {}; panel.targetContent = targetContent

    local center = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    center:SetPoint("TOPLEFT", targets, "TOPRIGHT", 10, 0); center:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -252, 12)
    Backdrop(center, C.card); panel.center = center; center._rows = {}
    ApplyEUIObject("panel", center, { inset = true })
    local centerTitle = Text(center, "GameFontNormal", "Choose a frame", C.teal); centerTitle:SetPoint("TOPLEFT", 16, -13); panel.centerTitle = centerTitle
    local centerHint = Text(center, "GameFontHighlightSmall", "First match wins", C.muted)
    centerHint:SetPoint("TOPLEFT", centerTitle, "BOTTOMLEFT", 0, -3); panel.centerHint = centerHint
    local active = Text(center, "GameFontHighlightSmall", "", C.muted); active:SetPoint("TOPRIGHT", -14, -14); panel.active = active
    local notice = CreateFrame("Button", nil, center, "BackdropTemplate")
    notice:SetPoint("TOPLEFT", 14, -76); notice:SetPoint("TOPRIGHT", -29, -76); notice:SetHeight(34)
    notice:SetFrameLevel(center:GetFrameLevel() + 20); notice:RegisterForClicks("LeftButtonUp")
    Backdrop(notice, { 0.12, 0.085, 0.035, 0.98 }, C.amber)
    ApplyEUIObject("button", notice)
    notice.label = Text(notice, "GameFontHighlightSmall", "", C.amber)
    notice.label:SetPoint("LEFT", 10, 0); notice.label:SetPoint("RIGHT", -10, 0)
    notice.label:SetJustifyH("LEFT"); notice.label:SetWordWrap(true)
    if notice.label.SetMaxLines then notice.label:SetMaxLines(2) end
    notice:SetScript("OnClick", function(self) self:Hide() end)
    SetTooltip(notice, "Dismiss", nil)
    notice:Hide(); panel.notice = notice
    local reactionScroll = CreateFrame("ScrollFrame", nil, center, "UIPanelScrollFrameTemplate")
    reactionScroll:SetPoint("TOPLEFT", 14, -78); reactionScroll:SetPoint("BOTTOMRIGHT", -29, 44); panel.reactionScroll = reactionScroll
    local reactionContent = CreateFrame("Frame", nil, reactionScroll)
    reactionContent:SetSize(math.max(1, center:GetWidth() - 43), 1); reactionScroll:SetScrollChild(reactionContent)
    center:SetScript("OnSizeChanged", function(_, width)
        reactionContent:SetWidth(math.max(1, width - 43))
    end)
    reactionScroll:EnableMouseWheel(true)
    reactionScroll:SetScript("OnMouseWheel", function(self, delta)
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - delta * 45)))
    end)
    SkinScrollFrame(reactionScroll)
    reactionContent._rows = {}; panel.reactionContent = reactionContent
    panel.copyRules = Button(center, "Copy rules", 82, function()
        if not panel.selected then return end
        local ok, reason = ns:CopyTargetRules(panel.selected)
        panel.active:SetText(ok and "Rules copied" or reason); panel.active:SetTextColor(unpack(ok and C.teal or C.amber))
    end)
    panel.copyRules:SetPoint("TOPRIGHT", -29, -43)
    SetTooltip(panel.copyRules, nil, nil)
    panel.pasteRules = Button(center, "Paste rules", 82, function()
        if not panel.selected then return end
        local ok, reason = ns:PasteTargetRules(panel.selected)
        panel.active:SetText(ok and "Rules pasted" or reason); panel.active:SetTextColor(unpack(ok and C.teal or C.amber))
    end)
    panel.pasteRules:SetPoint("RIGHT", panel.copyRules, "LEFT", -7, 0)
    SetTooltip(panel.pasteRules, "Paste rules", "Replaces this frame's rules")

    local presence = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    presence:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -12); presence:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -12, 12); presence:SetWidth(230)
    Backdrop(presence, C.card); panel.presence = presence; presence._rows = {}
    ApplyEUIObject("panel", presence, { inset = true })
    presence.titleIcon = DrawInspectorIcon(presence, "transition"); presence.titleIcon:SetSize(30, 30); presence.titleIcon:SetPoint("TOPLEFT", 10, -6)
    local pTitle = Text(presence, "GameFontNormal", "Transition & relationships", C.accent)
    pTitle:SetPoint("LEFT", presence.titleIcon, "RIGHT", 2, 0); pTitle:SetPoint("RIGHT", -10, 0)
    pTitle:SetJustifyH("LEFT"); pTitle:SetWordWrap(false)
    panel.presenceContent = CreateFrame("Frame", nil, presence); panel.presenceContent:SetPoint("TOPLEFT", 12, -42); panel.presenceContent:SetPoint("BOTTOMRIGHT", -12, 78); panel.presenceContent._rows = {}

    center:ClearAllPoints(); center:SetPoint("TOPLEFT", targets, "TOPRIGHT", 10, 0); center:SetPoint("BOTTOMRIGHT", presence, "BOTTOMLEFT", -10, 0)

    local reset = Button(presence, "Reset frame", 98, function()
        if panel.selected then ns:RemoveTarget(panel.selected); panel.selected = nil; ns:RenderOptions() end
    end)
    reset:SetPoint("BOTTOMRIGHT", -12, 12)
    panel.resetTarget = reset
    local forget
    forget = Button(presence, "Remove from list", 108, function()
        local id = panel.selected
        if not id or not ns:CanForgetCustomTarget(id) then return end
        if panel.forgetArmed ~= id then
            panel.forgetArmed = id
            panel.forgetToken = (panel.forgetToken or 0) + 1
            local token = panel.forgetToken
            forget:GetFontString():SetText("Confirm remove")
            panel.active:SetText("Removes it from every profile")
            panel.active:SetTextColor(unpack(C.amber))
            C_Timer.After(4, function()
                if panel.forgetToken == token then
                    panel.forgetArmed = nil
                    forget:GetFontString():SetText("Remove from list")
                end
            end)
            return
        end
        panel.forgetArmed = nil
        panel.forgetToken = (panel.forgetToken or 0) + 1
        local ok, reason = ns:ForgetCustomTarget(id)
        forget:GetFontString():SetText("Remove from list")
        panel.active:SetText(reason or "")
        panel.active:SetTextColor(unpack(ok and C.teal or C.amber))
        ns:RenderOptions()
    end)
    forget:SetPoint("BOTTOMRIGHT", reset, "TOPRIGHT", 0, 6)
    SetTooltip(forget, "Remove from list", "Removes it from every profile")
    panel.forgetTarget = forget
    panel:SetScript("OnShow", function() ns:RenderOptions() end)
    panel:SetScript("OnHide", function()
        panel:StopMovingOrSizing()
        if panel.peeking then ns:ExitEditorPeek(true) end
        panel.forgetArmed = nil
        panel.forgetToken = (panel.forgetToken or 0) + 1
        forget:GetFontString():SetText("Remove from list")
        if panel.notice then panel.notice:Hide() end
        if ns.ReactionPalette and ns.ReactionPalette:IsShown() then ns.ReactionPalette:Hide() end
        if ns.ConnectionPicker and ns.ConnectionPicker:IsShown() then ns.ConnectionPicker:Hide() end
        if ns.OpacityPicker and ns.OpacityPicker:IsShown() then ns.OpacityPicker:Hide() end
        if ns.DurationPicker and ns.DurationPicker:IsShown() then ns.DurationPicker:Hide() end
        if ns.PercentagePicker and ns.PercentagePicker:IsShown() then ns.PercentagePicker:Hide() end
        if ns.TimingPicker and ns.TimingPicker:IsShown() then ns.TimingPicker:Hide() end
        if ns.ProfilePicker and ns.ProfilePicker:IsShown() then ns.ProfilePicker:Hide() end
        if ns.ProfileDeleteConfirm and ns.ProfileDeleteConfirm:IsShown() then ns.ProfileDeleteConfirm:Hide() end
        if ns.ProfileTransfer and ns.ProfileTransfer:IsShown() then ns.ProfileTransfer:Hide() end
        if ns.CinematicKeyCapture and ns.CinematicKeyCapture:IsShown() then ns.CinematicKeyCapture:Hide() end
        -- These are children of the panel: hidden with it, but still flagged
        -- shown, so they would come back with the next panel:Show().
        for _, key in ipairs({ "ChatTextPicker", "FormPicker", "SpecPicker", "LayoutSizePicker", "LayoutPositionPicker" }) do
            if ns[key] and ns[key]:IsShown() then ns[key]:Hide() end
        end
        if ns.CloseHelp then ns:CloseHelp() end
        if ns.CancelTutorial then ns:CancelTutorial("editor_closed") end
        if ns.SelectionOutline and not panel.peeking then ns:RefreshSelectionOutline() end
        ns:CancelTargetDrag(true)
        ns:CancelReactionDrag()
        if panel.peeking then ns:RefreshSelectionOutline() end
        if not panel.peeking then ns:ApplyEditorTheme(false) end
    end)
    table.insert(UISpecialFrames, panel:GetName())
    panel:HookScript("OnSizeChanged", function() ns:FitWorkspaceCards() end)
    reactionContent:HookScript("OnSizeChanged", function(_, _, height)
        if height ~= panel._workspaceReactionHeight then
            panel._workspaceReactionHeight = height
            ns:FitWorkspaceCards()
        end
    end)
    self:ApplyPanelLayout()
end

function ns:ToggleOptions()
    self:CreateOptions()
    if self.Options.peeking then
        self:ExitEditorPeek()
    elseif self.Options:IsVisible() then
        self.Options:Hide()
    else
        self.Options:Show()
    end
end

function ns:EnterEditorPeek()
    local panel, bar = self.Options, self.PeekBar
    if not panel or not panel:IsVisible() or not bar then return end
    if self.ReactionPalette and self.ReactionPalette:IsShown() then self.ReactionPalette:Hide() end
    if self.ConnectionPicker and self.ConnectionPicker:IsShown() then self.ConnectionPicker:Hide() end
    if self.OpacityPicker and self.OpacityPicker:IsShown() then self.OpacityPicker:Hide() end
    if self.DurationPicker and self.DurationPicker:IsShown() then self.DurationPicker:Hide() end
    if self.TimingPicker and self.TimingPicker:IsShown() then self.TimingPicker:Hide() end
    if self.ProfilePicker and self.ProfilePicker:IsShown() then self.ProfilePicker:Hide() end
    if self.ProfileDeleteConfirm and self.ProfileDeleteConfirm:IsShown() then self.ProfileDeleteConfirm:Hide() end
    if self.ProfileTransfer and self.ProfileTransfer:IsShown() then self.ProfileTransfer:Hide() end
    if self.CinematicKeyCapture and self.CinematicKeyCapture:IsShown() then self.CinematicKeyCapture:Hide() end
    for _, key in ipairs({ "ChatTextPicker", "FormPicker", "SpecPicker", "LayoutSizePicker", "LayoutPositionPicker" }) do
        if self[key] and self[key]:IsShown() then self[key]:Hide() end
    end
    if self.CloseHelp then self:CloseHelp() end
    if self.CancelTutorial then self:CancelTutorial("preview") end
    self:CancelTargetDrag(true)
    self:CancelReactionDrag()
    panel.peeking = true
    panel.peekHoverID = nil
    local target = panel.selected and self.TargetByID[panel.selected]
    bar.label:SetText("Viewing: " .. (target and target.label or "game UI"))
    bar:Show()
    panel.peekChildVisibility = {}
    for _, child in ipairs({ panel:GetChildren() }) do
        if child ~= panel.targets then
            panel.peekChildVisibility[child] = child:IsShown()
            child:Hide()
        end
    end
    -- The bundled shell backdrop is made of direct texture regions rather than
    -- child frames. Hide those regions as well so Preview exposes the world,
    -- then restore their exact live alpha on return.
    panel.peekRegionAlpha = {}
    for index = 1, select("#", panel:GetRegions()) do
        local region = select(index, panel:GetRegions())
        if region and region.IsObjectType and region:IsObjectType("Texture") then
            panel.peekRegionAlpha[region] = region:GetAlpha()
            region:SetAlpha(0)
        end
    end
    panel:SetBackdropColor(0, 0, 0, 0)
    panel:SetBackdropBorderColor(0, 0, 0, 0)
    panel:EnableMouse(false)
    panel.targets:SetAlpha(0.30)
    panel.targets:Show()
    self:RefreshSelectionOutline()
end

function ns:ExitEditorPeek(skipShow)
    local panel = self.Options
    if not panel or not panel.peeking then return end
    panel.peeking = nil
    panel.peekHoverID = nil
    if self.PeekBar then self.PeekBar:Hide() end
    panel.targets:SetAlpha(1)
    for child, wasShown in pairs(panel.peekChildVisibility or {}) do child:SetShown(wasShown) end
    panel.peekChildVisibility = nil
    for region, alpha in pairs(panel.peekRegionAlpha or {}) do region:SetAlpha(alpha) end
    panel.peekRegionAlpha = nil
    panel:EnableMouse(true)
    self:ApplyEditorTheme()
    self:ApplyPanelLayout()
    if skipShow then return end
    if not panel:IsShown() then panel:Show() else self:RenderOptions() end
end

function ns:RefreshOptions()
    if self.Options and self.Options:IsVisible() then self:RenderOptions() end
end

local function BindingText(getter)
    local key = getter and getter(ns)
    if not key then return "Set shortcut" end
    -- Blizzard's abbreviated modifier text can read like a broken glyph
    -- beside punctuation keys (for example s-`). Spell out the modifiers.
    if key:find("SHIFT%-") or key:find("CTRL%-") or key:find("ALT%-") then
        return key:gsub("SHIFT%-", "Shift + "):gsub("CTRL%-", "Ctrl + "):gsub("ALT%-", "Alt + ")
    end
    return (GetBindingText and GetBindingText(key, "KEY_") or key) or key
end

local function CinematicBindingText()
    return BindingText(ns.GetCinematicBinding)
end

local function CinematicCameraBindingText()
    return BindingText(ns.GetCinematicCameraBinding)
end

local function CinematicKeyChord(key)
    if key == "ESCAPE" or key == "LALT" or key == "RALT" or key == "LCTRL" or key == "RCTRL" or key == "LSHIFT" or key == "RSHIFT" then return nil end
    local prefix = ""
    if IsShiftKeyDown and IsShiftKeyDown() then prefix = prefix .. "SHIFT-" end
    if IsControlKeyDown and IsControlKeyDown() then prefix = prefix .. "CTRL-" end
    if IsAltKeyDown and IsAltKeyDown() then prefix = prefix .. "ALT-" end
    return prefix .. key
end

function ns:CreateCinematicKeyCapture()
    if self.CinematicKeyCapture then return end
    local blocker = CreateFrame("Button", nil, self.Options, "BackdropTemplate")
    blocker:SetAllPoints(self.Options); blocker:SetFrameLevel(610); blocker:EnableMouse(true); blocker:RegisterForClicks("AnyUp")
    blocker:SetScript("OnClick", function() if ns.CinematicKeyCapture then ns.CinematicKeyCapture:Hide() end end)
    Backdrop(blocker, { 0, 0, 0, 0.48 }, { 0, 0, 0, 0 }); blocker:Hide()
    local capture = CreateFrame("Frame", "FrameGambitCinematicKey", self.Options, "BackdropTemplate")
    capture:SetSize(330, 152); capture:SetFrameStrata("FULLSCREEN_DIALOG"); capture:SetFrameLevel(611); capture:EnableMouse(true); capture:EnableKeyboard(true)
    if capture.SetPropagateKeyboardInput then capture:SetPropagateKeyboardInput(false) end
    Backdrop(capture, C.panel, C.accent); capture:Hide(); capture.blocker = blocker; self.CinematicKeyCapture = capture
    ApplyEUIObject("panel", capture, { inset = true })
    table.insert(UISpecialFrames, capture:GetName())
    local title = Text(capture, "GameFontNormal", "Set Cinematic shortcut", C.accent); title:SetPoint("TOPLEFT", 14, -13); capture.title = title
    capture.copy = Text(capture, "GameFontHighlightSmall", "Press a key. Esc: cancel", C.muted)
    capture.copy:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6); capture.copy:SetPoint("RIGHT", -14, 0); capture.copy:SetJustifyH("LEFT"); capture.copy:SetWordWrap(true)
    capture.status = Text(capture, "GameFontHighlightSmall", "Waiting…", C.teal); capture.status:SetPoint("BOTTOMLEFT", 14, 16)
    local cancel = Button(capture, "Cancel", 70, function() capture:Hide() end); cancel:SetPoint("BOTTOMRIGHT", -12, 12)
    capture.use = Button(capture, "Use shortcut", 94, function()
        if capture.pending == nil then return end
        local setter = capture.bindingKind == "camera" and ns.SetCinematicCameraBinding or ns.SetCinematicBinding
        local ok, reason = setter(ns, capture.pending or nil)
        if ok then capture:Hide(); ns:RenderOptions() else capture.status:SetText(reason); capture.status:SetTextColor(unpack(C.amber)) end
    end, true); capture.use:SetPoint("RIGHT", cancel, "LEFT", -7, 0); capture.use:Hide(); capture.status:SetPoint("RIGHT", capture.use, "LEFT", -8, 0); capture.status:SetWordWrap(true)
    capture:SetScript("OnKeyDown", function(_, key)
        if key == "ESCAPE" then capture:Hide(); return end
        if key == "BACKSPACE" or key == "DELETE" then
            capture.pending = false; capture.use:GetFontString():SetText("Clear shortcut"); capture.use:Show()
            capture.status:SetText(capture.bindingKind == "camera" and "Clear the camera shortcut?" or "Clear the Cinematic shortcut?"); capture.status:SetTextColor(unpack(C.amber)); return
        end
        local chord = CinematicKeyChord(key)
        if not chord then return end
        capture.pending = chord; capture.use:GetFontString():SetText("Use shortcut"); capture.use:Show()
        local occupied = GetBindingAction and GetBindingAction(chord)
        local extra = occupied and occupied ~= "" and " Replaces " .. occupied or ""
        local display = (GetBindingText and GetBindingText(chord, "KEY_") or chord) or chord
        capture.status:SetText("Use " .. display .. "?" .. extra); capture.status:SetTextColor(unpack(occupied and C.amber or C.teal))
    end)
    capture:SetScript("OnHide", function()
        capture.blocker:Hide()
        if not InCombatLockdown() then capture:EnableKeyboard(false) end
        capture.pending = nil; capture.use:Hide()
    end)
end

function ns:ShowEditorNotice(message, tone, duration)
    self:HideAppearancePicker()
    local panel = self.Options
    if not panel or not panel.notice or not message or message == "" then return end
    local color = C[tone] or C.amber
    panel.noticeToken = (panel.noticeToken or 0) + 1
    local token = panel.noticeToken
    panel.notice.label:SetText(tostring(message))
    panel.notice.label:SetTextColor(unpack(color))
    SetFallbackBackdrop(panel.notice, nil, color)
    panel.notice:Show()
    if panel.reactionScroll then
        panel.reactionScroll:ClearAllPoints()
        panel.reactionScroll:SetPoint("TOPLEFT", 14, -120)
        panel.reactionScroll:SetPoint("BOTTOMRIGHT", -29, 44)
    end
    panel.notice:SetScript("OnHide", function()
        if panel.reactionScroll then
            panel.reactionScroll:ClearAllPoints()
            panel.reactionScroll:SetPoint("TOPLEFT", 14, -78)
            panel.reactionScroll:SetPoint("BOTTOMRIGHT", -29, 44)
        end
    end)
    C_Timer.After(duration or 8, function()
        if panel.noticeToken == token and panel.notice then panel.notice:Hide() end
    end)
end

local function OpenCinematicKeyCapture(self, kind)
    if InCombatLockdown() then
        self:ShowEditorNotice("Not in combat", "amber")
        return
    end
    self:CreateCinematicKeyCapture()
    local capture = self.CinematicKeyCapture
    capture.bindingKind = kind == "camera" and "camera" or "mode"
    capture.title:SetText(capture.bindingKind == "camera" and "Set camera shortcut" or "Set Cinematic shortcut")
    capture.status:SetText("Waiting…"); capture.status:SetTextColor(unpack(C.teal))
    capture:ClearAllPoints(); capture:SetPoint("CENTER", self.Options, "CENTER", 0, 0)
    self:HideAppearancePicker(); capture.blocker:Show(); capture:Show(); capture:EnableKeyboard(true)
end

function ns:OpenCinematicKeyCapture()
    OpenCinematicKeyCapture(self, "mode")
end

function ns:OpenCinematicCameraKeyCapture()
    OpenCinematicKeyCapture(self, "camera")
end

function ns:RefreshCinematicEditorControls()
    local panel = self.Options
    if not panel or not panel.header or not panel.cinematicControls then return end
    local active = self:IsCinematicActive()
    panel.cinematicControls:SetShown(active)
    if self.LegacySkin then self.LegacySkin:LayoutHeader(panel, activeAppearanceID == "legacy") end
    if not active then return end

    local controls = panel.cinematicControls
    controls.shortcut:GetFontString():SetText("Mode: " .. CinematicBindingText())
    controls.cameraShortcut:GetFontString():SetText("Camera: " .. CinematicCameraBindingText())
    local fov, offsetDefault = self:GetCinematicCameraSettings()
    controls.fovApplying = true
    controls.fovSlider:SetValue(fov)
    controls.fovApplying = nil
    controls.fovLabel:SetText("FOV " .. math.floor(fov + 0.5) .. "°")
    controls.cameraDefaultToggle:GetFontString():SetText(offsetDefault and "On" or "Off")
    controls.cameraDefaultToggle._selected = offsetDefault
    controls.cameraDefaultToggle._selectedColor = offsetDefault and CINEMATIC_BUTTON or nil
    SetFallbackBackdrop(controls.cameraDefaultToggle, offsetDefault and CINEMATIC_BUTTON or C.cardAlt,
        offsetDefault and CINEMATIC_ACCENT or C.border)
    controls.cameraDefaultToggle:GetFontString():SetTextColor(unpack(offsetDefault and CINEMATIC_ACCENT or C.muted))
    local enabled, height = self:GetCinematicLetterboxSettings()
    controls.letterboxApplying = true
    controls.letterboxSlider:SetValue(height)
    controls.letterboxApplying = nil
    controls.letterboxLabel:SetText("Bars " .. math.floor(height * 100 + 0.5) .. "%")
    controls.letterboxToggle:GetFontString():SetText(enabled and "On" or "Off")
    controls.letterboxToggle._selected = enabled
    controls.letterboxToggle._selectedColor = enabled and CINEMATIC_BUTTON or nil
    SetFallbackBackdrop(controls.letterboxToggle, enabled and CINEMATIC_BUTTON or C.cardAlt,
        enabled and CINEMATIC_ACCENT or C.border)
    controls.letterboxToggle:GetFontString():SetTextColor(unpack(enabled and CINEMATIC_ACCENT or C.muted))
end


function ns:CreateTargetDrag()
    if self.TargetDrag then return end
    local drag = CreateFrame("Frame", nil, self.Options)
    drag:SetAllPoints(self.Options); drag:SetFrameLevel(575); drag:EnableMouse(false); drag:Hide()
    local ghost = CreateFrame("Frame", nil, drag, "BackdropTemplate")
    ghost:SetHeight(22); ghost:EnableMouse(false); Backdrop(ghost, C.card, C.teal); ghost:Hide(); drag.ghost = ghost
    ghost.dot = ghost:CreateTexture(nil, "OVERLAY")
    ghost.dot:SetSize(5, 5); ghost.dot:SetPoint("LEFT", 7, 0)
    ghost.label = Text(ghost, "GameFontNormalSmall", "", C.accent)
    ghost.label:SetPoint("LEFT", 22, 0); ghost.label:SetPoint("RIGHT", -7, 0)
    ghost.label:SetJustifyH("LEFT"); ghost.label:SetWordWrap(false)
    if ghost.label.SetMaxLines then ghost.label:SetMaxLines(1) end
    drag._ticker = function() ns:UpdateTargetDrag() end
    self.TargetDrag = drag
end

function ns:UpdateTargetDragGhost(drag)
    local ghost, row = drag.ghost, drag.row
    if not ghost or not row then return end
    ghost:SetWidth(math.max(1, drag.rowWidth or row:GetWidth()))
    ghost.label:SetText(row:GetFontString() and row:GetFontString():GetText() or "")
    ghost.label:SetTextColor(unpack(drag.available and C.accent or C.muted))
    ghost.dot:SetColorTexture(unpack(drag.available and C.teal or C.amber))
end

function ns:StartTargetDrag(id, row, available)
    local panel = self.Options
    if not panel or not panel:IsVisible() or not row or not self:GetTargetSettings(id) then return end
    self:CreateTargetDrag()
    local drag = self.TargetDrag
    if drag.active then self:CancelTargetDrag(true) end
    drag.active, drag.targetID, drag.row = true, id, row
    drag.available, drag.rowAlpha, drag.rowWidth = available == true, row:GetAlpha(), row:GetWidth()
    local cursorX, cursorY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    cursorX, cursorY = cursorX / scale, cursorY / scale
    drag.grabX = cursorX - (row:GetLeft() or cursorX)
    drag.grabY = (row:GetTop() or cursorY) - cursorY
    panel.treeDragID, panel.treeDropID = id, nil
    -- Match reaction-card dragging: reserve the source row while a complete
    -- visual duplicate follows the cursor to the prospective parent.
    row:SetAlpha(0)
    self:UpdateTargetDragGhost(drag)
    drag:SetScript("OnUpdate", drag._ticker)
    drag:Show(); drag.ghost:Show(); self:UpdateTargetDrag()
    panel.active:SetText("Drop on its parent")
    panel.active:SetTextColor(unpack(C.teal))
end

function ns:UpdateTargetDrag()
    local drag, panel = self.TargetDrag, self.Options
    if not drag or not drag.active then return end
    if not panel or not panel:IsVisible() or not self:GetTargetSettings(drag.targetID) then
        self:CancelTargetDrag()
        return
    end
    local cursorX, cursorY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    cursorX, cursorY = cursorX / scale, cursorY / scale
    drag.ghost:ClearAllPoints()
    drag.ghost:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cursorX - drag.grabX, cursorY + drag.grabY)
end

function ns:CancelTargetDrag(skipRender)
    local drag, panel = self.TargetDrag, self.Options
    if not drag then return end
    local row = drag.row
    if row then row:SetAlpha(drag.rowAlpha or 1) end
    drag.active, drag.targetID, drag.row, drag.available = nil, nil, nil, nil
    drag.rowAlpha, drag.rowWidth, drag.grabX, drag.grabY = nil, nil, nil, nil
    drag:SetScript("OnUpdate", nil)
    drag.ghost:Hide(); drag:Hide()
    if panel then panel.treeDragID, panel.treeDropID = nil, nil end
    if not skipRender and panel and panel:IsVisible() then self:RenderTargetRail() end
end

function ns:FinishTargetDrag()
    local drag, panel = self.TargetDrag, self.Options
    if not drag or not drag.active or not panel then return end
    local childID, parentID = drag.targetID, panel.treeDropID
    self:CancelTargetDrag(true)
    if childID and parentID and childID ~= parentID then
        local ok, reason = self:AddVisibilityLink(parentID, childID)
        self:RenderOptions()
        panel.active:SetText(reason or (ok and "Linked" or "Link failed"))
        panel.active:SetTextColor(unpack(ok and C.teal or C.amber))
        return
    end
    self:RenderOptions()
end

function ns:CreateReactionDrag()
    if self.ReactionDrag then return end
    local drag = CreateFrame("Frame", nil, self.Options)
    drag:SetAllPoints(self.Options); drag:SetFrameLevel(575); drag:EnableMouse(false); drag:Hide()
    local ghost = CreateFrame("Frame", nil, drag, "BackdropTemplate")
    ghost:SetHeight(39); ghost:EnableMouse(false); Backdrop(ghost, C.card, C.teal); ghost:Hide(); drag.ghost = ghost
    ghost.handle = Text(ghost, "GameFontNormal", "::", C.muted); ghost.handle:SetPoint("LEFT", 8, 0)
    local function GhostControl(width)
        local control = CreateFrame("Frame", nil, ghost, "BackdropTemplate")
        control:SetSize(width, 22); control:EnableMouse(false); Backdrop(control, C.cardAlt, C.border)
        control.text = Text(control, "GameFontNormalSmall", "", C.accent); control.text:SetPoint("CENTER")
        return control
    end
    ghost.enabled = GhostControl(30); ghost.enabled:SetPoint("LEFT", 29, 0)
    ghost.opacity = GhostControl(54); ghost.opacity:SetPoint("RIGHT", -87, 0)
    ghost.requirements = GhostControl(REQUIREMENT_BUTTON_SIZE)
    ghost.requirements:SetPoint("LEFT", ghost.enabled, "RIGHT", 5, 0)
    TrackTheme(ghost.requirements, "requirementButton"); StyleRequirementButton(ghost.requirements)
    SetRequirementButtonLabel(ghost.requirements, "+")
    ghost.up = GhostControl(22); ghost.up:SetPoint("RIGHT", -60, 0); DrawTriangle(ghost.up, "up")
    ghost.down = GhostControl(22); ghost.down:SetPoint("RIGHT", -34, 0); DrawTriangle(ghost.down, "down")
    ghost.remove = GhostControl(22); ghost.remove:SetPoint("RIGHT", -8, 0); ghost.remove.text:SetText("x")
    DrawRemoveMark(ghost.remove); ghost.remove:SetBackdropBorderColor(unpack(REMOVE_RED))
    ghost.label = Text(ghost, "GameFontHighlight", "", C.accent)
    ghost.label:SetPoint("LEFT", ghost.requirements, "RIGHT", 6, 0); ghost.label:SetPoint("RIGHT", ghost.opacity, "LEFT", -5, 0)
    ghost.label:SetJustifyH("LEFT")
    drag._ticker = function() ns:UpdateReactionDrag() end
    self.ReactionDrag = drag
end

function ns:UpdateReactionDragGhost(drag)
    local ghost, row = drag.ghost, drag.row
    if not ghost or not row then return end
    local enabled = row.enabled and row.enabled:GetFontString():GetText() == "On"
    local label = row.label and row.label:IsShown() and row.label:GetText() or ""
    if label == "" and row.formPicker and row.formPicker:IsShown() then
        label = row.formPicker:GetFontString():GetText()
        if row.formExpected and row.formExpected:IsShown() then label = label .. " | " .. (row.formExpected.value and "Yes" or "No") end
    end
    ghost:SetWidth(math.max(1, drag.rowWidth or row:GetWidth()))
    ghost.enabled:SetBackdropColor(unpack(enabled and C.teal or C.cardAlt))
    ghost.enabled.text:SetText(enabled and "On" or "Off")
    ghost.enabled.text:SetTextColor(unpack(enabled and { 0.02, 0.06, 0.07, 1 } or C.muted))
    ghost.label:SetText(label)
    local requirementLabel = row.requirements and row.requirements:GetFontString():GetText()
    SetRequirementButtonLabel(ghost.requirements, requirementLabel ~= "" and requirementLabel or "+")
    ghost.opacity.text:SetText(row.opacity and row.opacity:GetFontString():GetText() or "")
    for _, stroke in ipairs(ghost.remove.removeStrokes or {}) do stroke:SetVertexColor(unpack(REMOVE_RED)) end
end

function ns:LayoutReactionDragRows(drag)
    local panel = self.Options
    local settings = self:GetTargetSettings(drag.targetID)
    if not panel or not settings then return end
    local rows, count = panel.reactionContent._reactionRows or {}, #settings.reactions
    local destination = drag.insertIndex or drag.sourceIndex
    if destination > drag.sourceIndex then destination = destination - 1 end
    destination = math.max(1, math.min(count, destination))

    -- Lay out every non-dragged row as the final order would read, leaving a
    -- card-sized gap for the visual row travelling under the cursor.
    local source, y = drag.sourceIndex, 0
    local nextOriginal = 1
    local gap = (drag.row and drag.row:GetHeight() or 39) + 6
    for displayIndex = 1, count do
        if displayIndex == destination then
            y = y + gap
        else
            while nextOriginal == source do nextOriginal = nextOriginal + 1 end
            local row = rows[nextOriginal]
            if row then
                row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -y); row:SetPoint("TOPRIGHT", 0, -y)
                row:Show()
            end
            nextOriginal, y = nextOriginal + 1, y + (row and row:GetHeight() or 39) + 6
        end
    end
end

function ns:StartReactionDrag(id, reaction, row)
    if not self.Options or not self.Options:IsVisible() then return end
    local settings = self:GetTargetSettings(id)
    if not settings then return end
    local sourceIndex
    for index, candidate in ipairs(settings.reactions) do
        if candidate == reaction then sourceIndex = index; break end
    end
    if not sourceIndex then return end
    self:CreateReactionDrag()
    local drag = self.ReactionDrag
    if drag.active then self:CancelReactionDrag() end
    drag.active, drag.targetID, drag.reaction, drag.row = true, id, reaction, row
    drag.sourceIndex, drag.insertIndex = sourceIndex, sourceIndex
    drag.rowAlpha = row:GetAlpha()
    local cursorX, cursorY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    cursorX, cursorY = cursorX / scale, cursorY / scale
    drag.grabX = cursorX - (row:GetLeft() or cursorX)
    drag.grabY = (row:GetTop() or cursorY) - cursorY
    drag.rowWidth = row:GetWidth()
    -- Keep WoW's original drag owner untouched. A full visual duplicate
    -- follows the cursor while the real row becomes the reserved empty slot.
    row:SetAlpha(0)
    self:UpdateReactionDragGhost(drag)
    drag:SetScript("OnUpdate", drag._ticker)
    drag:Show(); drag.ghost:Show(); self:LayoutReactionDragRows(drag); self:UpdateReactionDrag()
end

function ns:UpdateReactionDrag()
    local drag = self.ReactionDrag
    if not drag or not drag.active then return end
    local panel = self.Options
    local settings = self:GetTargetSettings(drag.targetID)
    if not panel or not panel:IsVisible() or not settings then self:CancelReactionDrag(); return end
    local rows, count = panel.reactionContent._reactionRows or {}, #settings.reactions
    local cursorX, cursorY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    cursorX, cursorY = cursorX / scale, cursorY / scale
    local ghost = drag.ghost
    if ghost then
        ghost:ClearAllPoints()
        ghost:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cursorX - drag.grabX, cursorY + drag.grabY)
    end
    local insertIndex = count + 1
    for index = 1, count do
        -- The source row follows the cursor and must not take part in the
        -- drop calculation.
        if index ~= drag.sourceIndex then
            local centerY
            if rows[index] then
                local _, value = rows[index]:GetCenter()
                centerY = value
            end
            if centerY and cursorY > centerY then insertIndex = index; break end
        end
    end
    if drag.insertIndex == insertIndex then return end
    drag.insertIndex = insertIndex
    self:LayoutReactionDragRows(drag)
end

function ns:CancelReactionDrag(skipRender)
    local drag = self.ReactionDrag
    if not drag then return end
    local targetID, row = drag.targetID, drag.row
    if row then row:SetAlpha(drag.rowAlpha or 1) end
    drag.active, drag.targetID, drag.reaction, drag.row = nil, nil, nil, nil
    drag.sourceIndex, drag.insertIndex = nil, nil
    drag.rowAlpha, drag.grabX, drag.grabY, drag.rowWidth = nil, nil, nil, nil
    drag:SetScript("OnUpdate", nil)
    drag.ghost:Hide(); drag:Hide()
    if not skipRender and targetID and self.Options and self.Options:IsVisible() and self.Options.selected == targetID then
        self:RenderSelectedTarget(targetID)
    end
end

function ns:FinishReactionDrag()
    local drag = self.ReactionDrag
    if not drag or not drag.active then return end
    local targetID, reaction, sourceIndex, insertIndex = drag.targetID, drag.reaction, drag.sourceIndex, drag.insertIndex
    self:CancelReactionDrag(true)
    local settings = self:GetTargetSettings(targetID)
    if not settings then return end
    for index, candidate in ipairs(settings.reactions) do
        if candidate == reaction then sourceIndex = index; break end
    end
    if not sourceIndex or not insertIndex then return end
    table.remove(settings.reactions, sourceIndex)
    if insertIndex > sourceIndex then insertIndex = insertIndex - 1 end
    insertIndex = math.max(1, math.min(#settings.reactions + 1, insertIndex))
    table.insert(settings.reactions, insertIndex, reaction)
    self:InvalidateTargetTransition(targetID)
    if self.Options and self.Options:IsVisible() and self.Options.selected == targetID then self:RenderSelectedTarget(targetID) end
end


function ns:CreateProfilePicker()
    if self.ProfilePicker then return end
    local blocker = CreateFrame("Button", nil, self.Options, "BackdropTemplate")
    blocker:SetAllPoints(self.Options); blocker:SetFrameLevel(590); blocker:EnableMouse(true); blocker:RegisterForClicks("AnyUp")
    blocker:SetScript("OnClick", function() if ns.ProfilePicker then ns.ProfilePicker:Hide() end end)
    Backdrop(blocker, { 0, 0, 0, 0.30 }, { 0, 0, 0, 0 }); blocker:Hide()
    local picker = CreateFrame("Frame", "FrameGambitProfiles", self.Options, "BackdropTemplate")
    picker:SetSize(382, 500); picker:SetFrameStrata("FULLSCREEN_DIALOG"); picker:SetFrameLevel(591); picker:EnableMouse(true)
    Backdrop(picker, C.panel, C.accent); picker:Hide(); picker.blocker = blocker; self.ProfilePicker = picker
    ApplyEUIObject("panel", picker, { inset = true })
    table.insert(UISpecialFrames, picker:GetName())
    picker.title = Text(picker, "GameFontNormal", "Profiles", C.accent); picker.title:SetPoint("TOPLEFT", 14, -13)
    picker.copy = Text(picker, "GameFontHighlightSmall", "", C.muted)
    picker.copy:SetPoint("TOPLEFT", 14, -39); picker.copy:SetPoint("TOPRIGHT", -14, -39)
    picker.copy:SetJustifyH("LEFT"); picker.copy:SetWordWrap(false)
    picker.export = Button(picker, "Export", 58, function() ns:OpenProfileTransfer("export") end); picker.export:SetPoint("TOPRIGHT", -43, -11)
    picker.import = Button(picker, "Import", 58, function() ns:OpenProfileTransfer("import") end); picker.import:SetPoint("RIGHT", picker.export, "LEFT", -5, 0)
    local close = CloseButton(picker); close:SetPoint("TOPRIGHT", -9, -9)
    picker.inputEnabled = Button(picker, "Profile by input: Off", 344, function()
        local settings = ns:GetInputModeProfileSettings()
        ns:SetInputModeProfilesEnabled(not settings.enabled)
        ns:RenderProfilePicker()
    end)
    picker.inputEnabled:SetPoint("TOPLEFT", 14, -63)
    local function CycleInputProfile(mode)
        local settings = ns:GetInputModeProfileSettings()
        local names = { false }
        for _, name in ipairs(ns:GetProfileNames()) do
            if not ns:IsCinematicProfileName(name) then names[#names + 1] = name end
        end
        local index = 1
        for i, name in ipairs(names) do if name == settings[mode] then index = i; break end end
        ns:SetInputModeProfile(mode, names[index % #names + 1] or nil)
        ns:RenderProfilePicker()
    end
    picker.inputGamepad = Button(picker, "", 344, function() CycleInputProfile("gamepad") end)
    picker.inputGamepad:SetPoint("TOPLEFT", 14, -93)
    picker.inputKeyboard = Button(picker, "", 344, function() CycleInputProfile("keyboard") end)
    picker.inputKeyboard:SetPoint("TOPLEFT", 14, -123)
    local inputHelp = Text(picker, "GameFontHighlightSmall",
        "", C.muted)
    inputHelp:SetPoint("TOPLEFT", 14, -153); inputHelp:SetPoint("TOPRIGHT", -14, -153)
    inputHelp:SetJustifyH("LEFT"); inputHelp:SetWordWrap(true)
    SetTooltip(picker.inputEnabled, nil, nil)
    SetTooltip(picker.inputGamepad, nil, nil)
    SetTooltip(picker.inputKeyboard, nil, nil)
    local scroll = CreateFrame("ScrollFrame", nil, picker, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -207); scroll:SetPoint("BOTTOMRIGHT", -29, 68); picker.scroll = scroll
    local content = CreateFrame("Frame", nil, scroll); content:SetSize(326, 1); scroll:SetScrollChild(content); content._rows = {}; picker.content = content
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - delta * 42)))
    end)
    SkinScrollFrame(scroll)
    picker.name = CreateFrame("EditBox", nil, picker, "BackdropTemplate")
    picker.name:SetSize(220, 22); picker.name:SetPoint("BOTTOMLEFT", 14, 18); picker.name:SetAutoFocus(false); picker.name:SetFontObject(GameFontHighlightSmall)
    picker.name:SetTextInsets(8, 8, 0, 0); Backdrop(picker.name, C.cardAlt, C.border); picker.name:SetTextColor(unpack(C.inputText)); TrackTheme(picker.name, "inputText")
    ApplyEUIObject("edit", picker.name)
    picker.create = Button(picker, "Create copy", 106, function()
        local ok, reason = ns:CreateProfile(picker.name:GetText())
        if ok then picker:Hide() else picker.status:SetText(reason); picker.status:SetTextColor(unpack(C.amber)) end
    end, true)
    picker.create:SetPoint("LEFT", picker.name, "RIGHT", 8, 0)
    picker.name:SetScript("OnEnterPressed", function() picker.create:Click() end)
    picker.name:SetScript("OnEscapePressed", function() picker.name:ClearFocus() end)
    picker.status = Text(picker, "GameFontHighlightSmall", "", C.muted); picker.status:SetPoint("BOTTOMLEFT", 14, 4); picker.status:SetPoint("RIGHT", -14, 4); picker.status:SetJustifyH("LEFT")
    picker:SetScript("OnHide", function()
        picker.blocker:Hide(); picker.name:ClearFocus(); picker.name:SetText("")
        if ns.ProfileDeleteConfirm and ns.ProfileDeleteConfirm:IsShown() then ns.ProfileDeleteConfirm:Hide() end
        if ns.ProfileTransfer and ns.ProfileTransfer:IsShown() then ns.ProfileTransfer:Hide() end
    end)
end

function ns:CreateProfileTransfer()
    if self.ProfileTransfer then return end
    local blocker = CreateFrame("Button", nil, self.Options, "BackdropTemplate")
    blocker:SetAllPoints(self.Options); blocker:SetFrameLevel(594); blocker:EnableMouse(true); blocker:RegisterForClicks("AnyUp")
    blocker:SetScript("OnClick", function() if ns.ProfileTransfer then ns.ProfileTransfer:Hide() end end)
    Backdrop(blocker, { 0, 0, 0, 0.46 }, { 0, 0, 0, 0 }); blocker:Hide()
    local transfer = CreateFrame("Frame", "FrameGambitProfileTransfer", self.Options, "BackdropTemplate")
    transfer:SetSize(520, 420); transfer:SetFrameStrata("FULLSCREEN_DIALOG"); transfer:SetFrameLevel(595); transfer:EnableMouse(true)
    Backdrop(transfer, C.panel, C.accent); transfer:Hide(); transfer.blocker = blocker; self.ProfileTransfer = transfer
    ApplyEUIObject("panel", transfer, { inset = true })
    table.insert(UISpecialFrames, transfer:GetName())
    transfer.title = Text(transfer, "GameFontNormal", "", C.accent); transfer.title:SetPoint("TOPLEFT", 14, -13)
    transfer.copy = Text(transfer, "GameFontHighlightSmall", "", C.muted); transfer.copy:SetPoint("TOPLEFT", transfer.title, "BOTTOMLEFT", 0, -3); transfer.copy:SetPoint("RIGHT", -48, 0)
    transfer.copy:SetJustifyH("LEFT"); transfer.copy:SetWordWrap(false)
    local close = CloseButton(transfer); close:SetPoint("TOPRIGHT", -9, -9)
    local textPanel = CreateFrame("Frame", nil, transfer, "BackdropTemplate")
    textPanel:SetPoint("TOPLEFT", 14, -60); textPanel:SetPoint("BOTTOMRIGHT", -14, 112)
    Backdrop(textPanel, C.cardAlt, C.border); transfer.textPanel = textPanel
    ApplyEUIObject("panel", textPanel, { inset = true })
    local textBox = CreateFrame("Frame", nil, textPanel, "ScrollingEditBoxTemplate")
    textBox:SetPoint("TOPLEFT", 7, -7); textBox:SetPoint("BOTTOMRIGHT", -7, 7)
    transfer.textBox = textBox
    transfer.text = textBox:GetEditBox()
    ApplyEUIObject("edit", transfer.text)
    transfer.text:SetAutoFocus(false); transfer.text:SetFontObject(ChatFontNormal); transfer.text:SetMaxLetters(60000)
    transfer.text:SetTextColor(unpack(C.inputText)); TrackTheme(transfer.text, "inputText")
    transfer.nameLabel = Text(transfer, "GameFontHighlightSmall", "New profile name", C.teal); transfer.nameLabel:SetPoint("BOTTOMLEFT", 14, 76)
    transfer.name = CreateFrame("EditBox", nil, transfer, "BackdropTemplate")
    transfer.name:SetSize(270, 24); transfer.name:SetPoint("BOTTOMLEFT", 14, 47); transfer.name:SetAutoFocus(false); transfer.name:SetFontObject(GameFontHighlightSmall)
    transfer.name:SetTextInsets(8, 8, 0, 0); transfer.name:SetTextColor(unpack(C.inputText)); TrackTheme(transfer.name, "inputText"); Backdrop(transfer.name, C.cardAlt, C.border)
    ApplyEUIObject("edit", transfer.name)
    transfer.status = Text(transfer, "GameFontHighlightSmall", "", C.muted); transfer.status:SetPoint("BOTTOMLEFT", 14, 17); transfer.status:SetPoint("RIGHT", -14, 17); transfer.status:SetJustifyH("LEFT"); transfer.status:SetWordWrap(false)
    transfer.action = Button(transfer, "", 150, nil, true); transfer.action:SetPoint("BOTTOMRIGHT", -14, 47)
    transfer.action:SetFrameLevel(transfer:GetFrameLevel() + 30); transfer.action:EnableMouse(true); transfer.action:RegisterForClicks("AnyUp")

    local function SetStatus(message, color)
        transfer.status:SetText(message or "")
        transfer.status:SetTextColor(unpack(color or C.muted))
    end
    transfer.SetStatus = SetStatus

    local validationToken = 0
    transfer.text:SetScript("OnTextChanged", function(self)
        if transfer.mode ~= "import" then return end
        validationToken = validationToken + 1
        local token = validationToken
        local value = self:GetText() or ""
        if value == "" then SetStatus("Paste a profile", C.muted); return end
        local called, profile, summary = pcall(ns.ParseProfileImport, ns, value)
        if not called then SetStatus("Validation error: " .. tostring(profile), C.amber)
        elseif profile then
            local note = summary.clipboardAdjusted and "" or ""
            local skippedCount = summary.skippedTargets or 0
            local skipped = skippedCount > 0 and (" " .. skippedCount .. " unavailable frame" .. (skippedCount == 1 and "" or "s") .. " skipped.") or ""
            SetStatus("Ready: " .. summary.targets .. " frames, " .. summary.reactions .. " reactions." .. skipped .. note, C.teal)
        else SetStatus(summary, C.amber) end
        C_Timer.After(0, function()
            if token ~= validationToken or not transfer:IsShown() then return end
            self:SetCursorPosition(0)
            local scrollBox = transfer.textBox and transfer.textBox:GetScrollBox()
            if scrollBox and scrollBox.ScrollToBegin then scrollBox:ScrollToBegin() end
        end)
    end)
    transfer.text:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    transfer.name:SetScript("OnEnterPressed", function()
        transfer.action:Click()
    end)
    transfer.name:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    transfer:SetScript("OnHide", function()
        local reopenPicker, resultMessage = transfer.returnToPicker, transfer.resultMessage
        transfer.blocker:Hide(); transfer.mode, transfer.returnToPicker, transfer.resultMessage = nil, nil, nil
        transfer.text:ClearFocus(); transfer.name:ClearFocus(); transfer.text:SetText(""); transfer.name:SetText("")
        if reopenPicker and ns.Options and ns.Options:IsShown() then
            C_Timer.After(0, function()
                if not ns.Options or not ns.Options:IsShown() then return end
                ns:OpenProfilePicker()
                if resultMessage and ns.ProfilePicker then
                    ns.ProfilePicker.status:SetText(resultMessage)
                    ns.ProfilePicker.status:SetTextColor(unpack(C.teal))
                end
            end)
        end
    end)
end

function ns:OpenProfileTransfer(mode)
    self:CreateProfileTransfer()
    local transfer = self.ProfileTransfer
    transfer.returnToPicker = self.ProfilePicker and self.ProfilePicker:IsShown() or false
    if transfer.returnToPicker then self.ProfilePicker:Hide() end
    transfer.mode, transfer.resultMessage = mode, nil
    transfer.name:ClearFocus(); transfer.text:ClearFocus(); transfer.text:SetText(""); transfer.name:SetText("")
    transfer.nameLabel:Hide(); transfer.name:Hide()
    transfer.action:Show()
    transfer:ClearAllPoints(); transfer:SetPoint("CENTER", self.Options, "CENTER", 0, 0)
    self:HideAppearancePicker(); transfer.blocker:Show(); transfer:Show()
    if mode == "export" then
        transfer.title:SetText("Export " .. ShortText(FrameGambitDB.profile, 24))
        transfer.copy:SetText("")
        transfer.action:GetFontString():SetText("Select all")
        transfer.action:SetScript("OnClick", function() transfer.text:SetFocus(); transfer.text:HighlightText() end)
        local text, reason = self:ExportProfile()
        if not text then
            transfer.SetStatus(reason, C.amber); transfer.action:Hide()
            return
        end
        transfer.text:SetText(text); transfer.text:SetFocus(); transfer.text:HighlightText()
        transfer.SetStatus("Ctrl+C to copy", C.teal)
    else
        transfer.title:SetText("Import profile")
        transfer.copy:SetText("")
        transfer.nameLabel:Show(); transfer.name:Show()
        local used = {}
        for _, profileName in ipairs(self:GetProfileNames()) do used[profileName:lower()] = true end
        local suggested, suffix = "Imported profile", 2
        while used[suggested:lower()] do suggested, suffix = "Imported profile " .. suffix, suffix + 1 end
        transfer.name:SetText(suggested); transfer.name:HighlightText()
        transfer.SetStatus("Paste a profile", C.muted)
        transfer.action:GetFontString():SetText("Import profile")
        transfer.action:SetScript("OnClick", function()
            local importedName = transfer.name:GetText()
            local called, ok, result = pcall(ns.ImportProfile, ns, importedName, transfer.text:GetText())
            if not called then
                transfer.SetStatus("Import error: " .. tostring(ok), C.amber)
                return
            end
            if ok then
                local skippedCount = result.skippedTargets or 0
                local skipped = skippedCount > 0 and ("; skipped " .. skippedCount .. " unavailable frame" .. (skippedCount == 1 and "" or "s")) or ""
                transfer.resultMessage = "Imported " .. importedName .. " (" .. result.targets .. " frames, " .. result.reactions .. " reactions" .. skipped .. ")"
                transfer:Hide()
            else
                transfer.SetStatus(result, C.amber)
            end
        end)
        transfer.text:SetFocus()
    end
end

function ns:CreateProfileDeleteConfirm()
    if self.ProfileDeleteConfirm then return end
    local blocker = CreateFrame("Button", nil, self.Options, "BackdropTemplate")
    blocker:SetAllPoints(self.Options); blocker:SetFrameLevel(592); blocker:EnableMouse(true); blocker:RegisterForClicks("AnyUp")
    blocker:SetScript("OnClick", function() if ns.ProfileDeleteConfirm then ns.ProfileDeleteConfirm:Hide() end end)
    Backdrop(blocker, { 0, 0, 0, 0.42 }, { 0, 0, 0, 0 }); blocker:Hide()
    local confirm = CreateFrame("Frame", "FrameGambitProfileDelete", self.Options, "BackdropTemplate")
    confirm:SetSize(326, 138); confirm:SetFrameStrata("FULLSCREEN_DIALOG"); confirm:SetFrameLevel(593); confirm:EnableMouse(true)
    Backdrop(confirm, C.panel, C.red); confirm:Hide(); confirm.blocker = blocker; self.ProfileDeleteConfirm = confirm
    ApplyEUIObject("panel", confirm, { inset = true })
    table.insert(UISpecialFrames, confirm:GetName())
    confirm.title = Text(confirm, "GameFontNormal", "Delete profile?", C.red); confirm.title:SetPoint("TOPLEFT", 14, -13)
    confirm.copy = Text(confirm, "GameFontHighlightSmall", "", C.muted); confirm.copy:SetPoint("TOPLEFT", confirm.title, "BOTTOMLEFT", 0, -7); confirm.copy:SetPoint("RIGHT", -14, 0); confirm.copy:SetJustifyH("LEFT"); confirm.copy:SetWordWrap(true)
    local cancel = Button(confirm, "Cancel", 72, function() confirm:Hide() end); cancel:SetPoint("BOTTOMRIGHT", -101, 12)
    confirm.delete = Button(confirm, "Delete", 76, function()
        local ok, reason = ns:DeleteProfile(confirm.profileName)
        confirm:Hide()
        if ns.ProfilePicker and ns.ProfilePicker:IsShown() then
            ns:RenderProfilePicker()
            ns.ProfilePicker.status:SetText(ok and (reason or "Deleted") or reason)
            ns.ProfilePicker.status:SetTextColor(unpack(ok and C.teal or C.amber))
        end
    end, true)
    confirm.delete:SetPoint("BOTTOMRIGHT", -14, 12)
    confirm:SetScript("OnHide", function() confirm.blocker:Hide(); confirm.profileName = nil end)
end

function ns:OpenProfileDeleteConfirm(name)
    self:CreateProfileDeleteConfirm()
    local confirm = self.ProfileDeleteConfirm
    confirm.profileName = name
    confirm.copy:SetText("Delete '" .. ShortText(name, 24) .. "'?")
    confirm:ClearAllPoints(); confirm:SetPoint("CENTER", self.Options, "CENTER", 0, 0)
    self:HideAppearancePicker(); confirm.blocker:Show(); confirm:Show()
end

function ns:RenderProfilePicker()
    local picker = self.ProfilePicker
    if not picker or not picker:IsShown() then return end
    local inputSettings = self:GetInputModeProfileSettings()
    picker.inputEnabled:GetFontString():SetText("Profile by input: " .. (inputSettings.enabled and "On" or "Off"))
    picker.inputGamepad:GetFontString():SetText("Gamepad: " .. (inputSettings.gamepad or "Keep current"))
    picker.inputKeyboard:GetFontString():SetText("Keyboard/mouse: " .. (inputSettings.keyboard or "Keep current"))
    ClearChildren(picker.content)
    picker.content._profileRows = picker.content._profileRows or {}
    local active = FrameGambitDB.profile
    local y = 0
    for index, name in ipairs(self:GetProfileNames()) do
        local profileName = name
        local row = picker.content._profileRows[index]
        if not row then
            row = Button(picker.content, "", 290, nil)
            row.delete = Button(picker.content, "x", 22, nil); row.delete:SetPoint("LEFT", row, "RIGHT", 8, 0)
            picker.content._profileRows[index] = row
        end
        local selected = profileName == active
        local systemCinematic = ns:IsCinematicProfileName(profileName)
        row:Show(); row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -y); row._primary = selected
        SetFallbackBackdrop(row, selected and C.accent or C.cardAlt)
        row:GetFontString():SetText((selected and "Active: " or "") .. profileName .. (systemCinematic and " (built-in)" or ""))
        row:GetFontString():SetTextColor(unpack(selected and { 1, 1, 1, 1 } or C.accent))
        row:SetScript("OnClick", function()
            local ok, reason = ns:SelectProfile(profileName)
            if ok then picker:Hide() else picker.status:SetText(reason); picker.status:SetTextColor(unpack(C.amber)) end
        end)
        row:SetEnabled(not systemCinematic); row:SetAlpha(systemCinematic and 0.58 or 1)
        if profileName == "Default" or systemCinematic then
            row.delete:Hide()
        else
            row.delete:Show(); row.delete:SetScript("OnClick", function()
                ns:OpenProfileDeleteConfirm(profileName)
            end)
        end
        picker.content._rows[#picker.content._rows + 1] = row
        if row.delete:IsShown() then picker.content._rows[#picker.content._rows + 1] = row.delete end
        y = y + 30
    end
    picker.content:SetHeight(math.max(1, y))
    picker.scroll:SetVerticalScroll(math.min(picker.scroll:GetVerticalScroll(), picker.scroll:GetVerticalScrollRange()))
end

function ns:OpenProfilePicker()
    self:CreateProfilePicker()
    local picker = self.ProfilePicker
    if self:IsCinematicActive() then
        picker.status:SetText("")
    else
        picker.status:SetText("")
    end
    picker.status:SetTextColor(unpack(C.muted))
    picker:ClearAllPoints(); picker:SetPoint("CENTER", self.Options, "CENTER", 0, 0)
    self:HideAppearancePicker(); picker.blocker:Show(); picker:Show(); self:RenderProfilePicker()
end

function ns:RefreshActiveState()
    local panel = self.Options
    if not panel or not panel.selected then return end
    local state = self.runtime.active[panel.selected]
    if not state then return end
    local activeIndex = LocalActiveReactionIndex(state)
    if panel.liveReactionTargetID ~= panel.selected or panel.liveReactionIndex ~= activeIndex then
        local settings = self:GetTargetSettings(panel.selected)
        local rows = panel.reactionContent and panel.reactionContent._reactionRows
        for index, reaction in ipairs(settings and settings.reactions or {}) do
            local row = rows and rows[index]
            if row and row:IsShown() then
                SetReactionRowLiveState(row, index == activeIndex, reaction.enabled ~= false)
            end
        end
        panel.liveReactionTargetID, panel.liveReactionIndex = panel.selected, activeIndex
    end
    self:RefreshLayoutLiveState()
    -- Runs on every evaluator tick while the editor is open: build the line,
    -- then write the font string only when it actually changed.
    local text, color
    if state.pendingRestore then
        text, color = "Restoring profile…", C.amber
    elseif state.unavailable then
        text, color = "Unavailable", C.amber
    elseif state.hostHidden then
        text, color = "Hidden by its addon", C.amber
    elseif ns.runtime.percentageCurveErrors and ns.runtime.percentageCurveErrors[panel.selected] then
        text, color = "Health/mana not in this client", C.amber
    elseif state.protectedPercentage then
        text, color = "Health/mana set by the game", C.teal
    elseif state.reaction then
        local count = #(state.reaction.requirements or {})
        local info = ns.CONDITION_INFO[state.reaction.condition]
        local momentDetail = ""
        if info and info.kind == "moment" then
            local started = ns.runtime.moments[state.reaction.condition]
            if state.reaction.condition == "chat_text" and ns.GetChatTextMatchTime then
                started = ns:GetChatTextMatchTime(state.reaction)
            end
            local duration = state.reaction.duration or info.duration or 3
            if started then momentDetail = " (" .. Seconds(math.max(0, duration - (GetTime() - started))) .. " left)" end
        end
        local inherited = state.inheritedFrom and ns.TargetByID[state.inheritedFrom]
        local prefix = inherited and ("Following " .. inherited.label .. ": ") or "Active now: "
        text = prefix .. ReactionLabel(state.reaction) .. (count > 0 and " + " .. count or "") .. momentDetail .. " -> " .. Percent(state.desired)
        color = C.teal
    else
        local inherited = state.inheritedFrom and ns.TargetByID[state.inheritedFrom]
        text = (inherited and ("Following " .. inherited.label .. ": Otherwise") or "Active now: Otherwise") .. " -> " .. Percent(state.desired)
        color = C.muted
    end
    local layoutNote = self:GetLayoutStatusNote(panel.selected)
    if layoutNote then
        text, color = text .. " - " .. layoutNote, C.amber
    end
    -- Compare with the live text, not a cache: Core writes this line too
    -- (profile switches, Cinematic toggles).
    if panel.active:GetText() ~= text or panel._activeColor ~= color then
        panel._activeColor = color
        panel.active:SetText(text)
        panel.active:SetTextColor(unpack(color))
    end
end

-- Category rows are painted from the live appearance tokens every time, so
-- light and dark themes both work. Legacy additionally gets the quest-log
-- title highlight, the stock Blizzard list-selection look.
local function PaintCategoryTab(tab)
    local selected, hover = tab._selected, tab._hover
    if selected then
        tab.fill:SetColorTexture(C.blueSoft[1], C.blueSoft[2], C.blueSoft[3], 1)
    elseif hover then
        tab.fill:SetColorTexture(C.raised[1], C.raised[2], C.raised[3], 0.85)
    else
        tab.fill:SetColorTexture(0, 0, 0, 0)
    end
    if activeAppearanceID == "legacy" and (selected or hover) then
        tab.glow:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
        tab.glow:SetBlendMode("ADD")
        tab.glow:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], selected and 0.45 or 0.22)
        tab.glow:Show()
    else
        tab.glow:Hide()
    end
    tab.indicator:SetColorTexture(unpack(C.accent)); tab.indicator:SetShown(selected and true or false)
    tab.divider:SetColorTexture(unpack(C.faint)); tab.divider:SetShown(not tab.isLast and not selected)
    tab:GetFontString():SetTextColor(unpack(selected and (C.selectedText or C.text) or hover and C.text or C.muted))
    tab:SetAlpha(tab._dimmed and 0.4 or 1)
end

function ns:CreateReactionPalette()
    if self.ReactionPalette then return end
    local blocker = CreateFrame("Button", nil, self.Options, "BackdropTemplate")
    blocker:SetAllPoints(self.Options); blocker:SetFrameLevel(578); blocker:EnableMouse(true); blocker:RegisterForClicks("AnyUp")
    blocker:SetScript("OnClick", function() end); Backdrop(blocker, { 0, 0, 0, 0.32 }, { 0, 0, 0, 0 }); blocker:Hide()
    local palette = CreateFrame("Frame", "FrameGambitReactionPalette", self.Options, "BackdropTemplate")
    -- Categories sit in a vertical sidebar on the left and the condition
    -- cards fill the pane to its right. The height is fitted to the taller
    -- of the two in LayoutReactionPalette, so no dead space is left below.
    palette:SetSize(532, 300); palette:SetFrameStrata("FULLSCREEN_DIALOG"); palette:SetFrameLevel(580)
    palette:EnableMouse(true); Backdrop(palette, C.panel, C.accent); palette:Hide(); palette.blocker = blocker; self.ReactionPalette = palette
    ApplyEUIObject("panel", palette, { inset = true })
    table.insert(UISpecialFrames, palette:GetName())
    palette.title = Text(palette, "GameFontNormal", "Add a reaction", C.accent); palette.title:SetPoint("TOPLEFT", 14, -13)
    palette.context = Text(palette, "GameFontHighlightSmall", "First match wins", C.muted); palette.context:SetPoint("TOPLEFT", palette.title, "BOTTOMLEFT", 0, -3)
    palette.context:SetPoint("RIGHT", -40, 0); palette.context:SetJustifyH("LEFT"); palette.context:SetWordWrap(true)
    local close = CloseButton(palette); close:SetPoint("TOPRIGHT", -9, -9)
    palette.done = Button(palette, "Done", 66, function() palette:Hide() end, true); palette.done:SetPoint("BOTTOMRIGHT", -12, 11); palette.done:Hide()
    palette:SetScript("OnHide", function()
        if palette.search then palette.search:ClearFocus() end
        palette.blocker:Hide()
        local targetID, refresh = palette.targetID, palette.mode == "requirements"
        palette.mode, palette.reaction = nil, nil
        if refresh and targetID and ns.Options and ns.Options:IsVisible() then ns:RenderSelectedTarget(targetID) end
    end)
    palette.tabs, palette.conditionButtons = {}, {}
    palette.categoryRail = CreateFrame("Frame", nil, palette, "BackdropTemplate")
    palette.categoryRail:SetPoint("TOPLEFT", palette.context, "BOTTOMLEFT", 0, -12)
    palette.categoryRail:SetSize(144, #self.CONDITION_CATEGORY_ORDER * 24 + 8)
    Backdrop(palette.categoryRail, C.cardAlt, C.border)
    ApplyEUIObject("panel", palette.categoryRail, { inset = true })
    local categoryCount = #self.CONDITION_CATEGORY_ORDER
    for index, category in ipairs(self.CONDITION_CATEGORY_ORDER) do
        local categoryID = category.id
        -- Categories are deliberately not skinned buttons: they read as a
        -- flat navigation list, so the bevelled condition cards on the right
        -- stay the only things that look "pressable into a rule".
        local tab = CreateFrame("Button", nil, palette.categoryRail)
        tab:SetSize(134, 22)
        tab:SetPoint("TOPLEFT", 5, -4 - (index - 1) * 24)
        tab.fill = tab:CreateTexture(nil, "BACKGROUND")
        tab.fill:SetAllPoints()
        tab.glow = tab:CreateTexture(nil, "BORDER")
        tab.glow:SetAllPoints()
        tab.divider = tab:CreateTexture(nil, "BORDER")
        tab.divider:SetPoint("BOTTOMLEFT", 8, -1); tab.divider:SetPoint("BOTTOMRIGHT", -8, -1); tab.divider:SetHeight(1)
        tab.isLast = index == categoryCount
        local label = Text(tab, "GameFontNormalSmall", category.label, C.muted)
        label:SetPoint("LEFT", 12, 0); label:SetPoint("RIGHT", -16, 0); label:SetJustifyH("LEFT")
        tab:SetFontString(label)
        -- Active category: a slim accent bar on the leading edge.
        tab.indicator = tab:CreateTexture(nil, "ARTWORK")
        tab.indicator:SetTexture("Interface\\Buttons\\WHITE8X8")
        tab.indicator:SetPoint("TOPLEFT", 0, 0); tab.indicator:SetPoint("BOTTOMLEFT", 0, 0); tab.indicator:SetWidth(3)
        -- A small teal dot is reserved for requirements already selected
        -- in this category. It is deliberately separate from the active-tab
        -- bar: one answers "where am I?", the other "where did I add
        -- something?".
        tab.requirementMarker = tab:CreateTexture(nil, "OVERLAY")
        tab.requirementMarker:SetTexture("Interface\\Buttons\\WHITE8X8")
        tab.requirementMarker:SetSize(6, 6); tab.requirementMarker:SetPoint("RIGHT", -6, 0)
        SetTealTexture(tab.requirementMarker); tab.requirementMarker:Hide()
        tab.categoryLabel = category.label
        tab:SetScript("OnClick", function()
            if palette.search:GetText() ~= "" then palette.query = ""; palette.search:SetText("") end
            ns:ShowReactionCategory(categoryID)
        end)
        tab:SetScript("OnEnter", function(self)
            self._hover = true; PaintCategoryTab(self)
            if self._tooltipTitle then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self._tooltipTitle, unpack(TOOLTIP_TITLE_COLOR))
                if self._tooltipBody then GameTooltip:AddLine(self._tooltipBody, TOOLTIP_BODY_COLOR[1], TOOLTIP_BODY_COLOR[2], TOOLTIP_BODY_COLOR[3], true) end
                GameTooltip:Show()
            end
        end)
        tab:SetScript("OnLeave", function(self)
            self._hover = false; PaintCategoryTab(self)
            GameTooltip_Hide()
        end)
        SetTooltip(tab, category.label, nil)
        PaintCategoryTab(tab)
        palette.tabs[category.id] = tab
    end
    palette.content = CreateFrame("Frame", nil, palette)
    palette.content:SetPoint("TOPLEFT", palette.categoryRail, "TOPRIGHT", 12, 0); palette.content:SetPoint("BOTTOMRIGHT", -14, 12)
    -- Search: type to filter every category at once, Enter picks the top
    -- result, Escape clears the text first and closes the palette second.
    local search = CreateFrame("EditBox", nil, palette.content, "BackdropTemplate")
    search:SetPoint("TOPLEFT", 0, 0); search:SetPoint("TOPRIGHT", 0, 0); search:SetHeight(22)
    search:SetAutoFocus(false); search:SetFontObject(GameFontHighlightSmall); search:SetMaxLetters(40)
    search:SetTextInsets(22, 96, 0, 0); search:SetTextColor(unpack(C.inputText)); TrackTheme(search, "inputText")
    Backdrop(search, C.cardAlt, C.border); ApplyEUIObject("edit", search)
    search.icon = search:CreateTexture(nil, "OVERLAY")
    search.icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon"); search.icon:SetSize(14, 14); search.icon:SetPoint("LEFT", 6, -1)
    search.icon:SetVertexColor(unpack(C.muted))
    search.hint = Text(search, "GameFontHighlightSmall", "Search", C.muted)
    search.hint:SetPoint("LEFT", 22, 0)
    search.clear = CreateFrame("Button", nil, search)
    search.clear:SetSize(18, 18); search.clear:SetPoint("RIGHT", -3, 0)
    search.clear.text = Text(search.clear, "GameFontNormalSmall", "x", C.muted); search.clear.text:SetPoint("CENTER", 0, 1)
    search.clear:SetScript("OnEnter", function(self) self.text:SetTextColor(unpack(C.text)) end)
    search.clear:SetScript("OnLeave", function(self) self.text:SetTextColor(unpack(C.muted)) end)
    search.clear:SetScript("OnClick", function() search:SetText(""); search:SetFocus() end)
    search.clear:Hide()
    palette.searchStatus = Text(search, "GameFontHighlightSmall", "", C.muted)
    palette.searchStatus:SetPoint("RIGHT", search.clear, "LEFT", -2, 0); palette.searchStatus:SetJustifyH("RIGHT")
    search:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(unpack(C.accent)) end)
    search:SetScript("OnEditFocusLost", function(self) self:SetBackdropBorderColor(unpack(C.border)) end)
    search:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        search.hint:SetShown(text == "")
        palette.query = text:lower():match("^%s*(.-)%s*$") or ""
        ns:ShowReactionCategory(palette.categoryID)
    end)
    search:SetScript("OnEnterPressed", function(self)
        local first = palette.query ~= "" and palette.visibleConditions and palette.visibleConditions[1]
        if first and first:IsEnabled() then first:Click() elseif palette.query == "" then self:ClearFocus() end
    end)
    search:SetScript("OnEscapePressed", function(self)
        if self:GetText() ~= "" then self:SetText("") else self:ClearFocus(); palette:Hide() end
    end)
    palette.search = search
    palette.empty = Text(palette.content, "GameFontHighlightSmall", "No matches", C.muted)
    palette.empty:SetPoint("TOP", search, "BOTTOM", 0, -24); palette.empty:Hide()
    for _, category in ipairs(self.CONDITION_CATEGORY_ORDER) do
        for key, info in pairs(self.CONDITION_INFO) do
            if info.category == category.id and not info.internal and not info.deprecated then
                local conditionKey, conditionInfo = key, info
                local button = Button(palette.content, info.label, 172, function()
                    local targetID = palette.targetID
                    local settings = targetID and ns:GetTargetSettings(targetID)
                    if palette.mode == "requirements" and palette.reaction then
                        local reaction = palette.reaction
                        reaction.requirements = reaction.requirements or {}
                        local requirementIndex = RequirementIndex(reaction, conditionKey)
                        if requirementIndex then
                            table.remove(reaction.requirements, requirementIndex)
                        elseif conditionKey ~= reaction.condition then
                            local conflict = ns:GetRequirementConflict(reaction, conditionKey)
                            if conflict then
                                palette.context:SetText("Conflicts with " .. ConditionLabel(conflict)); ns:LayoutReactionPalette()
                                return
                            end
                            if reaction.condition == "mouseover" and #reaction.requirements == 0
                                and ns:RequiresUnconditionalMouseover(targetID) and ns:CountUnconditionalMouseover(settings) <= 1 then
                                palette.context:SetText("Hover group needs a Mouseover row"); ns:LayoutReactionPalette()
                                return
                            end
                            reaction.requirements[#reaction.requirements + 1] = conditionKey
                        end
                        ns:InvalidateTargetTransition(targetID)
                        ns:ShowReactionCategory(palette.categoryID)
                    elseif settings then
                        if #settings.reactions >= ns.MAX_REACTIONS_PER_TARGET then
                            palette.context:SetText("Max " .. ns.MAX_REACTIONS_PER_TARGET .. " reactions"); ns:LayoutReactionPalette()
                            return
                        end
                        settings.reactions[#settings.reactions + 1] = {
                            id = ns:NextReactionID(), condition = conditionKey, opacity = 1,
                            duration = conditionInfo.duration, enabled = true,
                        }
                        local reaction = settings.reactions[#settings.reactions]
                        ns:InvalidateTargetTransition(targetID)
                        palette:Hide()
                        if ns:IsPercentageCondition(conditionKey) then
                            ns:OpenPercentagePicker(targetID, reaction)
                        elseif conditionKey == "chat_text" then
                            ns:OpenChatTextPicker(targetID, reaction)
                        elseif conditionKey == "form" then
                            ns:OpenFormPicker(targetID, reaction)
                        elseif conditionKey == "spec" then
                            ns:OpenSpecPicker(targetID, reaction)
                        else
                            ns:RenderSelectedTarget(targetID)
                        end
                        if ns.Tutorial and ns.RefreshTutorial then ns:RefreshTutorial() end
                    end
                end)
                local tooltipBody = conditionInfo.help
                SetTooltip(button, conditionInfo.label, tooltipBody)
                button.defaultTooltipTitle, button.defaultTooltipBody = conditionInfo.label, tooltipBody
                button.conditionKey, button.category = conditionKey, category.id
                palette.conditionButtons[#palette.conditionButtons + 1] = button
            end
        end
    end
end

function ns:OpenPercentagePicker(id, reaction)
    if not self.PercentagePicker then
        local blocker = CreateFrame("Button", nil, self.Options, "BackdropTemplate")
        blocker:SetAllPoints(self.Options); blocker:SetFrameLevel(588); blocker:EnableMouse(true)
        blocker:RegisterForClicks("AnyUp"); blocker:SetScript("OnClick", function() end)
        Backdrop(blocker, { 0, 0, 0, 0.32 }, { 0, 0, 0, 0 }); blocker:Hide()
        local picker = CreateFrame("Frame", "FrameGambitPercentagePicker", self.Options, "BackdropTemplate")
        picker:SetSize(430, 250); picker:SetFrameStrata("FULLSCREEN_DIALOG"); picker:SetFrameLevel(590)
        picker:EnableMouse(true); Backdrop(picker, C.panel, C.accent); picker:Hide()
        picker.blocker = blocker; self.PercentagePicker = picker
        ApplyEUIObject("panel", picker, { inset = true }); table.insert(UISpecialFrames, picker:GetName())
        picker.title = Text(picker, "GameFontNormal", "Percentage comparison", C.accent)
        picker.title:SetPoint("TOPLEFT", 14, -13)
        picker.context = Text(picker, "GameFontHighlightSmall", "", C.muted)
        picker.context:SetPoint("TOPLEFT", 14, -39); picker.context:SetPoint("RIGHT", -25, 0)
        picker.context:SetJustifyH("LEFT"); picker.context:SetWordWrap(true)
        local close = CloseButton(picker); close:SetPoint("TOPRIGHT", -9, -9)
        picker.buttons = {}
        local function RefreshComparison()
            for _, button in ipairs(picker.buttons) do
                button:GetFontString():SetText((picker.operator == button.operator and "> " or "") .. button.label)
            end
        end
        for index, option in ipairs(ns.PERCENTAGE_OPERATORS) do
            local operator, label = option.id, option.label
            local button = Button(picker, label, 128, function()
                picker.operator = operator; RefreshComparison()
            end)
            button:SetPoint("TOPLEFT", 14 + ((index - 1) % 3) * 136, -94 - math.floor((index - 1) / 3) * 31)
            button.operator, button.label = operator, label
            picker.buttons[#picker.buttons + 1] = button
        end
        picker.RefreshComparison = RefreshComparison
        local label = Text(picker, "GameFontHighlightSmall", "Threshold (%)", C.text)
        label:SetPoint("TOPLEFT", 14, -170)
        picker.input = CreateFrame("EditBox", nil, picker, "BackdropTemplate")
        picker.input:SetPoint("TOPLEFT", 122, -162); picker.input:SetSize(92, 28)
        picker.input:SetAutoFocus(false); picker.input:SetFontObject(GameFontHighlightSmall)
        picker.input:SetTextInsets(8, 8, 0, 0); picker.input:SetMaxLetters(12)
        Backdrop(picker.input, C.cardAlt, C.border); ApplyEUIObject("edit", picker.input)
        picker.input:SetTextColor(unpack(C.inputText)); TrackTheme(picker.input, "inputText")
        picker.memberLabel = Text(picker, "GameFontHighlightSmall", "Party member", C.text)
        picker.memberLabel:SetPoint("TOPLEFT", 14, -207)
        picker.memberButtons = {}
        local function RefreshMember()
            for _, button in ipairs(picker.memberButtons) do
                button:GetFontString():SetText((picker.partyMember == button.member and "> " or "") .. button.label)
            end
        end
        for index = 0, 5 do
            local member = index > 0 and index or nil
            local text = member and tostring(member) or "Any"
            local button = Button(picker, text, 60, function()
                picker.partyMember = member; RefreshMember()
            end)
            button:SetPoint("TOPLEFT", 14 + index * 67, -229)
            button.member, button.label = member, text
            picker.memberButtons[#picker.memberButtons + 1] = button
        end
        picker.RefreshMember = RefreshMember
        picker.error = Text(picker, "GameFontHighlightSmall", "", C.red)
        picker.error:SetPoint("BOTTOMLEFT", 14, 22)
        local save = Button(picker, "Save", 92, function()
            if not picker.reaction then return end
            local value = tonumber(picker.input:GetText())
            if not value or value ~= value or value < 0 or value > 100 then
                picker.error:SetText("0 to 100"); return
            end
            local settings = ns:GetTargetSettings(picker.targetID)
            local stillPresent = false
            for _, current in ipairs(settings and settings.reactions or {}) do
                if current == picker.reaction then stillPresent = true; break end
            end
            if not stillPresent then picker:Hide(); return end
            picker.reaction.percentageOperator, picker.reaction.percentageThreshold = picker.operator, value
            picker.reaction.partyMember = picker.isParty and picker.partyMember or nil
            ns:InvalidateTargetTransition(picker.targetID); picker:Hide()
        end, true)
        save:SetPoint("BOTTOMRIGHT", -14, 14)
        picker.input:SetScript("OnEnterPressed", function() save:Click() end)
        picker.input:SetScript("OnEscapePressed", function() picker:Hide() end)
        picker:SetScript("OnHide", function()
            picker.input:ClearFocus(); picker.blocker:Hide()
            local targetID = picker.targetID
            picker.targetID, picker.reaction = nil, nil
            if targetID and ns.Options and ns.Options:IsVisible() then ns:RenderSelectedTarget(targetID) end
        end)
    end
    local normalized = { condition = reaction.condition, percentageOperator = reaction.percentageOperator,
        percentageThreshold = reaction.percentageThreshold, partyMember = reaction.partyMember }
    self:NormalizePercentageReaction(normalized)
    local picker = self.PercentagePicker
    picker.targetID, picker.reaction, picker.operator = id, reaction, normalized.percentageOperator
    picker.isParty = reaction.condition == "party_health" or reaction.condition == "party_mana"
    picker.partyMember = normalized.partyMember
    picker:SetHeight(picker.isParty and 310 or 250)
    picker.memberLabel:SetShown(picker.isParty)
    for _, button in ipairs(picker.memberButtons) do button:SetShown(picker.isParty) end
    picker.RefreshMember()
    picker.context:SetText((picker.isParty
        and "Any: other members. 1-5: frame slots"
        or self.CONDITION_INFO[reaction.condition].help) or "")
    picker.input:SetText(tostring(normalized.percentageThreshold)); picker.error:SetText("")
    picker.RefreshComparison()
    picker:ClearAllPoints(); picker:SetPoint("CENTER", self.Options, "CENTER", 0, 0)
    self:HideAppearancePicker(); picker.blocker:Show(); picker:Show()
    picker.input:SetFocus(); picker.input:HighlightText()
end

function ns:OpenChatTextPicker(id, reaction)
    if not self.ChatTextPicker then
        local blocker = CreateFrame("Button", nil, self.Options, "BackdropTemplate")
        blocker:SetAllPoints(self.Options); blocker:SetFrameLevel(588); blocker:EnableMouse(true)
        blocker:RegisterForClicks("AnyUp"); blocker:SetScript("OnClick", function() end)
        Backdrop(blocker, { 0, 0, 0, 0.32 }, { 0, 0, 0, 0 }); blocker:Hide()
        local picker = CreateFrame("Frame", "FrameGambitChatTextPicker", self.Options, "BackdropTemplate")
        picker:SetSize(430, 195); picker:SetFrameStrata("FULLSCREEN_DIALOG"); picker:SetFrameLevel(590)
        picker:EnableMouse(true); Backdrop(picker, C.panel, C.accent); picker:Hide()
        picker.blocker = blocker; self.ChatTextPicker = picker
        ApplyEUIObject("panel", picker, { inset = true }); table.insert(UISpecialFrames, picker:GetName())
        picker.title = Text(picker, "GameFontNormal", "Chat contains text", C.accent)
        picker.title:SetPoint("TOPLEFT", 14, -13)
        picker.context = Text(picker, "GameFontHighlightSmall", "Any case", C.muted)
        picker.context:SetPoint("TOPLEFT", 14, -39); picker.context:SetPoint("RIGHT", -25, 0)
        picker.context:SetJustifyH("LEFT"); picker.context:SetWordWrap(true)
        local close = CloseButton(picker); close:SetPoint("TOPRIGHT", -9, -9)
        picker.input = CreateFrame("EditBox", nil, picker, "BackdropTemplate")
        picker.input:SetPoint("TOPLEFT", 14, -91); picker.input:SetSize(402, 28)
        picker.input:SetAutoFocus(false); picker.input:SetFontObject(GameFontHighlightSmall)
        picker.input:SetTextInsets(8, 8, 0, 0); picker.input:SetMaxLetters(120)
        Backdrop(picker.input, C.cardAlt, C.border); ApplyEUIObject("edit", picker.input)
        picker.input:SetTextColor(unpack(C.inputText)); TrackTheme(picker.input, "inputText")
        local save = Button(picker, "Save text", 112, function()
            if not picker.reaction then return end
            picker.reaction.chatText = ns:NormalizeChatText(picker.input:GetText())
            ns:InvalidateTargetTransition(picker.targetID)
            picker:Hide()
        end, true)
        save:SetPoint("BOTTOMRIGHT", -14, 14)
        local hint = Text(picker, "GameFontHighlightSmall", "", C.muted)
        hint:SetPoint("BOTTOMLEFT", 14, 22)
        picker.input:SetScript("OnEnterPressed", function() save:Click() end)
        picker.input:SetScript("OnEscapePressed", function() picker:Hide() end)
        picker:SetScript("OnHide", function()
            picker.input:ClearFocus(); picker.blocker:Hide()
            local targetID = picker.targetID
            picker.targetID, picker.reaction = nil, nil
            if targetID and ns.Options and ns.Options:IsVisible() then ns:RenderSelectedTarget(targetID) end
        end)
    end
    local picker = self.ChatTextPicker
    picker.targetID, picker.reaction = id, reaction
    picker.input:SetText(self:NormalizeChatText(reaction.chatText))
    picker:ClearAllPoints(); picker:SetPoint("CENTER", self.Options, "CENTER", 0, 0)
    self:HideAppearancePicker(); picker.blocker:Show(); picker:Show()
    picker.input:SetFocus(); picker.input:HighlightText()
end

function ns:CreateFormPicker()
    if self.FormPicker then return end
    local blocker = CreateFrame("Button", nil, self.Options, "BackdropTemplate")
    blocker:SetAllPoints(self.Options); blocker:SetFrameLevel(588); blocker:EnableMouse(true); blocker:RegisterForClicks("AnyUp")
    blocker:SetScript("OnClick", function() end); Backdrop(blocker, { 0, 0, 0, 0.32 }, { 0, 0, 0, 0 }); blocker:Hide()
    local picker = CreateFrame("Frame", "FrameGambitFormPicker", self.Options, "BackdropTemplate")
    picker:SetSize(430, 260); picker:SetFrameStrata("FULLSCREEN_DIALOG"); picker:SetFrameLevel(590)
    picker:EnableMouse(true); Backdrop(picker, C.panel, C.accent); picker:Hide(); picker.blocker = blocker; self.FormPicker = picker
    ApplyEUIObject("panel", picker, { inset = true })
    table.insert(UISpecialFrames, picker:GetName())
    picker.title = Text(picker, "GameFontNormal", "Choose form", C.accent); picker.title:SetPoint("TOPLEFT", 14, -13)
    picker.context = Text(picker, "GameFontHighlightSmall", "", C.muted)
    picker.context:SetPoint("TOPLEFT", picker.title, "BOTTOMLEFT", 0, -3); picker.context:SetPoint("RIGHT", -35, 0); picker.context:SetJustifyH("LEFT"); picker.context:SetWordWrap(true)
    local close = CloseButton(picker); close:SetPoint("TOPRIGHT", -9, -9)
    picker.buttons = {}
    for index, option in ipairs(self.FORM_OPTIONS or {}) do
        local choice = option
        local button = Button(picker, option.label, 192, function()
            local reaction, targetID = picker.reaction, picker.targetID
            if not reaction or not targetID then return end
            reaction.formKey, reaction.formExpected = choice.id, reaction.formExpected ~= false
            ns:InvalidateTargetTransition(targetID)
            picker:Hide()
        end)
        button:SetPoint("TOPLEFT", 14 + ((index - 1) % 2) * 201, -72 - math.floor((index - 1) / 2) * 39)
        picker.buttons[#picker.buttons + 1] = { frame = button, option = choice }
    end
    picker:SetScript("OnHide", function()
        picker.blocker:Hide()
        local targetID = picker.targetID
        picker.targetID, picker.reaction = nil, nil
        if targetID and ns.Options and ns.Options:IsVisible() then ns:RenderSelectedTarget(targetID) end
    end)
end

function ns:OpenFormPicker(id, reaction)
    self:CreateFormPicker()
    local picker = self.FormPicker
    picker.targetID, picker.reaction = id, reaction
    for _, entry in ipairs(picker.buttons) do
        local option, button = entry.option, entry.frame
        local available = self:GetFormActivity(option.id) ~= nil
        local selected = reaction and reaction.formKey == option.id
        button._selected, button._selectedColor = selected, C.teal
        SetFallbackBackdrop(button, selected and C.teal or C.cardAlt)
        button:GetFontString():SetTextColor(unpack(SelectedButtonText(button, selected, C.accent)))
        button:SetAlpha(available and 1 or 0.42)
        SetTooltip(button, option.label, not available and "Not on this character" or nil)
    end
    picker:ClearAllPoints(); picker:SetPoint("CENTER", self.Options, "CENTER", 0, 0)
    self:HideAppearancePicker(); picker.blocker:Show(); picker:Show()
end

function ns:CreateSpecPicker()
    if self.SpecPicker then return end
    local blocker = CreateFrame("Button", nil, self.Options, "BackdropTemplate")
    blocker:SetAllPoints(self.Options); blocker:SetFrameLevel(588); blocker:EnableMouse(true); blocker:RegisterForClicks("AnyUp")
    blocker:SetScript("OnClick", function() end); Backdrop(blocker, { 0, 0, 0, 0.32 }, { 0, 0, 0, 0 }); blocker:Hide()
    local picker = CreateFrame("Frame", "FrameGambitSpecPicker", self.Options, "BackdropTemplate")
    picker:SetSize(430, 278); picker:SetFrameStrata("FULLSCREEN_DIALOG"); picker:SetFrameLevel(590)
    picker:EnableMouse(true); Backdrop(picker, C.panel, C.accent); picker:Hide(); picker.blocker = blocker; self.SpecPicker = picker
    ApplyEUIObject("panel", picker, { inset = true })
    table.insert(UISpecialFrames, picker:GetName())
    picker.title = Text(picker, "GameFontNormal", "Choose class", C.accent); picker.title:SetPoint("TOPLEFT", 14, -13)
    picker.context = Text(picker, "GameFontHighlightSmall", "", C.muted)
    picker.context:SetPoint("TOPLEFT", picker.title, "BOTTOMLEFT", 0, -3); picker.context:SetPoint("RIGHT", -35, 0); picker.context:SetJustifyH("LEFT"); picker.context:SetWordWrap(true)
    picker.close = CloseButton(picker); picker.close:SetPoint("TOPRIGHT", -9, -9)
    picker.back = Button(picker, "Back", 56, function()
        picker.classID = nil
        ns:ShowSpecPickerChoices()
    end); picker.back:SetPoint("BOTTOMLEFT", 14, 12); picker.back:Hide()
    picker.buttons = {}
    picker:SetScript("OnHide", function()
        picker.blocker:Hide()
        local targetID = picker.targetID
        picker.targetID, picker.reaction, picker.classID = nil, nil, nil
        if targetID and ns.Options and ns.Options:IsVisible() then ns:RenderSelectedTarget(targetID) end
    end)
end

function ns:ShowSpecPickerChoices()
    local picker = self.SpecPicker
    if not picker then return end
    local classID = picker.classID
    local choices = classID and (self.SPECS_BY_CLASS[classID] or {}) or (self.CLASS_OPTIONS or {})
    picker.title:SetText(classID and "Choose build" or "Choose class")
    picker.context:SetText(classID and "" or "")
    picker.back:SetShown(classID ~= nil)
    for index, choice in ipairs(choices) do
        local selectedChoice = choice
        local button = picker.buttons[index]
        if not button then button = Button(picker, "", 126, nil); picker.buttons[index] = button end
        local selected = picker.reaction and classID and picker.reaction.specID == selectedChoice.id
        button._selected, button._selectedColor = selected, C.teal
        SetFallbackBackdrop(button, selected and C.teal or C.cardAlt)
        button:GetFontString():SetText(selectedChoice.label)
        button:GetFontString():SetTextColor(unpack(SelectedButtonText(button, selected, C.accent)))
        button:ClearAllPoints(); button:SetPoint("TOPLEFT", 14 + ((index - 1) % 3) * 134, -74 - math.floor((index - 1) / 3) * 31)
        button:SetScript("OnClick", function()
            if not classID then
                picker.classID = selectedChoice.id
                ns:ShowSpecPickerChoices()
                return
            end
            local reaction, targetID = picker.reaction, picker.targetID
            if not reaction or not targetID then return end
            reaction.specClass, reaction.specID = classID, selectedChoice.id
            ns:InvalidateTargetTransition(targetID)
            picker:Hide()
        end)
        button:Show()
    end
    for index = #choices + 1, #picker.buttons do picker.buttons[index]:Hide() end
end

function ns:OpenSpecPicker(id, reaction)
    self:CreateSpecPicker()
    local picker = self.SpecPicker
    picker.targetID, picker.reaction, picker.classID = id, reaction, nil
    picker:ClearAllPoints(); picker:SetPoint("CENTER", self.Options, "CENTER", 0, 0)
    self:HideAppearancePicker(); picker.blocker:Show(); picker:Show(); self:ShowSpecPickerChoices()
end

function ns:ShowReactionCategory(categoryID)
    local palette = self.ReactionPalette
    if not palette then return end
    palette.categoryID = categoryID
    local requirementsByCategory = {}
    if palette.mode == "requirements" and palette.reaction then
        for _, condition in ipairs(palette.reaction.requirements or {}) do
            local info = self.CONDITION_INFO[condition]
            if info and info.category then requirementsByCategory[info.category] = true end
        end
    end
    -- A non-empty search spans every category. Rank: label starts with the
    -- query, then a word in the label does, then the label contains it
    -- anywhere, then only the help text or category name matches.
    local query = palette.query or ""
    local searching = query ~= ""
    local function SearchRank(button)
        local label = ConditionLabel(button.conditionKey):lower()
        local start = label:find(query, 1, true)
        if start == 1 then return 1 end
        if start and label:sub(start - 1, start - 1):match("[%s/%-%(]") then return 2 end
        if start then return 3 end
        local help = (button.defaultTooltipBody or ""):lower()
        local categoryTab = palette.tabs[button.category]
        if help:find(query, 1, true) or (categoryTab and categoryTab.categoryLabel:lower():find(query, 1, true)) then return 4 end
        return nil
    end
    local visible, countByCategory, matchesByCategory, rank = {}, {}, {}, {}
    for _, button in ipairs(palette.conditionButtons) do
        button:Hide()
        local info = ns.CONDITION_INFO[button.conditionKey]
        if not (palette.mode ~= "requirements" and info and info.requirementOnly)
            and not (palette.mode == "requirements"
            and (button.conditionKey == "form" or button.conditionKey == "spec" or button.conditionKey == "chat_text" or ns:IsPercentageCondition(button.conditionKey) or ns:GetBooleanConditionField(button.conditionKey))) then
            countByCategory[button.category] = (countByCategory[button.category] or 0) + 1
            if searching then
                rank[button] = SearchRank(button)
                if rank[button] then
                    visible[#visible + 1] = button
                    matchesByCategory[button.category] = true
                end
            elseif button.category == categoryID then
                visible[#visible + 1] = button
            end
        end
    end
    for id, tab in pairs(palette.tabs) do
        local hasRequirements = requirementsByCategory[id] == true
        -- While searching, no tab is "current"; categories without a hit
        -- fade so the rail doubles as a map of where the matches live.
        tab._selected = not searching and id == categoryID
        tab._dimmed = searching and not matchesByCategory[id]
        tab.requirementMarker:SetShown(hasRequirements)
        tab._tooltipTitle = tab.categoryLabel
        tab._tooltipBody = hasRequirements
            and "Has a selected requirement"
            or nil
        PaintCategoryTab(tab)
    end
    -- Size to the fullest category in this mode so switching tabs never
    -- makes the window jump; search results scroll-free within that space.
    local maxCount = 0
    for _, count in pairs(countByCategory) do maxCount = math.max(maxCount, count) end
    palette.maxConditionRows = math.ceil(maxCount / 2)
    local function PickerOrder(a, b)
        local aInfo, bInfo = ns.CONDITION_INFO[a.conditionKey], ns.CONDITION_INFO[b.conditionKey]
        local aOrder, bOrder = aInfo and aInfo.pickerOrder, bInfo and bInfo.pickerOrder
        if aOrder ~= bOrder then return (aOrder or math.huge) < (bOrder or math.huge) end
        return ConditionLabel(a.conditionKey) < ConditionLabel(b.conditionKey)
    end
    table.sort(visible, function(a, b)
        if searching and rank[a] ~= rank[b] then return rank[a] < rank[b] end
        if searching then return ConditionLabel(a.conditionKey) < ConditionLabel(b.conditionKey) end
        return PickerOrder(a, b)
    end)
    -- Keep results inside the fitted grid; the count tells the user to
    -- narrow the query rather than silently dropping matches.
    local capacity = palette.maxConditionRows * 2
    local overflow = #visible - capacity
    for index = #visible, capacity + 1, -1 do visible[index] = nil end
    palette.visibleConditions = visible
    palette.searchStatus:SetText(searching and (#visible == 0 and ""
        or overflow > 0 and (#visible + overflow) .. " matches - showing " .. #visible
        or #visible == 1 and "1 match - Enter to pick" or #visible .. " matches") or "")
    palette.empty:SetShown(searching and #visible == 0)
    palette.search.clear:SetShown(searching)
    for index, button in ipairs(visible) do
        local reaction = palette.reaction
        local requirementMode = palette.mode == "requirements" and reaction
        local selected = requirementMode and RequirementIndex(reaction, button.conditionKey)
        local blocked = requirementMode and button.conditionKey == reaction.condition
        local conflictWith = requirementMode and ns:GetRequirementConflict(reaction, button.conditionKey, selected and button.conditionKey or nil)
        -- Outside Add requirements, `requirementMode` is false rather than
        -- nil. Treat only an actual conflicting condition as incompatible.
        local incompatible = conflictWith and true or false
        local exists = requirementMode and blocked
        button:ClearAllPoints(); button:SetPoint("TOPLEFT", ((index - 1) % 2) * 176, -30 - math.floor((index - 1) / 2) * 30)
        if selected and incompatible then
            -- Preserve older impossible combinations for safe, manual
            -- cleanup. The red card remains clickable so it can be removed.
            button._selected, button._selectedColor = true, C.amber
            SetFallbackBackdrop(button, C.amber, C.amber)
            button:GetFontString():SetTextColor(1, 1, 1, 1)
            button:SetEnabled(true); button:SetAlpha(1)
            button._tooltipTitle = "Incompatible AND requirement"
            button._tooltipBody = "Conflicts with " .. ConditionLabel(conflictWith)
        elseif incompatible then
            button._selected, button._selectedColor = false, nil
            SetFallbackBackdrop(button, C.cardAlt, C.border)
            button:GetFontString():SetTextColor(unpack(C.muted))
            button:SetEnabled(false); button:SetAlpha(0.36)
            button._tooltipTitle = "Unavailable"
            button._tooltipBody = "Conflicts with " .. ConditionLabel(conflictWith)
        else
            button._selected, button._selectedColor = selected and true or false, C.teal
            SetFallbackBackdrop(button, selected and C.teal or C.cardAlt, C.border)
            button:GetFontString():SetTextColor(unpack(SelectedButtonText(button, selected, C.accent)))
            button:SetEnabled(not exists); button:SetAlpha(exists and 0.35 or 1)
            button._tooltipTitle = button.defaultTooltipTitle
            button._tooltipBody = button.defaultTooltipBody
        end
        button:Show()
    end
    self:LayoutReactionPalette()
end

function ns:LayoutReactionPalette()
    local palette = self.ReactionPalette
    if not palette then return end
    local header = 13 + palette.title:GetStringHeight() + 3 + palette.context:GetStringHeight() + 12
    local contentHeight = 30 + (palette.maxConditionRows or 1) * 30
    local body = math.max(palette.categoryRail:GetHeight(), contentHeight)
    local footer = palette.done:IsShown() and 44 or 14
    palette:SetHeight(math.ceil(header + body + footer))
end

-- Keyboard users can start typing immediately. With a gamepad active the
-- box stays unfocused so the stick/cursor keeps driving the grid and no
-- on-screen keyboard is summoned uninvited.
function ns:FocusReactionSearch()
    local palette = self.ReactionPalette
    if not palette or not palette:IsShown() then return end
    local gamepad = C_GamePad and C_GamePad.IsEnabled and C_GamePad.IsEnabled()
    if not gamepad then palette.search:SetFocus() end
end

function ns:OpenReactionPalette(id)
    self:CreateReactionPalette()
    local palette = self.ReactionPalette
    palette.targetID, palette.mode, palette.reaction = id, "reaction", nil
    palette.done:Hide()
    palette.title:SetText("Add a reaction")
    palette.context:SetText("First match wins")
    palette:ClearAllPoints(); palette:SetPoint("CENTER", self.Options, "CENTER", 0, 0)
    palette.query = ""; palette.search:SetText("")
    self:HideAppearancePicker(); palette.blocker:Show(); palette:Show()
    -- The guided lesson's next action is Mouseover. Open straight to its
    -- category rather than making a learner search a remembered tab.
    local tutorialMouseover = self.Tutorial and self.Tutorial.step == 5
    self:ShowReactionCategory(tutorialMouseover and "system" or (palette.categoryID or "system"))
    if tutorialMouseover and self.RefreshTutorial then self:RefreshTutorial() end
    if not tutorialMouseover then self:FocusReactionSearch() end
end

function ns:OpenRequirementPalette(id, reaction)
    self:CreateReactionPalette()
    local palette = self.ReactionPalette
    palette.targetID, palette.mode, palette.reaction = id, "requirements", reaction
    palette.title:SetText("Add requirements")
    palette.context:SetText("All must be true")
    palette.done:Show()
    palette:ClearAllPoints(); palette:SetPoint("CENTER", self.Options, "CENTER", 0, 0)
    palette.query = ""; palette.search:SetText("")
    self:HideAppearancePicker(); palette.blocker:Show(); palette:Show(); self:ShowReactionCategory(palette.categoryID or "system")
    self:FocusReactionSearch()
end

function ns:CreateConnectionPicker()
    if self.ConnectionPicker then return end
    local blocker = CreateFrame("Button", nil, self.Options, "BackdropTemplate")
    blocker:SetAllPoints(self.Options); blocker:SetFrameLevel(579); blocker:EnableMouse(true); blocker:RegisterForClicks("AnyUp")
    blocker:SetScript("OnClick", function() end)
    Backdrop(blocker, { 0, 0, 0, 0.42 }, { 0, 0, 0, 0 }); blocker:Hide()
    local picker = CreateFrame("Frame", "FrameGambitConnections", self.Options, "BackdropTemplate")
    picker:SetSize(430, 410); picker:SetFrameStrata("FULLSCREEN_DIALOG"); picker:SetFrameLevel(581)
    picker:EnableMouse(true); Backdrop(picker, C.panel, C.accent); picker:Hide(); picker.blocker = blocker; self.ConnectionPicker = picker
    ApplyEUIObject("panel", picker, { inset = true })
    table.insert(UISpecialFrames, picker:GetName())
    picker.title = Text(picker, "GameFontNormal", "Connections", C.accent); picker.title:SetPoint("TOPLEFT", 14, -13)
    picker.copy = Text(picker, "GameFontHighlightSmall", "", C.muted); picker.copy:SetPoint("TOPLEFT", picker.title, "BOTTOMLEFT", 0, -4); picker.copy:SetPoint("RIGHT", -14, 0); picker.copy:SetJustifyH("LEFT")
    picker.status = Text(picker, "GameFontHighlightSmall", "", C.teal); picker.status:SetPoint("TOPLEFT", picker.copy, "BOTTOMLEFT", 0, -6)
    picker.done = Button(picker, "Done", 66, function() picker:Hide() end, true); picker.done:SetPoint("BOTTOMRIGHT", -12, 12)
    picker.close = CloseButton(picker); picker.close:SetPoint("TOPRIGHT", -9, -9)
    local search = CreateFrame("EditBox", nil, picker, "BackdropTemplate")
    search:SetPoint("TOPLEFT", 14, -84); search:SetPoint("TOPRIGHT", -14, -84); search:SetHeight(22)
    search:SetAutoFocus(false); search:SetFontObject(GameFontHighlightSmall)
    search:SetTextInsets(8, 8, 0, 0); search:SetTextColor(unpack(C.inputText)); TrackTheme(search, "inputText"); Backdrop(search, C.cardAlt, C.border)
    ApplyEUIObject("edit", search)
    local searchHint = Text(search, "GameFontHighlightSmall", "Search", C.muted)
    searchHint:SetPoint("LEFT", 8, 0); search.hint = searchHint
    search:SetScript("OnEditFocusGained", function() searchHint:Hide() end)
    search:SetScript("OnEditFocusLost", function() if search:GetText() == "" then searchHint:Show() end end)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    search:SetScript("OnTextChanged", function(self)
        if self:GetText() == "" and not self:HasFocus() then searchHint:Show() else searchHint:Hide() end
        picker.query = self:GetText():lower():match("^%s*(.-)%s*$") or ""
        ns:RenderConnectionPicker()
    end)
    picker.search = search
    local scroll = CreateFrame("ScrollFrame", nil, picker, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -116); scroll:SetPoint("BOTTOMRIGHT", -29, 48)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - delta * 58)))
    end)
    SkinScrollFrame(scroll)
    picker.scroll = scroll
    picker.content = CreateFrame("Frame", nil, scroll)
    picker.content:SetSize(382, 1)
    scroll:SetScrollChild(picker.content)
    picker.buttons = {}
    picker.empty = Text(picker.content, "GameFontHighlightSmall", "No matches", C.muted)
    picker.empty:SetPoint("TOP", 0, -10); picker.empty:Hide()
    picker:SetScript("OnHide", function()
        picker.blocker:Hide()
        local sourceID = picker.sourceID
        picker.sourceID, picker.mode = nil, nil
        if sourceID and ns.TargetByID[sourceID] and ns.Options and ns.Options:IsVisible() then ns:RenderSelectedTarget(sourceID) end
    end)
end

function ns:RenderConnectionPicker()
    local picker = self.ConnectionPicker
    if not picker or not picker:IsShown() then return end
    local sourceID, mode = picker.sourceID, picker.mode
    if not self.TargetByID[sourceID] then picker:Hide(); return end
    picker.title:SetText(mode == "group" and "Hover group" or mode == "visibility" and "Visibility children" or "Linked children")
    picker.copy:SetText(mode == "group"
        and "Hover one, show all"
        or mode == "visibility"
            and "Children follow this frame"
            or "Hover this frame, show children")
    local group = mode == "group" and select(2, self:GetRevealGroup(sourceID)) or nil
    local children = mode == "link" and self:GetLinkedChildren(sourceID) or nil
    local visibilityChildren = mode == "visibility" and self:GetVisibilityChildren(sourceID) or nil
    for _, button in pairs(picker.buttons) do button:Hide() end
    local availableTargets = self:GetAvailableTargets()
    local filteredTargets = {}
    local query = picker.query or ""
    for _, target in ipairs(availableTargets) do
        local searchable = ((target.label or "") .. " " .. (target.source or "") .. " " .. (target.id or "")):lower()
        if query == "" or searchable:find(query, 1, true) then filteredTargets[#filteredTargets + 1] = target end
    end
    picker.empty:SetShown(#filteredTargets == 0)
    for index, target in ipairs(filteredTargets) do
        local targetID = target.id
        local button = picker.buttons[targetID]
        if not button then
            button = Button(picker.content, "", 185, nil)
            picker.buttons[targetID] = button
        end
        local isSource = targetID == sourceID
        local selected = mode == "group" and group and group.members[targetID]
            or mode == "link" and children[targetID]
            or mode == "visibility" and visibilityChildren[targetID]
        button:Show(); button:ClearAllPoints(); button:SetPoint("TOPLEFT", ((index - 1) % 2) * 193, -math.floor((index - 1) / 2) * 29)
        button._selected = selected and true or false; button._selectedColor = C.teal; button._primary = false
        SetFallbackBackdrop(button, selected and C.teal or C.cardAlt)
        button:GetFontString():SetText((selected and "[on] " or "") .. target.label .. (isSource and " [source]" or ""))
        button:GetFontString():SetTextColor(unpack(SelectedButtonText(button, selected, C.accent)))
        button:SetEnabled(not isSource); button:SetAlpha(isSource and 0.45 or 1)
        button:SetScript("OnClick", function()
            if mode == "group" then
                local _, current = ns:GetRevealGroup(sourceID)
                if current and current.members[targetID] then
                    ns:RemoveFromRevealGroup(targetID)
                else
                    local allowed, reason = ns:AddToRevealGroup(sourceID, targetID)
                    if not allowed then picker.status:SetText(reason); picker.status:SetTextColor(unpack(C.amber)); return end
                end
            elseif mode == "link" then
                if ns:GetLinkedChildren(sourceID)[targetID] then
                    ns:RemoveLink(sourceID, targetID)
                else
                    local allowed, reason = ns:AddLink(sourceID, targetID)
                    if not allowed then picker.status:SetText(reason); picker.status:SetTextColor(unpack(C.amber)); return end
                end
            else
                if ns:GetVisibilityChildren(sourceID)[targetID] then
                    ns:RemoveVisibilityLink(sourceID, targetID)
                else
                    local allowed, reason = ns:AddVisibilityLink(sourceID, targetID)
                    if not allowed then picker.status:SetText(reason); picker.status:SetTextColor(unpack(C.amber)); return end
                    picker.status:SetText(reason); picker.status:SetTextColor(unpack(C.teal))
                    ns:RenderConnectionPicker()
                    return
                end
            end
            picker.status:SetText(""); picker.status:SetTextColor(unpack(C.teal))
            ns:RenderConnectionPicker()
        end)
    end
    picker.content:SetHeight(math.max(28, math.ceil(#filteredTargets / 2) * 29))
    picker.scroll:SetVerticalScroll(math.min(picker.scroll:GetVerticalScroll(), picker.scroll:GetVerticalScrollRange()))
end

function ns:OpenConnectionPicker(mode, sourceID)
    if not self.TargetByID[sourceID] then return end
    self:CreateConnectionPicker()
    local picker = self.ConnectionPicker
    picker.mode, picker.sourceID = mode, sourceID
    picker.query = ""
    picker.search:SetText("")
    picker.search:ClearFocus()
    picker.search.hint:Show()
    picker.scroll:SetVerticalScroll(0)
    picker:ClearAllPoints(); picker:SetPoint("CENTER", self.Options, "CENTER", 0, 0)
    self:HideAppearancePicker(); picker.blocker:Show(); picker:Show(); self:RenderConnectionPicker()
end

function ns:CreateOpacityPicker()
    if self.OpacityPicker then return end
    local blocker = CreateFrame("Button", nil, self.Options, "BackdropTemplate")
    blocker:SetAllPoints(self.Options); blocker:SetFrameLevel(582); blocker:EnableMouse(true); blocker:RegisterForClicks("AnyUp")
    blocker:SetScript("OnClick", function() if ns.OpacityPicker then ns.OpacityPicker:Hide() end end)
    Backdrop(blocker, { 0, 0, 0, 0.22 }, { 0, 0, 0, 0 }); blocker:Hide()
    local picker = CreateFrame("Frame", "FrameGambitOpacity", self.Options, "BackdropTemplate")
    picker:SetSize(294, 148); picker:SetFrameStrata("FULLSCREEN_DIALOG"); picker:SetFrameLevel(583); picker:EnableMouse(true)
    Backdrop(picker, C.panel, C.accent); picker:Hide(); picker.blocker = blocker; self.OpacityPicker = picker
    ApplyEUIObject("panel", picker, { inset = true })
    table.insert(UISpecialFrames, picker:GetName())
    picker.title = Text(picker, "GameFontNormal", "Opacity", C.accent); picker.title:SetPoint("TOPLEFT", 14, -13)
    picker.value = Text(picker, "GameFontNormal", "", C.teal); picker.value:SetPoint("TOPRIGHT", -42, -13)
    local close = CloseButton(picker); close:SetPoint("TOPRIGHT", -9, -9)
    picker.slider = CreateFrame("Slider", nil, picker, "BackdropTemplate")
    picker.slider:SetPoint("TOPLEFT", 16, -46); picker.slider:SetPoint("TOPRIGHT", -16, -46); picker.slider:SetHeight(14)
    picker.slider:SetOrientation("HORIZONTAL")
    picker.slider:SetMinMaxValues(0, 1); picker.slider:SetValueStep(0.01); picker.slider:SetObeyStepOnDrag(true)
    Backdrop(picker.slider, C.cardAlt, C.border)
    local thumb = picker.slider:CreateTexture(nil, "OVERLAY"); thumb:SetSize(12, 20); SetTealTexture(thumb); picker.slider:SetThumbTexture(thumb)
    if ns.LegacySkin then ns.LegacySkin:Slider(picker.slider) end
    picker.presets = {}
    for index, value in ipairs({ 0, 0.12, 0.30, 0.50, 0.70, 1.00 }) do
        local presetValue = value
        local button = Button(picker, Percent(value), 39, function()
            -- Apply explicitly: choosing the value the slider already has
            -- (for example 100% while Keep is on) must still count.
            picker.loading = true; picker.slider:SetValue(presetValue); picker.loading = nil
            if picker.apply then picker.apply(presetValue); picker:UpdateVisuals(presetValue) end
        end)
        button:SetPoint("TOPLEFT", 16 + (index - 1) * 44, -78); picker.presets[#picker.presets + 1] = { button = button, value = value }
    end
    function picker:UpdateVisuals(value)
        local keep = self.keepOption and self.keepOption.get() or false
        self.value:SetText(keep and "Keep" or Percent(value))
        if self.keep and self.keepOption then SetLayoutChoiceState(self.keep, keep) end
        self.slider:SetAlpha(keep and 0.45 or 1)
        for _, preset in ipairs(self.presets) do
            local selected = not keep and math.abs(value - preset.value) < 0.005
            preset.button._selected, preset.button._selectedColor = selected, C.teal
            SetFallbackBackdrop(preset.button, selected and C.teal or C.cardAlt)
            preset.button:GetFontString():SetTextColor(unpack(SelectedButtonText(preset.button, selected, C.accent)))
        end
    end
    picker.done = Button(picker, "Done", 66, function() picker:Hide() end, true); picker.done:SetPoint("BOTTOMRIGHT", -12, 12)
    -- Rules with size and position on can leave opacity to later rules: the
    -- card's opacity button then reads Keep.
    picker.keep = Button(picker, "Keep opacity", 96, function()
        local option = picker.keepOption
        if not option then return end
        local ok, message = option.set(not option.get())
        picker.note:SetText(ok == false and message or "")
        picker:UpdateVisuals(picker.slider:GetValue())
    end)
    picker.keep:SetPoint("BOTTOMLEFT", 12, 12); picker.keep:Hide()
    SetTooltip(picker.keep, nil, nil)
    picker.note = Text(picker, "GameFontHighlightSmall", "", C.amber)
    picker.note:SetPoint("TOPLEFT", 16, -108); picker.note:SetWidth(262); picker.note:SetJustifyH("LEFT"); picker.note:SetWordWrap(true)
    picker.slider:SetScript("OnValueChanged", function(_, value)
        if picker.loading or not picker.apply then return end
        value = math.floor(value * 100 + 0.5) / 100
        picker.apply(value); picker:UpdateVisuals(value)
    end)
    picker:SetScript("OnHide", function()
        picker.blocker:Hide(); picker.apply = nil; picker.keepOption = nil
    end)
end

-- keepOption (optional): { get = function() return bool end, set = function(bool) end }.
-- Adds a Keep opacity switch; set may return false, message to refuse.
function ns:OpenOpacityPicker(label, value, apply, keepOption)
    self:CreateOpacityPicker()
    local picker = self.OpacityPicker
    picker.title:SetText(label)
    picker.value:SetText(Percent(value))
    picker.apply, picker.keepOption = apply, keepOption
    picker.keep:SetShown(keepOption ~= nil)
    picker.note:SetText("")
    picker:SetHeight(keepOption and 172 or 148)
    picker:ClearAllPoints(); picker:SetPoint("CENTER", self.Options, "CENTER", 0, 0)
    self:HideAppearancePicker(); picker.blocker:Show(); picker:Show()
    -- Setting the slider must not count as choosing an opacity (that turns Keep off).
    picker.loading = true; picker.slider:SetValue(value); picker.loading = nil
    picker:UpdateVisuals(value)
end

-- Experimental size and position -------------------------------------------

local function LayoutPickerShell(self, name, height, level)
    local blocker = CreateFrame("Button", nil, self.Options, "BackdropTemplate")
    blocker:SetAllPoints(self.Options); blocker:SetFrameLevel(level - 1); blocker:EnableMouse(true); blocker:RegisterForClicks("AnyUp")
    Backdrop(blocker, { 0, 0, 0, 0.22 }, { 0, 0, 0, 0 }); blocker:Hide()
    local picker = CreateFrame("Frame", name, self.Options, "BackdropTemplate")
    picker:SetSize(294, height); picker:SetFrameStrata("FULLSCREEN_DIALOG"); picker:SetFrameLevel(level); picker:EnableMouse(true)
    Backdrop(picker, C.panel, C.accent); picker:Hide(); picker.blocker = blocker
    blocker:SetScript("OnClick", function() picker:Hide() end)
    ApplyEUIObject("panel", picker, { inset = true })
    table.insert(UISpecialFrames, picker:GetName())
    picker.title = Text(picker, "GameFontNormal", "", C.accent); picker.title:SetPoint("TOPLEFT", 14, -13)
    picker.title:SetPoint("RIGHT", picker, "RIGHT", -120, 0); picker.title:SetJustifyH("LEFT"); picker.title:SetWordWrap(false)
    picker.value = Text(picker, "GameFontNormal", "", C.teal); picker.value:SetPoint("TOPRIGHT", -42, -13)
    local close = CloseButton(picker); close:SetPoint("TOPRIGHT", -9, -9)
    picker.done = Button(picker, "Done", 66, function() picker:Hide() end, true); picker.done:SetPoint("BOTTOMRIGHT", -12, 12)
    picker:SetScript("OnHide", function() picker.blocker:Hide(); picker.apply = nil end)
    return picker
end

local function ShowLayoutPicker(self, picker)
    picker:ClearAllPoints(); picker:SetPoint("CENTER", self.Options, "CENTER", 0, 0)
    self:HideAppearancePicker(); picker.blocker:Show(); picker:Show()
end

function ns:CreateLayoutSizePicker()
    if self.LayoutSizePicker then return end
    local picker = LayoutPickerShell(self, "FrameGambitLayoutSize", 214, 583)
    self.LayoutSizePicker = picker
    picker.slider = CreateFrame("Slider", nil, picker, "BackdropTemplate")
    picker.slider:SetPoint("TOPLEFT", 16, -46); picker.slider:SetPoint("TOPRIGHT", -16, -46); picker.slider:SetHeight(14)
    picker.slider:SetOrientation("HORIZONTAL")
    picker.slider:SetMinMaxValues(ns.LAYOUT_SCALE_MIN or 0.5, ns.LAYOUT_SCALE_MAX or 2)
    picker.slider:SetValueStep(0.05); picker.slider:SetObeyStepOnDrag(true)
    Backdrop(picker.slider, C.cardAlt, C.border)
    local thumb = picker.slider:CreateTexture(nil, "OVERLAY"); thumb:SetSize(12, 20); SetTealTexture(thumb); picker.slider:SetThumbTexture(thumb)
    if ns.LegacySkin then ns.LegacySkin:Slider(picker.slider) end
    function picker:Choose(value)
        if not self.apply then return end
        if value then
            value = math.floor(value * 20 + 0.5) / 20
            self.loading = true; self.slider:SetValue(value); self.loading = nil
        end
        self.current = value
        self:UpdateVisuals(value); self.apply(value)
    end
    picker.presets = {}
    for index, value in ipairs({ 0.75, 0.90, 1.00, 1.10, 1.25, 1.50 }) do
        local presetValue = value
        local button = Button(picker, ScaleText(value), 39, function() picker:Choose(presetValue) end)
        button:SetPoint("TOPLEFT", 16 + (index - 1) * 44, -78); picker.presets[#picker.presets + 1] = { button = button, value = value }
    end
    -- "Grow from": the point of the frame that stays put. One setting per frame.
    picker.pivotLabel = Text(picker, "GameFontHighlightSmall", "Grow from", C.muted)
    picker.pivotLabel:SetPoint("TOPLEFT", 16, -124)
    picker.pivots = {}
    local pivotNames = {
        { "TOPLEFT", "top left" }, { "TOP", "top" }, { "TOPRIGHT", "top right" },
        { "LEFT", "left" }, { "CENTER", "the middle" }, { "RIGHT", "right" },
        { "BOTTOMLEFT", "bottom left" }, { "BOTTOM", "bottom" }, { "BOTTOMRIGHT", "bottom right" },
    }
    for index, entry in ipairs(pivotNames) do
        local point = entry[1]
        local cell = Button(picker, "", 18, function()
            local settings = picker.pivotSettings
            if not settings then return end
            settings.layoutPivot = point ~= "CENTER" and point or nil
            picker:UpdateVisuals(picker.current)
            if picker.pivotChanged then picker.pivotChanged() end
        end)
        cell:SetSize(18, 18)
        cell:SetPoint("TOPLEFT", 96 + ((index - 1) % 3) * 21, -110 - math.floor((index - 1) / 3) * 21)
        SetTooltip(cell, "Grow from " .. entry[2], nil)
        picker.pivots[point] = cell
    end
    picker.same = Button(picker, "Same size", 86, function() picker:Choose(nil) end); picker.same:SetPoint("BOTTOMLEFT", 12, 12)
    SetTooltip(picker.same, nil, nil)
    function picker:UpdateVisuals(value)
        self.value:SetText(value and ScaleText(value) or "Same size")
        for _, preset in ipairs(self.presets) do
            local selected = value ~= nil and math.abs(value - preset.value) < 0.005
            preset.button._selected, preset.button._selectedColor = selected, C.teal
            SetFallbackBackdrop(preset.button, selected and C.teal or C.cardAlt)
            preset.button:GetFontString():SetTextColor(unpack(SelectedButtonText(preset.button, selected, C.accent)))
        end
        SetLayoutChoiceState(self.same, value == nil)
        self.slider:SetAlpha(value and 1 or 0.45)
        local current = (self.pivotSettings and self.pivotSettings.layoutPivot) or "CENTER"
        for point, cell in pairs(self.pivots) do SetLayoutChoiceState(cell, point == current) end
    end
    picker.slider:SetScript("OnValueChanged", function(_, value)
        if picker.loading or not picker.apply then return end
        value = math.floor(value * 20 + 0.5) / 20
        picker.current = value
        picker:UpdateVisuals(value); picker.apply(value)
    end)
end

-- value nil = Same size. fallback is the size shown on the slider meanwhile.
function ns:OpenLayoutSizePicker(label, value, fallback, allowSame, apply, pivotSettings, pivotChanged)
    self:CreateLayoutSizePicker()
    local picker = self.LayoutSizePicker
    picker.title:SetText(label .. " - size")
    picker.same:SetShown(allowSame)
    picker.pivotSettings, picker.pivotChanged = pivotSettings, pivotChanged
    picker.apply, picker.current = apply, value
    picker.loading = true; picker.slider:SetValue(value or fallback or 1); picker.loading = nil
    picker:UpdateVisuals(value)
    ShowLayoutPicker(self, picker)
end

function ns:CreateLayoutPositionPicker()
    if self.LayoutPositionPicker then return end
    local picker = LayoutPickerShell(self, "FrameGambitLayoutPosition", 158, 583)
    self.LayoutPositionPicker = picker
    picker.stepSize = 10
    function picker:Nudge(dx, dy)
        if not self.apply then return end
        local x, y = self.x, self.y
        if x == nil then x, y = self.fallbackX or 0, self.fallbackY or 0 end
        local limit = ns.LAYOUT_OFFSET_LIMIT or 2000
        self.x = math.max(-limit, math.min(limit, x + dx * self.stepSize))
        self.y = math.max(-limit, math.min(limit, y + dy * self.stepSize))
        self:UpdateVisuals(); self.apply(self.x, self.y)
    end
    picker.moves = {}
    for index, move in ipairs({ { "left", -1, 0, "Move left" }, { "right", 1, 0, "Move right" }, { "up", 0, 1, "Move up" }, { "down", 0, -1, "Move down" } }) do
        local dx, dy = move[2], move[3]
        local button = Button(picker, "", 30, function() picker:Nudge(dx, dy) end)
        button:SetPoint("TOPLEFT", 16 + (index - 1) * 34, -44); DrawTriangle(button, move[1])
        SetTooltip(button, move[4], nil)
        picker.moves[index] = button
    end
    picker.step = Button(picker, "", 64, function()
        picker.stepSize = picker.stepSize == 1 and 10 or (picker.stepSize == 10 and 50 or 1)
        picker:UpdateVisuals()
    end)
    picker.step:SetPoint("TOPLEFT", 156, -44)
    SetTooltip(picker.step, "Step size", nil)
    picker.reset = Button(picker, "Reset", 58, function()
        if not picker.apply then return end
        picker.x, picker.y = 0, 0
        picker:UpdateVisuals(); picker.apply(0, 0)
    end)
    picker.reset:SetPoint("TOPLEFT", 224, -44)
    SetTooltip(picker.reset, nil, nil)
    picker.help = Text(picker, "GameFontHighlightSmall", "Protected frames: not in combat", C.muted)
    picker.help:SetPoint("TOPLEFT", 16, -78); picker.help:SetWidth(262); picker.help:SetJustifyH("LEFT"); picker.help:SetWordWrap(true)
    picker.same = Button(picker, "Same position", 100, function()
        if not picker.apply then return end
        picker.x, picker.y = nil, nil
        picker:UpdateVisuals(); picker.apply(nil, nil)
    end)
    picker.same:SetPoint("BOTTOMLEFT", 12, 12)
    SetTooltip(picker.same, nil, nil)
    function picker:UpdateVisuals()
        self.value:SetText(LayoutPositionText(self.x, self.y, not self.allowSame))
        self.step:GetFontString():SetText("Step " .. self.stepSize)
        SetLayoutChoiceState(self.same, self.x == nil)
    end
end

-- x/y nil = Same position. fallbackX/Y is where the first arrow press starts.
function ns:OpenLayoutPositionPicker(label, x, y, fallbackX, fallbackY, allowSame, apply)
    self:CreateLayoutPositionPicker()
    local picker = self.LayoutPositionPicker
    picker.title:SetText(label .. " - position")
    picker.same:SetShown(allowSame)
    picker.allowSame = allowSame
    picker.x, picker.y, picker.fallbackX, picker.fallbackY, picker.apply = x, y, fallbackX, fallbackY, apply
    picker:UpdateVisuals()
    ShowLayoutPicker(self, picker)
end

-- Opens or closes a card's second line and wires its Size / Position / Keep
-- opacity controls. reaction nil = the Otherwise row.
-- leftUsed / rightReserve: pixels of the first line already taken from the
-- left and (up to the toggle) from the right. The controls sit beside the
-- toggle when they fit, and drop to a second line only in a narrow editor.
-- Returns true when they sit on the first line.
function ns:ConfigureLayoutLine(row, id, settings, reaction, available, open, leftUsed, rightReserve)
    local isRest = reaction == nil
    row.layoutToggle:SetShown(available)
    SetLayoutToggleState(row.layoutToggle, open)
    row.layoutToggle:SetScript("OnClick", function()
        if open then
            if isRest then
                settings.restLayoutLine, settings.restScale, settings.restOffsetX, settings.restOffsetY = nil, nil, nil, nil
                settings.restLayoutInstant = nil
            else
                reaction.layoutLine, reaction.scale, reaction.offsetX, reaction.offsetY, reaction.keepOpacity = nil, nil, nil, nil, nil
                reaction.layoutInstant = nil
            end
        else
            local supported, reason = ns:GetFrameLayoutSupport(id)
            if not supported then ns:ShowEditorNotice(reason or "Fade only", "amber"); return end
            if isRest then settings.restLayoutLine = true else reaction.layoutLine = true end
        end
        ns:InvalidateTargetTransition(id)
        ns:RenderSelectedTarget(id)
    end)
    row.size:SetShown(open); row.position:SetShown(open); row.instant:SetShown(open)
    row.layoutInline = false
    row:SetHeight(39)
    if not open then return false end
    local label = isRest and "Otherwise" or ReactionLabel(reaction)
    local function InstantValue() if isRest then return settings.restLayoutInstant == true end return reaction.layoutInstant == true end
    SetLayoutChoiceState(row.instant, InstantValue())
    row.instant:SetScript("OnClick", function()
        local value = not InstantValue() or nil
        if isRest then settings.restLayoutInstant = value else reaction.layoutInstant = value end
        SetLayoutChoiceState(row.instant, value == true)
        ns:InvalidateTargetTransition(id)
    end)

    local function SizeValue() return isRest and (settings.restScale or 1) or reaction.scale end
    row.size._liveActive = nil
    SetLayoutChoiceState(row.size, false)
    row.size:GetFontString():SetTextColor(unpack(C.text))  -- a value, not a switch
    row.size:GetFontString():SetText(LayoutSizeText(SizeValue(), isRest))
    row.size:SetScript("OnClick", function()
        ns:OpenLayoutSizePicker(label, SizeValue(), settings.restScale or 1, not isRest, function(value)
            if isRest then
                settings.restScale = value and math.abs(value - 1) > 0.0001 and value or nil
            else
                reaction.scale = value
            end
            ns:InvalidateTargetTransition(id)
            row.size:GetFontString():SetText(LayoutSizeText(SizeValue(), isRest))
            if row.refitLayout then row.refitLayout() end
        end, settings, function() ns:InvalidateTargetTransition(id) end)
    end)
    SetTooltip(row.size, "Size", nil)

    local canMove = isRest or ns:LayoutReactionCanMove(reaction)
    local function PositionValue()
        if isRest then return settings.restOffsetX or 0, settings.restOffsetY or 0 end
        return reaction.offsetX, reaction.offsetY
    end
    row.position._liveActive = nil
    SetLayoutChoiceState(row.position, false)
    row.position:GetFontString():SetTextColor(unpack(C.text))
    local positionX, positionY = PositionValue()
    row.position:GetFontString():SetText(canMove and LayoutPositionText(positionX, positionY, isRest) or "Move")
    row.position:SetEnabled(canMove); row.position:SetAlpha(canMove and 1 or 0.45)
    row.position:SetScript("OnClick", function()
        if not canMove then return end
        local x, y = PositionValue()
        ns:OpenLayoutPositionPicker(label, x, y, settings.restOffsetX or 0, settings.restOffsetY or 0, not isRest, function(newX, newY)
            if isRest then
                if newX == 0 and newY == 0 then newX, newY = nil, nil end
                settings.restOffsetX, settings.restOffsetY = newX, newY
                row.position:GetFontString():SetText(LayoutPositionText(settings.restOffsetX or 0, settings.restOffsetY or 0, true))
            else
                reaction.offsetX, reaction.offsetY = newX, newY
                row.position:GetFontString():SetText(LayoutPositionText(newX, newY))
            end
            if row.refitLayout then row.refitLayout() end
            ns:InvalidateTargetTransition(id)
        end)
    end)
    SetTooltip(row.position, "Position", not canMove and "Mouseover: size only" or "x right, y up")

    -- Buttons are as wide as their text; the group sits beside the toggle
    -- when it fits there and otherwise on a second line.
    local function Fit(button, minimum)
        local width = math.max(minimum, math.ceil(button:GetFontString():GetStringWidth()) + 12)
        button:SetWidth(width)
        return width
    end
    row.refitLayout = function() return Fit(row.size, 40), Fit(row.position, 40) end
    local sizeWidth, positionWidth = row.refitLayout()
    row.instant:SetWidth(46)
    local groupWidth = 46 + 5 + sizeWidth + 5 + positionWidth + 8
    local content = ns.Options and ns.Options.reactionContent
    local rowWidth = content and content:GetWidth() or 0
    -- 12 px of slack: text widths are measured, not guaranteed.
    local inline = rowWidth - (rightReserve or 0) - (leftUsed or 0) >= groupWidth + 12
    row.position:ClearAllPoints()
    if inline then row.position:SetPoint("RIGHT", row.layoutToggle, "LEFT", -8, 0)
    else row.position:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -40) end
    row.layoutInline = inline
    row:SetHeight(inline and 39 or LAYOUT_CARD_HEIGHT)
    return inline
end

-- Size / Position buttons light up on the rule that currently decides them.
function ns:RefreshLayoutLiveState()
    local panel = self.Options
    if not panel or not panel.selected or not self.GetFrameLayoutState then return end
    local record = self:GetFrameLayoutState(panel.selected)
    local owned = record ~= nil and not record.releasing
    local scaleIndex, positionIndex = owned and record.scaleIndex, owned and record.positionIndex
    local settings = self:GetTargetSettings(panel.selected)
    local rows = panel.reactionContent and panel.reactionContent._reactionRows
    for index in ipairs(settings and settings.reactions or {}) do
        local row = rows and rows[index]
        if row and row:IsShown() and row.size then
            SetLayoutLiveState(row.size, owned and scaleIndex == index)
            SetLayoutLiveState(row.position, owned and positionIndex == index)
        end
    end
    local rest = panel.otherwiseRow
    if rest and rest.size then
        SetLayoutLiveState(rest.size, owned and not scaleIndex)
        SetLayoutLiveState(rest.position, owned and not positionIndex)
    end
end

function ns:GetLayoutStatusNote(id)
    if not id or not self.GetFrameLayoutState or not self.TargetUsesLayout then return nil end
    local settings = self:GetTargetSettings(id)
    if not settings or not self:TargetUsesLayout(settings) then return nil end
    local record, reason = self:GetFrameLayoutState(id)
    if record then
        if record.waiting then return "size after combat" end
        if record.paused == "editMode" then return "normal in Edit Mode" end
        return nil
    end
    if reason then return "fade only" end
    return nil
end

function ns:CreateDurationPicker()
    if self.DurationPicker then return end
    local blocker = CreateFrame("Button", nil, self.Options, "BackdropTemplate")
    blocker:SetAllPoints(self.Options); blocker:SetFrameLevel(584); blocker:EnableMouse(true); blocker:RegisterForClicks("AnyUp")
    blocker:SetScript("OnClick", function() if ns.DurationPicker then ns.DurationPicker:Hide() end end)
    Backdrop(blocker, { 0, 0, 0, 0.22 }, { 0, 0, 0, 0 }); blocker:Hide()
    local picker = CreateFrame("Frame", "FrameGambitDuration", self.Options, "BackdropTemplate")
    picker:SetSize(294, 148); picker:SetFrameStrata("FULLSCREEN_DIALOG"); picker:SetFrameLevel(585); picker:EnableMouse(true)
    Backdrop(picker, C.panel, C.accent); picker:Hide(); picker.blocker = blocker; self.DurationPicker = picker
    ApplyEUIObject("panel", picker, { inset = true })
    table.insert(UISpecialFrames, picker:GetName())
    picker.title = Text(picker, "GameFontNormal", "Reaction duration", C.accent); picker.title:SetPoint("TOPLEFT", 14, -13)
    picker.value = Text(picker, "GameFontNormal", "", C.teal); picker.value:SetPoint("TOPRIGHT", -42, -13)
    local close = CloseButton(picker); close:SetPoint("TOPRIGHT", -9, -9)
    picker.slider = CreateFrame("Slider", nil, picker, "BackdropTemplate")
    picker.slider:SetPoint("TOPLEFT", 16, -46); picker.slider:SetPoint("TOPRIGHT", -16, -46); picker.slider:SetHeight(14)
    picker.slider:SetOrientation("HORIZONTAL")
    picker.slider:SetMinMaxValues(0.5, 30); picker.slider:SetValueStep(0.25); picker.slider:SetObeyStepOnDrag(true)
    Backdrop(picker.slider, C.cardAlt, C.border)
    local thumb = picker.slider:CreateTexture(nil, "OVERLAY"); thumb:SetSize(12, 20); SetTealTexture(thumb); picker.slider:SetThumbTexture(thumb)
    if ns.LegacySkin then ns.LegacySkin:Slider(picker.slider) end
    picker.presets = {}
    for index, value in ipairs({ 1, 2, 3, 4, 6, 10 }) do
        local presetValue = value
        local button = Button(picker, Seconds(value), 39, function() picker.slider:SetValue(presetValue) end)
        button:SetPoint("TOPLEFT", 16 + (index - 1) * 44, -78); picker.presets[#picker.presets + 1] = { button = button, value = value }
    end
    function picker:UpdateVisuals(value)
        self.value:SetText(Seconds(value))
        for _, preset in ipairs(self.presets) do
            local selected = math.abs(value - preset.value) < 0.01
            preset.button._selected, preset.button._selectedColor = selected, C.teal
            SetFallbackBackdrop(preset.button, selected and C.teal or C.cardAlt)
            preset.button:GetFontString():SetTextColor(unpack(SelectedButtonText(preset.button, selected, C.accent)))
        end
    end
    picker.done = Button(picker, "Done", 66, function() picker:Hide() end, true); picker.done:SetPoint("BOTTOMRIGHT", -12, 12)
    picker.slider:SetScript("OnValueChanged", function(_, value)
        if not picker.apply then return end
        value = math.floor(value * 4 + 0.5) / 4
        picker:UpdateVisuals(value); picker.apply(value)
    end)
    picker:SetScript("OnHide", function()
        picker.blocker:Hide(); picker.apply = nil
    end)
end

function ns:OpenDurationPicker(label, value, apply)
    self:CreateDurationPicker()
    local picker = self.DurationPicker
    local normalized = NormalizedDuration(value)
    picker.title:SetText(label .. " duration")
    picker.apply = apply
    picker.slider:SetValue(normalized)
    picker:UpdateVisuals(normalized)
    picker:ClearAllPoints(); picker:SetPoint("CENTER", self.Options, "CENTER", 0, 0)
    self:HideAppearancePicker(); picker.blocker:Show(); picker:Show()
end

function ns:CreateTimingPicker()
    if self.TimingPicker then return end
    local blocker = CreateFrame("Button", nil, self.Options, "BackdropTemplate")
    blocker:SetAllPoints(self.Options); blocker:SetFrameLevel(586); blocker:EnableMouse(true); blocker:RegisterForClicks("AnyUp")
    blocker:SetScript("OnClick", function() if ns.TimingPicker then ns.TimingPicker:Hide() end end)
    Backdrop(blocker, { 0, 0, 0, 0.22 }, { 0, 0, 0, 0 }); blocker:Hide()
    local picker = CreateFrame("Frame", "FrameGambitTiming", self.Options, "BackdropTemplate")
    picker:SetSize(318, 262); picker:SetFrameStrata("FULLSCREEN_DIALOG"); picker:SetFrameLevel(587); picker:EnableMouse(true)
    Backdrop(picker, C.panel, C.accent); picker:Hide(); picker.blocker = blocker; self.TimingPicker = picker
    ApplyEUIObject("panel", picker, { inset = true, listArt = true })
    table.insert(UISpecialFrames, picker:GetName())
    picker.title = Text(picker, "GameFontNormal", "Frame timing", C.accent); picker.title:SetPoint("TOPLEFT", 14, -13)
    picker.help = Text(picker, "GameFontHighlightSmall", "", C.muted); picker.help:SetPoint("TOPLEFT", picker.title, "BOTTOMLEFT", 0, -3); picker.help:SetWidth(276); picker.help:SetJustifyH("LEFT"); picker.help:SetWordWrap(false)
    local close = CloseButton(picker); close:SetPoint("TOPRIGHT", -9, -9)
    picker.fadeLabel = Text(picker, "GameFontHighlightSmall", "Fade-in time", C.teal); picker.fadeLabel:SetPoint("TOPLEFT", 16, -58)
    picker.fadeValue = Text(picker, "GameFontHighlightSmall", "", C.teal); picker.fadeValue:SetPoint("TOPRIGHT", -18, -58)
    picker.fade = CreateFrame("Slider", nil, picker, "BackdropTemplate")
    picker.fade:SetPoint("TOPLEFT", 16, -80); picker.fade:SetPoint("TOPRIGHT", -16, -80); picker.fade:SetHeight(14)
    picker.fade:SetOrientation("HORIZONTAL")
    picker.fade:SetMinMaxValues(0.05, 2); picker.fade:SetValueStep(0.05); picker.fade:SetObeyStepOnDrag(true); Backdrop(picker.fade, C.cardAlt, C.border)
    local fadeThumb = picker.fade:CreateTexture(nil, "OVERLAY"); fadeThumb:SetSize(12, 20); SetTealTexture(fadeThumb); picker.fade:SetThumbTexture(fadeThumb)
    if ns.LegacySkin then ns.LegacySkin:Slider(picker.fade) end
    picker.fadeOutLabel = Text(picker, "GameFontHighlightSmall", "Fade-out time", C.teal); picker.fadeOutLabel:SetPoint("TOPLEFT", 16, -116)
    picker.fadeOutValue = Text(picker, "GameFontHighlightSmall", "", C.teal); picker.fadeOutValue:SetPoint("TOPRIGHT", -18, -116)
    picker.fadeOut = CreateFrame("Slider", nil, picker, "BackdropTemplate")
    picker.fadeOut:SetPoint("TOPLEFT", 16, -138); picker.fadeOut:SetPoint("TOPRIGHT", -16, -138); picker.fadeOut:SetHeight(14)
    picker.fadeOut:SetOrientation("HORIZONTAL")
    picker.fadeOut:SetMinMaxValues(0.05, 2); picker.fadeOut:SetValueStep(0.05); picker.fadeOut:SetObeyStepOnDrag(true); Backdrop(picker.fadeOut, C.cardAlt, C.border)
    local fadeOutThumb = picker.fadeOut:CreateTexture(nil, "OVERLAY"); fadeOutThumb:SetSize(12, 20); SetTealTexture(fadeOutThumb); picker.fadeOut:SetThumbTexture(fadeOutThumb)
    if ns.LegacySkin then ns.LegacySkin:Slider(picker.fadeOut) end
    picker.delayLabel = Text(picker, "GameFontHighlightSmall", "Wait before fade-out", C.teal); picker.delayLabel:SetPoint("TOPLEFT", 16, -174)
    picker.delayValue = Text(picker, "GameFontHighlightSmall", "", C.teal); picker.delayValue:SetPoint("TOPRIGHT", -18, -174)
    picker.delay = CreateFrame("Slider", nil, picker, "BackdropTemplate")
    picker.delay:SetPoint("TOPLEFT", 16, -196); picker.delay:SetPoint("TOPRIGHT", -16, -196); picker.delay:SetHeight(14)
    picker.delay:SetOrientation("HORIZONTAL")
    picker.delay:SetMinMaxValues(0, 15); picker.delay:SetValueStep(0.05); picker.delay:SetObeyStepOnDrag(true); Backdrop(picker.delay, C.cardAlt, C.border)
    local delayThumb = picker.delay:CreateTexture(nil, "OVERLAY"); delayThumb:SetSize(12, 20); SetTealTexture(delayThumb); picker.delay:SetThumbTexture(delayThumb)
    if ns.LegacySkin then ns.LegacySkin:Slider(picker.delay) end
    picker.done = Button(picker, "Done", 66, function() picker:Hide() end, true); picker.done:SetPoint("BOTTOMRIGHT", -12, 12)
    function picker:UpdateVisuals()
        self.fadeValue:SetText(self.hostTiming and "automatic" or string.format("%.2fs", self.fade:GetValue()))
        self.fadeOutValue:SetText(self.hostTiming and "automatic" or string.format("%.2fs", self.fadeOut:GetValue()))
        self.delayValue:SetText(string.format("%.2fs", self.delay:GetValue()))
    end
    local function ApplyTiming()
        if picker.loading then return end
        local settings = picker.targetID and ns:GetTargetSettings(picker.targetID)
        if not settings then return end
        if not picker.hostTiming then
            settings.fadeInDuration = math.floor(picker.fade:GetValue() * 100 + 0.5) / 100
            settings.fadeOutDuration = math.floor(picker.fadeOut:GetValue() * 100 + 0.5) / 100
        end
        settings.fadeDelay = math.floor(picker.delay:GetValue() * 100 + 0.5) / 100
        ns:InvalidateTargetTransition(picker.targetID)
        picker:UpdateVisuals()
    end
    picker.fade:SetScript("OnValueChanged", ApplyTiming); picker.fadeOut:SetScript("OnValueChanged", ApplyTiming); picker.delay:SetScript("OnValueChanged", ApplyTiming)
    picker:SetScript("OnHide", function()
        local targetID = picker.targetID
        picker.blocker:Hide(); picker.targetID = nil; picker.hostTiming = nil
        if targetID and ns.Options and ns.Options:IsVisible() and ns.Options.selected == targetID then
            ns:RenderSelectedTarget(targetID)
        end
    end)
end

function ns:OpenTimingPicker(id, settings)
    self:CreateTimingPicker()
    local picker = self.TimingPicker
    local target = self.TargetByID[id]
    picker.targetID, picker.loading = id, true
    picker.hostTiming = target and target.timingOwner == "host" or false
    picker.help:SetText(picker.hostTiming
        and (target.timingNote or "Fade speed set by its addon")
        or (ns.TargetUsesLayout and ns:TargetUsesLayout(settings) and "Also for size and position"
        or ""))
    picker.fadeLabel:SetText(picker.hostTiming and (target.timingLabel or "Host fade") or "Fade-in time")
    picker.fade:SetEnabled(not picker.hostTiming)
    picker.fade:SetAlpha(picker.hostTiming and 0.35 or 1)
    picker.fadeOut:SetEnabled(not picker.hostTiming)
    picker.fadeOut:SetAlpha(picker.hostTiming and 0.35 or 1)
    picker.fadeOut:SetValue(settings.fadeOutDuration)
    picker.fade:SetValue(settings.fadeInDuration); picker.delay:SetValue(settings.fadeDelay)
    picker.loading = nil; picker:UpdateVisuals()
    picker:ClearAllPoints(); picker:SetPoint("CENTER", self.Options, "CENTER", 0, 0)
    self:HideAppearancePicker(); picker.blocker:Show(); picker:Show()
end

function ns:RenderTargetRail()
    local panel = self.Options
    if not panel or not panel:IsVisible() then return end
    local query = (panel.targetQuery or ""):match("^%s*(.-)%s*$"):lower()
    local profileTargets = self:Profile().targets
    ClearChildren(panel.targetContent)
    panel.tutorialTargetRow = nil
    panel.targetContent._targetRows = panel.targetContent._targetRows or {}
    local orderedTargets, depthByID = {}, {}
    local targetByID, managed, visited = {}, {}, {}
    for _, target in ipairs(self.Targets) do
        targetByID[target.id] = target
        local settings = profileTargets[target.id]
        if settings and settings.enabled ~= false then managed[target.id] = true end
    end
    local function Append(id, depth)
        if visited[id] or not managed[id] or not targetByID[id] then return end
        visited[id], depthByID[id] = true, depth
        orderedTargets[#orderedTargets + 1] = targetByID[id]
        for _, candidate in ipairs(self.Targets) do
            if self:GetVisibilityChildren(id)[candidate.id] then Append(candidate.id, depth + 1) end
        end
    end
    for _, target in ipairs(self.Targets) do
        if managed[target.id] and not self:GetVisibilityParent(target.id) then Append(target.id, 0) end
    end
    for _, target in ipairs(self.Targets) do if managed[target.id] then Append(target.id, 0) end end
    for _, target in ipairs(self.Targets) do
        if not managed[target.id] then orderedTargets[#orderedTargets + 1] = target end
    end
    -- The guided tutorial owns one session-only target. Keep it first in the
    -- real rail so the player learns on the actual controls without hunting
    -- through their personal target catalog.
    local tutorialID = self.Tutorial and self.Tutorial.targetID
    if tutorialID and self.TargetByID[tutorialID] then
        local prioritized = { self.TargetByID[tutorialID] }
        for _, target in ipairs(orderedTargets) do
            if target.id ~= tutorialID then prioritized[#prioritized + 1] = target end
        end
        orderedTargets, depthByID[tutorialID] = prioritized, 0
    end
    local y = 0
    local shown = 0
    for _, target in ipairs(orderedTargets) do
        local searchable = (target.label .. " " .. (target.source or "") .. " " .. target.id):lower()
        local settings = profileTargets[target.id]
        local isManaged = settings ~= nil and settings.enabled ~= false
        if query == "" or searchable:find(query, 1, true) then
            shown = shown + 1
            local index = shown
            local targetID = target.id
            local available, _, status, statusNote = self:GetTargetAvailability(target)
            local chosen = panel.selected == target.id
            local row = panel.targetContent._targetRows[index]
            if not row then
                row = Button(panel.targetContent, "", 172, nil)
                row.dot = row:CreateTexture(nil, "OVERLAY"); row.dot:SetSize(5, 5); row.dot:SetPoint("LEFT", 7, 0)
                local label = row:GetFontString()
                label:ClearAllPoints()
                -- Leave a deliberate second-square-sized breath after the status dot.
                label:SetPoint("LEFT", row, "LEFT", 22, 0)
                label:SetPoint("RIGHT", row, "RIGHT", -7, 0)
                label:SetJustifyH("LEFT")
                label:SetWordWrap(false)
                if label.SetMaxLines then label:SetMaxLines(1) end
                panel.targetContent._targetRows[index] = row
            end
            local depth = depthByID[target.id] or 0
            local indent = math.min(36, depth * 12)
            row:SetWidth(math.max(1, panel.targetScroll:GetWidth() - indent))
            row:Show(); row:ClearAllPoints(); row:SetPoint("TOPLEFT", indent, -y); y = y + 27
            row._primary = chosen
            if targetID == tutorialID then panel.tutorialTargetRow = row end
            row._targetID, row._managed = targetID, isManaged
            SetFallbackBackdrop(row, chosen and C.accent or C.cardAlt, C.border)
            local rowTextColor = chosen and { 1, 1, 1, 1 }
                or isManaged and (available and C.accent or C.amber)
                or C.muted
            local rowDotColor = isManaged and (available and C.accent or C.amber) or C.muted
            row:GetFontString():SetText((depth > 0 and ">  " or "") .. target.label)
            row:GetFontString():SetTextColor(unpack(rowTextColor))
            row.dot:SetColorTexture(unpack(rowDotColor))
            SetTooltip(row, target.label, status .. ": " .. statusNote)
            row:SetScript("OnClick", function()
                panel.selected = targetID
                if panel.peeking then
                    local selected = ns.TargetByID[targetID]
                    if ns.PeekBar then ns.PeekBar.label:SetText("Viewing: " .. (selected and selected.label or "game UI")) end
                    ns:RenderTargetRail()
                    ns:RefreshSelectionOutline()
                    return
                end
                ns:RenderOptions()
            end)
            row:RegisterForDrag("LeftButton")
            row:SetScript("OnDragStart", function(self)
                if panel.peeking or not self._managed then return end
                ns:StartTargetDrag(self._targetID, self, available)
            end)
            row:SetScript("OnDragStop", function() ns:FinishTargetDrag() end)
            if not row._treeHoverHooked then
                row:HookScript("OnEnter", function(self)
                    if panel.peeking then
                        panel.peekHoverID = self._targetID
                        local hovered = ns.TargetByID[self._targetID]
                        if ns.PeekBar then ns.PeekBar.label:SetText("Viewing: " .. (hovered and hovered.label or "game UI")) end
                        ns:RefreshSelectionOutline()
                    end
                    if panel.treeDragID and panel.treeDragID ~= self._targetID and self._managed then
                        panel.treeDropID = self._targetID
                        if not self._frameGambitEUI then self:SetBackdropBorderColor(unpack(C.teal)) end
                    end
                end)
                row:HookScript("OnLeave", function(self)
                    if panel.peeking and panel.peekHoverID == self._targetID then
                        panel.peekHoverID = nil
                        local selected = panel.selected and ns.TargetByID[panel.selected]
                        if ns.PeekBar then ns.PeekBar.label:SetText("Viewing: " .. (selected and selected.label or "game UI")) end
                        ns:RefreshSelectionOutline()
                    end
                    if panel.treeDropID == self._targetID then
                        panel.treeDropID = nil
                        if not self._frameGambitEUI then self:SetBackdropBorderColor(unpack(C.border)) end
                    end
                end)
                row._treeHoverHooked = true
            end
            row:SetAlpha(chosen and 1 or isManaged and (available and 1 or 0.78) or 0.55)
            panel.targetContent._rows[#panel.targetContent._rows + 1] = row
        end
    end
    if shown == 0 then
        local empty = panel.targetContent.empty
        if not empty then
            empty = Text(panel.targetContent, "GameFontHighlightSmall", "No frames", C.muted)
            empty:SetPoint("TOPLEFT", 7, 0); empty:SetWidth(154); empty:SetJustifyH("LEFT"); empty:SetWordWrap(true)
            panel.targetContent.empty = empty
        end
        empty:SetText("No matches")
        empty:Show(); panel.targetContent._rows[#panel.targetContent._rows + 1] = empty; y = 38
    end
    panel.targetContent:SetHeight(math.max(1, y))
    if panel.targetScroll then
        panel.targetScroll:SetVerticalScroll(math.min(panel.targetScroll:GetVerticalScroll(), panel.targetScroll:GetVerticalScrollRange()))
    end
end

function ns:RenderOptions()
    local panel = self.Options
    if not panel or not panel:IsVisible() then return end
    self:ApplyEditorTheme()
    self:RefreshAppearanceControls()
    self:RefreshCinematicEditorControls()
    self:ApplyPanelLayout()
    if panel.profile then
        local cinematicActive = self:IsCinematicActive()
        panel.profile.label:SetText(cinematicActive and "Editing: Cinematic" or ("Profile: " .. ShortText(FrameGambitDB.profile or "Default", 16)))
        panel.profile.arrow:Show()
        panel.profile.label:ClearAllPoints(); panel.profile.label:SetPoint("LEFT", 8, 0)
        panel.profile.label:SetPoint("RIGHT", panel.profile.arrow, "LEFT", activeAppearanceID == "legacy" and -6 or -2, 0)
        panel.profile.label:SetJustifyH("LEFT")
        SetFallbackBackdrop(panel.profile, nil, cinematicActive and CINEMATIC_ACCENT or C.border)
        panel.profile.label:SetTextColor(unpack(cinematicActive and CINEMATIC_ACCENT or C.accent))
        panel.profile:EnableMouse(true)
        panel.cinematic:SetShown(true)
        panel.cinematic:EnableMouse(true)
        panel.cinematic:GetFontString():SetText(cinematicActive and "Exit Cinematic" or "Edit Cinematic")
        panel.cinematic._tooltipTitle, panel.cinematic._tooltipBody = nil, nil
    end
    if not panel.selected or not self.TargetByID[panel.selected] then
        panel.selected = nil
        for _, target in ipairs(self.Targets) do
            if self:Profile().targets[target.id] then panel.selected = target.id; break end
        end
    end
    self:RenderTargetRail()
    self:RenderSelectedTarget(panel.selected)
    self:FitWorkspaceCards()
    self:RefreshSelectionOutline()
    if self.Tutorial and self.RefreshTutorial then self:RefreshTutorial() end
end

function ns:RefreshSelectionOutline()
    local outline, panel = self.SelectionOutline, self.Options
    local outlineID = panel and panel.peeking and (panel.peekHoverID or panel.selected) or panel and panel.selected
    if not outline or not panel or (not panel:IsVisible() and not panel.peeking)
        or panel.selectionOutlineEnabled == false or not outlineID then
        if outline then outline:SetScript("OnUpdate", nil); outline:Hide() end
        return
    end
    local frame = self:ResolveTarget(outlineID)
    local left, bottom, width, height
    if frame then left, bottom, width, height = self:GetUsableFrameRect(frame) end
    if not left then outline:SetScript("OnUpdate", nil); outline:Hide(); return end
    outline:ClearAllPoints()
    outline:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left - 3, bottom - 3)
    outline:SetSize(width + 6, height + 6)
    outline:SetBackdropBorderColor(unpack(C.teal))
    if not outline:GetScript("OnUpdate") then outline:SetScript("OnUpdate", outline._ticker) end
    outline:Show()
end

function ns:RenderSelectedTarget(id)
    local panel = self.Options
    ClearChildren(panel.reactionContent); ClearChildren(panel.presenceContent)
    panel.addReactionButton, panel.otherwiseRow, panel.outlineButton, panel.tutorialUseButton = nil, nil, nil, nil
    local target = self.TargetByID[id]
    local settings = target and self:GetTargetSettings(id) or nil
    local canForget = target ~= nil and self:CanForgetCustomTarget(id)
    panel.forgetTarget:SetShown(canForget)
    if panel.forgetArmed ~= id then
        panel.forgetArmed = nil
        panel.forgetTarget:GetFontString():SetText("Remove from list")
    end
    local canPaste = target ~= nil and self:CanPasteTargetRules()
    panel.copyRules:SetEnabled(settings ~= nil); panel.copyRules:SetAlpha(settings and 1 or 0.42)
    panel.pasteRules:SetEnabled(canPaste); panel.pasteRules:SetAlpha(canPaste and 1 or 0.42)
    local pasteFill = LiveStateFill()
    panel.pasteRules._selected, panel.pasteRules._selectedColor = canPaste, canPaste and pasteFill or nil
    SetFallbackBackdrop(panel.pasteRules, canPaste and pasteFill or C.cardAlt,
        canPaste and C.teal or C.border)
    panel.pasteRules:GetFontString():SetTextColor(unpack(canPaste and C.teal or C.muted))
    if not target then
        panel.centerTitle:SetText("Choose a frame")
        panel.centerHint:SetText("")
        panel.active:SetText("")
        panel.active:SetTextColor(unpack(C.muted))
        local begin = Button(panel.reactionContent, "Pick a frame", 116, function() ns:StartPicker() end, true)
        begin:SetPoint("TOPLEFT", 0, 0)
        panel.reactionContent._rows[#panel.reactionContent._rows + 1] = begin
        panel.reactionContent:SetHeight(30)
        self:FitWorkspaceCards()
        return
    end
    local available, _, status, statusNote, statusTone = self:GetTargetAvailability(target)
    if not available then
        panel.centerTitle:SetText(target.label .. " is unavailable")
        panel.centerHint:SetText("")
        panel.active:SetText(status)
        panel.active:SetTextColor(unpack(C[statusTone] or C.amber))
        local detail = Text(panel.reactionContent, "GameFontHighlightSmall", statusNote, C.muted)
        detail:SetPoint("TOPLEFT", 0, 0); detail:SetPoint("RIGHT", -10, 0); detail:SetJustifyH("LEFT"); detail:SetWordWrap(true)
        panel.reactionContent._rows[#panel.reactionContent._rows + 1] = detail
        local help = Text(panel.reactionContent, "GameFontHighlightSmall", "Rules kept", C.muted)
        help:SetPoint("TOPLEFT", detail, "BOTTOMLEFT", 0, -10); help:SetPoint("RIGHT", -10, 0); help:SetJustifyH("LEFT"); help:SetWordWrap(true)
        panel.reactionContent._rows[#panel.reactionContent._rows + 1] = help
        panel.reactionContent:SetHeight(82)
        self:FitWorkspaceCards()
        return
    end
    panel.centerTitle:SetText(target.label)
    panel.centerHint:SetText("First match wins")
    if not settings then
        panel.active:SetText("No rules yet")
        panel.active:SetTextColor(unpack(C.muted))
        local use = Button(panel.reactionContent, "Use this frame", 130, function()
            ns:AddTarget(id)
            ns:RenderOptions()
        end, true)
        panel.tutorialUseButton = use
        use:SetPoint("TOPLEFT", 0, 0)
        panel.reactionContent._rows[#panel.reactionContent._rows + 1] = use
        local help = Text(panel.reactionContent, "GameFontHighlightSmall", "Mouseover and In combat: 100%. Otherwise: 12%", C.muted)
        help:SetPoint("TOPLEFT", use, "BOTTOMLEFT", 0, -10)
        help:SetPoint("RIGHT", -10, 0)
        help:SetJustifyH("LEFT"); help:SetWordWrap(true)
        panel.reactionContent._rows[#panel.reactionContent._rows + 1] = help
        panel.reactionContent:SetHeight(70)
        self:FitWorkspaceCards()
        return
    end
    self:RefreshActiveState()

    local y = 0
    local activeState = ns.runtime.active[id]
    local activeReactionIndex = LocalActiveReactionIndex(activeState)
    -- Size and position controls appear only on frames that can be resized,
    -- or where saved rules already use them (so they can be turned off).
    local layoutSupported = ns.GetFrameLayoutSupport and ns:GetFrameLayoutSupport(id) or false
    local layoutAvailable = layoutSupported or (ns.TargetUsesLayout and ns:TargetUsesLayout(settings)) or false
    panel.liveReactionTargetID, panel.liveReactionIndex = id, activeReactionIndex
    panel.reactionContent._reactionRows = panel.reactionContent._reactionRows or {}
    for index, reaction in ipairs(settings.reactions) do
        local reactionIndex, reactionData = index, reaction
        local row = panel.reactionContent._reactionRows[index]
        if not row then
            row = NewReactionRow(panel.reactionContent)
            panel.reactionContent._reactionRows[index] = row
        end
        row:Show(); row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -y); row:SetPoint("TOPRIGHT", 0, -y)
        row.handle._targetID, row.handle._reaction, row.handle._row = id, reactionData, row
        row._tutorialReaction = reactionData
        local isActive = activeReactionIndex == index
        local isEnabled = reactionData.enabled ~= false
        -- A non-matching reaction is still a fully editable live rule.  Its
        -- normal card treatment already distinguishes it from the teal/orange
        -- winning row; opacity is reserved for an explicitly disabled row.
        SetReactionRowLiveState(row, isActive, isEnabled)
        local requirementCount = #(reactionData.requirements or {})
        local info = ns.CONDITION_INFO[reactionData.condition]
        local isMoment = info and info.kind == "moment"
        local isForm = reactionData.condition == "form"
        local booleanField = ns:GetBooleanConditionField(reactionData.condition)
        local isMovement = booleanField ~= nil
        local isSpec = reactionData.condition == "spec"
        local isChatText = reactionData.condition == "chat_text"
        local isPercentage = ns:IsPercentageCondition(reactionData.condition)
        local layoutOpen = layoutAvailable and reactionData.layoutLine == true
        row.layoutToggle:ClearAllPoints(); row.layoutToggle:SetPoint("RIGHT", row.opacity, "LEFT", -5, 0)
        row.layoutToggle:SetShown(layoutAvailable)
        row.label:SetText(ReactionLabel(reactionData))
        local leftUsed
        if isPercentage or isChatText or isForm or isSpec then
            leftUsed = 92 + (isPercentage and 190 or 132) + (isForm and 49 or 0) + 8
        elseif isMovement then
            leftUsed = 92 + math.ceil(row.label:GetStringWidth()) + 10 + 44 + 8
        else
            leftUsed = 92 + row.label:GetStringWidth() + 8
        end
        local layoutInline = ns:ConfigureLayoutLine(row, id, settings, reactionData, layoutAvailable, layoutOpen,
            leftUsed, 168 + (isMoment and 45 or 0))
        local beforeRequirements = layoutInline and row.instant or (layoutAvailable and row.layoutToggle or row.opacity)
        row.duration:ClearAllPoints(); row.duration:SetPoint("RIGHT", beforeRequirements, "LEFT", -5, 0)
        row.label:ClearAllPoints(); row.label:SetPoint("LEFT", row.requirements, "RIGHT", 6, 0)
        row.label:SetPoint("RIGHT", isMovement and row.formExpected or (isMoment and row.duration or beforeRequirements), "LEFT", -5)
        row.label:SetText(ReactionLabel(reactionData)); row.opacity:GetFontString():SetText(Percent(reactionData.opacity))
        row.label:SetShown(not isForm and not isSpec and not isChatText and not isPercentage)
        row.formPicker:SetShown(isForm or isSpec or isChatText or isPercentage)
        row.formPicker:SetWidth(isPercentage and 190 or 132); row.formExpected:SetShown(isForm or isMovement)
        SetTooltip(row.formPicker, ReactionLabel(reactionData), info and info.help)
        if isPercentage then
            row.formPicker:GetFontString():SetText(ReactionLabel(reactionData))
            row.formPicker:SetAlpha(1)
            row.formPicker:SetScript("OnClick", function() ns:OpenPercentagePicker(id, reactionData) end)
            row.formExpected:SetCallback(nil)
        elseif isChatText then
            row.formPicker:GetFontString():SetText(ReactionLabel(reactionData))
            row.formPicker:SetAlpha(1)
            row.formPicker:SetScript("OnClick", function() ns:OpenChatTextPicker(id, reactionData) end)
            row.formExpected:SetCallback(nil)
        elseif isForm then
            row.formExpected:SetTips("Form is active", nil,
                "Form is inactive", nil)
            local option = ns.FORM_BY_ID and ns.FORM_BY_ID[reactionData.formKey]
            local formAvailable = option and ns:GetFormActivity(reactionData.formKey) ~= nil
            row.formPicker:GetFontString():SetText(option and ("Form: " .. option.label) or "Form: choose one")
            row.formPicker:SetAlpha(formAvailable and 1 or 0.58)
            row.formPicker:SetScript("OnClick", function() ns:OpenFormPicker(id, reactionData) end)
            row.formExpected:ClearAllPoints(); row.formExpected:SetPoint("LEFT", row.formPicker, "RIGHT", 5, 0)
            row.formExpected:SetValue(reactionData.formExpected ~= false)
            row.formExpected:SetCallback(function(value)
                reactionData.formExpected = value
                ns:InvalidateTargetTransition(id)
                ns:RenderSelectedTarget(id)
            end)
        elseif isMovement then
            local yesTitle = info and info.gamepad and (info.label .. ": Yes") or "Movement: Yes"
            local noTitle = info and info.gamepad and (info.label .. ": No") or "Movement: No"
            row.formExpected:SetTips(yesTitle, info and info.help,
                noTitle, info and info.help)
            row.formPicker:SetScript("OnClick", nil)
            -- The answer button sits right after the full condition name.
            row.formExpected:ClearAllPoints(); row.formExpected:SetPoint("LEFT", row.requirements, "RIGHT", 6 + math.ceil(row.label:GetStringWidth()) + 10, 0)
            row.formExpected:SetValue(reactionData[booleanField] ~= false)
            row.formExpected:SetCallback(function(value)
                reactionData[booleanField] = value
                ns:InvalidateTargetTransition(id)
                ns:RenderSelectedTarget(id)
            end)
        elseif isSpec then
            local option = ns.SPEC_BY_ID and ns.SPEC_BY_ID[reactionData.specID]
            local specAvailable = option and ns:GetSpecActivity(reactionData.specClass, reactionData.specID) ~= nil
            row.formPicker:GetFontString():SetText(option and ("Spec: " .. option.label) or "Spec: choose one")
            row.formPicker:SetAlpha(specAvailable and 1 or 0.58)
            row.formPicker:SetScript("OnClick", function() ns:OpenSpecPicker(id, reactionData) end)
            row.formExpected:SetCallback(nil)
        else
            row.formPicker:SetScript("OnClick", nil); row.formExpected:SetCallback(nil)
        end
        row.enabled._selected, row.enabled._selectedColor = isEnabled, C.teal
        SetFallbackBackdrop(row.enabled, isEnabled and C.teal or C.cardAlt)
        row.enabled:GetFontString():SetText(isEnabled and "On" or "Off")
        row.enabled:GetFontString():SetTextColor(unpack(SelectedButtonText(row.enabled, isEnabled, C.muted, C.muted)))
        row.enabled:SetScript("OnClick", function()
            if isEnabled and reactionData.condition == "mouseover" and #(reactionData.requirements or {}) == 0
                and ns:RequiresUnconditionalMouseover(id) and ns:CountUnconditionalMouseover(settings) <= 1 then
                ns:ShowEditorNotice("Relationship needs a Mouseover row", "amber")
                return
            end
            reactionData.enabled = not isEnabled
            ns:InvalidateTargetTransition(id)
            ns:RenderSelectedTarget(id)
        end)
        row.opacity:SetScript("OnClick", function(self, button)
            local keepOption
            if layoutOpen then
                keepOption = {
                    get = function() return reactionData.keepOpacity == true end,
                    set = function(keep)
                        if keep and reactionData.condition == "mouseover" and #(reactionData.requirements or {}) == 0
                            and ns:RequiresUnconditionalMouseover(id) and ns:CountUnconditionalMouseover(settings) <= 1 then
                            return false, "Relationship needs a Mouseover row"
                        end
                        reactionData.keepOpacity = keep or nil
                        ns:InvalidateTargetTransition(id)
                        row.opacity:GetFontString():SetText(keep and "Keep" or Percent(reactionData.opacity))
                    end,
                }
            end
            ns:OpenOpacityPicker(ReactionLabel(reactionData), reactionData.opacity, function(value)
                reactionData.opacity = value
                -- Choosing an opacity turns Keep opacity off again.
                reactionData.keepOpacity = nil
                ns:InvalidateTargetTransition(id)
                row.opacity:GetFontString():SetText(Percent(value))
            end, keepOption)
        end)
        if layoutAvailable and reactionData.keepOpacity then row.opacity:GetFontString():SetText("Keep") end
        SetRequirementButtonLabel(row.requirements, requirementCount > 0 and "+" .. requirementCount or "+")
        if requirementCount > 0 then
            local conditions = { ReactionLabel(reactionData) }
            for _, condition in ipairs(reactionData.requirements or {}) do
                conditions[#conditions + 1] = ConditionLabel(condition)
            end
            SetTooltip(row.requirements, "Requirements (" .. #conditions .. ")",
                "All must be true")
            row.requirements._tooltipLines = conditions
        else
            SetTooltip(row.requirements, "Requirements", nil)
            row.requirements._tooltipLines = nil
        end
        row.requirements:SetScript("OnClick", function() ns:OpenRequirementPalette(id, reactionData) end)
        if isMoment then
            row.duration:Show(); row.duration:GetFontString():SetText(Seconds(reactionData.duration or info.duration))
            row.duration:SetScript("OnClick", function()
                ns:OpenDurationPicker(ReactionLabel(reactionData), reactionData.duration or info.duration, function(value)
                    reactionData.duration = value
                    row.duration:GetFontString():SetText(Seconds(value))
                end)
            end)
        else
            row.duration:Hide(); row.duration:SetScript("OnClick", nil)
        end
        row.up:SetScript("OnClick", function()
            if reactionIndex > 1 then settings.reactions[reactionIndex], settings.reactions[reactionIndex - 1] = settings.reactions[reactionIndex - 1], settings.reactions[reactionIndex]; ns:InvalidateTargetTransition(id); ns:RenderSelectedTarget(id) end
        end)
        row.down:SetScript("OnClick", function()
            if reactionIndex < #settings.reactions then settings.reactions[reactionIndex], settings.reactions[reactionIndex + 1] = settings.reactions[reactionIndex + 1], settings.reactions[reactionIndex]; ns:InvalidateTargetTransition(id); ns:RenderSelectedTarget(id) end
        end)
        SetFallbackBackdrop(row.remove, nil, REMOVE_RED)
        for _, stroke in ipairs(row.remove.removeStrokes or {}) do stroke:SetVertexColor(unpack(REMOVE_RED)) end
        row.remove:SetScript("OnClick", function()
            if reactionData.condition == "mouseover" and #(reactionData.requirements or {}) == 0
                and ns:RequiresUnconditionalMouseover(id) and ns:CountUnconditionalMouseover(settings) <= 1 then
                ns:ShowEditorNotice("Relationship needs a Mouseover row", "amber")
                return
            end
            table.remove(settings.reactions, reactionIndex)
            ns:InvalidateTargetTransition(id)
            ns:RenderSelectedTarget(id)
        end)
        panel.reactionContent._rows[#panel.reactionContent._rows + 1] = row; y = y + row:GetHeight() + 6
    end
    local add = Button(panel.reactionContent, "+ Add reaction", 130, function() ns:OpenReactionPalette(id) end, true)
    add:SetPoint("TOPLEFT", 0, -y); panel.reactionContent._rows[#panel.reactionContent._rows + 1] = add; y = y + 38
    panel.addReactionButton = add
    local rest = CreateFrame("Frame", nil, panel.reactionContent, "BackdropTemplate")
    rest:SetSize(10, 39); rest:SetPoint("TOPLEFT", 0, -y); rest:SetPoint("TOPRIGHT", 0, -y); Backdrop(rest, { 0.045, 0.05, 0.07, 1 })
    if ns.LegacySkin then ns.LegacySkin:Row(rest, false) end
    panel.otherwiseRow = rest
    rest.line = CreateFrame("Frame", nil, rest)
    rest.line:SetPoint("TOPLEFT"); rest.line:SetPoint("TOPRIGHT"); rest.line:SetHeight(39); rest.line:EnableMouse(false)
    local restLabel = Text(rest, "GameFontHighlight", "Otherwise", C.muted); restLabel:SetPoint("LEFT", rest.line, "LEFT", 29, 0)
    local visibilityParent = ns:GetVisibilityParent(id)
    local visibilityParentTarget = visibilityParent and ns.TargetByID[visibilityParent]
    local restOpacity
    restOpacity = Button(rest, visibilityParent and ("Follow " .. (visibilityParentTarget and visibilityParentTarget.label or visibilityParent)) or Percent(settings.atRest), visibilityParent and 132 or 54, function(self, button)
        if visibilityParent then return end
        ns:OpenOpacityPicker("Otherwise", settings.atRest, function(value)
            settings.atRest = value
            ns:InvalidateTargetTransition(id)
            restOpacity:GetFontString():SetText(Percent(value))
        end)
    end)
    restOpacity:SetEnabled(not visibilityParent)
    restOpacity:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    SetTooltip(restOpacity, visibilityParent and "Follows parent" or "Otherwise opacity",
        nil)
    restOpacity:SetPoint("RIGHT", rest.line, "RIGHT", -8, 0); panel.reactionContent._rows[#panel.reactionContent._rows + 1] = rest
    AddLayoutControls(rest)
    rest.layoutToggle:SetPoint("RIGHT", restOpacity, "LEFT", -5, 0)
    ns:ConfigureLayoutLine(rest, id, settings, nil, layoutAvailable, layoutAvailable and settings.restLayoutLine == true,
        29 + 80, 8 + (visibilityParent and 132 or 54) + 5 + 22 + 5)
    panel.otherwiseRow = rest
    y = y + rest:GetHeight()
    panel.reactionContent:SetHeight(math.max(1, y))
    if panel.reactionScroll then
        panel.reactionScroll:SetVerticalScroll(math.min(panel.reactionScroll:GetVerticalScroll(), panel.reactionScroll:GetVerticalScrollRange()))
    end

    local p = panel.presenceContent
    local function OpenTiming()
        ns:OpenTimingPicker(id, settings)
    end
    -- One button opens the timing window and shows all of its values.
    local timingText
    if target.timingOwner == "host" then
        timingText = (target.timingLabel or "Host fade") .. "  /  Wait " .. Seconds(settings.fadeDelay)
    else
        timingText = "In " .. Seconds(settings.fadeInDuration) .. "  /  Out " .. Seconds(settings.fadeOutDuration)
            .. "  /  Wait " .. Seconds(settings.fadeDelay)
    end
    local fade = Button(p, timingText, 100, OpenTiming)
    fade:SetPoint("TOPLEFT", 0, 0); fade:SetPoint("TOPRIGHT", 0, 0)
    p._rows[#p._rows + 1] = fade
    local timingHelp = target.timingOwner == "host" and (target.timingNote or "Fade speed set by its addon")
        or string.format("In %.2fs, out %.2fs", settings.fadeInDuration, settings.fadeOutDuration)
    SetTooltip(fade, target.timingLabel or "Frame timing", timingHelp)
    local preview
    preview = InspectorActionCard(p, fade, "eye", "Frame outline", panel.selectionOutlineEnabled ~= false, function()
        panel.selectionOutlineEnabled = not panel.selectionOutlineEnabled
        ns:RefreshSelectionOutline(); ns:RenderSelectedTarget(id)
    end)
    SetTooltip(preview, nil, nil)
    p._rows[#p._rows + 1] = preview
    panel.outlineButton = preview
    local relationshipAnchor = preview
    if id == "minimap" then
        local order = ns.MINIMAP_NATIVE_MARKER_ORDER or { "keep", "hide_zero", "scale" }
        local labels = ns.MINIMAP_NATIVE_MARKER_MODES or {}
        local mode = labels[settings.nativeMarkerMode] and settings.nativeMarkerMode or "hide_zero"
        settings.nativeMarkerMode = mode
        local markerAvailable, markerReason = true, nil
        if ns.GetMinimapNativeMarkerAvailability then
            markerAvailable, markerReason = ns:GetMinimapNativeMarkerAvailability(mode)
        end
        local markers
        markers = Button(p, markerAvailable and ("Markers: " .. (labels[mode] or mode)) or "Markers: unavailable", 206, function()
            local modeAvailable, reason = true, nil
            if ns.GetMinimapNativeMarkerAvailability then
                modeAvailable, reason = ns:GetMinimapNativeMarkerAvailability(settings.nativeMarkerMode or "keep")
            end
            if modeAvailable == false then
                ns:ShowEditorNotice(reason or "Not in this client", "amber")
                return
            end
            local current = settings.nativeMarkerMode or "keep"
            local index = 1
            for i, value in ipairs(order) do if value == current then index = i; break end end
            settings.nativeMarkerMode = order[index % #order + 1]
            if current == "keep" and settings.nativeMarkerMode ~= "keep" and reason then
                ns:ShowEditorNotice(reason, "amber")
            end
            markers:GetFontString():SetText("Markers: " .. (labels[settings.nativeMarkerMode] or settings.nativeMarkerMode))
            markers:SetBackdropBorderColor(unpack(settings.nativeMarkerMode == "keep" and C.border or C.amber))
            if ns.UpdateMinimapStack then ns:UpdateMinimapStack(true) end
        end)
        markers:SetBackdropBorderColor(unpack(markerAvailable and mode == "keep" and C.border or C.amber))
        SetTooltip(markers, "Minimap markers",
            markerAvailable and ("Experimental. Leave unchanged is safest" .. (markerReason and ("\n\n" .. markerReason) or ""))
                or (markerReason or "Not in this client"))
        markers:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -6); p._rows[#p._rows + 1] = markers
        relationshipAnchor = markers
    end
    local _, currentRevealGroup = ns:GetRevealGroup(id)
    local currentChildren = ns:GetLinkedChildren(id)
    local currentChildCount = 0; for _ in pairs(currentChildren) do currentChildCount = currentChildCount + 1 end
    local currentVisibilityChildren = ns:GetVisibilityChildren(id)
    local currentVisibilityCount = 0; for _ in pairs(currentVisibilityChildren) do currentVisibilityCount = currentVisibilityCount + 1 end
    local group = InspectorActionCard(p, relationshipAnchor, "group", "Hover group", currentRevealGroup ~= nil, function() ns:OpenConnectionPicker("group", id) end)
    SetTooltip(group, nil, nil)
    p._rows[#p._rows + 1] = group
    local link = InspectorActionCard(p, group, "link", "Linked child", currentChildCount > 0, function() ns:OpenConnectionPicker("link", id) end)
    p._rows[#p._rows + 1] = link
    SetTooltip(link, nil, nil)
    local visibility = InspectorActionCard(p, link, "visibility", "Visibility child", currentVisibilityCount > 0, function() ns:OpenConnectionPicker("visibility", id) end)
    p._rows[#p._rows + 1] = visibility
    SetTooltip(visibility, nil, nil)
    local previous = visibility
    -- Relationship status rows: one line each, fact on the left and its
    -- undo action on the right. Stacking label-over-button doubled the
    -- height and pushed the list into the Reset frame footer.
    local function StatusRow(text, color, label, width, onClick)
        local row = CreateFrame("Frame", nil, p)
        row:SetHeight(24)
        row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, previous == visibility and -12 or -6)
        row:SetPoint("RIGHT", p, "RIGHT", 0, 0)
        local fact = Text(row, "GameFontHighlightSmall", text, color)
        fact:SetPoint("LEFT", 2, 0); fact:SetPoint("RIGHT", -(width + 8), 0)
        fact:SetJustifyH("LEFT"); fact:SetWordWrap(false)
        local action = Button(row, label, width, onClick)
        action:SetPoint("RIGHT", 0, 0)
        p._rows[#p._rows + 1] = row
        previous = row
        return row
    end
    local _, revealGroup = ns:GetRevealGroup(id)
    if revealGroup then
        local count = 0; for _ in pairs(revealGroup.members) do count = count + 1 end
        StatusRow("Together: " .. count .. " frames", C.teal, "Leave", 54, function()
            ns:RemoveFromRevealGroup(id); ns:RenderSelectedTarget(id)
        end)
    end
    local children = ns:GetLinkedChildren(id)
    local childCount = 0; for _ in pairs(children) do childCount = childCount + 1 end
    if childCount > 0 then
        StatusRow("Reveals: " .. childCount .. " frame" .. (childCount == 1 and "" or "s"), C.teal, "Clear links", 82, function()
            local linked = {}; for childID in pairs(ns:GetLinkedChildren(id)) do linked[#linked + 1] = childID end
            for _, childID in ipairs(linked) do ns:RemoveLink(id, childID) end
            ns:RenderSelectedTarget(id)
        end)
    end
    local parents = ns:GetLinkParents(id)
    if #parents > 0 then
        StatusRow("Revealed by: " .. #parents .. " source" .. (#parents == 1 and "" or "s"), C.muted, "Unlink me", 74, function()
            for _, parentID in ipairs(ns:GetLinkParents(id)) do ns:RemoveLink(parentID, id) end
            ns:RenderSelectedTarget(id)
        end)
    end
    local visibilityChildren = ns:GetVisibilityChildren(id)
    local visibilityCount = 0; for _ in pairs(visibilityChildren) do visibilityCount = visibilityCount + 1 end
    if visibilityCount > 0 then
        StatusRow("Visibility children: " .. visibilityCount, C.teal, "Clear", 54, function()
            local ids = {}; for childID in pairs(ns:GetVisibilityChildren(id)) do ids[#ids + 1] = childID end
            for _, childID in ipairs(ids) do ns:RemoveVisibilityLink(id, childID) end
            ns:RenderSelectedTarget(id)
        end)
    end
    if visibilityParent then
        local parentTarget = ns.TargetByID[visibilityParent]
        local hasLocalRules = settings and #(settings.reactions or {}) > 0
        StatusRow((hasLocalRules and "Local rules, then: " or "Follows: ") .. (parentTarget and parentTarget.label or visibilityParent), C.teal, "Stop following", 92, function()
            ns:RemoveVisibilityLink(visibilityParent, id); ns:RenderSelectedTarget(id)
        end)
    end
    self:FitWorkspaceCards()
end

local function NewPickerWireframe(picker)
    local wire = CreateFrame("Frame", nil, picker)
    wire:SetFrameLevel(903)
    wire:EnableMouse(false)
    wire.lines = {}
    for index = 1, 4 do
        local line = wire:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.42)
        wire.lines[index] = line
    end
    wire.lines[1]:SetPoint("TOPLEFT"); wire.lines[1]:SetPoint("TOPRIGHT"); wire.lines[1]:SetHeight(2)
    wire.lines[2]:SetPoint("BOTTOMLEFT"); wire.lines[2]:SetPoint("BOTTOMRIGHT"); wire.lines[2]:SetHeight(2)
    wire.lines[3]:SetPoint("TOPLEFT"); wire.lines[3]:SetPoint("BOTTOMLEFT"); wire.lines[3]:SetWidth(2)
    wire.lines[4]:SetPoint("TOPRIGHT"); wire.lines[4]:SetPoint("BOTTOMRIGHT"); wire.lines[4]:SetWidth(2)
    return wire
end

local function PositionPickerWire(wire, entry, color, alpha)
    wire:ClearAllPoints()
    wire:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", entry.left, entry.bottom)
    wire:SetSize(entry.width, entry.height)
    for _, line in ipairs(wire.lines) do line:SetColorTexture(color[1], color[2], color[3], alpha) end
    wire:Show()
end

local function HidePickerWireframes(picker)
    for _, wire in ipairs(picker.overviewWires or {}) do wire:Hide() end
    for _, wire in ipairs(picker.candidateWires or {}) do wire:Hide() end
end

local function QueuePickerOverview(picker)
    for _, wire in ipairs(picker.overviewWires or {}) do wire:Hide() end
    local atlas = picker.atlas
    if not atlas or not atlas.finalized then return end
    picker.overviewWires = picker.overviewWires or {}
    picker.overviewIndex = 1
end

local function ContinuePickerOverview(picker)
    local atlas, index = picker.atlas, picker.overviewIndex
    if not atlas or not atlas.finalized or not index then return end
    local started = type(debugprofilestop) == "function" and debugprofilestop() or nil
    local processed = 0
    while index <= #(atlas.overview or {}) and processed < 10
        and (processed == 0 or not started or debugprofilestop() - started < 0.8) do
        local wire = picker.overviewWires[index]
        if not wire then wire = NewPickerWireframe(picker); wire:SetFrameLevel(902); picker.overviewWires[index] = wire end
        PositionPickerWire(wire, atlas.overview[index], C.accent, 0.38)
        index, processed = index + 1, processed + 1
    end
    picker.overviewIndex = index <= #(atlas.overview or {}) and index or nil
end

local function QueuePickerCandidateWires(picker)
    picker.candidateWires = picker.candidateWires or {}
    for _, wire in ipairs(picker.candidateWires) do wire:Hide() end
    picker.candidateWireEntries = {}
    if picker.phase ~= "browse" then picker.candidateWireIndex = nil; return end
    local candidates, index = picker.candidates or {}, picker.index or 0
    if index > 1 then picker.candidateWireEntries[#picker.candidateWireEntries + 1] = candidates[index - 1] end
    if index > 0 and index < #candidates then picker.candidateWireEntries[#picker.candidateWireEntries + 1] = candidates[index + 1] end
    picker.candidateWireIndex = #picker.candidateWireEntries > 0 and 1 or nil
end

local function ContinuePickerCandidateWires(picker)
    local index = picker.candidateWireIndex
    if not index then return end
    local entries = picker.candidateWireEntries or {}
    local maximum = #entries
    local started = type(debugprofilestop) == "function" and debugprofilestop() or nil
    local processed = 0
    while index <= maximum and processed < 8
        and (processed == 0 or not started or debugprofilestop() - started < 0.6) do
        local wire = picker.candidateWires[index]
        if not wire then wire = NewPickerWireframe(picker); wire:SetFrameLevel(903); picker.candidateWires[index] = wire end
        -- Adjacent choices are only quiet context. Teal is reserved for the
        -- single candidate the player would select right now.
        PositionPickerWire(wire, entries[index], C.accent, 0.18)
        index, processed = index + 1, processed + 1
    end
    picker.candidateWireIndex = index <= maximum and index or nil
end

local function PositionPickerDock(picker, x, y)
    if not picker or not picker.dock or type(x) ~= "number" or type(y) ~= "number" then return end
    if picker.dock.IsMouseOver and picker.dock:IsMouseOver() then return end
    if picker.dockAnchorX and math.abs(x - picker.dockAnchorX) < 160
        and math.abs(y - picker.dockAnchorY) < 160 then return end
    local uiWidth = tonumber(UIParent and UIParent:GetWidth()) or 0
    local uiHeight = tonumber(UIParent and UIParent:GetHeight()) or 0
    local width = tonumber(picker.dock:GetWidth()) or 400
    local height = tonumber(picker.dock:GetHeight()) or 168
    local left = x + 28
    if left + width > uiWidth - 12 then left = x - width - 28 end
    local bottom = y + 28
    if bottom + height > uiHeight - 12 then bottom = y - height - 28 end
    left = math.max(12, math.min(math.max(12, uiWidth - width - 12), left))
    bottom = math.max(12, math.min(math.max(12, uiHeight - height - 12), bottom))
    picker.dock:ClearAllPoints()
    picker.dock:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
    picker.dockAnchorX, picker.dockAnchorY = x, y
end

local function DimEntirePickerScreen(picker)
    local dims = picker and picker.scrim
    if not dims or not dims[1] then return end
    local uiWidth = tonumber(UIParent and UIParent:GetWidth()) or 0
    local uiHeight = tonumber(UIParent and UIParent:GetHeight()) or 0
    dims[1]:ClearAllPoints()
    dims[1]:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    dims[1]:SetSize(uiWidth, uiHeight)
    dims[1]:Show()
    for index = 2, 4 do dims[index]:Hide() end
end

local function FilterPickerCandidates(candidates, showTechnical)
    if showTechnical then return candidates or {}, 0 end
    local useful, hidden = {}, 0
    for _, candidate in ipairs(candidates or {}) do
        if candidate.technical then
            hidden = hidden + 1
        else
            useful[#useful + 1] = candidate
        end
    end
    -- Never strand the player when the only selectable object is technical.
    if #useful == 0 then return candidates or {}, 0 end
    return useful, hidden
end

local function PickerDisplayLabel(candidate)
    return candidate and (candidate.displayLabel or candidate.label) or "Unknown frame"
end

local function PickerTechnicalName(candidate)
    if not candidate then return "" end
    local technical = candidate.name or candidate.debugName
    if type(technical) ~= "string" or technical == "" or technical == PickerDisplayLabel(candidate) then return "" end
    return technical
end

local function PickerStackText(picker)
    local candidates, index = picker.candidates or {}, picker.index or 0
    local previous = index > 1 and PickerDisplayLabel(candidates[index - 1]) or "Start of stack"
    local following = index < #candidates and PickerDisplayLabel(candidates[index + 1]) or "End of stack"
    return string.format("Previous: %s   |   %d / %d   |   Next: %s", ShortText(previous, 15), index, #candidates, ShortText(following, 15))
end

function ns:CreatePicker()
    if self.Picker then return end
    local picker = CreateFrame("Button", "FrameGambitPicker", UIParent)
    picker:SetAllPoints(UIParent); picker:SetFrameStrata("FULLSCREEN_DIALOG"); picker:SetFrameLevel(900)
    picker:EnableMouse(true); picker:EnableMouseWheel(true); picker:RegisterForClicks("LeftButtonUp")
    picker:SetNormalTexture("Interface\\Buttons\\WHITE8X8"); picker:GetNormalTexture():SetAlpha(0)
    picker.outline = CreateFrame("Frame", nil, picker, "BackdropTemplate"); Backdrop(picker.outline, { C.teal[1], C.teal[2], C.teal[3], 0.09 }, C.teal); picker.outline:SetFrameLevel(905); picker.outline:EnableMouse(false)
    picker.dock = CreateFrame("Frame", nil, picker, "BackdropTemplate"); picker.dock:SetSize(400, 168); picker.dock:SetPoint("TOP", 0, -34); picker.dock:SetFrameLevel(910); picker.dock:EnableMouse(true); picker.dock:EnableMouseWheel(true); picker.dock:SetClampedToScreen(true); Backdrop(picker.dock, C.panel, C.accent)
    ApplyEUIObject("panel", picker.dock, { inset = true })
    picker.title = Text(picker.dock, "GameFontNormalLarge", "Point at a frame", C.accent); picker.title:SetPoint("TOPLEFT", 12, -10); picker.title:SetWidth(376); picker.title:SetWordWrap(false)
    picker.technicalName = Text(picker.dock, "GameFontHighlightSmall", "", C.muted); picker.technicalName:SetPoint("TOPLEFT", picker.title, "BOTTOMLEFT", 0, -2); picker.technicalName:SetWidth(376); picker.technicalName:SetWordWrap(false)
    picker.capability = Text(picker.dock, "GameFontHighlightSmall", "", C.teal); picker.capability:SetPoint("TOPLEFT", picker.technicalName, "BOTTOMLEFT", 0, -2); picker.capability:SetWidth(376); picker.capability:SetWordWrap(false)
    picker.wheel = Text(picker.dock, "GameFontNormal", "WHEEL: NEXT FRAME", C.accent); picker.wheel:SetPoint("TOPLEFT", picker.capability, "BOTTOMLEFT", 0, -7); picker.wheel:SetWidth(376); picker.wheel:SetJustifyH("CENTER")
    picker.stack = Text(picker.dock, "GameFontHighlightSmall", "", C.muted); picker.stack:SetPoint("TOPLEFT", picker.wheel, "BOTTOMLEFT", 0, -5); picker.stack:SetWidth(376); picker.stack:SetJustifyH("CENTER"); picker.stack:SetWordWrap(false)
    picker.help = Text(picker.dock, "GameFontHighlightSmall", "Esc: cancel", C.muted); picker.help:SetPoint("TOPLEFT", picker.stack, "BOTTOMLEFT", 0, -4); picker.help:SetWidth(376); picker.help:SetJustifyH("CENTER"); picker.help:SetWordWrap(false)
    picker.previous = Button(picker.dock, "< Previous", 84, function() ns:CyclePicker(1) end); picker.previous:SetPoint("BOTTOMLEFT", 12, 10)
    picker.technicalToggle = Button(picker.dock, "Show technical", 112, function() ns:TogglePickerTechnicalFrames() end); picker.technicalToggle:SetPoint("BOTTOM", 0, 10)
    picker.next = Button(picker.dock, "Next >", 84, function() ns:CyclePicker(-1) end); picker.next:SetPoint("BOTTOMRIGHT", -12, 10)
    picker.previous:EnableMouseWheel(true); picker.technicalToggle:EnableMouseWheel(true); picker.next:EnableMouseWheel(true)
    picker.previous:SetScript("OnMouseWheel", function(_, delta) ns:CyclePicker(delta) end)
    picker.technicalToggle:SetScript("OnMouseWheel", function(_, delta) ns:CyclePicker(delta) end)
    picker.next:SetScript("OnMouseWheel", function(_, delta) ns:CyclePicker(delta) end)
    picker.technicalToggle._tooltipTitle = "Technical frames"
    picker.technicalToggle._tooltipBody = "Full-screen and system layers"
    picker.use = Button(picker.dock, "Use this frame", 112, function() ns:UsePickedTarget() end, true); picker.use:SetPoint("BOTTOMRIGHT", -12, 10); picker.use:Hide()
    picker.again = Button(picker.dock, "Choose again", 96, function() ns:ChooseAgain() end); picker.again:SetPoint("RIGHT", picker.use, "LEFT", -7, 0); picker.again:Hide()
    picker.scrim = {}
    for i = 1, 4 do
        local dim = CreateFrame("Frame", nil, picker)
        dim:SetFrameLevel(901)
        local texture = dim:CreateTexture(nil, "BACKGROUND")
        texture:SetAllPoints()
        texture:SetColorTexture(0, 0, 0, 0.52)
        picker.scrim[i] = dim
    end
    picker._ticker = function(self, elapsed)
        self.updateElapsed = (self.updateElapsed or 0) + elapsed
        if self.overviewIndex then ContinuePickerOverview(self) end
        if self.candidateWireIndex then ContinuePickerCandidateWires(self) end
        if (self.atlas and not self.atlas.finalized) or self.updateElapsed >= 0.03 then
            self.updateElapsed = 0
            ns:UpdatePicker()
        end
    end
    picker:SetScript("OnMouseWheel", function(_, delta) ns:CyclePicker(delta) end)
    picker.dock:SetScript("OnMouseWheel", function(_, delta) ns:CyclePicker(delta) end)
    picker:SetScript("OnClick", function() ns:SelectPickerCandidate() end)
    picker:SetScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
        local restore = self.exitReason == "cancel" and self.returnToOptions and not InCombatLockdown()
        local wasCinematicKeep = self.intent == "cinematic_keep"
        self.phase, self.pendingTargetID, self.pendingCandidate, self.candidates, self.allCandidates, self.index, self.mode, self.intent = nil, nil, nil, nil, nil, 0, nil, nil
        self.showTechnical, self.hiddenTechnical, self.candidateWireEntries, self.dockAnchorX, self.dockAnchorY = nil, nil, nil, nil, nil
        self.atlas, self.lastCursorX, self.lastCursorY, self.forceVisual, self.updateElapsed, self.overviewIndex, self.candidateWireIndex = nil, nil, nil, nil, 0, nil, nil
        self.outline:Hide(); HidePickerWireframes(self)
        for _, dim in ipairs(self.scrim) do dim:Hide() end
        GameTooltip_Hide()
        if wasCinematicKeep then
            ns.runtime.cinematicPickerReveal = nil
            if ns:IsCinematicActive() then
                ns:UpdateCinematicBlackout()
            end
        end
        self.use:Hide(); self.again:Hide(); self.previous:Hide(); self.next:Hide(); self.technicalToggle:Hide(); self.dock:SetHeight(168)
        if restore and ns.Options and not ns.Options:IsVisible() then ns.Options:Show() end
    end)
    table.insert(UISpecialFrames, picker:GetName())
    picker:Hide(); self.Picker = picker
end

function ns:StartPicker(intent)
    if InCombatLockdown() then
        if self.Options then self.Options.active:SetText("Not in combat") self.Options.active:SetTextColor(unpack(C.amber)) end
        return
    end
    -- /fg pick can be the first editor action after a reload.
    self:CreateOptions()
    self:CreatePicker()
    if intent == "cinematic_keep" and self:IsCinematicActive() then
        self.runtime.cinematicPickerReveal = true
        self:UpdateCinematicBlackout()
    end
    self.Picker.mode, self.Picker.intent, self.Picker.candidates, self.Picker.index = "atlas", intent or "target", {}, 0
    self.Picker.allCandidates, self.Picker.showTechnical, self.Picker.hiddenTechnical = {}, false, 0
    self.Picker.returnToOptions = self.Options and self.Options:IsVisible() or false
    self.Picker.exitReason, self.Picker.phase, self.Picker.pendingTargetID, self.Picker.pendingCandidate = "cancel", "browse", nil, nil
    self.Picker.atlas = self:BeginPickerAtlas()
    self.Picker.lastCursorX, self.Picker.lastCursorY, self.Picker.forceVisual = nil, nil, true
    self.Picker.dockAnchorX, self.Picker.dockAnchorY = nil, nil
    self.Picker.use:Hide(); self.Picker.again:Hide(); self.Picker.previous:Hide(); self.Picker.next:Hide(); self.Picker.technicalToggle:Hide(); self.Picker.dock:SetHeight(168)
    self.Picker.title:SetText("Finding frames…")
    self.Picker.technicalName:SetText("")
    self.Picker.capability:SetText("")
    self.Picker.wheel:SetText("WHEEL: NEXT FRAME")
    self.Picker.stack:SetText("")
    self.Picker.help:SetText("Esc: cancel")
    self.Picker.technicalToggle:SetText("Show technical")
    self.Picker.help:SetTextColor(unpack(C.muted))
    if self.Options then self.Options:Hide() end
    local cursorX, cursorY = self:GetUICursorPosition()
    PositionPickerDock(self.Picker, cursorX, cursorY)
    self.Picker:SetScript("OnUpdate", self.Picker._ticker)
    self.Picker:Show(); self:UpdatePicker()
end

local function PickerFrame(candidate)
    if not candidate then return nil end
    if candidate.frame then return candidate.frame end
    return candidate.id and ns:ResolveTarget(candidate.id)
end

local function PickerCapability(candidate)
    if candidate and candidate.frame then
        if candidate.name then return candidate.isRoot and "Saved window" or "Saved frame", "Kept after reload", "teal" end
        return candidate.isRoot and "Temporary window" or "Temporary frame", "Lost on reload", "amber"
    end
    return ns:GetTargetCapability(candidate)
end

function ns:UpdatePicker()
    local picker = self.Picker
    if not picker or not picker:IsShown() then return end
    local candidate
    if picker.phase == "confirm" then
        candidate = picker.pendingCandidate or (picker.pendingTargetID and self.TargetByID[picker.pendingTargetID])
        if not candidate or not PickerFrame(candidate) then self:ChooseAgain(); return end
    else
        if picker.atlas and not picker.atlas.finalized then
            local done = self:ContinuePickerAtlas(picker.atlas, 64)
            picker.outline:Hide(); picker.capability:Show()
            DimEntirePickerScreen(picker)
            picker.title:SetText("Finding frames…")
            picker.technicalName:SetText("")
            picker.stack:SetText("")
            picker.capability:SetText(string.format("%d checked | %d found", picker.atlas.inspected or 0, picker.atlas.eligible or 0))
            picker.capability:SetTextColor(unpack(C.teal))
            picker.help:SetText("Esc: cancel")
            if not done then return end
            picker.forceVisual = true
            QueuePickerOverview(picker)
            ContinuePickerOverview(picker)
            if #(picker.atlas.entries or {}) == 0 then
                picker.title:SetText("No frames found")
                picker.capability:SetText(string.format("%d checked | try /reload", picker.atlas.inspected or 0))
                picker.capability:SetTextColor(unpack(C.amber))
            else
                picker.previous:Show(); picker.next:Show(); picker.technicalToggle:Show()
            end
        end
        local x, y = self:GetUICursorPosition()
        local overDock = picker.dock.IsMouseOver and picker.dock:IsMouseOver()
        if not overDock then PositionPickerDock(picker, x, y) end
        local moved = not overDock and x and y and (not picker.lastCursorX or math.abs(x - picker.lastCursorX) >= 1 or math.abs(y - picker.lastCursorY) >= 1)
        if moved then
            local previous = picker.candidates and picker.candidates[picker.index]
            picker.lastCursorX, picker.lastCursorY = x, y
            picker.allCandidates = self:GetPickerAtlasCandidates(picker.atlas, x, y)
            picker.candidates, picker.hiddenTechnical = FilterPickerCandidates(picker.allCandidates, picker.showTechnical)
            picker.index = 0
            if previous and previous.frame then
                for index, found in ipairs(picker.candidates) do
                    if found.frame == previous.frame then picker.index = index; break end
                end
            end
            if picker.index == 0 and #picker.candidates > 0 then picker.index = 1 end
            picker.forceVisual = true
        end
        local underCursor = picker.candidates or {}
        if #underCursor == 0 then
            picker.index = 0
        else
            picker.index = math.max(1, math.min(picker.index or 1, #underCursor))
        end
        candidate = picker.candidates[picker.index]
        if not moved and not picker.forceVisual then return end
    end
    local frame = PickerFrame(candidate)
    local left, bottom, width, height
    if candidate and candidate.derivedRect and candidate.left then
        -- A zero-sized logical container is represented by its cached union of
        -- visible descendants. Its own GetRect remains nil by definition.
        left, bottom, width, height = candidate.left, candidate.bottom, candidate.width, candidate.height
    elseif picker.phase == "browse" and candidate and candidate.left then
        left, bottom, width, height = candidate.left, candidate.bottom, candidate.width, candidate.height
    elseif frame then
        left, bottom, width, height = self:GetUsableFrameRect(frame)
    end
    local redrawWires = picker.forceVisual
    picker.forceVisual = nil
    if redrawWires then QueuePickerCandidateWires(picker); ContinuePickerCandidateWires(picker) end
    if not left or not bottom or not width or not height then
        if picker.phase == "confirm" then self:ChooseAgain(); return end
        picker.outline:Hide()
        DimEntirePickerScreen(picker)
        picker.capability:Show()
        local mapped = picker.atlas and #(picker.atlas.entries or {}) or 0
        if mapped == 0 then
            picker.title:SetText("No frames found")
            picker.technicalName:SetText("")
            picker.stack:SetText("")
            picker.capability:SetText(string.format("%d checked | try /reload", picker.atlas and picker.atlas.inspected or 0))
            picker.capability:SetTextColor(unpack(C.amber))
            picker.help:SetText("Esc: cancel")
        else
            picker.title:SetText("No frame under the pointer")
            picker.technicalName:SetText("")
            picker.capability:SetText(string.format("%d selectable areas found", mapped))
            picker.capability:SetTextColor(unpack(C.teal))
            picker.stack:SetText("")
            picker.help:SetText("Esc: cancel")
        end
        return
    end
    picker.outline:ClearAllPoints(); picker.outline:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left - 3, bottom - 3); picker.outline:SetSize(width + 6, height + 6); picker.outline:Show()
    -- Four panels create a safe spotlight: real frames remain untouched, while
    -- the rest of the screen is gently de-emphasized during selection.
    local uiWidth, uiHeight = UIParent:GetWidth(), UIParent:GetHeight()
    local x, y, w, h = left, bottom, width, height
    local top, right = y + h, x + w
    local dims = picker.scrim
    if candidate.technical and (candidate.screenRatio or 0) >= 0.82 then
        -- A full-screen render layer has no useful spotlight hole. Keeping the
        -- whole picker dim prevents the world from flashing bright whenever
        -- the cursor briefly leaves a smaller UI control.
        DimEntirePickerScreen(picker)
    else
        dims[1]:ClearAllPoints(); dims[1]:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, top); dims[1]:SetSize(uiWidth, math.max(0, uiHeight - top)); dims[1]:Show()
        dims[2]:ClearAllPoints(); dims[2]:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0); dims[2]:SetSize(uiWidth, math.max(0, y)); dims[2]:Show()
        dims[3]:ClearAllPoints(); dims[3]:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, y); dims[3]:SetSize(math.max(0, x), h); dims[3]:Show()
        dims[4]:ClearAllPoints(); dims[4]:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", right, y); dims[4]:SetSize(math.max(0, uiWidth - right), h); dims[4]:Show()
    end
    if picker.phase == "confirm" then
        picker.title:SetText((picker.intent == "cinematic_keep" and "Keep visible: " or "Selected: ") .. PickerDisplayLabel(candidate))
        picker.technicalName:SetText(PickerTechnicalName(candidate))
        local capability, _, tone = PickerCapability(candidate)
        picker.capability:Show(); picker.capability:SetText(capability); picker.capability:SetTextColor(unpack(C[tone] or C.accent))
        picker.wheel:SetText("FRAME SELECTED")
        picker.stack:SetText("Check the outline")
        picker.help:SetText(picker.intent == "cinematic_keep" and "Keep it in Cinematic?" or "")
    else
        local scope = candidate.isRoot == false and "inner frame" or "whole window"
        picker.title:SetText(ShortText(PickerDisplayLabel(candidate), 38))
        picker.technicalName:SetText(ShortText(PickerTechnicalName(candidate), 52))
        local capability, _, tone = PickerCapability(candidate)
        if candidate.technical then
            capability = (candidate.technicalReason or "System layer") .. " | likely wrong"
            tone = "accent"
        elseif candidate.broad then
            capability = "Large container"
            tone = "accent"
        else
            capability = capability .. " | " .. scope
        end
        picker.capability:Show(); picker.capability:SetText(capability); picker.capability:SetTextColor(unpack(C[tone] or C.accent))
        picker.stack:SetText(PickerStackText(picker))
        picker.help:SetText((picker.hiddenTechnical or 0) > 0
            and string.format("Esc: cancel | %d hidden", picker.hiddenTechnical)
            or "Esc: cancel")
        picker.technicalToggle:SetText(picker.showTechnical and "Hide technical" or "Show technical")
    end
end

function ns:CyclePicker(delta)
    local picker = self.Picker
    if picker.phase ~= "browse" then return end
    if not picker.candidates or #picker.candidates == 0 then return end
    picker.index = picker.index - delta
    if picker.index < 1 then picker.index = #picker.candidates elseif picker.index > #picker.candidates then picker.index = 1 end
    picker.forceVisual = true
    self:UpdatePicker()
end

function ns:TogglePickerTechnicalFrames()
    local picker = self.Picker
    if not picker or picker.phase ~= "browse" then return end
    local previous = picker.candidates and picker.candidates[picker.index]
    picker.showTechnical = not picker.showTechnical
    picker.candidates, picker.hiddenTechnical = FilterPickerCandidates(picker.allCandidates, picker.showTechnical)
    picker.index = #picker.candidates > 0 and 1 or 0
    if previous and previous.frame then
        for index, candidate in ipairs(picker.candidates) do
            if candidate.frame == previous.frame then picker.index = index; break end
        end
    end
    picker.forceVisual = true
    self:UpdatePicker()
end

function ns:SelectPickerCandidate()
    local picker = self.Picker
    local candidate = picker and picker.candidates and picker.candidates[picker.index]
    if not candidate or picker.phase ~= "browse" then return end
    picker.phase, picker.pendingCandidate, picker.pendingTargetID = "confirm", candidate, candidate.id
    picker.forceVisual = true
    picker.dock:SetHeight(168); picker.previous:Hide(); picker.next:Hide(); picker.technicalToggle:Hide(); picker.use:Show(); picker.again:Show()
    self:UpdatePicker()
end

function ns:ChooseAgain()
    local picker = self.Picker
    if not picker or not picker:IsShown() then return end
    picker.phase, picker.pendingTargetID, picker.pendingCandidate = "browse", nil, nil
    picker.forceVisual = true
    picker.dock:SetHeight(168); picker.use:Hide(); picker.again:Hide(); picker.previous:Show(); picker.next:Show(); picker.technicalToggle:Show()
    picker.wheel:SetText("WHEEL: NEXT FRAME")
    picker.help:SetTextColor(unpack(C.muted))
    self:UpdatePicker()
end

function ns:UsePickedTarget()
    local picker = self.Picker
    local candidate = picker and picker.pendingCandidate
    if picker and picker.intent == "cinematic_keep" then
        local ok, reason
        if candidate and candidate.frame then ok, reason = self:KeepCinematicFrame(candidate.frame) end
        if not ok then
            self:ChooseAgain()
            picker.help:SetText(reason or "Frame gone")
            picker.help:SetTextColor(unpack(C.amber))
            return
        end
        picker.exitReason = "used"
        picker:Hide()
        if self.Options then self.Options:Show() end
        return
    end
    local targetID = candidate and candidate.id
    if candidate and candidate.frame then
        local id, reason = self:RegisterDiscoveredFrame(candidate.frame, candidate.label, true)
        if not id then
            self:ChooseAgain()
            picker.help:SetText(reason or "Frame gone")
            picker.help:SetTextColor(unpack(C.amber))
            return
        end
        targetID = id
    end
    local target = targetID and self.TargetByID[targetID]
    if not target or not self:ResolveTarget(targetID) then self:ChooseAgain(); return end
    if InCombatLockdown() then self:CancelPicker("interrupted"); return end
    picker.exitReason = "used"
    picker:Hide()
    self:AddTarget(targetID)
    self.Options.selected = targetID
    self.Options:Show()
end

function ns:CancelPicker(reason)
    if self.Picker and self.Picker:IsShown() then
        self.Picker.exitReason = reason == "cancel" and "cancel" or "interrupted"
        self.Picker:Hide()
    end
end

-- Install the bundled facade unconditionally. EllesmereUI remains an optional
-- functional frame provider, but it never adopts or recolors Frame Gambit's UI.
ns:SetEUITheme(BUNDLED_SKIN)
