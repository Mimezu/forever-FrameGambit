local root = arg and arg[1] or "."
local combat = false
InCombatLockdown = function() return combat end
hooksecurefunc = function(object, name, hook)
    local original = object[name]
    object[name] = function(self, ...) original(self, ...); hook(self, ...) end
end
local function frame(alpha, ignores)
    local f = { alpha = alpha or 1, ignores = ignores, children = {}, shown = true }
    function f:GetAlpha() return self.alpha end
    function f:SetAlpha(value)
        self.writes = (self.writes or 0) + 1
        self.alpha = math.floor(value * 255 + 0.5) / 255
    end
    function f:IsIgnoringParentAlpha() return self.ignores end
    function f:IsShown() return self.shown end
    function f:GetChildren() return unpack(self.children) end
    return f
end
local function near(actual, expected)
    assert(math.abs(actual - expected) < 0.005, tostring(actual) .. " ~= " .. tostring(expected))
end
PartyFrame = frame()
CompactPartyFrame = frame()
local member, pet, ordinary = frame(0.4), frame(), frame()
member.selectionHighlight, pet.selectionHighlight, ordinary.selectionHighlight = frame(0.8, true), frame(1, true), frame(0.7, false)
PartyFrame.children = { CompactPartyFrame }
CompactPartyFrame.children = { member, pet, ordinary }
local target = { names = { "PartyFrame", "CompactPartyFrame" } }
local ns = { TargetByID = { party_frames = target } }
assert(loadfile(root .. "/PartySelection.lua"))("FrameGambit", ns)
assert(target.resolve() == PartyFrame)
assert(target.acquire(PartyFrame))
for _, opacity in ipairs({ 0.5, 0.2, 0, 1, 0 }) do
    PartyFrame:SetAlpha(opacity)
    near(member.selectionHighlight:GetAlpha(), 0.8 * opacity)
    near(pet.selectionHighlight:GetAlpha(), opacity)
    near(ordinary.selectionHighlight:GetAlpha(), 0.7)
    assert(member.selectionHighlight.ignores and member.selectionHighlight.shown)
end
local late = frame()
late.selectionHighlight = frame(1, true)
table.insert(CompactPartyFrame.children, late)
target.resolve()
near(late.selectionHighlight:GetAlpha(), 0)
-- A native repaint becomes the new baseline, without accumulating fade error.
member.selectionHighlight:SetAlpha(0.6)
target.resolve()
near(member.selectionHighlight:GetAlpha(), 0)
PartyFrame:SetAlpha(0.3)
local writes = member.selectionHighlight.writes
for _ = 1, 30 do target.resolve() end
assert(member.selectionHighlight.writes == writes, "unchanged quantized alpha should not be rewritten")
near(member.selectionHighlight:GetAlpha(), 0.18)
-- A native repaint equal to the applied value is still a new host baseline.
member.selectionHighlight:SetAlpha(member.selectionHighlight:GetAlpha())
local repainted = member.selectionHighlight:GetAlpha() / PartyFrame:GetAlpha()
PartyFrame:SetAlpha(0.5)
near(member.selectionHighlight:GetAlpha(), repainted * PartyFrame:GetAlpha())
member.selectionHighlight:SetAlpha(0.6)
-- Pool removal restores the released region, then reacquisition is clean.
local recycled = pet.selectionHighlight
pet.selectionHighlight = nil
target.resolve()
near(recycled:GetAlpha(), 1)
pet.selectionHighlight = recycled
target.resolve()
target.release(PartyFrame)
near(member.selectionHighlight:GetAlpha(), 0.6)
near(pet.selectionHighlight:GetAlpha(), 1)
near(late.selectionHighlight:GetAlpha(), 1)
PartyFrame:SetAlpha(0)
near(member.selectionHighlight:GetAlpha(), 0.6)
-- Compact-only fallback and first acquisition during combat use reconciliation.
PartyFrame = nil
combat = true
assert(target.resolve() == CompactPartyFrame)
target.acquire(CompactPartyFrame)
CompactPartyFrame:SetAlpha(0)
target.resolve()
near(member.selectionHighlight:GetAlpha(), 0)
combat = false
target.resolve()
CompactPartyFrame:SetAlpha(0.5)
near(member.selectionHighlight:GetAlpha(), 0.3)
target.release(CompactPartyFrame)
near(member.selectionHighlight:GetAlpha(), 0.6)
print("Party selection opacity tests passed")
