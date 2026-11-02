-- Run from the client directory with Lua 5.1 or LuaJIT.
local now = 1
GetTime = function() return now end
InCombatLockdown = function() return false end
hooksecurefunc = function(object, name, hook)
    local original = assert(object[name])
    object[name] = function(self, ...) original(self, ...); hook(self, ...) end
end
local function near(actual, expected)
    assert(math.abs(actual - expected) < 0.00001, tostring(actual) .. " ~= " .. expected)
end
local function frame(parent)
    return { GetParent = function() return parent end, GetChildren = function() end,
        GetRegions = function() end }
end
UIParent = frame()
MinimapCluster = frame(UIParent)
Minimap = frame(MinimapCluster)
local values, rejected, names = {}, {}, {}
local function addChannel(name)
    names[#names + 1] = name
    values[name] = 255
    Minimap["Set" .. name] = function(_, value)
        if rejected[name] then error("blocked") end
        values[name] = math.floor(value)
    end
end
for _, kind in ipairs({ "Quest", "Task", "Arch" }) do
    for _, part in ipairs({ "Inside", "Outside", "Ring" }) do
        addChannel(kind .. "Blob" .. part .. "Alpha")
    end
end
local ns = { runtime = { active = {}, frameByID = {}, managedIDByFrame = {} } }
local settings = { enabled = true, nativeMarkerMode = "keep" }
function ns:GetTargetSettings() return settings end
assert(loadfile("Interface/AddOns/FrameGambit/MinimapStack.lua"))("FrameGambit", ns)
-- Observe skin configuration before management (including disabled rings).
Minimap:SetQuestBlobInsideAlpha(160)
Minimap:SetArchBlobRingAlpha(0)
local function fade(value)
    ns.runtime.active.cluster = { alpha = value }
    ns.runtime.frameByID.cluster = MinimapCluster
    ns.runtime.managedIDByFrame[MinimapCluster] = "cluster"
    now = now + 0.3
    ns:UpdateMinimapStack(true)
end
fade(0)
for _, name in ipairs(names) do near(values[name], 0) end
fade(1)
near(values.QuestBlobInsideAlpha, 160)
near(values.QuestBlobRingAlpha / 255, 1) -- Must visibly return, not 1/255 opacity.
fade(0.5)
near(values.QuestBlobInsideAlpha, 80)
near(values.TaskBlobRingAlpha, 128)
near(values.ArchBlobRingAlpha, 0)
-- Every setter hook must retain its own channel, without recursion.
for i, name in ipairs(names) do
    Minimap["Set" .. name](Minimap, i * 20)
    near(values[name], i * 10)
end
fade(0)
values.QuestBlobRingAlpha = 1 -- Native layer rebuild without a Lua setter.
now = now + 0.3
ns:UpdateMinimapStack(false)
near(values.QuestBlobRingAlpha, 0)
-- Explicit Minimap and Cluster targets combine for native channels.
ns.runtime.active.minimap = { alpha = 0.4 }
ns.runtime.frameByID.minimap = Minimap
ns.runtime.managedIDByFrame[Minimap] = "minimap"
fade(0.5)
near(values.QuestBlobInsideAlpha, 0) -- Combined 20% map opacity hides blobs only.
ns.runtime.active.minimap = nil
ns.runtime.managedIDByFrame[Minimap] = nil
ns.runtime.frameByID.minimap = nil
-- Rejected restoration keeps the evaluator awake until it succeeds.
rejected.TaskBlobRingAlpha = true
assert(not ns:ReleaseMinimapStack())
assert(ns:HasMinimapStackPendingWork())
ns.runtime.active, ns.runtime.frameByID, ns.runtime.managedIDByFrame = {}, {}, {}
rejected.TaskBlobRingAlpha = nil
ns:UpdateMinimapStack(false)
for i, name in ipairs(names) do near(values[name], i * 20) end
assert(not ns:HasMinimapStackPendingWork())
Minimap:SetQuestBlobInsideAlpha(200)
near(values.QuestBlobInsideAlpha, 200)
-- Re-enable and test failure/retry while active.
rejected.QuestBlobInsideAlpha = true
fade(0)
near(values.QuestBlobInsideAlpha, 200)
rejected.QuestBlobInsideAlpha = nil
ns:UpdateMinimapStack(false)
near(values.QuestBlobInsideAlpha, 0)
assert(ns:ReleaseMinimapStack())
near(values.QuestBlobInsideAlpha, 200)
-- Optional missing methods do not prevent other channels from fading.
Minimap.SetTaskBlobOutsideAlpha = nil
fade(0)
near(values.QuestBlobRingAlpha, 0)
assert(ns:ReleaseMinimapStack())
print("PASS: native blob channels, host writes, combined targets, rebuilds and restoration")
