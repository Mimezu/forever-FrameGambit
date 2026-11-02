local ADDON, ns = ...

-- Frame Gambit's letterbox is a presentation overlay only. It never parents,
-- hides, or otherwise mutates Blizzard or third-party frames.

local DEFAULT_HEIGHT = 0.04
local MIN_HEIGHT = 0
local MAX_HEIGHT = 0.25

local function NormalizeHeight(value)
    value = tonumber(value) or DEFAULT_HEIGHT
    value = math.max(MIN_HEIGHT, math.min(MAX_HEIGHT, value))
    return math.floor(value * 100 + 0.5) / 100
end

function ns:GetCinematicLetterboxSettings()
    local db = FrameGambitDB
    if type(db) ~= "table" then return false, DEFAULT_HEIGHT end
    db.cinematic = type(db.cinematic) == "table" and db.cinematic or {}
    local cinematic = db.cinematic
    cinematic.letterboxEnabled = cinematic.letterboxEnabled == true
    cinematic.letterboxHeight = NormalizeHeight(cinematic.letterboxHeight)
    return cinematic.letterboxEnabled, cinematic.letterboxHeight
end

function ns:CreateCinematicLetterbox()
    if self.CinematicLetterboxTop and self.CinematicLetterboxBottom then return end
    local function Bar(name, point)
        -- DialogueUI fades or hides UIParent during conversations. Own an
        -- independent root so Cinematic Mode's bars stay opaque and visible.
        -- Keep UIParent's geometry and scale without inheriting its visibility.
        local frame = CreateFrame("Frame", name)
        frame:SetPoint(point == "TOP" and "TOPLEFT" or "BOTTOMLEFT", UIParent,
            point == "TOP" and "TOPLEFT" or "BOTTOMLEFT", 0, 0)
        frame:SetPoint(point == "TOP" and "TOPRIGHT" or "BOTTOMRIGHT", UIParent,
            point == "TOP" and "TOPRIGHT" or "BOTTOMRIGHT", 0, 0)
        -- LOW is the first UI layer above the WorldFrame, so the bars still
        -- cover world-space names/nameplates.  Keeping them below MEDIUM also
        -- leaves conventional data bars visible without changing their owner.
        frame:SetFrameStrata("LOW")
        frame:SetFrameLevel(1)
        frame:EnableMouse(false)
        local black = frame:CreateTexture(nil, "BACKGROUND")
        black:SetAllPoints()
        black:SetColorTexture(0, 0, 0, 1)
        frame:Hide()
        return frame
    end
    self.CinematicLetterboxTop = Bar("FrameGambitCinematicLetterboxTop", "TOP")
    self.CinematicLetterboxBottom = Bar("FrameGambitCinematicLetterboxBottom", "BOTTOM")
end

function ns:IsCinematicLetterboxFrame(frame)
    return frame ~= nil and (frame == self.CinematicLetterboxTop or frame == self.CinematicLetterboxBottom)
end

function ns:RefreshCinematicLetterbox()
    self:CreateCinematicLetterbox()
    local enabled, height = self:GetCinematicLetterboxSettings()
    local active = self.IsCinematicActive and self:IsCinematicActive()
    local parentHeight = UIParent and UIParent:GetHeight() or 0
    if type(parentHeight) ~= "number" or parentHeight <= 0 then parentHeight = 1080 end
    local pixels = math.floor(parentHeight * height + 0.5)
    local scale = UIParent:GetEffectiveScale()
    self.CinematicLetterboxTop:SetScale(scale)
    self.CinematicLetterboxBottom:SetScale(scale)
    self.CinematicLetterboxTop:SetHeight(pixels)
    self.CinematicLetterboxBottom:SetHeight(pixels)
    if active and enabled and pixels > 0 then
        self.CinematicLetterboxTop:Show()
        self.CinematicLetterboxBottom:Show()
    else
        self.CinematicLetterboxTop:Hide()
        self.CinematicLetterboxBottom:Hide()
    end
end

function ns:SetCinematicLetterboxEnabled(enabled)
    local db = FrameGambitDB
    if type(db) ~= "table" then return false end
    db.cinematic = type(db.cinematic) == "table" and db.cinematic or {}
    db.cinematic.letterboxEnabled = enabled == true
    self:RefreshCinematicLetterbox()
    return true
end

function ns:SetCinematicLetterboxHeight(height)
    local db = FrameGambitDB
    if type(db) ~= "table" then return false end
    db.cinematic = type(db.cinematic) == "table" and db.cinematic or {}
    db.cinematic.letterboxHeight = NormalizeHeight(height)
    self:RefreshCinematicLetterbox()
    return true
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
watcher:RegisterEvent("UI_SCALE_CHANGED")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:SetScript("OnEvent", function()
    C_Timer.After(0, function()
        if ns.RefreshCinematicLetterbox then ns:RefreshCinematicLetterbox() end
    end)
end)
