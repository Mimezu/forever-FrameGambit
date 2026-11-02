local root = arg and arg[1] or "Interface/AddOns/FrameGambit"
GetTime = function() return 1 end
InCombatLockdown = function() return false end
SlashCmdList = {}
C_Timer = { After = function() end }
CreateFrame = function() return { RegisterEvent = function() end, RegisterUnitEvent = function() end, SetScript = function() end } end
local ns = {}
assert(loadfile(root .. "/Core.lua"))("FrameGambit", ns)
ns.IsCinematicActive = function() return false end
ns.Wake = function() end
ns.RefreshOptions = function() end
ns.ResolveTarget = function() return {} end
local rules = {}
for index, condition in ipairs({ "player_health", "player_mana", "party_health", "party_mana" }) do
    rules[index] = { id = index, condition = condition, percentageOperator = "<", percentageThreshold = 50, opacity = 1 }
end
local settings = { enabled = true, reactions = rules }
FrameGambitDB = { profile = "Default", profiles = { Default = { targets = { chat = settings } } } }
local units = { player = { 40, 100, 25, 100 }, party1 = { 70, 100, 0, 0 }, party2 = { 20, 100, 80, 100 } }
local calls, raid = 0, false
UnitExists = function(unit) return units[unit] ~= nil end
IsInRaid = function() return raid end
local disconnected = false
UnitIsConnected = function() return not disconnected end
UnitHealth = function(unit) calls = calls + 1; return units[unit][1] end
UnitHealthMax = function(unit) return units[unit][2] end
UnitPower = function(unit, power) assert(power == 0); calls = calls + 1; return units[unit][3] end
UnitPowerMax = function(unit, power) assert(power == 0); return units[unit][4] end
local function met(rule) return ns:ConditionIsMet(rule.condition, "chat", rule) end
ns:BuildStateContext()
assert(met(rules[1]) and met(rules[2]) and met(rules[3]) and not met(rules[4]))
assert(calls == 5, "sample units once per requested resource, skipping absent mana")
for i = 1, 50 do assert(met(rules[1])) end
assert(calls == 5, "evaluation never re-queries unit APIs")
-- Exercise the user's full priority-rule path, including damage and recovery.
local userSettings = { enabled = true, atRest = 0, reactions = {
    { condition = "mouseover", opacity = 1 },
    { condition = "player_health", percentageOperator = "~=", percentageThreshold = 100, opacity = 0.5 },
    { condition = "party_health", percentageOperator = "<", percentageThreshold = 70, opacity = 0.7 },
} }
local profile = ns:Profile()
profile.targets.chat = userSettings
local function checkPlayerHealth(health, operator, threshold, expected)
    units.player[1] = health
    userSettings.reactions[2].percentageOperator = operator
    userSettings.reactions[2].percentageThreshold = threshold
    ns:BuildStateContext()
    assert(ns:Evaluate("chat", userSettings) == expected, "health must select the correct priority rule")
end
checkPlayerHealth(90, "~=", 100, 0.5)
checkPlayerHealth(50, "<", 70, 0.5)
checkPlayerHealth(100, "<", 70, 0.7)
ns.runtime.hovered.chat = true
checkPlayerHealth(50, "<", 70, 1)
ns.runtime.hovered.chat = nil
profile.targets.chat = settings
units.player[1] = 40
ns:BuildStateContext()
local r = rules[1]
for _, case in ipairs({ {"<",40,false},{"<=",40,true},{"=",40,true},{"~=",40,false},{">=",40,true},{">",40,false},{">",39,true} }) do
    r.percentageOperator, r.percentageThreshold = case[1], case[2]
    assert(met(r) == case[3], "comparison " .. case[1])
end
units.player[1] = 0
r.percentageOperator, r.percentageThreshold = "=", 0
ns:BuildStateContext(); assert(met(r), "zero health is valid")
units.player[1] = 100
r.percentageThreshold = 100
ns:BuildStateContext(); assert(met(r), "100 percent is valid")
raid = true
ns:BuildStateContext(); assert(not met(rules[3]) and not met(rules[4]), "raid excludes party rules")
raid = false
disconnected = true
ns:BuildStateContext(); assert(not met(rules[3]), "offline members cannot match")
disconnected = false
units.party2 = nil
ns:BuildStateContext(); assert(not met(rules[3]), "player never satisfies party rule")
units.player[4] = 0
rules[2].percentageOperator = "~="
ns:BuildStateContext(); assert(not met(rules[2]), "no mana is unknown even for not-equal")
local secret = setmetatable({}, { __lt = function() error("secret compared") end, __div = function() error("secret divided") end })
issecretvalue = function(v) return rawequal(v, secret) end
units.player[1] = secret
r.percentageOperator = "~="
ns:BuildStateContext(); assert(not met(r), "secret current health is unknown")
units.player[1], units.player[2] = 20, secret
ns:BuildStateContext(); assert(not met(r), "secret maximum health is unknown")
UnitHealth = function() error("API restricted") end
ns:BuildStateContext(); assert(not met(r), "API failures are unknown")
assert(not ns:ConditionIsMet(r.condition, "chat", r, true), "parameterized requirements are unsupported")
ns:GetTargetSettings("chat")
rules = settings.reactions
r.percentageOperator, r.percentageThreshold = ">=", 12.5
rules[#rules + 1] = { id = 5, condition = r.condition, percentageOperator = "<=", percentageThreshold = 80, opacity = 0.25 }
local payload = assert(ns:ExportProfile("Default"))
local parsed = assert(ns:ParseProfileImport(payload))
assert(parsed.targets.chat.reactions[1].percentageThreshold == 12.5)
assert(parsed.targets.chat.reactions[1].percentageOperator == ">=")
assert(parsed.targets.chat.reactions[5].percentageOperator == "<=" and parsed.targets.chat.reactions[5].opacity == 0.25)
local function changedPayload(from, to)
    local body = payload:match("^[^\n]+\n(.*)$")
    local first, last = assert(body:find(from, 1, true))
    body = body:sub(1, first - 1) .. to .. body:sub(last + 1)
    local checksum = 0
    for index = 1, #body do checksum = (checksum + body:byte(index) * index) % 65521 end
    return "FrameGambit-1:" .. string.format("%04X", checksum) .. "\n" .. body
end
assert(not ns:ParseProfileImport(changedPayload("P|chat|1|>=|12.5", "P|chat|1|oops|12.5")), "invalid operator rejected")
assert(not ns:ParseProfileImport(changedPayload("P|chat|1|>=|12.5", "P|chat|1|>=|101")), "invalid threshold rejected")
assert(not ns:ParseProfileImport(changedPayload("P|chat|1|>=|12.5\n", "")), "missing parameter rejected")
assert(not ns:ParseProfileImport(changedPayload("P|chat|1|>=|12.5", "P|chat|1|>=|12.5\nP|chat|1|>=|12.5")), "duplicate parameter rejected")
assert(not ns:ParseProfileImport(changedPayload("R|chat|1|player_health|1||", "R|chat|1|player_health|1||party_health")), "parameterized requirement rejected")
for _, operator in ipairs(ns.PERCENTAGE_OPERATORS) do
    r.percentageOperator = operator.id
    local result = assert(ns:ParseProfileImport(assert(ns:ExportProfile("Default"))))
    assert(result.targets.chat.reactions[1].percentageOperator == operator.id)
end
local malformed = { condition = "player_health", percentageOperator = "bad", percentageThreshold = 999 }
ns:NormalizePercentageReaction(malformed)
assert(malformed.percentageOperator == "<" and malformed.percentageThreshold == 100)
-- Disabled rules and absent conditions must not query resource APIs.
for _, rule in ipairs(rules) do rule.enabled = false end
calls = 0
ns:BuildStateContext(); assert(calls == 0)
print("Percentage condition tests passed: " .. root)
