local now = 10
GetTime = function() return now end
InCombatLockdown = function() return false end
SlashCmdList = {}
C_Timer = { After = function() end }
CreateFrame = function()
    local f = { RegisterEvent = function() end, RegisterUnitEvent = function() end }
    function f:SetScript(k, v) self[k] = v end
    function f:GetScript(k) return self[k] end
    return f
end
hooksecurefunc = function(object, name, fn)
    if type(object) == "string" then object, name, fn = _G, object, name end
    local old = object[name]
    object[name] = function(...) old(...); fn(...) end
end
local ns = {}
assert(loadfile("Interface/AddOns/FrameGambit/Core.lua"))("FrameGambit", ns)
ns.IsCinematicActive = function() return false end
ns.Wake = function() end
ns.RefreshOptions = function() end
local function rule(id, query)
    return { id = id, condition = "chat_text", chatText = query, opacity = 0.75, duration = 5 }
end
local name, item, dungeon, special, empty = rule(1, "Mimezu"), rule(2, "Linen Cloth"),
    rule(3, "Deadmines"), rule(4, "100% [rare].*|"), rule(5, "")
local settings = { enabled = true, atRest = 0, reactions = { name, item, dungeon, special, empty } }
FrameGambitDB = { profile = "Default", profiles = { Default = { targets = { chat = settings } } } }
ChatFrame1 = { AddMessage = function() end }
ns.ResolveTarget = function() return ChatFrame1 end
CHAT_FRAMES = { "ChatFrame1" }
FCF_OpenTemporaryWindow = function()
    ChatFrame27 = { AddMessage = function() end }
    CHAT_FRAMES[#CHAT_FRAMES + 1] = "ChatFrame27"
end
assert(loadfile("Interface/AddOns/FrameGambit/ChatText.lua"))("FrameGambit", ns)
local function met(r) return ns:ConditionIsMet("chat_text", "chat", r, false, now) end
ChatFrame1:AddMessage("[General] Someone: hello MIMEZU!")
assert(met(name) and not met(item) and not met(dungeon) and not met(empty))
now = 14
ChatFrame1:AddMessage("[Guild] Welcome Mimezu")
now = 18
assert(met(name), "match refreshes timer")
now = 20
assert(not met(name), "match expires")
ChatFrame1:AddMessage("WTS |cff00ff00|Hitem:12345:0:0|h[Linen Cloth]|h|r")
assert(met(item))
local hiddenID = rule(6, "12345")
settings.reactions[#settings.reactions + 1] = hiddenID
ChatFrame1:AddMessage("WTS |Hitem:12345|h[Other Item]|h")
assert(not met(hiddenID), "hidden hyperlink data is not visible text")
FCF_OpenTemporaryWindow()
ChatFrame27:AddMessage("LF2M DEADMINES")
assert(met(dungeon), "late temporary chat window gets a hook")
ChatFrame1:AddMessage("selling 100% [rare].*|| now")
assert(met(special), "match uses literal text, never Lua patterns")
item.chatText = "Wool Cloth"
assert(not met(item), "editing query invalidates old match")
ChatFrame1:AddMessage("WTS Wool Cloth")
assert(met(item))
dungeon.enabled = false
now = 30
ChatFrame27:AddMessage("Deadmines")
dungeon.enabled = true
assert(not met(dungeon), "disabled rules do not accumulate new matches")
issecretvalue = function(v) return v == "secret Mimezu" end
ChatFrame1:AddMessage("secret Mimezu")
assert(not met(name), "secret message ignored")
issecretvalue = nil
assert(not ns:ConditionIsMet("chat_text", "chat", name, true, now))
ns:GetTargetSettings("chat")
local parsed = assert(ns:ParseProfileImport(assert(ns:ExportProfile("Default"))))
assert(parsed.targets.chat.reactions[4].chatText == special.chatText)
assert(parsed.targets.chat.reactions[2].chatText == "Wool Cloth")
assert(parsed.targets.chat.reactions[2].duration == 5)
assert(ns:CopyTargetRules("chat"))
assert(ns:PasteTargetRules("other"))
assert(ns:GetTargetSettings("other").reactions[2].chatText == "Wool Cloth")
print("PASS: text matching, item links, late windows, literal phrases, duration, edits, privacy, sharing and copying")
