local root = arg and arg[1] or "Interface/AddOns/FrameGambit"
local now, queued, eventFrame = 100, {}, nil
GetTime = function() return now end
C_Timer = { After = function(_, fn) queued[#queued + 1] = fn end }
local function flush() local q = queued; queued = {}; for _, fn in ipairs(q) do fn() end end
CreateFrame = function()
    eventFrame = { events = {} }
    function eventFrame:RegisterEvent(e) self.events[e] = true end
    function eventFrame:SetScript(_, fn) self.onEvent = fn end
    return eventFrame
end
hooksecurefunc = function(obj, method, post)
    local orig = obj[method]
    obj[method] = function(...) local r = orig(...); post(...); return r end
end
local px, py = 0, 0
UnitPosition = function() return py, px end

local function Frame(parent)
    local f = { alpha = 1, shown = true, parent = parent, scripts = {} }
    function f:SetAlpha(a) self.alpha = a end
    function f:GetParent() return self.parent end
    function f:HookScript(name, fn) self.scripts[name] = fn end
    function f:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function f:GetEffectiveAlpha() return self.alpha * (self.parent and self.parent:GetEffectiveAlpha() or 1) end
    return f
end
local UIParentStub = Frame(nil)
local cluster = Frame(UIParentStub)
Minimap = Frame(cluster)

local ns, nudges = {}, 0
assert(loadfile(root .. "/MinimapRedraw.lua"))("FrameGambit", ns)
ns.NudgeMinimapZoom = function() nudges = nudges + 1; return true end

eventFrame.onEvent(eventFrame, "PLAYER_ENTERING_WORLD")
cluster:SetAlpha(1); flush()
assert(nudges == 0, "Login does not nudge (Core's startup hold does)")

-- Short hover dip, standing still: no nudge.
cluster:SetAlpha(0.5); flush(); now = now + 0.5
cluster:SetAlpha(1); flush()
assert(nudges == 0, "Short dip does not nudge")

-- Long dim: nudge once on reaching full.
now = now + 5
cluster:SetAlpha(0.3); cluster:SetAlpha(0.2); flush()
now = now + 3
cluster:SetAlpha(0.6); cluster:SetAlpha(1); flush()
assert(nudges == 1, "Long dim nudges")
cluster:SetAlpha(1); flush(); assert(nudges == 1, "Staying full does not nudge again")

-- Short dim while running a distance: nudge.
now = now + 5
cluster:SetAlpha(0); flush(); px = 50; now = now + 1
cluster:SetAlpha(1); flush()
assert(nudges == 2, "Moved while dimmed nudges")

-- Zone change while dimmed: nudge.
now = now + 5
cluster:SetAlpha(0.4); flush()
eventFrame.onEvent(eventFrame, "ZONE_CHANGED_INDOORS")
now = now + 0.3
cluster:SetAlpha(1); flush()
assert(nudges == 3, "Zone change while dimmed nudges")

-- Zone change at full opacity: the map redraws itself.
eventFrame.onEvent(eventFrame, "ZONE_CHANGED")
now = now + 5; cluster:SetAlpha(0.5); flush(); now = now + 0.2; cluster:SetAlpha(1); flush()
assert(nudges == 3, "Zone change at full is not remembered")

-- Hidden and shown again: OnShow counts as coming back.
now = now + 5
cluster.shown = false; cluster.scripts.OnHide(); flush()
now = now + 4
cluster.shown = true; cluster.scripts.OnShow(); flush()
assert(nudges == 4, "Hide/show after a while nudges")

-- Secret alpha is ignored.
issecretvalue = function(v) return v == "secret" end
local getAlpha = Minimap.GetEffectiveAlpha
Minimap.GetEffectiveAlpha = function() return "secret" end
cluster:SetAlpha(0.2); flush()
Minimap.GetEffectiveAlpha = getAlpha
assert(nudges == 4)
print("PASS: minimap redraw after long dim, movement, zone change, hide/show; no nudge on short dips")
