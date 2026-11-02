local _, ns = ...
local groups = { "GAMEPLAY", "MODIFIER", "FRIENDLY_TARGETING", "HOSTILE_TARGETING", "PARTY", "MENU", "HUD" }
local current
local owners = setmetatable({}, { __mode = "k" })

local function Secret(value) return issecretvalue and issecretvalue(value) or false end
local function Number(value)
    return not Secret(value) and type(value) == "number" and value == value and math.abs(value) <= 10000000
end
local function Call(object, method)
    if not object or Secret(object) then return nil end
    local ok, a, b, c, d = pcall(function() return object[method](object) end)
    if ok then return a, b, c, d end
end
local function Alpha(root)
    local value = Call(root, "GetAlpha")
    if Number(value) and value >= 0 and value <= 1 then return value end
end
local function Shown(frame)
    local shown = Call(frame, "IsShown")
    return not Secret(shown) and shown == true
end

-- The native root is only 10 x 10. Read its known group members for visual
-- bounds, without changing their visibility, geometry or ownership.
local function Bounds(root)
    if not Shown(root) then return end
    local ok, nativeGroups = pcall(function() return root.groups end)
    if not ok or Secret(nativeGroups) or type(nativeGroups) ~= "table" then return end
    local left, bottom, right, top
    for _, name in ipairs(groups) do
        local members = nativeGroups[name]
        if not Secret(members) and type(members) == "table" then
            for index = 1, 64 do
                local member = members[index]
                if Secret(member) then return end
                if member == nil then break end
                if Shown(member) then
                    local x, y, w, h = ns:GetUsableFrameRect(member)
                    if Number(x) and Number(y) and Number(w) and Number(h) and w > 0 and h > 0 then
                        left, bottom = math.min(left or x, x), math.min(bottom or y, y)
                        right, top = math.max(right or (x + w), x + w), math.max(top or (y + h), y + h)
                    end
                end
            end
        end
    end
    if left then return left, bottom, right - left, top - bottom end
end

local function NewProxy(root)
    local proxy = { root = root, active = false, applied = 1 }
    function proxy:GetFrameGambitVisualFrame() return self.root end
    function proxy:GetRect() return Bounds(self.root) end
    function proxy:GetEffectiveScale() return UIParent:GetEffectiveScale() end
    function proxy:IsShown() return Bounds(self.root) ~= nil end
    function proxy:GetAlpha() return self.active and self.applied or 1 end
    function proxy:Acquire()
        if self.active then return true end
        if owners[self.root] and owners[self.root] ~= self then return false end
        local value = Alpha(self.root)
        if value == nil then return false end
        self.base, self.lastApplied, self.applied, self.active = value, value, 1, true
        owners[self.root] = self
        return true
    end
    function proxy:SetAlpha(value)
        if not Number(value) or value < 0 or value > 1 then error("Invalid legend opacity", 0) end
        if not self.active then return end
        local live = Alpha(self.root)
        if live == nil then error("Legend alpha unavailable", 0) end
        if math.abs(live - self.lastApplied) > 0.001 then self.base = live end
        local desired = self.base * value
        if math.abs(live - desired) > 0.001 then
            self.root:SetAlpha(desired)
            live = Alpha(self.root)
            if live == nil then error("Legend alpha readback unavailable", 0) end
        end
        -- Remember the native readback, including rounding or a skipped write.
        -- Otherwise reconciliation treats our own fade as a new host baseline.
        self.lastApplied, self.applied = live, value
    end
    function proxy:Release()
        if not self.active then return end
        self:SetAlpha(1)
        if owners[self.root] == self then owners[self.root] = nil end
        self.active, self.applied = false, 1
    end
    return proxy
end

ns:RegisterTarget({
    id = "gamepad_input_legend", label = "Gamepad - Control hints",
    source = "Blizzard", protected = true, skipManagedAlphaHook = true,
    capability = "Controller hints", capabilityTone = "teal",
    capabilityNote = "Fades Blizzard's controller hints while preserving its current controls and menu state.",
    resolve = function()
        local root = _G.GamepadPersistentInputLegend
        if not root or Secret(root) then return nil end
        if not current or current.root ~= root then current = NewProxy(root) end
        if current.active then current:SetAlpha(current.applied) end
        return current
    end,
    acquire = function(proxy) return proxy:Acquire() end,
    release = function(proxy) return proxy:Release() end,
})
