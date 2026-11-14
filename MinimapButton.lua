local _, ns = ...

-- Frame Gambit's own minimap button. It is an ordinary child of Minimap and
-- never ignores parent alpha, so MinimapStack's fade reaches it through the
-- Minimap itself (no second lease, no double multiplier), and its rectangle
-- joins the minimap's hover area through the descendant union.

local DEFAULT_ANGLE = 200
local button

local function Settings()
    FrameGambitDB = type(FrameGambitDB) == "table" and FrameGambitDB or {}
    local saved = FrameGambitDB.minimapButton
    if type(saved) ~= "table" then
        saved = { hide = false, angle = DEFAULT_ANGLE }
        FrameGambitDB.minimapButton = saved
    end
    if type(saved.angle) ~= "number" then saved.angle = DEFAULT_ANGLE end
    return saved
end

-- Offset from the minimap centre for an angle in degrees. Square minimaps
-- keep the button on the square's edge instead of a circle inside it.
function ns.MinimapButtonOffset(angle, radius, square)
    local rad = math.rad(angle)
    local x, y = math.cos(rad), math.sin(rad)
    if square then
        local edge = math.max(math.abs(x), math.abs(y))
        if edge > 0 then x, y = x / edge, y / edge end
    end
    return x * radius, y * radius
end

local function Place()
    if not button then return end
    local map = _G.Minimap
    local square = type(GetMinimapShape) == "function" and GetMinimapShape() == "SQUARE"
    local radius = (map:GetWidth() or 140) / 2 + (square and 4 or 6)
    local x, y = ns.MinimapButtonOffset(Settings().angle, radius, square)
    button:ClearAllPoints()
    button:SetPoint("CENTER", map, "CENTER", x, y)
end

-- Angle (degrees, 0-360) from the minimap centre to the cursor.
function ns.MinimapButtonAngle(cursorX, cursorY, centerX, centerY)
    local atan2 = math.atan2 or math.atan
    return math.deg(atan2(cursorY - centerY, cursorX - centerX)) % 360
end

local function OnDragUpdate()
    local map = _G.Minimap
    local centerX, centerY = map:GetCenter()
    local cursorX, cursorY = GetCursorPosition()
    local scale = map:GetEffectiveScale()
    if not centerX or not scale or scale == 0 then return end
    Settings().angle = ns.MinimapButtonAngle(cursorX / scale, cursorY / scale, centerX, centerY)
    Place()
end

local function Create()
    if button or not _G.Minimap then return button end
    button = CreateFrame("Button", "FrameGambitMinimapButton", _G.Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(_G.Minimap:GetFrameLevel() + 8)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20); background:SetPoint("CENTER")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18); icon:SetPoint("CENTER")
    icon:SetTexture(ns.ICON_TEXTURE)
    button.icon = icon
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53); border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button:SetScript("OnClick", function() ns:ToggleOptions() end)
    button:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        self:SetScript("OnUpdate", OnDragUpdate)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self:UnlockHighlight()
        Place()
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(ns.NAME or "Frame Gambit")
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ns.MinimapButton = button
    Place()
    return button
end

function ns:IsMinimapButtonShown()
    return Settings().hide ~= true
end

function ns:SetMinimapButtonShown(shown)
    Settings().hide = not shown
    if shown then
        Create()
        if button then button:Show(); Place() end
    elseif button then
        button:Hide()
    end
    if self.RefreshSettingsPage then self:RefreshSettingsPage() end
    if self.RefreshSettingsPicker then self:RefreshSettingsPicker() end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    if ns:IsMinimapButtonShown() then ns:SetMinimapButtonShown(true) end
end)
