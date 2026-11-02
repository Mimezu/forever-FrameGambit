local root = arg and arg[1] or "Interface/AddOns/FrameGambit"
GetTime = function() return 1 end
InCombatLockdown = function() return false end
SlashCmdList = {}
C_Timer = { After = function() end }
CreateFrame = function() return { RegisterEvent = function() end, RegisterUnitEvent = function() end, SetScript = function() end } end
local ns = {}
assert(loadfile(root .. "/Core.lua"))("FrameGambit", ns)
ns.Wake, ns.RefreshOptions = function() end, function() end
ns.ResolveTarget = function() return {} end
local health = { player = 10, party1 = 20, party2 = 30, party3 = 40, party4 = 50 }
local mana = { player = 12.5, party1 = 25, party2 = 37.5, party3 = 50, party4 = 62.5 }
local units = { "player", "party1", "party2", "party3", "party4" }
for index, unit in ipairs(units) do _G["CompactPartyFrameMember" .. index] = { unit = unit } end
UnitExists = function(unit) return health[unit] ~= nil end
local raid, offline, calls = false, nil, 0
IsInRaid = function() return raid end
UnitIsConnected = function(unit) return unit ~= offline end
UnitHealth = function(unit) calls = calls + 1; return health[unit] end
UnitHealthMax = function() return 100 end
UnitPower = function(unit, power) assert(power == 0); return mana[unit] end
UnitPowerMax = function() return 100 end
local rules = {}
for index = 1, 5 do
    rules[index] = { id = index, condition = "party_health", partyMember = index, percentageOperator = "=", percentageThreshold = health[units[index]], opacity = 0.5 }
    rules[5 + index] = { id = 5 + index, condition = "party_mana", partyMember = index, percentageOperator = "=", percentageThreshold = mana[units[index]], opacity = 0.7 }
end
local settings = { enabled = true, reactions = rules }
FrameGambitDB = { profile = "Default", profiles = { Default = { targets = { chat = settings } } } }
local function met(rule) return ns:ConditionIsMet(rule.condition, "chat", rule) end
ns:BuildStateContext()
for _, rule in ipairs(rules) do assert(met(rule), "select assigned unit for slot " .. rule.partyMember) end
assert(calls == 5, "sample each unit once despite Any and numbered rules")
-- Reordered compact layout: slot 1 now shows party3 rather than the player.
CompactPartyFrameMember1.unit = "party3"
ns:BuildStateContext(); assert(not met(rules[1]))
rules[1].percentageThreshold = 40
ns:BuildStateContext(); assert(met(rules[1]))
offline = "party3"
ns:BuildStateContext(); assert(not met(rules[1]))
offline = nil
CompactPartyFrameMember1.unit = nil
ns:BuildStateContext(); assert(not met(rules[1]), "missing assignment must not select another unit")
CompactPartyFrameMember1.unit = "player"
rules[1].percentageThreshold = 10
raid = true
ns:BuildStateContext(); assert(not met(rules[1]), "party selectors exclude raids")
raid = false
-- Any retains legacy other-member behavior and must not include the player.
rules[1].partyMember = nil
ns:BuildStateContext(); assert(not met(rules[1]))
rules[1].percentageThreshold = 20
ns:BuildStateContext(); assert(met(rules[1]))
rules[1].partyMember, rules[1].percentageThreshold = 1, 10
local payload = assert(ns:ExportProfile("Default"))
local restored = assert(ns:ParseProfileImport(payload))
for index, rule in ipairs(restored.targets.chat.reactions) do
    assert(rule.partyMember == ((index - 1) % 5) + 1)
end
assert(ns:CopyTargetRules("chat"))
assert(ns:PasteTargetRules("party_frames"))
assert(ns:GetTargetSettings("party_frames").reactions[1].partyMember == 1)
local function invalidMember(field)
    local body = payload:match("^[^\n]+\n(.*)$")
    local old = "P|chat|1|=|10|1"
    local first, last = assert(body:find(old, 1, true))
    body = body:sub(1, first-1) .. "P|chat|1|=|10|" .. field .. body:sub(last+1)
    local checksum = 0
    for index = 1, #body do checksum = (checksum + body:byte(index) * index) % 65521 end
    return "FrameGambit-1:" .. string.format("%04X", checksum) .. "\n" .. body
end
for _, field in ipairs({ "0", "6", "1.5", "player" }) do assert(not ns:ParseProfileImport(invalidMember(field))) end
for _, value in ipairs({ 0, 6, 1.5, "invalid" }) do
    local rule = { condition = "party_health", partyMember = value }
    ns:NormalizePercentageReaction(rule); assert(rule.partyMember == nil)
end
local playerRule = { condition = "player_health", partyMember = 1 }
ns:NormalizePercentageReaction(playerRule); assert(playerRule.partyMember == nil)
print("Party member slots, reorder, unknown/offline/raid, Any, copy and import tests passed")
