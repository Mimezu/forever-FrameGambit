local _, ns = ...
local curves = setmetatable({}, { __mode = "k" })
local selector, selectorError
local LINKED_PARENT_HOVER_REACTION = { condition = "linked_parent_hover", opacity = 1, requirements = {}, linkedParent = true }
ns.runtime.percentageCurveErrors = {}

local function SelectOpacity(low, high, fallback)
    if selectorError then error(selectorError, 0) end
    if not selector then
        local bar = CreateFrame("StatusBar")
        bar:Hide()
        -- Verify the native clamp contract using PUBLIC values before feeding
        -- it opaque ones. No health or protected output is inspected here.
        for _, probe in ipairs({ {0.25, 0.25, 0.8, 0.25}, {0.75, 0.75, 0.2, 0.75},
            {0, 0, 1, 0}, {1, 1, 0, 1}, {0, 1, 0.5, 0.5} }) do
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(probe[3])
            bar:SetMinMaxValues(probe[1], probe[2])
            local result = bar:GetValue()
            if (issecretvalue and issecretvalue(result)) or type(result) ~= "number" or result ~= probe[4] then
                selectorError = "Client does not support native opacity selection"
                error(selectorError, 0)
            end
        end
        selector = bar
    end
    -- Matching curves supply [opacity, opacity]; nonmatches supply [0, 1].
    -- Native range clamping selects the rule or preserves the fallback.
    -- The resulting value stays opaque all the way to the target's SetAlpha.
    selector:SetMinMaxValues(0, 1)
    selector:SetValue(fallback)
    selector:SetMinMaxValues(low, high)
    return selector:GetValue()
end

-- Curves transform protected percentages entirely inside the client. Never
-- read, compare, format or perform arithmetic on their resulting alpha.
local function Protected(value)
    if type(value) ~= "table" then return false end
    if value.protectedPercentage then return true end
    for _, member in ipairs(value) do
        if type(member) == "table" and member.protectedPercentage then return true end
    end
    return false
end

local function CurveAlpha(sample, rule, fallback, scale)
    local getter = sample.mana and UnitPowerPercent or UnitHealthPercent
    if type(getter) ~= "function" or not C_CurveUtil or not C_CurveUtil.CreateColorCurve then return fallback end
    local byUnit = curves[rule]
    if not byUnit then byUnit = {}; curves[rule] = byUnit end
    local curve = byUnit[sample.unit]
    if not curve then curve = C_CurveUtil.CreateColorCurve(); byUnit[sample.unit] = curve end
    curve:ClearPoints()
    curve:SetType(Enum.LuaCurveType.Step)
    local threshold = (rule.percentageThreshold or 50) / 100
    -- Native curve points may use single precision. A double's next value
    -- can collapse onto the same point; keep boundaries distinct at the
    -- client's display precision (0.00001 percentage points).
    local after = threshold + 1e-7
    local compose = issecretvalue and issecretvalue(fallback)
    local opacity = (rule.opacity or 1) * scale
    local yes, no
    if compose then
        yes, no = CreateColor(opacity, opacity, 0, 1), CreateColor(0, 1, 0, 1)
    else
        yes, no = CreateColor(1, 1, 1, opacity), CreateColor(1, 1, 1, fallback)
    end
    local operator = rule.percentageOperator or "<"
    local initial, points = no, {}
    if operator == "<" then initial = yes; points = {{threshold, no}}
    elseif operator == "<=" then initial = yes; points = {{after, no}}
    elseif operator == ">" then points = {{after, yes}}
    elseif operator == ">=" then points = {{threshold, yes}}
    elseif operator == "=" then points = {{threshold, yes}, {after, no}}
    elseif operator == "~=" then initial = yes; points = {{threshold, no}, {after, yes}} end
    -- Start below zero so an exact zero threshold never duplicates a point.
    curve:AddPoint(-1, initial)
    for _, point in ipairs(points) do curve:AddPoint(point[1], point[2]) end
    local color
    if sample.mana then color = getter(sample.unit, 0, false, curve)
    else color = getter(sample.unit, false, curve) end
    if compose then
        local low, high = color:GetRGBA()
        return 1, 1, 1, SelectOpacity(low, high, fallback)
    end
    return color:GetRGBA() -- Caller explicitly selects the alpha component.
end

function ns:GetManagedScaledPercentageOpacity(frame, scale)
    local id = self.runtime.managedIDByFrame[frame]
    local settings = id and self:GetTargetSettings(id)
    if not settings then error("No managed percentage source for this frame", 0) end
    -- Scale only public rule outputs, then let UnitHealthPercent perform the
    -- protected transformation. Never feed GetAlpha() into Curve:Evaluate().
    return self:Evaluate(id, settings, nil, GetTime(), scale)
end

local function ApplyCurve(sample, rule, fallback, scale)
    local ok, result, _, _, alpha = pcall(CurveAlpha, sample, rule, fallback, scale)
    -- Failure is not a positive match. Keep the lower-priority result.
    if not ok then
        local reason = not (issecretvalue and issecretvalue(result)) and type(result) == "string" and result or "Protected curve error"
        return fallback, reason
    end
    if not (issecretvalue and issecretvalue(alpha)) and type(alpha) ~= "number" then return fallback, "Curve returned no alpha" end
    return alpha
end

function ns:EvaluateProtectedPercentages(id, settings, seen, now, outputScale)
    outputScale = outputScale or 1
    self.runtime.percentageCurveErrors[id] = nil
    local needed = false
    for _, rule in ipairs(settings.reactions or {}) do
        if rule.enabled ~= false and rule.keepOpacity ~= true and self:IsPercentageCondition(rule.condition)
            and Protected(self:GetPercentageContextValue(rule.condition, rule)) then needed = true; break end
    end
    if not needed then return false end
    if not self:HasUnconditionalMouseover(settings) and self:IsLinkedParentHovered(id) then
        return true, outputScale, 0, LINKED_PARENT_HOVER_REACTION
    end
    seen = seen or {}
    local alpha = (settings.atRest or 0.12) * outputScale
    local activeIndex, activeRule, inheritedFrom
    if not seen[id] then
        seen[id] = true
        local parentID = self:GetVisibilityParent(id)
        local parent = parentID and self:GetTargetSettings(parentID)
        if parent and parent.enabled ~= false and not seen[parentID] then
            alpha, activeIndex, activeRule, inheritedFrom = self:Evaluate(parentID, parent, seen, now, outputScale)
            inheritedFrom = inheritedFrom or parentID
        end
    end
    -- Fold from the bottom. Each protected rule selects its opacity or the
    -- remaining rules through the curve; public matches still take priority.
    for index = #(settings.reactions or {}), 1, -1 do
        local rule = settings.reactions[index]
        -- Keep opacity rows change only size or position.
        if rule.enabled ~= false and rule.keepOpacity ~= true then
            local value = self:GetPercentageContextValue(rule.condition, rule)
            if self:IsPercentageCondition(rule.condition) and Protected(value) then
                local allowed = true
                for _, condition in ipairs(rule.requirements or {}) do
                    if not self:ConditionIsMet(condition, id, rule, true, now) then allowed = false; break end
                end
                if allowed then
                    if self:PercentageConditionIsMet(rule.condition, rule) then
                        alpha = (rule.opacity or 1) * outputScale
                        activeIndex, activeRule, inheritedFrom = index, rule, nil
                    elseif value.protectedPercentage then
                        local failed
                        alpha, failed = ApplyCurve(value, rule, alpha, outputScale)
                        if failed then self.runtime.percentageCurveErrors[id] = failed
                        else activeIndex, activeRule, inheritedFrom = nil, nil, nil end
                    else
                        for _, sample in ipairs(value) do
                            if type(sample) == "table" and sample.protectedPercentage then
                                local failed
                                alpha, failed = ApplyCurve(sample, rule, alpha, outputScale)
                                if failed then self.runtime.percentageCurveErrors[id] = failed
                                else activeIndex, activeRule, inheritedFrom = nil, nil, nil end
                            end
                        end
                    end
                end
            elseif self:ReactionIsMet(rule, id, now) then
                alpha = (rule.opacity or 1) * outputScale
                activeIndex, activeRule, inheritedFrom = index, rule, nil
            end
        end
    end
    return true, alpha, activeIndex, activeRule, inheritedFrom
end

-- On-demand diagnostics only; never print protected health or opacity values.
function ns:PrintHealthDiagnostics()
    self:BuildStateContext()
    local settings = self:GetTargetSettings("party_frames")
    if not settings then print("Frame Gambit: no Party Frames settings"); return end
    self:Evaluate("party_frames", settings, nil, GetTime())
    print("Frame Gambit health curve:", self.runtime.percentageCurveErrors.party_frames or "no curve error")
    for index, rule in ipairs(settings.reactions or {}) do
        if self:IsPercentageCondition(rule.condition) then
            local value = self:GetPercentageContextValue(rule.condition, rule)
            local status = value == nil and "unavailable" or (Protected(value) and "protected" or "public")
            print(index, rule.condition, "member", rule.partyMember or "Any", "enabled", rule.enabled ~= false, "sample", status)
        end
    end
end
