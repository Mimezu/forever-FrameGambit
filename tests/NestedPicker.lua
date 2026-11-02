local root = arg and arg[1] or "."
local function frame(name, parent)
    local f = { name = name, parent = parent }
    function f:GetName() return self.name end
    function f:GetParent() return self.parent end
    function f:GetRect() return 0, 0, 100, 20 end
    function f:GetAlpha() return 1 end
    function f:SetAlpha() end
    function f:IsShown() return true end
    if name then _G[name] = f end
    return f
end
UIParent = frame("UIParent")
CompactPartyFrame = frame("CompactPartyFrame", UIParent)
CompactPartyFrameTitle = frame("CompactPartyFrameTitle", CompactPartyFrame)

local function fresh()
    local ns = {}
    local profile = { targets = {} }
    function ns:Profile() return profile end
    assert(loadfile(root .. "/Targets.lua"))("FrameGambit", ns)
    return ns, profile
end
local function selectFrame(ns, profile, f)
    local id, reason = ns:RegisterDiscoveredFrame(f, f:GetName(), true)
    assert(id, reason)
    profile.targets[id] = profile.targets[id] or { enabled = true }
    return id
end
for _, parentFirst in ipairs({ true, false }) do
    FrameGambitDB = {}
    local ns, profile = fresh()
    local parentID, titleID
    if parentFirst then
        parentID = selectFrame(ns, profile, CompactPartyFrame)
        titleID = selectFrame(ns, profile, CompactPartyFrameTitle)
    else
        titleID = selectFrame(ns, profile, CompactPartyFrameTitle)
        parentID = selectFrame(ns, profile, CompactPartyFrame)
    end
    assert(parentID == "party_frames" and titleID ~= parentID)
    assert(ns:ResolveTarget(titleID) == CompactPartyFrameTitle)
    assert(profile.targets[parentID] ~= profile.targets[titleID])
    assert(FrameGambitDB.customTargets[titleID].exact == true)
    local count = #ns.Targets
    assert(selectFrame(ns, profile, CompactPartyFrameTitle) == titleID)
    assert(#ns.Targets == count, "Repeated selection must reuse the target")
    local restored = fresh()
    restored:RegisterStoredCustomFrames()
    assert(restored:ResolveTarget(titleID) == CompactPartyFrameTitle)
end

-- Custom and unnamed containers must also work in either order.
for _, named in ipairs({ true, false }) do
    for _, parentFirst in ipairs({ true, false }) do
        FrameGambitDB = {}
        local ns, profile = fresh()
        local parent = frame(named and "NestedPickerContainer" or nil, UIParent)
        local child = frame(named and "NestedPickerChild" or nil, parent)
        local first, second = parent, child
        if not parentFirst then first, second = child, parent end
        local firstID = selectFrame(ns, profile, first)
        local secondID = selectFrame(ns, profile, second)
        assert(firstID ~= secondID)
        assert(ns:ResolveTarget(firstID) == first)
        assert(ns:ResolveTarget(secondID) == second)
        assert(selectFrame(ns, profile, second) == secondID)
    end
end
local ns = fresh()
assert(ns:RegisterDiscoveredFrame(UIParent, "UIParent", true) == nil)
local forbidden = frame(nil, UIParent)
function forbidden:IsForbidden() return true end
assert(ns:RegisterDiscoveredFrame(forbidden, "Forbidden", true) == nil)
print("Nested picker selection tests passed")
