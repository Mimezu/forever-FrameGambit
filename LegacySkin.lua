local _, ns = ...

-- Forever's Blizzard_LegacySystem/Blizzard_LegacyChallenges.xml uses
-- PortraitFrameTemplate + Legacy-Challenge-BG. Keep the client's own
-- NineSliceLayouts (including Forever's overrides), offsets and atlas sizes.
local Skin = { scrolls = setmetatable({}, { __mode = "k" }),
    arrows = setmetatable({}, { __mode = "k" }), icons = setmetatable({}, { __mode = "k" }),
    sliders = setmetatable({}, { __mode = "k" }) }
ns.LegacySkin = Skin

local function Enabled()
    return ns.GetAppearanceTheme and ns:GetAppearanceTheme() == "legacy"
end

local function Atlas(parent, name, layer, sublevel)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0)
    t:SetAtlas(name, true)
    return t
end

local function Border(parent, layout, level)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints(parent)
    f:SetFrameLevel(parent:GetFrameLevel() + (level or 1))
    f:EnableMouse(false)
    NineSliceUtil.ApplyLayoutByName(f, layout)
    if layout == "InsetFrameTemplate" then
        -- The stock inset has bright silver bevels. Keep its native geometry
        -- but bring it into the Legacy window's quieter bronze interior.
        for _, key in ipairs({ "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
            "TopEdge", "BottomEdge", "LeftEdge", "RightEdge" }) do
            if f[key] then f[key]:SetVertexColor(.72, .57, .36, .8) end
        end
    end
    return f
end

-- List-header art is a single atlas in Blizzard's template. Slice it here
-- to preserve its corners even on a 22px control or a tall inspector card.
-- Corners are fixed-size. Straight rails use the undecorated center texel,
-- never a repeat of the full edge (which contains non-tileable ornament).
-- This changes rail length without scaling its thickness or corner features.
local function SlicedAtlas(parent, atlas, cap, layer)
    local art = { pieces = {}, parent = parent, atlas = atlas }
    function art:Layout()
        local info = C_Texture.GetAtlasInfo(self.atlas)
        if not info then return end
        local width, height = parent:GetSize()
        if width <= 0 or height <= 0 then return end
        if self.width == width and self.height == height and self.lastAtlas == self.atlas then return end
        self.width, self.height, self.lastAtlas = width, height, self.atlas
        local cx = math.min(cap, width / 2, info.width / 2)
        local cy = math.min(cap, height / 2, info.height / 2)
        local used = 0
        local function Piece(x, y, w, h, sx, sy, sw, sh)
            if w <= 0 or h <= 0 then return end
            used = used + 1
            local t = self.pieces[used]
            if not t then
                t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, -2)
                self.pieces[used] = t
            end
            t:SetTexture(info.file or info.filename)
            local u, v = info.rightTexCoord - info.leftTexCoord, info.bottomTexCoord - info.topTexCoord
            t:SetTexCoord(info.leftTexCoord + u * sx / info.width,
                info.leftTexCoord + u * (sx + sw) / info.width,
                info.topTexCoord + v * sy / info.height,
                info.topTexCoord + v * (sy + sh) / info.height)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
            t:SetSize(w, h)
            t:SetVertexColor(1, 1, 1, 1)
            t:SetShown(self.visible ~= false)
        end
        Piece(0, 0, cx, cy, 0, 0, cx, cy)
        Piece(width - cx, 0, cx, cy, info.width - cx, 0, cx, cy)
        Piece(0, height - cy, cx, cy, 0, info.height - cy, cx, cy)
        Piece(width - cx, height - cy, cx, cy, info.width - cx, info.height - cy, cx, cy)
        local sx, sy = math.max(1, info.width - 2 * cx), math.max(1, info.height - 2 * cy)
        local midX, midY = math.floor(info.width / 2), math.floor(info.height / 2)
        Piece(cx, 0, width - 2 * cx, cy, midX, 0, 1, cy)
        Piece(cx, height - cy, width - 2 * cx, cy, midX, info.height - cy, 1, cy)
        Piece(0, cy, cx, height - 2 * cy, 0, midY, cx, 1)
        Piece(width - cx, cy, cx, height - 2 * cy, info.width - cx, midY, cx, 1)
        Piece(cx, cy, width - 2 * cx, height - 2 * cy, cx, cy, sx, sy)
        for index = used + 1, #self.pieces do self.pieces[index]:Hide() end
        self.used = used
    end
    function art:SetShown(show)
        self.visible = show
        for index, piece in ipairs(self.pieces) do piece:SetShown(show and index <= (self.used or 0)) end
        if show then self:Layout() end
    end
    parent:HookScript("OnSizeChanged", function() if art.visible then art:Layout() end end)
    art:Layout()
    return art
end

-- Legacy-Challenge-BG (920x575) paints a header divider somewhere around
-- rows 55-66. Its exact row is not something we can rely on, so the art is
-- cut around it: rows 0-48 become the header band, rows 74+ the body, and
-- the divider is redrawn by us exactly at the header's bottom edge.
local HEADER_BAND_ROWS, BODY_FIRST_ROW = 48, 74

local function HideBundled(state, show)
    for _, key in ipairs({ "bg", "hover", "art", "overlay", "topBar", "bottomBar", "atlasBorder", "x" }) do
        if state[key] then state[key]:SetShown(show) end
    end
    for _, t in ipairs(state.border or {}) do t:SetShown(show) end
end

local function Surface(frame, inset)
    local t = Atlas(frame, "Legacy-Challenge-BG", "BACKGROUND", -4)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", 3, -3)
    t:SetPoint("BOTTOMRIGHT", -3, 3)
    -- Use only the leather portion inside cards, never the window's header.
    local info = C_Texture.GetAtlasInfo("Legacy-Challenge-BG")
    if info then
        t:SetTexture(info.file or info.filename)
        local du, dv = info.rightTexCoord - info.leftTexCoord, info.bottomTexCoord - info.topTexCoord
        t:SetTexCoord(info.leftTexCoord + du * .05, info.rightTexCoord - du * .05,
            info.topTexCoord + dv * .20, info.bottomTexCoord - dv * .02)
    end
    t:SetVertexColor(inset and .8 or 1, inset and .8 or 1, inset and .8 or 1)
    return t
end

function Skin:Apply(kind, frame, state, opts, enabled)
    opts = opts or {}
    local native = state.legacy
    if not enabled then
        if native then
            for _, object in pairs(native.visuals) do object:SetShown(false) end
            HideBundled(state, true)
            if native.originalSize then frame:SetSize(unpack(native.originalSize)) end
        end
        return
    end
    if not native then
        native = { visuals = {} }
        state.legacy = native
        local visuals = native.visuals
        if kind == "shell" then
            local main = frame:GetName() == "FrameGambitOptions"
            visuals.background = Atlas(frame, "Legacy-Challenge-BG", "BACKGROUND", -4)
            visuals.background:ClearAllPoints()
            visuals.background:SetPoint("TOPLEFT", 0, -10)
            visuals.background:SetPoint("BOTTOMRIGHT", -2, 2)
            visuals.border = Border(frame, main and "PortraitFrameTemplate" or "ButtonFrameTemplateNoPortrait", 6)
            if main then
                -- The atlas paints a header divider ~64/575 of the way down.
                -- Stretched whole, that line lands at a fixed height and cut
                -- through the Cinematic strip. Split it: the header band is
                -- stretched to end under our header (LayoutHeader), and the
                -- leather body fills the rest, so the divider always sits
                -- between toolbar and workspace.
                local info = C_Texture.GetAtlasInfo("Legacy-Challenge-BG")
                if info then
                    local du, dv = info.rightTexCoord - info.leftTexCoord, info.bottomTexCoord - info.topTexCoord
                    local bandEnd = info.topTexCoord + dv * (HEADER_BAND_ROWS / info.height)
                    local bodyStart = info.topTexCoord + dv * (BODY_FIRST_ROW / info.height)
                    visuals.background:SetTexture(info.file or info.filename)
                    visuals.background:SetTexCoord(info.leftTexCoord, info.rightTexCoord, info.topTexCoord, bandEnd)
                    local body = frame:CreateTexture(nil, "BACKGROUND", nil, -4)
                    body:SetTexture(info.file or info.filename)
                    body:SetTexCoord(info.leftTexCoord, info.rightTexCoord, bodyStart, info.bottomTexCoord)
                    body:SetPoint("TOPLEFT", visuals.background, "BOTTOMLEFT")
                    body:SetPoint("BOTTOMRIGHT", -2, 2)
                    visuals.backgroundBody = body
                    frame._legacyHeaderBand = visuals.background
                    -- Our divider: a dark groove over a faint bronze catch-light,
                    -- the same bevel the atlas line uses.
                    local groove = frame:CreateTexture(nil, "BACKGROUND", nil, -3)
                    groove:SetColorTexture(0, 0, 0, .6); groove:SetHeight(1)
                    local catch = frame:CreateTexture(nil, "BACKGROUND", nil, -3)
                    catch:SetColorTexture(.62, .47, .26, .38); catch:SetHeight(1)
                    catch:SetPoint("TOPLEFT", groove, "BOTTOMLEFT"); catch:SetPoint("TOPRIGHT", groove, "BOTTOMRIGHT")
                    visuals.dividerGroove, visuals.dividerCatch = groove, catch
                    frame._legacyHeaderDivider = groove
                end
                local chrome = CreateFrame("Frame", nil, frame)
                chrome:SetAllPoints(frame)
                chrome:SetFrameLevel(frame:GetFrameLevel() + 7)
                chrome:EnableMouse(false)
                visuals.chrome = chrome
                frame._legacyChrome = chrome
                local portraitFrame = CreateFrame("Frame", nil, frame)
                portraitFrame:SetAllPoints(frame)
                portraitFrame:SetFrameLevel(frame:GetFrameLevel() + 5)
                portraitFrame:EnableMouse(false)
                visuals.portrait = portraitFrame
                local portrait = portraitFrame:CreateTexture(nil, "ARTWORK")
                portrait:SetTexture(ns.ICON_TEXTURE)
                portrait:SetSize(62, 62)
                portrait:SetPoint("TOPLEFT", -5, 7)
                local mask = portraitFrame:CreateMaskTexture()
                mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                mask:SetPoint("TOPLEFT", portrait, "TOPLEFT", 2, 0)
                mask:SetPoint("BOTTOMRIGHT", portrait, "BOTTOMRIGHT", -2, 4)
                portrait:AddMaskTexture(mask)
                local title = chrome:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                title:SetPoint("TOPLEFT", 58, -6)
                title:SetPoint("TOPRIGHT", -28, -6)
                title:SetText("Frame Gambit")
                native.title = title
            end
        elseif kind == "edit" then
            visuals.art = SlicedAtlas(frame, "common-searchbar-a", 6)
        elseif kind == "panel" then
            if opts.listArt then
                -- Same Blizzard list-button art as the cards.
                visuals.art = SlicedAtlas(frame, "common-button-list-collapseExpand", 5)
            else
                if not opts.noBg then visuals.background = Surface(frame, opts.inset) end
                if not opts.noBorder then visuals.border = Border(frame, "InsetFrameTemplate", 1) end
            end
            frame._legacyPanelVisuals = visuals
        elseif kind == "button" then
            visuals.art = SlicedAtlas(frame, "common-button-list-collapseExpand", 5)
            local highlight = frame:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetColorTexture(1, .82, .3, .12)
            highlight:SetPoint("TOPLEFT", 4, -4)
            highlight:SetPoint("BOTTOMRIGHT", -4, 4)
            visuals.highlight = highlight
            local selected = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
            selected:SetColorTexture(1, .65, .12, .18)
            selected:SetPoint("TOPLEFT", 4, -4)
            selected:SetPoint("BOTTOMRIGHT", -4, 4)
            visuals.selected = selected
            local function Refresh()
                if Enabled() then Skin:Apply(kind, frame, state, opts, true) end
            end
            frame:HookScript("OnMouseDown", function() native.pressed = true; Refresh() end)
            frame:HookScript("OnMouseUp", function() native.pressed = false; Refresh() end)
            frame:HookScript("OnHide", function() native.pressed = false end)
            frame:HookScript("OnEnable", Refresh)
            frame:HookScript("OnDisable", Refresh)
        elseif kind == "close" then
            native.originalSize = { frame:GetSize() }
            -- A decoration-only Blizzard button supplies all four native
            -- textures. Input stays on the existing Frame Gambit control.
            local close = CreateFrame("Button", nil, frame, "UIPanelCloseButtonNoScripts")
            close:SetSize(24, 24)
            close:SetPoint("CENTER")
            close:SetFrameLevel(frame:GetFrameLevel() + 1)
            close:EnableMouse(false)
            visuals.close = close
            frame:HookScript("OnEnter", function() if Enabled() then close:LockHighlight() end end)
            frame:HookScript("OnLeave", function() close:UnlockHighlight(); close:SetButtonState("NORMAL") end)
            frame:HookScript("OnMouseDown", function() if Enabled() then close:SetButtonState("PUSHED") end end)
            frame:HookScript("OnMouseUp", function() close:SetButtonState("NORMAL") end)
        end
    end
    HideBundled(state, false)
    for _, object in pairs(native.visuals) do object:SetShown(true) end
    if kind == "panel" and frame._legacyHeader then
        for _, object in pairs(native.visuals) do object:SetShown(false) end
    end
    if kind == "button" then
        local disabled = frame.IsEnabled and not frame:IsEnabled()
        native.visuals.selected:SetShown(not disabled and (native.pressed or frame._selected or frame._primary) or false)
        native.visuals.highlight:SetShown(not disabled)
        for _, piece in ipairs(native.visuals.art.pieces) do
            local shade = disabled and .45 or native.pressed and .7 or 1
            piece:SetVertexColor(shade, shade, shade)
        end
        local label = frame.Text or (frame.GetFontString and frame:GetFontString())
        if label then
            if disabled then label:SetTextColor(.5, .5, .5)
            elseif frame._cinematicAccent then label:SetTextColor(.90, .52, .24)
            elseif frame._selected or frame._primary then label:SetTextColor(1, .96, .82)
            else label:SetTextColor(1, .82, 0) end
        end
    end
end

-- Reaction cards use the same Blizzard list-button art as the frame list and
-- the right-hand cards. Its lit top edge makes each card stand out from the
-- leather behind it.
function Skin:Row(frame, selected)
    local native = frame._legacyRow
    if not Enabled() then
        if native then
            native.art:SetShown(false)
            native.selected:SetShown(false)
        end
        return
    end
    if not native then
        native = { art = SlicedAtlas(frame, "common-button-list-collapseExpand", 5) }
        native.selected = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
        native.selected:SetPoint("TOPLEFT", 4, -4)
        native.selected:SetPoint("BOTTOMRIGHT", -4, 4)
        native.selected:SetColorTexture(1, .65, .12, .15)
        frame._legacyRow = native
    end
    frame:SetBackdropColor(0, 0, 0, 0)
    frame:SetBackdropBorderColor(0, 0, 0, 0)
    native.art:SetShown(true)
    native.selected:SetShown(selected)
end

-- Use the exact MinimalScrollBar employed by LegacyChallengeCategoryList.
-- Keep Frame Gambit's existing ScrollFrame and wheel/scroll-child behavior.
function Skin:UpdateScroll(scroll, custom)
    local bar = self.scrolls[scroll]
    if not Enabled() then if bar then bar:Hide() end; return false end
    if not bar then
        bar = CreateFrame("EventFrame", nil, scroll:GetParent(), "MinimalScrollBar")
        bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 5, 0)
        bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 5, 0)
        bar:SetFrameLevel(custom:GetFrameLevel())
        bar:RegisterCallback("OnScroll", function(_, percentage)
            if not bar.syncing then scroll:SetVerticalScroll(percentage * math.max(0, scroll:GetVerticalScrollRange())) end
        end, self)
        self.scrolls[scroll] = bar
    end
    custom:Hide()
    local range, height = math.max(0, scroll:GetVerticalScrollRange()), math.max(1, scroll:GetHeight())
    bar.syncing = true
    bar:SetVisibleExtentPercentage(height / (height + range))
    bar:SetPanExtentPercentage(range > 0 and math.min(1, 45 / range) or 1)
    bar:SetScrollPercentage(range > 0 and scroll:GetVerticalScroll() / range or 0)
    bar.syncing = false
    bar:SetShown(range > 0 and scroll:IsShown())
    return true
end

function Skin:Layout(panel, enabled)
    if not panel or not panel.legacyTitle then return end
    local native = enabled
    if panel.closeButton then
        -- Forever loads Blizzard_SharedXML's Camelot override, whose
        -- UIPanelCloseButtonDefaultAnchorsMixin anchors TOPRIGHT (-2, 1).
        -- Mainline's (1, 0) pushes the X past the Camelot frame border.
        panel.closeButton:ClearAllPoints()
        panel.closeButton:SetSize(native and 24 or 26, native and 24 or 26)
        panel.closeButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", native and -2 or -4, native and 1 or -4)
    end
    if enabled then
        for _, frame in ipairs({ panel.header, panel.cinematicControls }) do
            for _, visual in pairs(frame._legacyPanelVisuals or {}) do visual:SetShown(not native) end
        end
    end
    panel.legacyTitle:SetShown(not native)
    panel.legacyIcon:SetShown(not native)
    self:LayoutHeader(panel, native)
end

-- The editor header is one toolbar row, shared by every skin:
--   [context: Profile v][Cinematic]  subtitle ...   [Preview] | [Appearance][? Help]
-- Context (what you are editing) leads on the left; view and utility actions
-- sit on the right, split by a hairline. Legacy borrows the window's own
-- title bar for identity and version, so its header shrinks to the row
-- itself and the context group tucks in beside the portrait. Other skins keep
-- their icon + title block, and the toolbar centres on that block instead.
local TOOLBAR_GAP, GROUP_GAP = 6, 16
function Skin:LayoutHeader(panel, native)
    local header = panel.header
    local cinematic = ns.IsCinematicActive and ns:IsCinematicActive()
    -- 64px strip + 8px bottom inset (+6px breathing room under the taller identity block).
    local controlsHeight = cinematic and (native and 72 or 78) or 0
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", 12, native and -32 or -12)
    header:SetPoint("TOPRIGHT", -12, native and -32 or -12)
    local rowHeight = native and 40 or 74
    header:SetHeight(rowHeight + controlsHeight)
    -- Vertical centre of the toolbar row, measured from the header top.
    local rowY = native and -8 or -25
    local profile, cinematicButton, peek = panel.profile, panel.cinematic, panel.peek
    local help, appearance = panel.helpButton, panel.appearance
    if not (profile and cinematicButton and peek and help and appearance) then return end
    for _, control in ipairs({ profile, cinematicButton, peek, help, appearance }) do control:ClearAllPoints() end

    help:SetPoint("TOPRIGHT", header, "TOPRIGHT", native and -4 or -12, rowY)
    appearance:SetPoint("RIGHT", help, "LEFT", -TOOLBAR_GAP, 0)
    local divider = panel.headerDivider
    if divider then
        divider:ClearAllPoints()
        divider:SetPoint("RIGHT", appearance, "LEFT", -GROUP_GAP / 2, 0)
        divider:SetSize(1, 18); divider:Show()
        peek:SetPoint("RIGHT", divider, "LEFT", -GROUP_GAP / 2, 0)
    else
        peek:SetPoint("RIGHT", appearance, "LEFT", -GROUP_GAP, 0)
    end

    local subtitle, version = panel.subtitle, panel.version
    subtitle:ClearAllPoints(); subtitle:SetJustifyH("LEFT")
    if version then version:ClearAllPoints() end
    if native then
        -- Clear the 62px portrait, which hangs ~23px into this row.
        profile:SetPoint("TOPLEFT", header, "TOPLEFT", 52, rowY)
        cinematicButton:SetPoint("LEFT", profile, "RIGHT", TOOLBAR_GAP, 0)
        subtitle:SetPoint("LEFT", cinematicButton, "RIGHT", GROUP_GAP, 0)
        subtitle:SetPoint("RIGHT", peek, "LEFT", -GROUP_GAP, 0)
        -- Version reads as window metadata in the title bar, left of the X.
        local band = panel._legacyHeaderBand
        if band then
            band:ClearAllPoints()
            band:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -10)
            band:SetPoint("RIGHT", panel, "RIGHT", -2, 0)
            band:SetPoint("BOTTOM", header, "BOTTOM", 0, -6)
        end
        local groove = panel._legacyHeaderDivider
        if groove then
            -- Centred in the 12px gap between header and workspace, inset
            -- to the window's inner border.
            groove:ClearAllPoints()
            groove:SetPoint("LEFT", panel, "LEFT", 4, 0)
            groove:SetPoint("RIGHT", panel, "RIGHT", -6, 0)
            groove:SetPoint("TOP", header, "BOTTOM", 0, -5)
        end
        if version then
            if version.SetParent and panel._legacyChrome then version:SetParent(panel._legacyChrome); version:SetDrawLayer("OVERLAY") end
            version:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -34, -6)
        end
    else
        -- The context group joins the right-hand toolbar; identity owns the left.
        cinematicButton:SetPoint("RIGHT", peek, "LEFT", -GROUP_GAP, 0)
        profile:SetPoint("RIGHT", cinematicButton, "LEFT", -TOOLBAR_GAP, 0)
        subtitle:SetPoint("TOPLEFT", panel.legacyTitle, "BOTTOMLEFT", 0, -4)
        subtitle:SetPoint("RIGHT", profile, "LEFT", -GROUP_GAP, 0)
        if version then
            if version.SetParent then version:SetParent(header) end
            version:SetPoint("BOTTOMLEFT", panel.legacyTitle, "BOTTOMRIGHT", 8, 1)
        end
    end
    subtitle:SetShown(panel:GetWidth() >= 1080)
end

function Skin:Arrow(control, direction, enabled)
    self.arrows[control] = direction
    if not control._legacyArrow and enabled then
        control._legacyArrow = Atlas(control, "minimal-scrollbar-arrow-top", "OVERLAY")
        control._legacyArrow:SetPoint("CENTER")
    end
    for _, line in ipairs(control.arrowLines or {}) do line:SetShown(not enabled) end
    if control._legacyArrow then
        control._legacyArrow:SetShown(enabled)
        control._legacyArrow:SetRotation(({ up=0, down=math.pi, left=math.pi/2, right=-math.pi/2 })[direction] or 0)
    end
end

function Skin:Icon(texture, enabled)
    self.icons[texture] = true
    texture:SetDesaturated(enabled)
    if enabled then texture:SetVertexColor(.95, .78, .46) else texture:SetVertexColor(1, 1, 1) end
end

function Skin:RefreshDetails(enabled)
    for control, direction in pairs(self.arrows) do self:Arrow(control, direction, enabled) end
    for texture in pairs(self.icons) do self:Icon(texture, enabled) end
    for slider in pairs(self.sliders) do self:Slider(slider, enabled) end
end

function Skin:Slider(slider, enabled)
    if enabled == nil then enabled = Enabled() end
    local state = self.sliders[slider]
    if state == nil then self.sliders[slider] = false end
    if not state and not enabled then return end
    if not state then
        state = { original = slider:GetThumbTexture() }
        state.left = Atlas(slider, "Minimal_SliderBar_Left", "BACKGROUND")
        state.left:SetPoint("LEFT")
        state.right = Atlas(slider, "Minimal_SliderBar_Right", "BACKGROUND")
        state.right:SetPoint("RIGHT")
        state.middle = Atlas(slider, "_Minimal_SliderBar_Middle", "BACKGROUND")
        state.middle:SetPoint("TOPLEFT", state.left, "TOPRIGHT")
        state.middle:SetPoint("TOPRIGHT", state.right, "TOPLEFT")
        state.middle:SetHorizTile(true)
        state.thumb = Atlas(slider, "Minimal_SliderBar_Button", "OVERLAY")
        self.sliders[slider] = state
    end
    for _, key in ipairs({ "left", "middle", "right", "thumb" }) do state[key]:SetShown(enabled) end
    if enabled then
        slider:SetBackdropColor(0, 0, 0, 0)
        slider:SetBackdropBorderColor(0, 0, 0, 0)
        slider:SetThumbTexture(state.thumb)
        state.original:Hide()
    else
        slider:SetThumbTexture(state.original)
        state.original:Show()
    end
end
