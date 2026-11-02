-- Run from the client directory: lua Interface/AddOns/FrameGambit/tests/GamepadOpacity.lua
local root = arg[1] or "Interface/AddOns/FrameGambit"
local targets, ns = {}, {}
function ns:RegisterTarget(target) targets[target.id] = target end
local function region(base, rounding)
    local f = { alpha = base }
    function f:GetAlpha() return self.alpha end
    function f:SetAlpha(value)
        if self.reject then error("rejected write") end
        self.alpha = math.floor(value * 255 + rounding) / 255
    end
    function f:GetRect() return 0, 0, 40, 40 end
    function f:IsShown() return true end
    return f
end
assert(loadfile(root .. "/GamepadShoulders.lua"))("FrameGambit", ns)
assert(loadfile(root .. "/GamepadLegend.lua"))("FrameGambit", ns)
for _, rounding in ipairs({ 0, 0.5 }) do
    local unit = {}
    for _, side in ipairs({ "Left", "Right" }) do
        for _, part in ipairs({ "Background", "Icon", "Highlight" }) do
            unit[side .. "Shoulder" .. part] = region(1, rounding)
        end
    end
    GamepadMainActionBarFrame = { PageUnit = unit }
    GamepadPersistentInputLegend = region(1, rounding)
    for _, id in ipairs({ "gamepad_shoulder_left", "gamepad_shoulder_right", "gamepad_input_legend" }) do
        local target = targets[id]
        local proxy = target.resolve()
        assert(target.acquire(proxy))
        local members = proxy.members or { proxy.root }
        for cycle = 1, 20 do
            for _, opacity in ipairs({ 0.5, 0.12, 0, 0.73, 1 }) do
                proxy:SetAlpha(opacity)
                for _ = 1, 40 do target.resolve() end
                for _, member in ipairs(members) do
                    assert(math.abs(member:GetAlpha() - opacity) <= 1 / 255,
                        id .. " progressively dimmed in cycle " .. cycle)
                end
            end
        end
        -- Real native repaints still replace the baseline, and restore safely.
        members[1]:SetAlpha(0.8)
        proxy:SetAlpha(0.5)
        assert(math.abs(members[1]:GetAlpha() - 0.4) <= 1 / 255)
        target.release(proxy)
        assert(math.abs(members[1]:GetAlpha() - 0.8) <= 1 / 255)
        assert(target.acquire(proxy))
        proxy:SetAlpha(0)
        members[1].reject = true
        assert(not pcall(target.release, proxy))
        members[1].reject = nil
        target.release(proxy)
        assert(math.abs(members[1]:GetAlpha() - 0.8) <= 1 / 255)
    end
end
print("PASS: gamepad opacity survives rounded alpha, repeated fades, native repaints and release retries")
