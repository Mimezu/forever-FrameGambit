local _, ns = ...
local states, hooked = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
local attached = setmetatable({}, { __mode = "k" })
local function Secret(value) return issecretvalue and issecretvalue(value) end
local function Alpha(frame)
    local ok, value = pcall(frame.GetAlpha, frame)
    if ok and not Secret(value) and type(value) == "number" then return value end
end
local function Write(state, value)
    state.writing = true
    local ok = pcall(state.prompt.SetAlpha, state.prompt, value)
    state.writing = nil
    if ok then state.last = Alpha(state.prompt); state.opaque = Secret(value) end
    return ok
end
local function Sync(root)
    local state = states[root]
    if not state or not state.active then return end
    -- An explicitly managed prompt gets its own rules.
    if ns.runtime.managedIDByFrame[state.prompt] then return end
    local live = Alpha(state.prompt)
    if live and state.last and math.abs(live - state.last) > 0.001 then state.base = live end
    local ok, alpha = pcall(root.GetAlpha, root)
    if not ok then return end
    local desired
    if Secret(alpha) then
        if state.base == 1 then desired = alpha
        elseif state.base == 0 then desired = 0
        else
            ok, desired = pcall(ns.GetManagedScaledPercentageOpacity, ns, root, state.base)
            if not ok then return end
        end
    elseif type(alpha) == "number" then desired = state.base * alpha
    else return end
    if Secret(desired) or live == nil or math.abs(live - desired) > 0.001 then Write(state, desired) end
end
local function Release(root)
    local state = states[root]
    if not state then return end
    state.active = false
    if not ns.runtime.managedIDByFrame[state.prompt] then
        local live = Alpha(state.prompt)
        if state.opaque or (live and state.last and math.abs(live - state.last) <= 0.001) then
            if not Write(state, state.base) then error("Class prompt restoration pending", 0) end
        end
    end
    states[root] = nil
end
local function Prepare(root, prompt)
    local state = states[root]
    if state and state.prompt ~= prompt then Release(root); state = nil end
    if not state and prompt then
        local base = Alpha(prompt)
        if base == nil then return false end
        state = { prompt = prompt, base = base, last = base, active = true }
        states[root] = state
    end
    if not state then return true end -- prompt may be created later
    if not InCombatLockdown() and type(hooksecurefunc) == "function" then
        if not hooked[root] then
            hooked[root] = pcall(hooksecurefunc, root, "SetAlpha", function() Sync(root) end)
        end
        if not hooked[prompt] then
            hooked[prompt] = pcall(hooksecurefunc, prompt, "SetAlpha", function(_, value)
                if Secret(value) or type(value) ~= "number" then return end
                for owner, current in pairs(states) do
                    if current.prompt == prompt and current.active and not current.writing then
                        current.base, current.last = value, value
                        Sync(owner)
                    end
                end
            end)
        end
    end
    Sync(root)
    return true
end
local function Prompt(root)
    local page = GamepadMainActionBarFrame and GamepadMainActionBarFrame.PageUnit
    if not page then return end
    if root == page.LeftClassAction then return page.LeftInputPrompt, true end
    if root == page.RightClassAction then return page.RightInputPrompt, true end
end
function ns:PrepareGamepadClassTarget(root, target)
    local prompt, supported = Prompt(root)
    if not supported then return end
    if not attached[target] then
        -- Picked targets keep their IDs and settings; add only a companion
        -- opacity lease. No reparenting, input hooks, or layout changes.
        local acquire, release = target.acquire, target.release
        target.acquire = function(frame)
            if acquire and acquire(frame) == false then return false end
            return Prepare(frame, Prompt(frame))
        end
        target.release = function(frame)
            Release(frame)
            if release then return release(frame) end
        end
        attached[target] = true
    end
    if states[root] and states[root].active then Prepare(root, prompt) end
end
