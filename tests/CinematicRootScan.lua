local root = arg and arg[1] or "Interface/AddOns/FrameGambit"
local now = 10
GetTime = function() return now end
InCombatLockdown = function() return false end
SlashCmdList = {}
CreateFrame = function()
    local d = { scripts = {}, events = {} }
    function d:RegisterEvent(event) self.events[event] = true end
    d.RegisterUnitEvent = d.RegisterEvent
    function d:SetScript(event, fn) self.scripts[event] = fn end
    function d:GetScript(event) return self.scripts[event] end
    return d
end
hooksecurefunc = function() end
local children = 40
UIParent = { GetNumChildren = function() return children end, GetName = function() return "UIParent" end }
local ns = {}
assert(loadfile(root .. "/Core.lua"))("FrameGambit", ns)
local scans = 0
ns.IsCinematicActive = function() return true end
ns.GetUIParentFrameRoots = function() scans = scans + 1; return {} end
ns.RefreshCinematicExemptions = function() end
ns:BeginCinematicBlackout()
assert(scans == 1)
-- Nothing changed: the 2.5 s check stays cheap.
for _ = 1, 20 do
    now = now + 2.5
    if ns:CinematicRootScanDue(now) then ns:BeginCinematicBlackout() end
end
assert(scans == 1, "no full scan while UIParent's children are unchanged: " .. scans)
-- A new root: found at the next check.
children = 41
now = now + 2.5
assert(ns:CinematicRootScanDue(now), "new child triggers a scan")
ns:BeginCinematicBlackout()
assert(scans == 2)
now = now + 2.5
assert(not ns:CinematicRootScanDue(now), "count settled")
-- The safety sweep still runs every 60 s.
now = now + 60
assert(ns:CinematicRootScanDue(now), "60 s sweep")
-- No child count available: always scan, as before.
UIParent.GetNumChildren = nil
ns:BeginCinematicBlackout()
now = now + 2.5
assert(ns:CinematicRootScanDue(now), "unknown count falls back to scanning")
assert(ns.tickMemo == nil, "scan memo cleared")
print("PASS: Cinematic root rescan only on child-count change, 60 s sweep, fallback without a count")
