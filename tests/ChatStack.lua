local now = 0
GetTime = function() return now end
local root = arg[1] or "."
local drivers = {}
CreateFrame = function()
    local f = { RegisterEvent = function() end }
    function f:SetScript(key, fn) self[key] = fn end
    drivers[#drivers + 1] = f
    return f
end
hooksecurefunc = function(object, key, fn)
    if type(object) == "string" then object, key, fn = _G, object, key end
    local original = object[key]
    object[key] = function(...) local result = original(...); fn(...); return result end
end
local function Frame(parent, alpha, ignore)
    local f = { parent = parent, alpha = alpha or 1, ignore = ignore, children = {}, shown = true }
    if parent then parent.children[#parent.children + 1] = f end
    function f:GetAlpha() return self.alpha end
    function f:SetAlpha(value)
        self.alpha = self.rounded and math.floor(value * 255 + 0.5) / 255 or value
    end
    function f:GetParent() return self.parent end
    function f:IsIgnoringParentAlpha() return self.ignore end
    function f:GetChildren() return unpack(self.children) end
    function f:IsShown() return self.shown end
    function f:GetRect() return 10, 20, 300, 150 end
    function f:GetEffectiveScale() return 1 end
    function f:Effective()
        return self.alpha * ((self.ignore or not self.parent) and 1 or self.parent:Effective())
    end
    return f
end
UIParent = Frame()
ChatFrame1 = Frame(UIParent)
ChatFrame1EditBox = Frame(ChatFrame1, 0.35)
GeneralDockManager = Frame(UIParent)
ChatFrame1Tab = Frame(GeneralDockManager, 0.8)
local escape = Frame(ChatFrame1, 0.6, true)
CHAT_FRAMES = { "ChatFrame1" }
FCF_OpenTemporaryWindow = function()
    ChatFrame27 = Frame(UIParent)
    ChatFrame27Tab = Frame(GeneralDockManager, 0.8)
    CHAT_FRAMES[#CHAT_FRAMES + 1] = "ChatFrame27"
end
FCF_UnDockFrame = function() ChatFrame1Tab.parent = UIParent end
FCF_DockFrame = function() ChatFrame1Tab.parent = GeneralDockManager end
local ns = { TargetByID = { chat = {} }, Wake = function() end }
assert(loadfile(root .. "/ChatStack.lua"))("FrameGambit", ns)
assert(drivers[1].OnUpdate == nil, "no permanent chat OnUpdate")
local target = ns.TargetByID.chat
local proxy = target.resolve()
assert(target.acquire(proxy))
proxy:SetAlpha(0.5)
assert(ChatFrame1:Effective() == 0.5)
assert(ChatFrame1EditBox:Effective() == 0.175, "child must inherit multiplier only once")
assert(ChatFrame1Tab:Effective() == 0.4)
assert(escape:Effective() == 0.3, "ignoring-parent descendant needs its own multiplier")
proxy:SetAlpha(0)
FCF_OpenTemporaryWindow()
assert(ChatFrame27.alpha == 0, "late whisper must join while hidden")
proxy:SetAlpha(1)
assert(ChatFrame27.alpha == 1 and ChatFrame27Tab:Effective() == 0.8, "whisper reveal includes new tab")
for _ = 1, 20 do
    proxy:SetAlpha(0.5)
    FCF_UnDockFrame()
    assert(ChatFrame1Tab:Effective() == 0.4)
    FCF_DockFrame()
    assert(ChatFrame1Tab.alpha == 0.8 and ChatFrame1Tab:Effective() == 0.4, "redock must not compound alpha")
    ChatFrame1:SetAlpha(0.9)
    assert(ChatFrame1.alpha == 0.45)
    proxy:SetAlpha(0)
    target.release(proxy)
    assert(ChatFrame1.alpha == 0.9 and escape.alpha == 0.6 and ChatFrame1EditBox.alpha == 0.35)
    target.acquire(proxy)
end
proxy:SetAlpha(0)
local late = Frame(ChatFrame27, 0.7, true)
now = now + 0.5; ns:RefreshChatStack()
assert(late.alpha == 0, "new anonymous escapee must join on audit")
proxy:SetAlpha(1)
assert(late.alpha == 0.7)
ChatFrame1.shown = false
assert(proxy:IsShown(), "inactive main tab must not disable group")
assert(proxy:GetRect() == 10)
local found = false
for _, frame in ipairs(proxy:GetFrameGambitCinematicFrames()) do if frame == ChatFrame27 then found = true end end
assert(found, "cinematic exemptions must include future chat")
target.release(proxy)
ChatFrame1:SetAlpha(0.75)
assert(ChatFrame1.alpha == 0.75, "release leaves host in control")
ChatFrame27.rounded = true
target.acquire(proxy)
for _ = 1, 30 do
    proxy:SetAlpha(0.123)
    now = now + 0.5; ns:RefreshChatStack()
    proxy:SetAlpha(1)
    assert(ChatFrame27.alpha == 1, "rounded client alpha must never become the native baseline")
end
target.release(proxy)
-- Loading Ellesmere later replaces the target callbacks. Core releases the
-- old proxy through the NEW target, which must still restore our members.
target.acquire(proxy)
proxy:SetAlpha(0)
EllesmereUI = { _ModuleNS = { EllesmereUIChat = { ECHAT = { SetChatAlpha = function() end } } } }
assert(loadfile(root .. "/EUIChatVisibility.lua"))("FrameGambit", ns)
target.release(proxy)
assert(ChatFrame1.alpha == 0.75 and GeneralDockManager.alpha == 1, "provider handoff restores native group")
print("PASS: chat group, future whispers, single alpha inheritance, docking, host writes, release/reacquire, escapees and cinematic members")
