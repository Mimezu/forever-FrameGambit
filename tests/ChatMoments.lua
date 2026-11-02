local root = arg and arg[1] or "Interface/AddOns/FrameGambit"
local now, driver = 10
GetTime = function() return now end
InCombatLockdown = function() return false end
SlashCmdList = {}
C_Timer = { After = function() end }
CreateFrame = function()
    driver = { scripts = {}, events = {} }
    function driver:RegisterEvent(event) self.events[event] = true end
    driver.RegisterUnitEvent = driver.RegisterEvent
    function driver:SetScript(event, fn) self.scripts[event] = fn end
    function driver:GetScript(event) return self.scripts[event] end
    return driver
end
local ns = {}
assert(loadfile(root .. "/Core.lua"))("FrameGambit", ns)
ns.IsCinematicActive = function() return false end
local function event(name, ...) driver.scripts.OnEvent(driver, name, ...) end
local categories = {
    chat_private = { "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER" },
    chat_guild = { "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER" },
    chat_group = { "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
        "CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER" },
}
for condition, events in pairs(categories) do
    assert(ns.CONDITION_INFO[condition].category == "chat")
    assert(ns.CONDITION_INFO[condition].duration == 10)
    for _, name in ipairs(events) do
        for key in pairs(ns.runtime.moments) do ns.runtime.moments[key] = nil end
        assert(driver.events[name], "Missing event registration: " .. name)
        event(name, "test message", "Sender")
        assert(ns.runtime.moments[condition] == now)
        for key in pairs(ns.runtime.moments) do assert(key == condition, "Unrelated chat condition triggered") end
        local rule = { condition = condition, duration = 4 }
        assert(ns:ConditionIsMet(condition, "chat", rule, false, now + 3))
        assert(not ns:ConditionIsMet(condition, "chat", rule, false, now + 5))
        now = now + 3
        event(name, "another message", "Sender")
        assert(ns:ConditionIsMet(condition, "chat", rule, false, now + 3), "New message must restart duration")
    end
end
for key in pairs(ns.runtime.moments) do ns.runtime.moments[key] = nil end
for _, name in ipairs({ "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER_INFORM", "CHAT_MSG_SYSTEM",
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_CHANNEL_NOTICE", "CHAT_MSG_CHANNEL_JOIN", "CHAT_MSG_RAID_BOSS_WHISPER" }) do
    event(name, "test", "Sender")
    assert(next(ns.runtime.moments) == nil, "Unexpected reveal from " .. name)
end
assert(driver.events.CHAT_MSG_CHANNEL)
assert(ns.CONDITION_INFO.chat_general.duration == 10)
for _, channelType in ipairs({ 0, 2, 22, 26 }) do
    event("CHAT_MSG_CHANNEL", "test", "Sender", "", "Other channel", "", "", channelType, 1, "Other")
    assert(not ns.runtime.moments.chat_general, "Channel number 1 is not necessarily General")
end
event("CHAT_MSG_CHANNEL", "test", "Sender", "", "7. General - Zone", "", "", 1, 7, "General")
assert(ns.runtime.moments.chat_general == now)
assert(ns:ConditionIsMet("chat_general", "chat", { duration = 3 }, false, now + 2))
assert(not ns:ConditionIsMet("chat_general", "chat", { duration = 3 }, false, now + 4))
now = now + 2
event("CHAT_MSG_CHANNEL", "test", "Sender", "", "Localized General", "", "", 1, 4, "Localized name")
assert(ns.runtime.moments.chat_general == now)
assert(driver.events.CHAT_MSG_SYSTEM and driver.events.CHAT_MSG_BN_INLINE_TOAST_ALERT)
assert(ns.CONDITION_INFO.chat_friend_status.category == "chat")
ERR_FRIEND_ONLINE_SS = "|Hplayer:%s|h[%s]|h has come online."
ERR_FRIEND_OFFLINE_S = "%s has gone offline."
local function friendEvent(name, message)
    now = now + 1
    event(name, message)
    assert(ns.runtime.moments.chat_friend_status == now)
    assert(ns:ConditionIsMet("chat_friend_status", "chat", { duration = 3 }, false, now + 2))
    assert(not ns:ConditionIsMet("chat_friend_status", "chat", { duration = 3 }, false, now + 4))
end
friendEvent("CHAT_MSG_SYSTEM", string.format(ERR_FRIEND_ONLINE_SS, "Friend-Realm", "Friend"))
friendEvent("CHAT_MSG_SYSTEM", string.format(ERR_FRIEND_OFFLINE_S, "Friend"))
friendEvent("CHAT_MSG_BN_INLINE_TOAST_ALERT", "FRIEND_ONLINE")
friendEvent("CHAT_MSG_BN_INLINE_TOAST_ALERT", "FRIEND_OFFLINE")
local last = ns.runtime.moments.chat_friend_status
now = now + 1
event("CHAT_MSG_SYSTEM", "Friend has gone offline!") -- Punctuation is literal.
event("CHAT_MSG_SYSTEM", "Guild member has come online.")
event("CHAT_MSG_BN_INLINE_TOAST_ALERT", "FRIEND_REQUEST")
event("CHAT_MSG_BN_INLINE_TOAST_ALERT", "FRIEND_REMOVED")
event("CHAT_MSG_SAY", "Friend has gone offline.")
event("CHAT_MSG_SYSTEM", {})
assert(ns.runtime.moments.chat_friend_status == last)
ERR_FRIEND_OFFLINE_S = "%1$s est hors ligne (ami)."
friendEvent("CHAT_MSG_SYSTEM", "Ami est hors ligne (ami).")
local secret = {}
issecretvalue = function(value) return value == secret end
event("CHAT_MSG_SYSTEM", secret)
event("CHAT_MSG_BN_INLINE_TOAST_ALERT", secret)
assert(ns.runtime.moments.chat_friend_status == now)
print("PASS: chat activity, localized friend notifications, Battle.net presence, unrelated messages and duration refresh/expiry")
