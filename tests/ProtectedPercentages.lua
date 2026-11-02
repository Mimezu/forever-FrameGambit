local root = arg and arg[1] or "Interface/AddOns/FrameGambit"
local secrets = setmetatable({}, { __mode = "k" })
local function secret(value)
    local token = setmetatable({}, {
        __lt = function() error("secret comparison") end,
        __le = function() error("secret comparison") end,
        __sub = function() error("secret arithmetic") end,
        __mul = function() error("secret arithmetic") end,
        __tostring = function() error("secret formatting") end,
    })
    secrets[token] = value
    return token
end
issecretvalue = function(value) return type(value) == "table" and secrets[value] ~= nil end
local function unwrap(value) if issecretvalue(value) then return secrets[value] end; return value end
GetTime = function() return 1 end
InCombatLockdown = function() return false end
SlashCmdList = {}
C_Timer = { After = function() end }
local selectorCount = 0
CreateFrame = function(kind)
    if kind == "StatusBar" then
        selectorCount = selectorCount + 1
        local bar = {}
        function bar:Hide() end
        function bar:SetMinMaxValues(low, high)
            self.low, self.high = low, high
            if self.value ~= nil then self:SetValue(self.value) end
        end
        function bar:SetValue(value)
            local result = math.max(unwrap(self.low), math.min(unwrap(self.high), unwrap(value)))
            self.value = (issecretvalue(value) or issecretvalue(self.low) or issecretvalue(self.high)) and secret(result) or result
        end
        function bar:GetValue() return self.value end
        return bar
    end
    return { RegisterEvent = function() end, RegisterUnitEvent = function() end, SetScript = function() end }
end
hooksecurefunc = function(object, name, hook)
    local original = object[name]
    object[name] = function(self, ...) original(self, ...); hook(self, ...) end
end
Enum = { LuaCurveType = { Step = 1, Linear = 0 } }
CreateColor = function(r, g, b, a) return { GetRGBA = function() return r, g, b, a end } end
C_CurveUtil = { CreateColorCurve = function()
    local curve = { points = {} }
    function curve:SetType(kind) self.kind = kind end
    function curve:ClearPoints() self.points = {} end
    function curve:AddPoint(x, color)
        local r, g, b, a = color:GetRGBA()
        assert(not issecretvalue(r) and not issecretvalue(g) and not issecretvalue(b) and not issecretvalue(a), "AddPoint rejects protected color components")
        self.points[#self.points + 1] = { x, a, r, g, b }
    end
    function curve:Evaluate(input)
        assert(not issecretvalue(input), "Secret values are only allowed during untainted execution")
        local value, alpha = unwrap(input), self.points[1][2]
        local selected = self.points[1]
        if self.kind == 0 then
            alpha = value * unwrap(self.points[2][2])
        else
            for _, point in ipairs(self.points) do if value >= point[1] then alpha = point[2]; selected = point end end
        end
        return CreateColor(secret(selected[3]), secret(selected[4]), secret(selected[5]), secret(unwrap(alpha)))
    end
    return curve
end }
local health = { player = 0.5, party1 = 0.9, party2 = 0.8 }
UnitExists = function(unit) return health[unit] ~= nil end
UnitIsConnected = function() return true end
IsInRaid = function() return false end
UnitHealth = function(unit) return secret(health[unit] * 100) end
UnitHealthMax = function() return 100 end
UnitHealthPercent = function(unit, predicted, curve) return curve:Evaluate(health[unit]) end
local ns = {}
assert(loadfile(root .. "/Core.lua"))("FrameGambit", ns)
assert(loadfile(root .. "/Targets.lua"))("FrameGambit", ns)
assert(loadfile(root .. "/PercentageOpacity.lua"))("FrameGambit", ns)
ns.Wake, ns.RefreshOptions = function() end, function() end
local function frame(alpha)
    local f = { alpha = alpha, children = {} }
    function f:GetAlpha() return self.alpha end
    function f:SetAlpha(value) if self.rejectAlpha then error("alpha write blocked") end; self.alpha = value end
    function f:IsShown() return true end
    function f:GetRect() return 0, 0, 100, 20 end
    function f:GetChildren() return unpack(self.children) end
    return f
end
CompactPartyFrame = frame(0.85)
local member = frame(1)
member.selectionHighlight = frame(0.8)
function member.selectionHighlight:IsIgnoringParentAlpha() return true end
CompactPartyFrame.children = { member }
assert(loadfile(root .. "/PartySelection.lua"))("FrameGambit", ns)
local rule = { condition = "player_health", percentageOperator = "<", percentageThreshold = 70, opacity = 0.5 }
local settings = { enabled = true, atRest = 0, reactions = {
    { condition = "mouseover", opacity = 1 }, rule,
    { condition = "party_health", percentageOperator = "<", percentageThreshold = 70, opacity = 0.7 },
} }
FrameGambitDB = { profile = "Default", profiles = { Default = { targets = { party_frames = settings } } } }
local function tick(expected)
    ns:BuildStateContext()
    ns:ApplyTarget("party_frames", 1)
    assert(math.abs(unwrap(CompactPartyFrame.alpha) - expected) < 1e-10)
    assert(math.abs(unwrap(member.selectionHighlight.alpha) - expected * 0.8) < 1e-10, "highlight follows protected opacity")
end
tick(0.5)
assert(ns.runtime.active.party_frames.protectedPercentage)
health.player = 0.9; tick(0)
health.party2 = 0.5; tick(0.7)
health.player = 0.5; tick(0.5)
ns.runtime.hovered.party_frames = true; tick(1)
assert(ns.runtime.active.party_frames.index == 1, "public mouseover winner must highlight its row")
assert(ns.runtime.active.party_frames.reaction == settings.reactions[1], "public winner must retain its label")
assert(not ns.runtime.active.party_frames.protectedPercentage, "public winner must replace protected status")
ns.runtime.hovered.party_frames = nil; tick(0.5)
assert(ns.runtime.active.party_frames.index == nil and ns.runtime.active.party_frames.reaction == nil,
    "protected result must not claim the previous public winner")
assert(ns.runtime.active.party_frames.protectedPercentage, "protected health must retain native status")
CompactPartyFrame:SetAlpha(0.9)
assert(unwrap(CompactPartyFrame.alpha) == 0.5, "host repaint retains protected rule")
health.party2 = 0.8
for _, case in ipairs({ {"<",0.7,0},{"<=",0.7,0.5},{">",0.7,0},{">=",0.7,0.5},{"=",0.7,0.5},{"~=",0.7,0}, {"~=",1,0.5} }) do
    rule.percentageOperator, health.player = case[1], case[2]
    tick(case[3])
end
rule.percentageOperator, rule.percentageThreshold, health.player = "~=", 100, 0.9; tick(0.5)
health.player = 1; tick(0)
rule.percentageOperator, rule.percentageThreshold, health.player = "=", 0, 0; tick(0.5)
rule.requirements = { "combat" }; tick(0)
rule.requirements = {}; tick(0.5)
-- Numbered protected health and mana follow the frame's current unit.
CompactPartyFrameMember1 = { unit = "player" }
CompactPartyFrameMember2 = { unit = "party1" }
UnitPower = function(unit) return secret(health[unit] * 100) end
UnitPowerMax = function() return 100 end
UnitPowerPercent = function(unit, power, unmodified, curve)
    assert(power == 0)
    return curve:Evaluate(health[unit])
end
for _, condition in ipairs({ "party_health", "party_mana" }) do
    rule.condition, rule.partyMember = condition, 1
    rule.percentageOperator, rule.percentageThreshold = "<", 70
    health.player, health.party1 = 0.5, 0.9
    tick(0.5)
    rule.partyMember = 2; tick(0)
    CompactPartyFrameMember2.unit = "player"; tick(0.5)
    CompactPartyFrameMember2.unit = nil; tick(0)
    CompactPartyFrameMember2.unit = "party1"
end
rule.condition, rule.partyMember = "player_health", nil
tick(0.5)
ns:RestoreControlledFrame("party_frames")
assert(CompactPartyFrame.alpha == 0.9, "restore latest public host opacity")
assert(member.selectionHighlight.alpha == 0.8, "restore highlights")
assert(ns.runtime.protectedAlpha[CompactPartyFrame] == nil)
-- Native border alpha 1 forwards the opaque parent directly.
member.selectionHighlight:SetAlpha(1)
health.player = 1
ns:BuildStateContext(); ns:ApplyTarget("party_frames", 1)
ns:ResolveTarget("party_frames")
assert(unwrap(member.selectionHighlight.alpha) == 0, "whole-party hidden border")
health.player = 0.5
ns:BuildStateContext(); ns:ApplyTarget("party_frames", 1)
ns:ResolveTarget("party_frames")
assert(unwrap(member.selectionHighlight.alpha) == 0.5, "whole-party visible border")
ns:RestoreControlledFrame("party_frames")
assert(member.selectionHighlight.alpha == 1)
-- A title can have an opaque local alpha aspect after its parent fades.
CompactPartyFrameTitle = frame(0.9)
function CompactPartyFrameTitle:GetAlpha() return secret(unwrap(self.alpha)) end
assert(ns:RegisterTarget({ id = "custom_frame_title", label = "Party title", names = { "CompactPartyFrameTitle" } }))
ns:Profile().targets.custom_frame_title = { enabled = true, atRest = 0, reactions = {} }
health.player = 1
ns:BuildStateContext(); ns:ApplyTarget("party_frames", 1)
ns:ApplyTarget("custom_frame_title", 1)
assert(unwrap(CompactPartyFrameTitle.alpha) == 0, "opaque child still applies its own zero rule")
ns.runtime.hovered.party_frames = true
ns:ApplyTarget("party_frames", 1)
ns:ApplyTarget("custom_frame_title", 1)
assert(unwrap(CompactPartyFrame.alpha) == 1 and unwrap(CompactPartyFrameTitle.alpha) == 0, "parent mouseover cannot override title")
CompactPartyFrameTitle:SetAlpha(secret(0.6))
assert(unwrap(CompactPartyFrameTitle.alpha) == 0, "opaque host repaint respects title rule")
CompactPartyFrameTitle.rejectAlpha = true
ns:RestoreControlledFrame("custom_frame_title")
assert(ns.runtime.pendingRestore[CompactPartyFrameTitle], "opaque baseline restore queued")
CompactPartyFrameTitle.rejectAlpha = false
ns:RestorePendingAlphas()
assert(unwrap(CompactPartyFrameTitle.alpha) == 0.6, "restore latest opaque native title alpha")
-- Real party trees exceed the generic scan budget. Known borders must be
-- visited first, even if their alpha is already opaque on first acquisition.
ns:RestoreControlledFrame("party_frames")
ns.runtime.hovered.party_frames = nil
CompactPartyFrame = frame(1)
local busy = frame(1)
for index = 1, 140 do busy.children[index] = frame(1) end
local late = frame(1)
function late:GetParent() return CompactPartyFrame end
late.selectionHighlight = frame(secret(1))
function late.selectionHighlight:IsIgnoringParentAlpha() return true end
CompactPartyFrameMember1 = late
CompactPartyFrame.children = { busy, late }
health.player = 1
ns:BuildStateContext(); ns:ApplyTarget("party_frames", 1)
assert(unwrap(late.selectionHighlight.alpha) == 0, "known member bypasses exhausted subtree budget")
health.player = 0.5
ns:BuildStateContext(); ns:ApplyTarget("party_frames", 1)
assert(unwrap(late.selectionHighlight.alpha) == 0.5)
ns:RestoreControlledFrame("party_frames")
assert(unwrap(late.selectionHighlight.alpha) == 1, "restore opaque late border baseline")
-- Reproduce the reported player health + Any party health + player mana stack.
local mana = 1
UnitPower = function() return secret(mana * 100) end
UnitPowerPercent = function(_, _, _, curve) return curve:Evaluate(mana) end
settings.reactions = {
    { condition = "mouseover", opacity = 1 },
    { condition = "player_health", percentageOperator = "<", percentageThreshold = 70, opacity = 0.2 },
    { condition = "party_health", percentageOperator = "<", percentageThreshold = 50, opacity = 0.8 },
    { condition = "player_mana", percentageOperator = "<", percentageThreshold = 60, opacity = 0.4 },
}
for playerMatch = 0, 1 do
    for partyMatch = 0, 1 do
        for manaMatch = 0, 1 do
            health.player = playerMatch == 1 and 0.3 or 1
            health.party1, health.party2 = 1, partyMatch == 1 and 0.3 or 1
            mana = manaMatch == 1 and 0.3 or 1
            ns:BuildStateContext()
            local expected = playerMatch == 1 and 0.2 or partyMatch == 1 and 0.8 or manaMatch == 1 and 0.4 or 0
            local alpha = ns:Evaluate("party_frames", settings, nil, 1)
            assert(math.abs(unwrap(alpha) - expected) < 1e-10, "first matching protected rule must win")
            assert(not ns.runtime.percentageCurveErrors.party_frames, "all protected rules must be evaluated")
            local scaled = ns:Evaluate("party_frames", settings, nil, 1, 0.8)
            assert(math.abs(unwrap(scaled) - expected * 0.8) < 1e-10, "border scaling preserves priority")
        end
    end
end
assert(selectorCount == 1, "reuse one hidden native selector across units, rules and ticks")
print("Protected health/mana priority and borders pass with protected curve points forbidden")
