__print = print
local root = arg and arg[1] or "Interface/AddOns/FrameGambit"
local now, driver, wakes = 10, nil, 0
GetTime = function() return now end
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
assert(loadfile(root .. "/ExtraConditions.lua"))("FrameGambit", ns)
ns.Wake = function() wakes = wakes + 1 end
local secret = {}
issecretvalue = function(v) return rawequal(v, secret) end
local units, raid, instance, mapID = {}, false, false, 84
IsInRaid = function() return raid end
IsInInstance = function() return instance end
UnitExists = function(u) return units[u] ~= nil end
UnitIsConnected = function(u) return units[u] and units[u].connected ~= false end
UnitAffectingCombat = function(u) return units[u] and units[u].combat or false end
UnitGUID = function(u) return units[u] and units[u].guid end
UnitName = function(u) return units[u] and units[u].name, units[u] and units[u].realm end
UnitCanAttack = function(_, u) return units[u] and units[u].hostile or false end
UnitIsDeadOrGhost = function(u) return units[u] and units[u].dead or false end
UnitClassification = function(u) return units[u] and units[u].classification end
UnitThreatSituation = function(_, u) return units[u] and units[u].threat end
UnitDetailedThreatSituation = function(_, u) return false, 0, 0, 0, units[u] and units[u].rawThreat end
C_Map = {
    GetBestMapForUnit = function() return mapID end,
    GetMapInfo = function(id) return { parentMapID = id == 9999 and 84 or 0 } end,
}
local needed = { party_combat = true, major_city = true, elite_combat = true }
local function state()
    local c = {}
    ns:BuildExtraConditionContext(needed, c)
    return c
end
assert(state().major_city and not state().party_combat and not state().elite_combat)
mapID = 1453; assert(state().major_city, "Forever city")
mapID = 2393; assert(state().major_city, "Midnight city")
mapID = 9999; assert(state().major_city, "City interior inherits city")
mapID = 12; IsResting = function() return true end
assert(not state().major_city, "An outdoor inn is not a city")
mapID = 84; instance = true; assert(not state().major_city, "City dungeon is not outdoor city")
instance = false; mapID = secret; assert(not state().major_city)
mapID = nil; assert(not state().major_city)
mapID = 84
units.player = { combat = true, guid = "self", name = "Self" }
assert(not state().party_combat, "Player excluded")
units.party1 = { combat = true, guid = "friend", name = "Friend" }
assert(state().party_combat)
units.party1.connected = false; assert(not state().party_combat)
units.party1.connected = true; units.party1.combat = secret; assert(not state().party_combat)
units.party1.combat = true; raid = true; assert(not state().party_combat)
raid = false
units.target = { hostile = true, classification = "elite" }
assert(not state().elite_combat, "Targeting an idle elite does not count")
units.target.threat = 0; assert(not state().elite_combat, "Status zero needs readable positive threat")
units.target.rawThreat = 0; assert(not state().elite_combat, "No threat does not count")
units.target.rawThreat = secret; assert(not state().elite_combat, "Secret threat does not count")
units.target.rawThreat = 25; assert(state().elite_combat, "Non-tanking positive threat counts")
local detailedThreat = UnitDetailedThreatSituation
UnitDetailedThreatSituation = nil; assert(not state().elite_combat, "Missing detailed API is unavailable")
UnitDetailedThreatSituation = function() error("restricted") end
assert(not state().elite_combat, "Failing detailed API is unavailable")
UnitDetailedThreatSituation = detailedThreat
units.target.threat = secret; assert(not state().elite_combat)
units.target.threat = 2; units.target.classification = secret; assert(not state().elite_combat)
units.target.classification = "rare"; assert(not state().elite_combat, "Non-elite rare excluded")
units.target.classification = "rareelite"; assert(state().elite_combat)
units.target.dead = true; assert(not state().elite_combat)
units.target.dead = false; units.target.hostile = false; assert(not state().elite_combat)
units.nameplate40 = { hostile = true, classification = "worldboss", threat = 3 }
assert(state().elite_combat)
units.player.combat = false; assert(not state().elite_combat)
units.player.combat = secret; assert(not state().elite_combat)

LOOT_ITEM = "%s receives loot: %s."
LOOT_ITEM_MULTIPLE = "%s receives loot: %sx%d."
LOOT_ITEM_PUSH = "%s receives item: %s."
LOOT_ITEM_PUSH_MULTIPLE = "%s receives item: %sx%d."
LOOT_ROLL_WON = "%s won: %s"
LOOT_ROLL_YOU_WON = "You won: %s"
LOOT_ROLL_WON_NO_SPAM_NEED = "%1$s won: %3$s (Need - %2$d)"
LOOT_ROLL_YOU_WON_NO_SPAM_DE = "|HlootHistory:%d|h[Loot]|h: You (Disenchant - %d) Won: %s"
local function loot(message, name, guid)
    now = now + 1
    driver.scripts.OnEvent(driver, "CHAT_MSG_LOOT", message, name, nil, nil, nil, nil, nil, nil, nil, nil, nil, guid)
end
local item = "|cffabcdef|Hitem:123:0|h[Sword (Test)]|h|r"
loot("Friend receives loot: " .. item .. ".", "", nil)
assert(ns.runtime.moments.chat_party_loot == now, "Empty sender uses localized receiver")
assert(ns:ConditionIsMet("chat_party_loot", "chat", { duration = 3 }, false, now + 2))
assert(not ns:ConditionIsMet("chat_party_loot", "chat", { duration = 3 }, false, now + 4))
loot("Friend receives item: " .. item .. "x2.", "", "friend")
assert(ns.runtime.moments.chat_party_loot == now)
local last = ns.runtime.moments.chat_party_loot
loot("Self receives loot: " .. item .. ".", "Self", "self")
loot("Stranger receives loot: " .. item .. ".", "Stranger", "stranger")
loot("Friend receives loot: " .. item .. ".", "Friend", "stranger")
loot("Friend receives loot: " .. item .. ".", secret, nil)
loot("Friend receives loot: " .. item .. ".", "Friend", secret)
loot(secret, nil, nil)
assert(ns.runtime.moments.chat_party_loot == last, "Self/stranger/secret must not reveal party loot")
raid = true; loot("Friend receives loot: " .. item .. ".", "Friend", "friend")
assert(ns.runtime.moments.chat_party_loot == last); raid = false
units.party1.realm = "Other Realm"
loot("Friend receives loot: " .. item .. ".", "Friend", nil)
assert(ns.runtime.moments.chat_party_loot == last, "Cross-realm short names do not establish identity")
loot("Friend-OtherRealm receives loot: " .. item .. ".", "", nil)
assert(ns.runtime.moments.chat_party_loot == now)
units.party1.realm = nil
LOOT_ITEM = "%2$s a ete recu par %1$s (butin)."
loot(item .. " a ete recu par Friend (butin).", "", nil)
assert(ns.runtime.moments.chat_party_loot == now, "Positional localized receiver")
loot("Friend won: " .. item, nil, nil)
assert(ns.runtime.moments.chat_loot_winner == now)
loot("You won: " .. item, nil, nil)
assert(ns.runtime.moments.chat_loot_winner == now)
loot("Friend won: " .. item .. " (Need - 95)", nil, nil)
assert(ns.runtime.moments.chat_loot_winner == now)
loot("|HlootHistory:1|h[Loot]|h: You (Disenchant - 76) Won: " .. item, nil, nil)
assert(ns.runtime.moments.chat_loot_winner == now)
last = ns.runtime.moments.chat_loot_winner
loot("Friend selected Need for: " .. item, nil, nil)
loot("All passed on: " .. item, nil, nil)
assert(ns.runtime.moments.chat_loot_winner == last)
assert(ns:ConditionIsMet("chat_loot_winner", "chat", {}, true, last + 9))
assert(not ns:ConditionIsMet("chat_loot_winner", "chat", {}, true, last + 11))
assert(driver.events.CHAT_MSG_LOOT and wakes > 0)
-- Campfire sitting follows only a learned timer aura; learning needs /fg campfire.
local playerAuras, printed = {}, {}
print = function(text) printed[#printed + 1] = tostring(text) end
C_UnitAuras = {
    GetPlayerAuraBySpellID = function(id)
        for _, aura in ipairs(playerAuras) do if aura.spellId == id then return aura end end
    end,
    GetAuraDataByIndex = function(_, index, filter)
        local seen = 0
        for _, aura in ipairs(playerAuras) do
            if (aura.harmful and "HARMFUL" or "HELPFUL") == filter then
                seen = seen + 1
                if seen == index then return aura end
            end
        end
    end,
}
FrameGambitDB = {}
local campNeed = { campfire_sitting = true }
local function sitting() local c = {}; ns:BuildExtraConditionContext(campNeed, c); return c.campfire_sitting end
assert(sitting() == false, "No timer aura is not sitting")
playerAuras = { { spellId = 1229739, name = "Welcoming Campfire", duration = 60, expirationTime = now + 40 } }
assert(sitting() == true, "Welcoming Campfire is built in")
playerAuras = {}
ns:HandleCampfireCommand("")
assert(printed[#printed]:find("no auras"), "Empty aura list explains how to learn")
playerAuras = {
    { spellId = 1, name = "Power Word: Fortitude", duration = 1800, expirationTime = now + 1700 },
    { spellId = 1229451, name = "Boosted Rest", duration = 3600, expirationTime = now + 3000, harmful = true },
    { spellId = 777, name = "Campfire Timer", duration = 60, expirationTime = now + 42 },
}
ns:HandleCampfireCommand("")
assert(FrameGambitDB.campfireAuras[777] == "Campfire Timer", "Single short aura is learned")
assert(sitting() == true)
table.remove(playerAuras, 3); assert(sitting() == false, "Timer gone: standing or buffed")
playerAuras[3] = { spellId = 777, name = secret, duration = 60, expirationTime = now + 30 }
assert(sitting() == true, "Learned IDs do not need a readable name")
C_UnitAuras.GetPlayerAuraBySpellID = function() return secret end
assert(sitting() == false, "Secret aura data is not sitting")
ns:HandleCampfireCommand("clear"); assert(FrameGambitDB.campfireAuras == nil)
playerAuras = {
    { spellId = 5, name = "Food", duration = 30, expirationTime = now + 20 },
    { spellId = 6, name = "Cozy Fire", duration = 60, expirationTime = now + 50 },
}
ns:HandleCampfireCommand("")
assert(FrameGambitDB.campfireAuras == nil, "Ambiguous short auras are not guessed")
ns:HandleCampfireCommand("9"); assert(FrameGambitDB.campfireAuras == nil)
ns:HandleCampfireCommand("2"); assert(FrameGambitDB.campfireAuras[6] == "Cozy Fire", "Numbered pick")
playerAuras = { { spellId = 8, name = "Warm Glow", duration = 0, expirationTime = 0 } }
FrameGambitDB.campfireAuras = nil
ns:HandleCampfireCommand(""); assert(FrameGambitDB.campfireAuras == nil, "Untimed aura needs a pick")
ns:HandleCampfireCommand("1"); assert(FrameGambitDB.campfireAuras[8])
print = _G.__print

-- The module uses the same shared evaluator and profile wire format as Core.
ns.IsCinematicActive = function() return false end
ns.ResolveTarget = function() return {} end
local reactions = {}
for index, id in ipairs({ "major_city", "party_combat", "elite_combat", "chat_party_loot", "chat_loot_winner", "campfire_sitting" }) do
    reactions[index] = { id = index, condition = id, opacity = 1 }
end
FrameGambitDB = { profile = "Default", profiles = { Default = { targets = {
    chat = { enabled = true, reactions = reactions },
} } } }
ns:GetTargetSettings("chat")
ns:BuildStateContext()
assert(ns:ConditionIsMet("major_city", "chat", reactions[1]), "shared evaluator calls module")
local parsed = assert(ns:ParseProfileImport(assert(ns:ExportProfile("Default"))))
for index, reaction in ipairs(reactions) do
    assert(parsed.targets.chat.reactions[index].condition == reaction.condition)
end
print("PASS: party combat/loot identity, localized roll winners, city maps, engaged elites, secret values, moment expiry, campfire timer learning")
