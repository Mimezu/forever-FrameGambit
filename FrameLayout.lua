local ADDON, ns = ...

-- Experimental size and position rules.
--
-- Every rule keeps its opacity, and may also set a size, a position, or both.
-- Each of the three follows the first matching rule that sets it, then the
-- frame's Otherwise values. A rule set to "Keep" opacity only changes layout.
--
-- Frame Gambit takes over a frame's geometry only once a rule or Otherwise
-- sets a size or position. Frames are scaled around their centre and moved
-- relative to where their owner (Edit Mode, Ellesmere...) places them; the
-- owner's anchor and scale are captured, followed when the owner changes
-- them, and written back when no rule needs the frame any more.
--
-- Protected frames are never touched in combat. Combat-start changes are
-- applied from PLAYER_REGEN_DISABLED, before the lockdown begins.

local runtime = ns.runtime
local NO_ENTRIES = {}

ns.LAYOUT_SCALE_MIN, ns.LAYOUT_SCALE_MAX = 0.5, 2
ns.LAYOUT_OFFSET_LIMIT = 2000

-- Composite adapters fade several frames (or a proxy) as one target; there
-- is no single frame to resize or move.
local FADE_ONLY_TARGETS = {
    chat = true,
    gamepad_base = true, gamepad_lt = true, gamepad_rt = true, gamepad_both = true,
}

local POINT_FACTORS = {
    TOPLEFT = { -0.5, 0.5 }, TOP = { 0, 0.5 }, TOPRIGHT = { 0.5, 0.5 },
    LEFT = { -0.5, 0 }, CENTER = { 0, 0 }, RIGHT = { 0.5, 0 },
    BOTTOMLEFT = { -0.5, -0.5 }, BOTTOM = { 0, -0.5 }, BOTTOMRIGHT = { 0.5, -0.5 },
}

local state = {
    records = {},                                         -- id -> owned frame record
    idByFrame = setmetatable({}, { __mode = "k" }),
    hooked = setmetatable({}, { __mode = "k" }),
    guard = setmetatable({}, { __mode = "k" }),
    hostPoints = setmetatable({}, { __mode = "k" }),
    hostScale = setmetatable({}, { __mode = "k" }),
    status = {},                                          -- id -> reason when layout cannot apply
    animating = {},                                       -- id -> record with a transition in progress
    reapplyQueued = false,
}
runtime.layout = state

local function IsSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

local function Finite(value)
    return type(value) == "number" and not IsSecret(value) and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function Round(value, step)
    return math.floor(value / step + 0.5) * step
end

local function NormalizeScale(value)
    value = tonumber(value)
    if not Finite(value) then return nil end
    return Round(math.max(ns.LAYOUT_SCALE_MIN, math.min(ns.LAYOUT_SCALE_MAX, value)), 0.01)
end

local function NormalizeOffset(value)
    value = tonumber(value)
    if not Finite(value) then return nil end
    return Round(math.max(-ns.LAYOUT_OFFSET_LIMIT, math.min(ns.LAYOUT_OFFSET_LIMIT, value)), 1)
end
ns.NormalizeLayoutScale, ns.NormalizeLayoutOffset = NormalizeScale, NormalizeOffset

-- Rules that involve Mouseover may grow or shrink the frame, never move it.
function ns:LayoutReactionCanMove(reaction)
    if type(reaction) ~= "table" or reaction.condition == "mouseover" then return false end
    for _, requirement in ipairs(type(reaction.requirements) == "table" and reaction.requirements or NO_ENTRIES) do
        if requirement == "mouseover" then return false end
    end
    return true
end

function ns:NormalizeLayoutReaction(reaction)
    reaction.keepOpacity = reaction.keepOpacity == true or nil
    reaction.scale = NormalizeScale(reaction.scale)
    local x, y = NormalizeOffset(reaction.offsetX), NormalizeOffset(reaction.offsetY)
    if x == nil or y == nil or not self:LayoutReactionCanMove(reaction) then x, y = nil, nil end
    reaction.offsetX, reaction.offsetY = x, y
    -- The card's size and position line stays open while the rule uses it.
    reaction.layoutLine = (reaction.layoutLine == true or reaction.keepOpacity or reaction.scale or x) and true or nil
    reaction.layoutInstant = reaction.layoutInstant == true and reaction.layoutLine and true or nil
end

-- Otherwise values are stored only when they differ from the host layout.
function ns:NormalizeLayoutDefaults(settings)
    local scale = NormalizeScale(settings.restScale)
    settings.restScale = scale and math.abs(scale - 1) > 0.0001 and scale or nil
    local x, y = NormalizeOffset(settings.restOffsetX), NormalizeOffset(settings.restOffsetY)
    if not x or not y or (x == 0 and y == 0) then x, y = nil, nil end
    settings.restOffsetX, settings.restOffsetY = x, y
    settings.layoutPivot = self:NormalizeLayoutPivot(settings.layoutPivot)
    settings.restLayoutLine = (settings.restLayoutLine == true or settings.restScale or x) and true or nil
    settings.restLayoutInstant = settings.restLayoutInstant == true and settings.restLayoutLine and true or nil
end

-- The point of the frame that stays put while it is resized. Center is the
-- default and stored as nil.
function ns:NormalizeLayoutPivot(value)
    if type(value) ~= "string" then return nil end
    value = value:upper()
    return value ~= "CENTER" and POINT_FACTORS[value] and value or nil
end

function ns:ReactionChangesLayout(reaction)
    return type(reaction) == "table" and (reaction.scale ~= nil or reaction.offsetX ~= nil)
end

function ns:TargetUsesLayout(settings)
    if type(settings) ~= "table" then return false end
    if settings.restScale ~= nil or settings.restOffsetX ~= nil then return true end
    for _, reaction in ipairs(type(settings.reactions) == "table" and settings.reactions or NO_ENTRIES) do
        if reaction.scale ~= nil or reaction.offsetX ~= nil then return true end
    end
    return false
end

-- Size and position follow independent first-match chains through the same
-- rule list as opacity. A rule that leaves one of them unset is transparent
-- for it. Returns the relative scale, the offset in UIParent units, and the
-- winning rule indices (nil = Otherwise), and whether the change should be
-- instant: the rules now in charge decide (Otherwise when none is).
function ns:ResolveFrameLayout(id, settings, now)
    local scale = settings.restScale or 1
    local x, y = settings.restOffsetX or 0, settings.restOffsetY or 0
    local scaleIndex, positionIndex
    for index, reaction in ipairs(settings.reactions or NO_ENTRIES) do
        local wantsScale = scaleIndex == nil and reaction.scale ~= nil
        local wantsPosition = positionIndex == nil and reaction.offsetX ~= nil and self:LayoutReactionCanMove(reaction)
        if (wantsScale or wantsPosition) and self:ReactionIsMet(reaction, id, now) then
            if wantsScale then scale, scaleIndex = reaction.scale, index end
            if wantsPosition then x, y, positionIndex = reaction.offsetX, reaction.offsetY or 0, index end
            if scaleIndex and positionIndex then break end
        end
    end
    local reactions = settings.reactions or NO_ENTRIES
    local instant
    if scaleIndex or positionIndex then
        instant = (scaleIndex and reactions[scaleIndex].layoutInstant == true)
            or (positionIndex and reactions[positionIndex].layoutInstant == true) or false
    else
        instant = settings.restLayoutInstant == true
    end
    return scale, x, y, scaleIndex, positionIndex, instant
end

local function Method(frame, name)
    local ok, method = pcall(function() return frame[name] end)
    return ok and type(method) == "function" and method or nil
end

-- The widget's own engine method, skipping instance overrides. Edit Mode
-- systems replace SetPoint/SetScale with Lua wrappers that notify the Edit
-- Mode manager and re-run ManageFramePositions(); calling those from addon
-- code would run Blizzard's layout code under our taint. Our temporary
-- layout also must not be recorded by any owner as its own.
local function EngineMethod(frame, name)
    local meta = getmetatable(frame)
    local index = type(meta) == "table" and meta.__index
    if type(index) == "table" then
        local method = rawget(index, name)
        if type(method) == "function" then return method end
    end
    return Method(frame, name)
end

local function IsProtectedFrame(frame)
    if not frame then return false end
    local method = Method(frame, "IsProtected")
    if not method then return false end
    local ok, protected = pcall(method, frame)
    if not ok or IsSecret(protected) then return true end
    return protected == true
end

local function ReadAnchor(frame)
    local getNumPoints, getPoint = Method(frame, "GetNumPoints"), Method(frame, "GetPoint")
    if not getNumPoints or not getPoint then return nil, "This frame can only fade." end
    local ok, count = pcall(getNumPoints, frame)
    if not ok or not Finite(count) then return nil, "The game hides this frame's position from addons." end
    if count == 0 then return nil, "This frame has no position yet. Show it first." end
    if count ~= 1 then return nil, "This frame is held by several anchors, so it can only fade." end
    local pointOK, point, relTo, relPoint, x, y = pcall(getPoint, frame, 1)
    if not pointOK or IsSecret(point) or IsSecret(relTo) or IsSecret(relPoint)
        or type(point) ~= "string" or not POINT_FACTORS[point:upper()]
        or not Finite(x) or not Finite(y) then
        return nil, "The game hides this frame's position from addons."
    end
    if relPoint ~= nil and (type(relPoint) ~= "string" or not POINT_FACTORS[relPoint:upper()]) then
        return nil, "The game hides this frame's position from addons."
    end
    return { point = point, relTo = relTo, relPoint = relPoint or point, x = x, y = y }
end

local function ReadScale(frame)
    local getScale = Method(frame, "GetScale")
    if not getScale then return nil end
    local ok, scale = pcall(getScale, frame)
    if not ok or not Finite(scale) or scale <= 0 then return nil end
    return scale
end

-- Target-level support, without taking the frame over.
function ns:GetFrameLayoutSupport(id)
    local target = self.TargetByID[id]
    if not target then return false, "This frame is not available." end
    -- A target labelled "Opacity only" promises to leave layout to its owner.
    if FADE_ONLY_TARGETS[id] or target.layout == false or target.skipManagedAlphaHook
        or target.capability == "Opacity only" then
        return false, "Frame Gambit can only fade this frame."
    end
    local record = state.records[id]
    if record and not record.releasing then return true end
    local frame = self:ResolveTarget(id)
    if not frame then return false, "Open this part of the UI first." end
    for _, name in ipairs({ "SetPoint", "SetScale", "GetScale", "GetEffectiveScale", "GetSize" }) do
        if not Method(frame, name) then return false, "Frame Gambit can only fade this frame." end
    end
    local forbidden = Method(frame, "IsForbidden")
    if forbidden then
        local ok, value = pcall(forbidden, frame)
        if not ok or IsSecret(value) or value == true then return false, "Frame Gambit can only fade this frame." end
    end
    local anchor, reason = ReadAnchor(frame)
    if not anchor then return false, reason end
    if not ReadScale(frame) then return false, "The game hides this frame's size from addons." end
    return true
end

-- A write is blocked while the frame, or the frame it is anchored to, is
-- protected during combat.
local function CanWrite(record)
    if not InCombatLockdown() then return true end
    return not IsProtectedFrame(record.frame) and not IsProtectedFrame(record.base.relTo)
end

local function WriteGeometry(record, scale, dx, dy)
    local frame, base = record.frame, record.base
    local factors = POINT_FACTORS[base.point:upper()]
    local current, effective = ReadScale(frame), nil
    local getEffective = Method(frame, "GetEffectiveScale")
    if getEffective then
        local ok, value = pcall(getEffective, frame)
        if ok and Finite(value) and value > 0 then effective = value end
    end
    local uiOK, uiScale = pcall(function() return UIParent:GetEffectiveScale() end)
    if not factors or not current or not effective or not uiOK or not Finite(uiScale) or uiScale <= 0 then return false end
    local sizeOK, width, height = pcall(frame.GetSize, frame)
    if not sizeOK or not Finite(width) or not Finite(height) then width, height = 0, 0 end
    -- Anchor offsets are in the frame's own (scaled) units. Keep the frame's
    -- centre fixed while scaling, then add the offset in UIParent units.
    local ratio = base.scale * (effective / current) / uiScale
    -- Keep the pivot point (the centre unless the frame chooses a corner or
    -- an edge) where it is: shift the anchor by its distance from the pivot.
    local pivot = POINT_FACTORS[record.pivot or "CENTER"] or POINT_FACTORS.CENTER
    local x = base.x / scale + (factors[1] - pivot[1]) * width * (scale - 1) / scale + dx / (ratio * scale)
    local y = base.y / scale + (factors[2] - pivot[2]) * height * (scale - 1) / scale + dy / (ratio * scale)
    if not Finite(x) or not Finite(y) then return false end
    local setScale, setPoint = EngineMethod(frame, "SetScale"), EngineMethod(frame, "SetPoint")
    if not setScale or not setPoint then return false end
    state.guard[frame] = true
    local ok = pcall(function()
        local wanted = base.scale * scale
        if math.abs(current - wanted) > 0.00001 then setScale(frame, wanted) end
        setPoint(frame, base.point, base.relTo, base.relPoint, x, y)
    end)
    state.guard[frame] = nil
    if ok then
        record.applied = record.applied or {}
        record.applied.scale, record.applied.x, record.applied.y = scale, dx, dy
        record.applied.pivot = record.pivot or "CENTER"
        record.written = true
    end
    return ok
end

-- Used when the owner re-anchored the frame in a way we cannot follow: the
-- anchor is the owner's again, only our scale may still need undoing.
local function RestoreScale(record)
    local frame = record.frame
    local current = ReadScale(frame)
    if not record.written or not current or math.abs(current - record.base.scale) < 0.00001 then return end
    local setScale = EngineMethod(frame, "SetScale")
    if not setScale then return end
    state.guard[frame] = true
    pcall(setScale, frame, record.base.scale)
    state.guard[frame] = nil
end

local function QueueHostReapply()
    ns:Wake()
    if state.reapplyQueued or not C_Timer or not C_Timer.After then return end
    state.reapplyQueued = true
    C_Timer.After(0, function()
        state.reapplyQueued = false
        if next(state.hostPoints) or next(state.hostScale) then ns:UpdateFrameLayouts(GetTime()) end
    end)
end

local function HostPointsChanged(frame)
    if state.guard[frame] or not state.idByFrame[frame] then return end
    state.hostPoints[frame] = true
    QueueHostReapply()
end

local function HostScaleChanged(frame)
    if state.guard[frame] or not state.idByFrame[frame] then return end
    state.hostScale[frame] = true
    QueueHostReapply()
end

local function HookHost(frame)
    if state.hooked[frame] then return true end
    if InCombatLockdown() or type(hooksecurefunc) ~= "function" then return false end
    local ok = pcall(hooksecurefunc, frame, "SetPoint", HostPointsChanged)
        and pcall(hooksecurefunc, frame, "ClearAllPoints", HostPointsChanged)
        and pcall(hooksecurefunc, frame, "SetScale", HostScaleChanged)
    if ok and Method(frame, "SetAllPoints") then pcall(hooksecurefunc, frame, "SetAllPoints", HostPointsChanged) end
    state.hooked[frame] = ok or nil
    return ok
end

local function DropRecord(id, record)
    state.records[id] = nil
    if record and state.idByFrame[record.frame] == id then
        state.idByFrame[record.frame] = nil
        state.hostPoints[record.frame], state.hostScale[record.frame] = nil, nil
    end
end

local AdoptHostChanges

-- Write the owner's layout back. Returns false while combat blocks it.
function ns:ReleaseFrameLayout(id)
    local record = state.records[id]
    if not record then return true end
    record.releasing = true
    record.transition = nil
    if not record.written then DropRecord(id, record); return true end
    if not CanWrite(record) then record.waiting = true; return false end
    -- Take in any owner move first, so the write-back never undoes it.
    if AdoptHostChanges(record) then WriteGeometry(record, 1, 0, 0) else RestoreScale(record) end
    DropRecord(id, record)
    return true
end

-- The owner moved or rescaled the frame: adopt its new layout as the base.
AdoptHostChanges = function(record)
    local frame = record.frame
    if state.hostScale[frame] then
        state.hostScale[frame] = nil
        local scale = ReadScale(frame)
        if scale then record.base.scale = scale; record.applied, record.immediate = nil, true end
    end
    if state.hostPoints[frame] then
        state.hostPoints[frame] = nil
        local anchor = ReadAnchor(frame)
        if not anchor then return false end
        anchor.scale = record.base.scale
        record.base = anchor
        -- Reapply the current layout on the new base at once; animating
        -- from the host's layout would show the frame jumping.
        record.applied, record.immediate = nil, true
    end
    return true
end

local function IsLayoutPaused(id)
    local editMode = _G.EditModeManagerFrame
    if editMode then
        local ok, active = pcall(function() return editMode:IsEditModeActive() end)
        if ok and not IsSecret(active) and active == true then return "editMode" end
    end
    if ns.IsGamepadEditingTarget and ns:IsGamepadEditingTarget(id) then return "gamepadEdit" end
    return nil
end

local function SameLayout(a, scale, x, y)
    return a and math.abs(a.scale - scale) < 0.0005 and math.abs(a.x - x) < 0.05 and math.abs(a.y - y) < 0.05
end

local function IsShown(frame)
    local method = Method(frame, "IsShown")
    if not method then return false end
    local ok, shown = pcall(method, frame)
    return ok and not IsSecret(shown) and shown == true
end

-- Advances a record's transition to `now`. Runs from the 20 Hz evaluator and,
-- for smoothness, every game frame while a transition is in progress.
local function StepTransition(record, now)
    local transition = record.transition
    if not transition or not CanWrite(record) then return end
    local progress = math.min(1, math.max(0, (now - transition.startedAt) / transition.duration))
    local from, to = transition.from, transition.to
    local ok = WriteGeometry(record,
        from.scale + (to.scale - from.scale) * progress,
        from.x + (to.x - from.x) * progress,
        from.y + (to.y - from.y) * progress)
    if progress >= 1 and ok then
        record.transition, record.returnStarted = nil, nil
        record.fromRule = transition.toRule
        state.animating[record.id] = nil
    end
end

-- Called every game frame between evaluator ticks. It costs nothing unless a
-- size or position transition is running, and then touches only that frame.
function ns:StepFrameLayouts(now)
    local animating = state.animating
    local id, record = next(animating)
    while id do
        local nextID, nextRecord = next(animating, id)
        -- Owner moves and Edit Mode are handled by the full pass.
        if state.records[id] ~= record or not record.transition or record.releasing then
            animating[id] = nil
        elseif not state.hostPoints[record.frame] and not state.hostScale[record.frame] then
            StepTransition(record, now)
        end
        id, record = nextID, nextRecord
    end
end

function ns:ApplyFrameLayout(id, settings, now, combatStart)
    local frame, target = self:ResolveTargetThisTick(id)
    local record = state.records[id]
    if record and (record.frame ~= frame or record.releasing) then
        if not self:ReleaseFrameLayout(id) and record.frame ~= frame then return end
        record = state.records[id]
        if record then return end
    end
    if not frame then state.status[id] = "Open this part of the UI first."; return end
    if self.IsCinematicActive and self:IsCinematicActive() and self.IsCinematicSuiteWindow
        and self:IsCinematicSuiteWindow(frame) then return end
    if not record then
        if combatStart then return end
        local supported, reason = self:GetFrameLayoutSupport(id)
        if not supported then state.status[id] = reason; return end
        if not HookHost(frame) then state.status[id] = "Waiting for combat to end."; return end
        local anchor = ReadAnchor(frame)
        local scale = anchor and ReadScale(frame)
        if not anchor or not scale then state.status[id] = "The game hides this frame's position from addons."; return end
        anchor.scale = scale
        record = { id = id, frame = frame, base = anchor, immediate = true }
        state.records[id], state.idByFrame[frame] = record, id
        state.hostPoints[frame], state.hostScale[frame] = nil, nil
    end
    state.status[id] = nil
    if not AdoptHostChanges(record) then
        -- The owner re-anchored the frame in a way we cannot follow. Leave it
        -- to the owner; the next pass may take it over again.
        if not CanWrite(record) then return end
        RestoreScale(record)
        DropRecord(id, record)
        state.status[id] = "This frame is held by several anchors, so it can only fade."
        return
    end
    -- Only protected frames need the combat-start pass; others keep animating.
    if combatStart and not IsProtectedFrame(frame) and not IsProtectedFrame(record.base.relTo) then return end
    local pause = IsLayoutPaused(id)
    local scale, x, y, scaleIndex, positionIndex, instant
    if pause then
        scale, x, y = 1, 0, 0
    else
        scale, x, y, scaleIndex, positionIndex, instant = self:ResolveFrameLayout(id, settings, now)
    end
    record.paused = pause
    record.scale, record.x, record.y = scale, x, y
    local pivot = settings.layoutPivot or "CENTER"
    -- Choosing another pivot re-places the frame at once instead of easing.
    if record.applied and (record.applied.pivot or "CENTER") ~= pivot then record.immediate = true end
    record.pivot = pivot
    record.scaleIndex, record.positionIndex = scaleIndex, positionIndex
    local fromRule = scaleIndex ~= nil or positionIndex ~= nil
    if not CanWrite(record) then
        record.waiting = not SameLayout(record.applied, scale, x, y) or nil
        record.transition, record.returnStarted = nil, nil
        return
    end
    record.waiting = nil
    local applied = record.applied or { scale = 1, x = 0, y = 0 }
    if SameLayout(applied, scale, x, y) and record.applied and (applied.pivot or "CENTER") == pivot then
        record.transition, record.returnStarted, record.immediate = nil, nil, nil
        record.fromRule = fromRule
        return
    end
    -- Instant rules skip the fade times and the wait before returning.
    local immediate = record.immediate or combatStart or pause or instant or not IsShown(frame)
    record.immediate = nil
    if immediate then
        record.transition, record.returnStarted = nil, nil
        WriteGeometry(record, scale, x, y)
        record.fromRule = fromRule
        return
    end
    -- Returning to Otherwise waits like a fade-out, then uses the fade-out
    -- time; changes toward a rule use the fade-in time.
    if record.fromRule and not fromRule and (settings.fadeDelay or 0) > 0 then
        record.returnStarted = record.returnStarted or now
        if now < record.returnStarted + settings.fadeDelay then return end
    else
        record.returnStarted = nil
    end
    local transition = record.transition
    if not transition or not SameLayout(transition.to, scale, x, y) then
        transition = {
            from = { scale = applied.scale, x = applied.x, y = applied.y },
            to = { scale = scale, x = x, y = y },
            startedAt = now,
            duration = math.max(0.01, (fromRule and settings.fadeInDuration or settings.fadeOutDuration) or 0.2),
            toRule = fromRule,
        }
        record.transition = transition
    end
    state.animating[id] = record
    StepTransition(record, now)
end

local scratchSeen = {}
function ns:UpdateFrameLayouts(now, combatStart)
    if type(FrameGambitDB) ~= "table" then return end
    now = now or GetTime()
    local profile = self:Profile()
    for id in pairs(scratchSeen) do scratchSeen[id] = nil end
    for id, settings in pairs(type(profile.targets) == "table" and profile.targets or NO_ENTRIES) do
        if type(settings) == "table" and settings.enabled ~= false and self:TargetUsesLayout(settings) then
            scratchSeen[id] = true
            self:ApplyFrameLayout(id, settings, now, combatStart)
        end
    end
    for id in pairs(state.status) do
        if not scratchSeen[id] then state.status[id] = nil end
    end
    if combatStart then return end
    local release
    for id in pairs(state.records) do
        if not scratchSeen[id] then release = release or {}; release[#release + 1] = id end
    end
    for _, id in ipairs(release or NO_ENTRIES) do self:ReleaseFrameLayout(id) end
end

-- PLAYER_REGEN_DISABLED runs before the combat lockdown starts. Settle
-- protected frames for "In combat" now; they cannot change again until the
-- fight ends. InCombatLockdown() is checked first in case the client has
-- already locked down.
function ns:OnLayoutCombatStart()
    if InCombatLockdown() or not next(state.records) then return end
    runtime.layoutCombatStarting = true
    local ok = pcall(function()
        self:BuildStateContext()
        self:UpdateFrameLayouts(GetTime(), true)
    end)
    runtime.layoutCombatStarting = nil
    return ok
end

-- Written back before logout so a frame whose position the client saves
-- never stores a Frame Gambit layout.
function ns:ReleaseAllFrameLayouts()
    local ids = {}
    for id in pairs(state.records) do ids[#ids + 1] = id end
    for _, id in ipairs(ids) do self:ReleaseFrameLayout(id) end
end

function ns:HasFrameLayoutWork()
    return next(state.records) ~= nil
end

-- Hover is decided by the frame's current rectangle plus its Otherwise
-- rectangle (this function adds the second). At rest the two are the same, so
-- only the resting frame starts a Mouseover size rule; once it has grown, the
-- larger current rectangle keeps it grown; and a rule that shrinks the frame
-- cannot flicker, because the larger Otherwise area still counts as hovered.
function ns:FrameLayoutHoverContains(id, x, y)
    local record = state.records[id]
    local applied = record and record.applied
    if not applied or applied.scale <= 0 then return false end
    local settings = self:GetTargetSettings(id)
    if not settings then return false end
    local restScale, restX, restY = settings.restScale or 1, settings.restOffsetX or 0, settings.restOffsetY or 0
    if math.abs(applied.scale - restScale) < 0.0005 and math.abs(applied.x - restX) < 0.05
        and math.abs(applied.y - restY) < 0.05 then return false end
    if (type(x) ~= "number" or type(y) ~= "number") and self.GetUICursorPosition then x, y = self:GetUICursorPosition() end
    if type(x) ~= "number" or type(y) ~= "number" then return false end
    local left, bottom, width, height = self:GetUsableFrameRect(record.frame)
    if not left then return false end
    -- The pivot point stays where it is on screen (less the current offset).
    local pivot = POINT_FACTORS[applied.pivot or "CENTER"] or POINT_FACTORS.CENTER
    local normalWidth, normalHeight = width / applied.scale, height / applied.scale
    local pivotX = left + (0.5 + pivot[1]) * width - applied.x
    local pivotY = bottom + (0.5 + pivot[2]) * height - applied.y
    local restWidth, restHeight = normalWidth * restScale, normalHeight * restScale
    local restLeft = pivotX - (0.5 + pivot[1]) * restWidth + restX
    local restBottom = pivotY - (0.5 + pivot[2]) * restHeight + restY
    return x >= restLeft and x <= restLeft + restWidth
        and y >= restBottom and y <= restBottom + restHeight
end

-- Editor status for the selected frame.
function ns:GetFrameLayoutState(id)
    return state.records[id], state.status[id]
end
