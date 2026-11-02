local root = arg and arg[1] or "Interface/AddOns/FrameGambit"
local driver
GetTime = function() return 10 end
InCombatLockdown = function() return false end
SlashCmdList = {}
CreateFrame = function()
    driver = { scripts = {}, events = {} }
    function driver:RegisterEvent(event) self.events[event] = true end
    driver.RegisterUnitEvent = driver.RegisterEvent
    function driver:SetScript(event, fn) self.scripts[event] = fn end
    function driver:GetScript(event) return self.scripts[event] end
    return driver
end
hooksecurefunc = function(frame) frame.hooks = frame.hooks + 1 end
local ns = {}
assert(loadfile(root .. "/Core.lua"))("FrameGambit", ns)
local function frame(name, parent)
    local f = { name = name, parent = parent, alpha = 1, hooks = 0, writes = 0 }
    function f:GetName() return self.name end
    function f:GetParent() return self.parent end
    function f:GetAlpha() return self.alpha end
    function f:SetAlpha(a) self.writes = self.writes + 1; self.alpha = a end
    function f:HookScript() self.hooks = self.hooks + 1 end
    function f:IsShown() return false end
    return f
end
UIParent = frame("UIParent")
BankFrame = frame("BankFrame", UIParent)
local panel = frame("BankPanel", BankFrame)
local button = frame(nil, panel)
GuildBankFrame = frame("GuildBankFrame", UIParent)
local hud = frame("TestHUD", UIParent)
ns.IsFrameGambitFrame = function() return false end
ns.IsCinematicActive = function() return true end
ns.GetUIParentFrameRoots = function() return { BankFrame, GuildBankFrame, hud } end
ns.RefreshCinematicExemptions = function() end
for _, f in ipairs({ BankFrame, panel, button, GuildBankFrame }) do
    assert(ns:IsCinematicBlackoutExempt(f), "Hidden bank tree must remain exempt")
    ns:HookCinematicPanel(f)
    ns:HookCinematicRoot(f)
    assert(f.hooks == 0, "Bank tree must not receive Cinematic hooks")
end
ns:BeginCinematicBlackout()
assert(BankFrame.writes == 0 and GuildBankFrame.writes == 0)
assert(not ns.runtime.cinematicBlackout[BankFrame])
assert(hud.alpha == 0 and hud.hooks > 0, "Ordinary HUD still fades")
FrameGambitDB = {}
assert(driver.events.ADDON_ACTION_BLOCKED and driver.events.ADDON_ACTION_FORBIDDEN)
driver.scripts.OnEvent(driver, "ADDON_ACTION_BLOCKED", "AnotherAddon", "Test")
assert(not FrameGambitDB.blockedActions)
for i = 1, 7 do
    driver.scripts.OnEvent(driver, "ADDON_ACTION_BLOCKED", "FrameGambit", "Test" .. i)
end
assert(#FrameGambitDB.blockedActions == 5)
assert(FrameGambitDB.blockedActions[1].action == "Test3")
assert(FrameGambitDB.blockedActions[5].cinematic)
print("PASS: hidden bank trees receive no Cinematic hooks/alpha writes; HUD blackout and bounded diagnostics work")
