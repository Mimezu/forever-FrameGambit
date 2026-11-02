local root = arg[1] or "Interface/AddOns/FrameGambit"
CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end
SlashCmdList = {}
C_Timer = { After = function() end }
InCombatLockdown = function() return false end
hooksecurefunc = function(owner, name, callback)
    local original = owner[name]
    owner[name] = function(self, ...)
        original(self, ...)
        callback(self, ...)
    end
end
local ns = {}
assert(loadfile(root .. "/Core.lua"))("FrameGambit", ns)
assert(loadfile(root .. "/Targets.lua"))("FrameGambit", ns)
assert(loadfile(root .. "/GamepadClassPrompts.lua"))("FrameGambit", ns)
local function frame(alpha)
    return { alpha = alpha, GetAlpha = function(self) return self.alpha end,
        SetAlpha = function(self, value) self.alpha = math.floor(value * 255 + 0.5) / 255 end,
        IsShown = function() return true end, GetRect = function() return 0, 0, 40, 40 end }
end
local button, prompt, right = frame(1), frame(1), frame(1)
GamepadMainActionBarFrame = { PageUnit = { LeftClassAction = button, LeftInputPrompt = prompt, RightClassAction = right } }
TestClassAction = button
local target = { id = "picked", names = { "TestClassAction" } }
ns.TargetByID.picked = target
assert(ns:ResolveTarget("picked") == button)
assert(target.acquire(button))
local function near(value, expected) assert(math.abs(value - expected) < 0.005, tostring(value) .. " ~= " .. expected) end
button:SetAlpha(0.12)
near(prompt.alpha, 0.12)
for _ = 1, 20 do ns:ResolveTarget("picked") end
near(prompt.alpha, 0.12) -- rounded readback must not compound fades
button:SetAlpha(0)
near(prompt.alpha, 0)
prompt:SetAlpha(0) -- Companion hides art even if already faded to zero
button:SetAlpha(1)
near(prompt.alpha, 0)
prompt:SetAlpha(1)
near(prompt.alpha, 1)
button:SetAlpha(0.5)
near(prompt.alpha, 0.5)
near(right.alpha, 1)
target.release(button)
near(prompt.alpha, 1)
button:SetAlpha(0)
near(prompt.alpha, 1) -- inactive hooks must not retain ownership
button:SetAlpha(1)
assert(target.acquire(button))
button:SetAlpha(0.12)
local replacement = frame(0.6)
GamepadMainActionBarFrame.PageUnit.LeftInputPrompt = replacement
ns:ResolveTarget("picked")
near(prompt.alpha, 1)
near(replacement.alpha, 0.6 * button.alpha)
ns.runtime.managedIDByFrame[replacement] = "explicit_prompt"
replacement:SetAlpha(0.8)
button:SetAlpha(0)
near(replacement.alpha, 0.8)
target.release(button)
near(replacement.alpha, 0.8)
print("PASS: picked class prompt opacity, rounding, native hiding, replacement, independent rules and restoration")
