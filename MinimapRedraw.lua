local ADDON, ns = ...

-- The client only draws new minimap terrain while the map is at full opacity.
-- Tiles that come into view while it is faded or hidden stay black until the
-- next redraw. So when the map comes back to full opacity after having missed
-- a redraw, nudge the zoom once (the same fix as zooming by hand).
--
-- Event-driven: SetAlpha/Show hooks on the minimap and its ancestors, plus
-- zone events. No polling.

local FULL = 0.99
local LONG_DIM = 2        -- seconds below full that count as "missed a redraw"
local MOVE_DISTANCE = 20  -- yards moved while dimmed that count too
local MIN_GAP = 1         -- seconds between two nudges

local state = {
    full = nil,        -- last known: map at full opacity
    dimSince = nil,    -- when it went below full
    dimX = nil, dimY = nil,
    dirty = false,     -- something changed while dimmed
    pending = false,
    lastNudge = -math.huge,
}
ns.minimapRedraw = state

local function Secret(value)
    return issecretvalue and issecretvalue(value) or false
end

local function MapAlpha()
    local map = _G.Minimap
    if not map then return nil end
    local ok, shown = pcall(map.IsVisible, map)
    if not ok or Secret(shown) then return nil end
    if not shown then return 0 end
    local okAlpha, alpha = pcall(map.GetEffectiveAlpha, map)
    if not okAlpha or Secret(alpha) or type(alpha) ~= "number" then return nil end
    return alpha
end

local function PlayerXY()
    if type(UnitPosition) ~= "function" then return nil end
    local ok, y, x = pcall(UnitPosition, "player")
    if not ok or Secret(x) or Secret(y) or type(x) ~= "number" or type(y) ~= "number" then return nil end
    return x, y
end

local function MovedWhileDim()
    if not state.dimX then return false end
    local x, y = PlayerXY()
    if not x then return false end
    local dx, dy = x - state.dimX, y - state.dimY
    return dx * dx + dy * dy >= MOVE_DISTANCE * MOVE_DISTANCE
end

local function Nudge(now)
    state.dirty = false
    if now - state.lastNudge < MIN_GAP then return end
    state.lastNudge = now
    if ns.NudgeMinimapZoom then ns:NudgeMinimapZoom() end
end

function ns:CheckMinimapRedraw()
    state.pending = false
    local alpha = MapAlpha()
    if alpha == nil then return end
    local now = GetTime()
    local full = alpha >= FULL
    if full == state.full then return end
    state.full = full
    if not full then
        state.dimSince = now
        state.dimX, state.dimY = PlayerXY()
        return
    end
    local dimmedFor = state.dimSince and now - state.dimSince or 0
    if state.dirty or dimmedFor >= LONG_DIM or MovedWhileDim() then Nudge(now) end
    state.dimSince, state.dimX, state.dimY = nil, nil, nil
end

-- SetAlpha fires many times in a fade; check once on the next frame.
local function Schedule()
    if state.pending then return end
    state.pending = true
    C_Timer.After(0, function() ns:CheckMinimapRedraw() end)
end

local hooked = setmetatable({}, { __mode = "k" })
local function HookChain()
    local frame, depth = _G.Minimap, 0
    while frame and depth < 20 do
        if not hooked[frame] then
            hooked[frame] = true
            if type(frame.SetAlpha) == "function" then hooksecurefunc(frame, "SetAlpha", Schedule) end
            if type(frame.HookScript) == "function" then
                pcall(frame.HookScript, frame, "OnShow", function() HookChain(); Schedule() end)
                pcall(frame.HookScript, frame, "OnHide", Schedule)
            end
        end
        local ok, parent = pcall(frame.GetParent, frame)
        frame = ok and parent or nil
        depth = depth + 1
    end
end
ns.HookMinimapRedrawChain = HookChain

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
    "ZONE_CHANGED_NEW_AREA" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Loading screens are handled by the startup hold in Core.
        HookChain()
        state.full, state.dirty = nil, false
        return
    end
    -- New area while dimmed: the map missed it. At full it redraws on its own.
    if state.full == false then state.dirty = true end
end)
