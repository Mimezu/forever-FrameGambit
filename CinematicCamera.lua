local ADDON, ns = ...

-- These are the same zoom curves Narcissus uses for its working photo-mode
-- composition. Retail also ignores the shoulder CVar while its two character
-- centering locks are enabled, so those CVars are leased only while the live
-- Frame Gambit offset is on.
local CURVE_DEFAULT = { 0.361, -0.1654 }
local CURVE_VISAGE_MALE = { 0.361, -0.1654 }
local CURVE_VISAGE_FEMALE = { 0.38, 0.0311 }
local CURVE_DRACTHYR = { 0.1704, 0.0749 }
local CURVE_MOUNTED = { 1.2495, -4 }
local MODEL_CURVE = {
    [4207724] = CURVE_DRACTHYR,
    [4220448] = CURVE_VISAGE_FEMALE,
    [4395382] = CURVE_VISAGE_MALE,
}
local SHOULDER_MAX, ZOOM_EPSILON, VALUE_EPSILON = 5.5, 0.01, 0.0001
local CVAR_NAME = {
    fov = "cameraFov",
    shoulder = "test_cameraOverShoulder",
    centered = "CameraKeepCharacterCentered",
    reduced = "CameraReduceUnexpectedMovement",
}
local state = { active = false, offsetEnabled = false, refreshGeneration = 0 }
local modelProbe

local function IsSecret(value)
    if type(issecretvalue) ~= "function" then return false end
    local ok, secret = pcall(issecretvalue, value)
    return ok and secret == true
end

local function Number(value)
    if IsSecret(value) then return nil end
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return nil end
    return value
end

local function GetCVarNumber(name)
    if not C_CVar or type(C_CVar.GetCVar) ~= "function" then return nil end
    local ok, value = pcall(C_CVar.GetCVar, name)
    return ok and Number(value) or nil
end

local function SetCVarNumber(name, value)
    value = Number(value)
    if not value or not C_CVar or type(C_CVar.SetCVar) ~= "function" then return false end
    return pcall(C_CVar.SetCVar, name, value)
end

local function NearlyEqual(left, right)
    return left ~= nil and right ~= nil and math.abs(left - right) <= VALUE_EPSILON
end

local function LeaseCVar(name, value)
    if state.dialogueActive then return false, false end
    local lease = state[name]
    if not lease then
        local original = GetCVarNumber(CVAR_NAME[name])
        if original == nil then return false, false end
        lease = { original = original }
        state[name] = lease
    end
    local live = GetCVarNumber(CVAR_NAME[name])
    if NearlyEqual(lease.applied, value) and NearlyEqual(live, value) then return true, false end
    if not SetCVarNumber(CVAR_NAME[name], value) then return false, false end
    lease.applied = value
    return true, true
end

local function RestoreCVar(name)
    if state.dialogueActive then return false end
    local lease = state[name]
    if not lease then return true end
    local live = GetCVarNumber(CVAR_NAME[name])
    if live == nil then return false end
    if not NearlyEqual(live, lease.applied) then state[name] = nil; return true end
    if not SetCVarNumber(CVAR_NAME[name], lease.original) then return false end
    state[name] = nil
    return true
end

local function CameraZoom()
    if type(GetCameraZoom) ~= "function" then return nil end
    local ok, zoom = pcall(GetCameraZoom)
    return ok and Number(zoom) or nil
end

local function PlayerRaceID()
    if type(UnitRace) ~= "function" then return nil end
    local ok, _, raceFile, raceID = pcall(UnitRace, "player")
    if not ok or IsSecret(raceFile) or IsSecret(raceID) then return nil end
    raceID = Number(raceID)
    if raceFile == "Dracthyr" or raceID == 52 or raceID == 70 then return raceID or 52 end
    return raceID
end

local function IsDracthyr()
    local raceID = PlayerRaceID()
    return raceID == 52 or raceID == 70
end

local function IsPlayerMounted()
    if type(IsMounted) ~= "function" then return false end
    local ok, mounted = pcall(IsMounted)
    return ok and not IsSecret(mounted) and mounted == true
end

local function DracthyrVisageState()
    if not IsDracthyr() or not C_UnitAuras or type(C_UnitAuras.WantsAlteredForm) ~= "function" then return nil end
    local ok, wantsAltered = pcall(C_UnitAuras.WantsAlteredForm, "player")
    if not ok or IsSecret(wantsAltered) or type(wantsAltered) ~= "boolean" then return nil end
    -- Matches Narcissus' Retail adapter: false is Visage, true is Dracthyr.
    return wantsAltered == false
end

local function EnsureModelProbe()
    if modelProbe ~= nil then return modelProbe or nil end
    if type(CreateFrame) ~= "function" then modelProbe = false; return nil end
    local ok, probe = pcall(CreateFrame, "PlayerModel")
    if not ok or not probe or type(probe.SetUnit) ~= "function"
        or type(probe.GetModelFileID) ~= "function" then modelProbe = false; return nil end
    if type(probe.Hide) == "function" then probe:Hide() end
    modelProbe = probe
    return probe
end

local function ModelCurve()
    local probe = EnsureModelProbe()
    if not probe then return nil end
    if type(probe.ClearModel) == "function" then pcall(probe.ClearModel, probe) end
    if not pcall(probe.SetUnit, probe, "player") then return nil end
    local ok, modelID = pcall(probe.GetModelFileID, probe)
    modelID = ok and Number(modelID) or nil
    return modelID and MODEL_CURVE[modelID] or nil
end

local function CurrentCurve()
    if IsPlayerMounted() then return CURVE_MOUNTED end
    if IsDracthyr() then
        local visage = DracthyrVisageState()
        if visage == true then
            if type(UnitSex) == "function" then
                local ok, sex = pcall(UnitSex, "player")
                if ok and not IsSecret(sex) and sex == 3 then return CURVE_VISAGE_FEMALE end
            end
            return CURVE_VISAGE_MALE
        elseif visage == false then
            return CURVE_DRACTHYR
        end
        return ModelCurve() or CURVE_VISAGE_MALE
    end
    return CURVE_DEFAULT
end

local function ShoulderForZoom(zoom)
    zoom = Number(zoom)
    if not zoom then return nil end
    local curve = CurrentCurve()
    return math.max(0, math.min(SHOULDER_MAX, zoom * curve[1] + curve[2]))
end

local function RequestCameraRefresh()
    if type(CameraZoomIn) ~= "function" then return end
    state.refreshGeneration = state.refreshGeneration + 1
    local generation = state.refreshGeneration
    local function Refresh()
        if generation ~= state.refreshGeneration or not state.active or not state.offsetEnabled or state.dialogueActive then return end
        pcall(CameraZoomIn, 0)
    end
    if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(0, Refresh) else Refresh() end
end

local function EnableOffset(refreshCamera)
    local zoom = CameraZoom()
    local shoulder = ShoulderForZoom(zoom)
    if not shoulder then return false end
    local okCentered, centeredChanged = LeaseCVar("centered", 0)
    local okReduced, reducedChanged = LeaseCVar("reduced", 0)
    local okShoulder, shoulderChanged = LeaseCVar("shoulder", shoulder)
    if not (okCentered and okReduced and okShoulder) then return false end
    state.lastZoom = zoom
    if refreshCamera and (centeredChanged or reducedChanged or shoulderChanged) then RequestCameraRefresh() end
    return true
end

local function DisableOffset()
    state.refreshGeneration = state.refreshGeneration + 1
    LeaseCVar("shoulder", 0)
    RestoreCVar("centered")
    RestoreCVar("reduced")
    state.lastZoom = nil
    return true
end

local function StopZoomWatcher()
    if state.zoomTicker and type(state.zoomTicker.Cancel) == "function" then state.zoomTicker:Cancel() end
    state.zoomTicker = nil
end

local function StartZoomWatcher()
    StopZoomWatcher()
    if state.dialogueActive or not state.offsetEnabled or not C_Timer or type(C_Timer.NewTicker) ~= "function" then return end
    state.zoomTicker = C_Timer.NewTicker(0.10, function()
        if not state.active or not state.offsetEnabled or state.dialogueActive then return end
        local zoom = CameraZoom()
        if zoom and (not state.lastZoom or math.abs(zoom - state.lastZoom) > ZOOM_EPSILON) then
            -- The player's own zoom command already refreshed the camera.
            EnableOffset(false)
        end
    end)
end

local function ApplyLiveOffset(enabled, refreshCamera)
    if not state.active then return false end
    state.offsetEnabled = enabled == true
    if state.offsetEnabled then
        local ok = EnableOffset(refreshCamera)
        StartZoomWatcher()
        return ok
    end
    StopZoomWatcher()
    return DisableOffset()
end

function ns:GetCinematicCameraSettings()
    local cinematic = FrameGambitDB and FrameGambitDB.cinematic or {}
    return math.max(40, math.min(100, tonumber(cinematic.cameraFOV) or 90)), cinematic.cameraOffsetDefault == true
end

function ns:SetCinematicFOV(value)
    if not FrameGambitDB then return false end
    FrameGambitDB.cinematic = type(FrameGambitDB.cinematic) == "table" and FrameGambitDB.cinematic or {}
    value = math.max(40, math.min(100, math.floor((tonumber(value) or 90) + 0.5)))
    FrameGambitDB.cinematic.cameraFOV = value
    if state.active then LeaseCVar("fov", value) end
    return true
end

function ns:SetCinematicCameraOffsetDefault(enabled)
    if not FrameGambitDB then return false end
    FrameGambitDB.cinematic = type(FrameGambitDB.cinematic) == "table" and FrameGambitDB.cinematic or {}
    enabled = enabled == true
    FrameGambitDB.cinematic.cameraOffsetDefault = enabled
    if state.active then ApplyLiveOffset(enabled, true) end
    return true
end

function ns:IsCinematicCameraOffsetEnabled()
    return state.active and state.offsetEnabled == true
end

local function AcceptExperimentalCamera()
    -- Cinematic intentionally uses experimental camera CVars. Suppress this
    -- warning before applying them, and repeat after each UI reload because
    -- Blizzard registers its confirmation event again during startup.
    -- A warning that is already showing is left for the player to close:
    -- hiding a Blizzard popup from addon code runs Forever's gamepad popup
    -- handler under Frame Gambit's taint.
    local event = "EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED"
    if UIParent and type(UIParent.UnregisterEvent) == "function" then
        pcall(UIParent.UnregisterEvent, UIParent, event)
    end
    if GameEvent and type(GameEvent.UnregisterInternalEvent) == "function" then
        pcall(GameEvent.UnregisterInternalEvent, event)
    end
end

function ns:AcquireCinematicCamera()
    if not self:IsCinematicActive() then return false end
    AcceptExperimentalCamera()
    local fov, entryOffset = self:GetCinematicCameraSettings()
    local entering = not state.active
    if entering then state.active, state.offsetEnabled, state.lastZoom = true, entryOffset, nil end
    LeaseCVar("fov", fov)
    if state.offsetEnabled then EnableOffset(entering); StartZoomWatcher() else DisableOffset() end
    return true
end

function ns:ReleaseCinematicCamera()
    if not state.active and not state.fov and not state.shoulder
        and not state.centered and not state.reduced then return false end
    state.active, state.offsetEnabled = false, false
    state.refreshGeneration = state.refreshGeneration + 1
    StopZoomWatcher()
    RestoreCVar("fov")
    RestoreCVar("shoulder")
    RestoreCVar("centered")
    RestoreCVar("reduced")
    state.lastZoom = nil
    return true
end

function ns:RefreshCinematicCamera()
    if self:IsCinematicActive() then return self:AcquireCinematicCamera() end
    self:ReleaseCinematicCamera()
    return true
end

function ns:RefreshCinematicCameraOffset()
    if not state.active or not state.offsetEnabled then return false end
    state.refreshGeneration = state.refreshGeneration + 1
    local generation = state.refreshGeneration
    local function Refresh()
        if generation ~= state.refreshGeneration or not state.active or not state.offsetEnabled or state.dialogueActive then return end
        EnableOffset(true)
    end
    if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(0, Refresh) else Refresh() end
    return true
end

function ns:ToggleCinematicCameraOffset()
    if not self:IsCinematicActive() then return false, "Turn on Cinematic Mode first." end
    if not state.active then self:AcquireCinematicCamera() end
    local enabled = not state.offsetEnabled
    ApplyLiveOffset(enabled, true)
    return true, enabled
end

-- DialogueUI owns the conversation camera until it has restored its snapshot.
-- Retain our leases so exiting Cinematic Mode during a conversation can still
-- restore the original camera afterward, without overwriting dialogue motion.
FrameGambitAPI = FrameGambitAPI or {}
function FrameGambitAPI.SetDialogueCameraActive(active)
    active = active == true
    if state.dialogueActive == active then return end
    state.dialogueActive = active
    state.refreshGeneration = state.refreshGeneration + 1
    if active then
        StopZoomWatcher()
    else
        ns:RefreshCinematicCamera()
    end
end

local events = CreateFrame("Frame")
local modelEventRegistered = false
if type(events.RegisterUnitEvent) == "function" then
    modelEventRegistered = pcall(events.RegisterUnitEvent, events, "UNIT_MODEL_CHANGED", "player")
end
if not modelEventRegistered and type(events.RegisterEvent) == "function" then
    pcall(events.RegisterEvent, events, "UNIT_MODEL_CHANGED")
end
if type(events.RegisterEvent) == "function" then pcall(events.RegisterEvent, events, "PLAYER_MOUNT_DISPLAY_CHANGED") end
events:SetScript("OnEvent", function(_, _, unit)
    if unit == nil or (not IsSecret(unit) and unit == "player") then ns:RefreshCinematicCameraOffset() end
end)
