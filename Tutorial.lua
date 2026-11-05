local ADDON, ns = ...

-- A self-contained coach layer. It teaches the real editor through one
-- session-only Frame Gambit frame, never touching a player's existing UI.
local C = ns.COLORS
local WHITE = "Interface\\Buttons\\WHITE8X8"
local TITLE = "GameFontNormalLarge"
local BODY = "GameFontHighlightSmall"
local BUTTON_HOVER = { 0.095, 0.108, 0.129, 1 }

local function Backdrop(frame, fill, border)
    local actualFill, actualBorder = fill or C.card, border or C.border
    if ns.TrackAppearanceObject then
        if actualFill == C.window then ns:TrackAppearanceObject(frame, "windowBackground") end
        if actualFill == C.panel then ns:TrackAppearanceObject(frame, "panelBackground") end
        if actualFill == C.card then ns:TrackAppearanceObject(frame, "cardBackground") end
        if actualFill == C.cardAlt then ns:TrackAppearanceObject(frame, "insetBackground") end
        if actualFill == C.raised then ns:TrackAppearanceObject(frame, "raisedBackground") end
        if actualFill == C.blueSoft then ns:TrackAppearanceObject(frame, "blueSoftBackground") end
        if actualBorder == C.border then ns:TrackAppearanceObject(frame, "border") end
        if actualBorder == C.teal then ns:TrackAppearanceObject(frame, "tealBorder") end
        if actualBorder == C.accent then ns:TrackAppearanceObject(frame, "accentBorder") end
    end
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    frame:SetBackdropColor(unpack(actualFill))
    frame:SetBackdropBorderColor(unpack(actualBorder))
end

local function Text(parent, font, value, color)
    local text = parent:CreateFontString(nil, "ARTWORK", font or BODY)
    text:SetText(value or "")
    local actualColor = color or C.muted
    text:SetTextColor(unpack(actualColor))
    if ns.TrackAppearanceObject then
        if actualColor == C.accent then ns:TrackAppearanceObject(text, "text") end
        if actualColor == C.teal then ns:TrackAppearanceObject(text, "tealText") end
        if actualColor == C.text then ns:TrackAppearanceObject(text, "primaryText") end
        if actualColor == C.muted then ns:TrackAppearanceObject(text, "mutedText") end
    end
    if ns.TrackEUIObject then ns:TrackEUIObject("font", text) end
    return text
end

local function Button(parent, label, width, callback, primary)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetHeight(24); button:SetWidth(width or 94)
    button._primary = primary
    Backdrop(button, primary and C.blueSoft or C.raised, C.border)
    local text = Text(button, "GameFontNormalSmall", label, C.text)
    text:SetPoint("CENTER")
    button:SetFontString(text)
    if ns.TrackEUIObject then ns:TrackEUIObject("button", button) end
    button:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(C.blue))
        self:SetBackdropColor(unpack(BUTTON_HOVER))
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(C.border))
        self:SetBackdropColor(unpack(self._primary and C.blueSoft or C.raised))
    end)
    button:SetScript("OnClick", callback)
    return button
end

local function CloseButton(parent, callback)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(26, 26); button:SetFrameLevel(parent:GetFrameLevel() + 12)
    Backdrop(button, C.cardAlt, C.border)
    local strokes = {}
    for _, angle in ipairs({ math.pi / 4, -math.pi / 4 }) do
        local stroke = button:CreateTexture(nil, "ARTWORK")
        stroke:SetTexture(WHITE); stroke:SetSize(2, 13); stroke:SetPoint("CENTER")
        stroke:SetRotation(angle); stroke:SetVertexColor(unpack(C.text))
        table.insert(strokes, stroke)
    end
    button:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(C.teal)); for _, s in ipairs(strokes) do s:SetVertexColor(unpack(C.teal)) end
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(C.border)); for _, s in ipairs(strokes) do s:SetVertexColor(unpack(C.text)) end
    end)
    button:SetScript("OnClick", callback)
    if ns.TrackEUIObject then ns:TrackEUIObject("close", button) end
    return button
end

local function GetState()
    if ns.GetTutorialState then
        local step, completed = ns:GetTutorialState()
        return tonumber(step) or 1, completed == true
    end
    return 1, false
end

local function SaveState(step, completed)
    if ns.SetTutorialState then ns:SetTutorialState(step, completed == true) end
end

local function Notice(message, color)
    local panel = ns.Options
    if panel and panel.active then
        panel.active:SetText(message)
        panel.active:SetTextColor(unpack(color or C.amber))
    end
end

local function IsCombat()
    return InCombatLockdown and InCombatLockdown() or false
end

local function CreateOutline()
    if ns.TutorialOutline then return ns.TutorialOutline end
    local outline = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    outline:SetFrameStrata("FULLSCREEN_DIALOG"); outline:SetFrameLevel(880); outline:EnableMouse(false)
    Backdrop(outline, { 0, 0, 0, 0 }, C.teal); outline:Hide()
    local group = outline:CreateAnimationGroup()
    group:SetLooping("REPEAT")
    local fade = group:CreateAnimation("Alpha"); fade:SetOrder(1); fade:SetFromAlpha(0.55); fade:SetToAlpha(1); fade:SetDuration(0.65); fade:SetSmoothing("IN_OUT")
    local fadeBack = group:CreateAnimation("Alpha"); fadeBack:SetOrder(2); fadeBack:SetFromAlpha(1); fadeBack:SetToAlpha(0.55); fadeBack:SetDuration(0.65); fadeBack:SetSmoothing("IN_OUT")
    outline.pulse = group
    ns.TutorialOutline = outline
    return outline
end

local function ClearOutline()
    local outline = ns.TutorialOutline
    if outline then outline.pulse:Stop(); outline:Hide() end
end

local function CreateSpotlight()
    if ns.TutorialSpotlight then return ns.TutorialSpotlight end
    local spotlight = { frames = {} }
    for index = 1, 4 do
        local dim = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        dim:SetFrameStrata("FULLSCREEN_DIALOG"); dim:SetFrameLevel(840); dim:EnableMouse(false)
        Backdrop(dim, { 0, 0, 0, 0.68 }, { 0, 0, 0, 0 }); dim:Hide()
        spotlight.frames[index] = dim
    end
    ns.TutorialSpotlight = spotlight
    return spotlight
end

local function ClearSpotlight()
    local spotlight = ns.TutorialSpotlight
    if not spotlight then return end
    for _, dim in ipairs(spotlight.frames or {}) do dim:Hide() end
end

local function SafeShown(frame)
    if not frame or not frame.IsShown then return false end
    local ok, shown = pcall(frame.IsShown, frame)
    return ok and not (issecretvalue and issecretvalue(shown)) and shown == true
end

local function Highlight(frame)
    local outline = CreateOutline()
    if not SafeShown(frame) then ClearOutline(); return end
    local left, bottom, width, height
    if ns.GetUsableFrameRect then
        left, bottom, width, height = ns:GetUsableFrameRect(frame)
    end
    if not left or not bottom or not width or not height or width < 2 or height < 2 then ClearOutline(); return end
    outline:ClearAllPoints(); outline:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left - 3, bottom - 3)
    outline:SetSize(width + 6, height + 6); outline:Show(); outline.pulse:Play()
end

local function Spotlight(frame)
    if not SafeShown(frame) or not ns.GetUsableFrameRect then ClearSpotlight(); return end
    local left, bottom, width, height = ns:GetUsableFrameRect(frame)
    if not left or not bottom or not width or not height or width < 2 or height < 2 then ClearSpotlight(); return end
    local uiWidth, uiHeight = UIParent:GetSize()
    local right, top = left + width, bottom + height
    local dims = CreateSpotlight().frames
    dims[1]:ClearAllPoints(); dims[1]:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, top); dims[1]:SetSize(uiWidth, math.max(0, uiHeight - top))
    dims[2]:ClearAllPoints(); dims[2]:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0); dims[2]:SetSize(uiWidth, math.max(0, bottom))
    dims[3]:ClearAllPoints(); dims[3]:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, bottom); dims[3]:SetSize(math.max(0, left), math.max(0, height))
    dims[4]:ClearAllPoints(); dims[4]:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", right, bottom); dims[4]:SetSize(math.max(0, uiWidth - right), math.max(0, height))
    for _, dim in ipairs(dims) do dim:Show() end
end

local function EnsureOptions()
    if ns.CreateOptions then ns:CreateOptions() end
    if ns.Options and not ns.Options:IsShown() then ns.Options:Show() end
    return ns.Options
end

local function FindControl(kind)
    local panel = ns.Options
    if not panel then return nil end
    if kind == "tutorial_target" then return panel.tutorialTargetRow or panel.targets end
    if kind == "tutorial_use" then
        -- Once the player has clicked Use this frame, that button is gone.
        -- Continue with a small real-row focus instead of outlining the whole
        -- workspace while they read the confirmation.
        return panel.tutorialUseButton or (panel.reactionContent and panel.reactionContent._reactionRows or {})[1]
    end
    if kind == "tutorial_stationary" then
        for _, row in ipairs(panel.reactionContent and panel.reactionContent._reactionRows or {}) do
            if row._tutorialReaction and row._tutorialReaction.condition == "stationary" then return row end
        end
        return (panel.reactionContent and panel.reactionContent._reactionRows or {})[1]
    end
    if kind == "add" then
        local rows = panel.reactionContent and panel.reactionContent._reactionRows or {}
        -- While the card palette is open, show the learner exactly where
        -- Mouseover lives. Once it is added, guide the second half of this
        -- step by spotlighting that row's opacity control.
        local palette = ns.ReactionPalette
        if palette and palette:IsShown() then
            for _, button in ipairs(palette.conditionButtons or {}) do
                if button.conditionKey == "mouseover" and SafeShown(button) then return button end
            end
        end
        for _, row in ipairs(rows) do
            if row._tutorialReaction and row._tutorialReaction.condition == "mouseover" then return row.opacity end
        end
        return panel.addReactionButton
    end
    if kind == "tutorial_move" then
        for _, row in ipairs(panel.reactionContent and panel.reactionContent._reactionRows or {}) do
            if row._tutorialReaction and row._tutorialReaction.condition == "mouseover" then return row.up end
        end
        return nil
    end
    if kind == "otherwise" then return panel.otherwiseRow end
    if kind == "outline" then return panel.outlineButton or (panel.selectionOutlineEnabled and ns.SelectionOutline) end
    if kind == "cinematic" then return panel.cinematic end
    if kind == "tutorial_frame" then return ns.TutorialPracticeFrame end
    return nil
end

local STEPS = {
    { title = "Welcome to Frame Gambit", body = "This temporary frame lets you practice in the real editor. The lesson does not change or save rules for your existing UI.", focus = "tutorial_frame" },
    { title = "1. Select Tutorial Frame", body = "Click Tutorial Frame at the top of the frame list.", focus = "tutorial_target" },
    { title = "2. Manage the frame", body = "Click Use this frame. Frame Gambit will control only its opacity.", focus = "tutorial_use" },
    { title = "3. See the resting rule", body = "Standing still matches Stationary at 30%. Move briefly to fall through to Otherwise at 100%.", focus = "tutorial_stationary" },
    { title = "4. Add Mouseover at 100%", body = "Click + Add reaction, choose Mouseover, then set it to 100%. It is added below Stationary.", focus = "add" },
    { title = "5. Put Mouseover first", body = "Hover the Tutorial Frame. Stationary still wins because it is first. Move Mouseover above it, then hover again.", focus = "tutorial_move" },
    { title = "6. Set Otherwise", body = "Set Otherwise below 100%. It applies only when no reaction matches.", focus = "otherwise" },
    { title = "7. Check the frame", body = "Frame outline marks the selected UI. Turn it on, then use Preview to inspect other frames while the frame list stays available.", focus = "outline" },
    { title = "You are ready", body = "You selected a frame, added and reordered reactions, and set Otherwise. Finish to remove the temporary frame and its lesson rules.", focus = "cinematic", finish = true },
}

local function CanAdvance(tutorial)
    local id = tutorial.targetID
    local settings = id and ns.GetTargetSettings and ns:GetTargetSettings(id)
    if tutorial.step == 2 then return ns.Options and ns.Options.selected == id, "Select Tutorial Frame in the frame list first." end
    if tutorial.step == 3 then return settings ~= nil and settings.enabled ~= false, "Click Use this frame first." end
    if tutorial.step == 5 then
        for _, reaction in ipairs(settings and settings.reactions or {}) do
            if reaction.condition == "mouseover" and math.abs((reaction.opacity or 0) - 1) < 0.001 then return true end
        end
        return false, "Add Mouseover and set its opacity to 100%."
    end
    if tutorial.step == 6 then
        local first = settings and settings.reactions and settings.reactions[1]
        return first and first.condition == "mouseover" and tutorial.hoveredBeforePriority == true and tutorial.hoveredAfterPriority == true,
            "Hover while Stationary is first, then move Mouseover above it and hover again."
    end
    if tutorial.step == 7 then return settings and math.abs((settings.atRest or 1) - 1) > 0.001, "Choose a different Otherwise opacity." end
    return true
end

local function EnsureTutorialFrame()
    local frame = ns.TutorialPracticeFrame
    if frame then frame:Show(); return frame end
    frame = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    frame:SetSize(196, 62); frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 18, -18)
    frame:SetFrameStrata("FULLSCREEN_DIALOG"); frame:SetFrameLevel(860); frame:SetToplevel(true); frame:EnableMouse(true)
    Backdrop(frame, { 0.045, 0.06, 0.09, 0.98 }, C.teal)
    if ns.TrackEUIObject then ns:TrackEUIObject("panel", frame, { inset = true }) end
    local portrait = frame:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(42, 42); portrait:SetPoint("LEFT", 9, 0)
    if SetPortraitTexture then SetPortraitTexture(portrait, "player") else portrait:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark") end
    local title = Text(frame, "GameFontNormal", "TUTORIAL FRAME", C.teal); title:SetPoint("TOPLEFT", portrait, "TOPRIGHT", 9, -9)
    local detail = Text(frame, BODY, "Temporary practice frame", C.muted); detail:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    frame:SetScript("OnEnter", function()
        local tutorial = ns.Tutorial
        local settings = tutorial and tutorial.targetID and ns.GetTargetSettings and ns:GetTargetSettings(tutorial.targetID)
        local first = settings and settings.reactions and settings.reactions[1]
        if tutorial and tutorial.step == 6 and first then
            if first.condition == "stationary" then
                tutorial.hoveredBeforePriority = true
            elseif first.condition == "mouseover" then
                tutorial.hoveredAfterPriority = true
            end
            ns:RefreshTutorial()
        end
    end)
    ns.TutorialPracticeFrame = frame
    return frame
end

local function SeedTutorialStationaryRule(tutorial)
    local settings = tutorial and tutorial.targetID and ns.GetTargetSettings and ns:GetTargetSettings(tutorial.targetID)
    if not settings or tutorial.stationarySeeded then return settings ~= nil end
    settings.reactions = { { id = ns:NextReactionID(), condition = "stationary", opacity = 0.30 } }
    -- The contrast is intentional: standing still matches Stationary at 30%,
    -- while taking a step falls through to Otherwise at a very visible 100%.
    settings.atRest, settings.fadeInDuration, settings.fadeOutDuration, settings.fadeDelay = 1, 0.12, 0.12, 0
    settings.cinematicMode = nil
    tutorial.stationarySeeded = true
    ns:InvalidateTargetTransition(tutorial.targetID)
    ns:RenderOptions()
    return true
end

local function StartTutorialTarget(tutorial, resume)
    local panel = ns.Options
    tutorial.previousSelected = panel and panel.selected or nil
    tutorial.previousQuery = panel and panel.targetQuery or ""
    local frame = EnsureTutorialFrame()
    tutorial.frame = frame
    local id, reason = ns:RegisterDiscoveredFrame(frame, "Tutorial Frame", true)
    if not id then return false, reason end
    tutorial.targetID = id
    if panel then
        panel.targetQuery = ""
        if panel.targetFilter then panel.targetFilter:SetText("") end
        -- Step 3 onward needs the real editor to be looking at the temporary
        -- target. Step 2 deliberately leaves selection to the player.
        if resume and tutorial.step >= 3 then panel.selected = id end
    end
    if resume and tutorial.step >= 4 then
        ns:AddTarget(id)
        SeedTutorialStationaryRule(tutorial)
        tutorial.hoveredBeforePriority = tutorial.step > 6
        tutorial.hoveredAfterPriority = tutorial.step > 6
        if tutorial.step >= 6 then
            local settings = ns:GetTargetSettings(id)
            settings.reactions[#settings.reactions + 1] = { id = ns:NextReactionID(), condition = "mouseover", opacity = 1 }
            if tutorial.step >= 7 then settings.reactions[1], settings.reactions[2] = settings.reactions[2], settings.reactions[1] end
            if tutorial.step >= 8 then settings.atRest = 0.12 end
            ns:InvalidateTargetTransition(id)
        end
    end
    ns:RenderOptions()
    return true
end

local function CleanupTutorialTarget(tutorial)
    if not tutorial then return end
    local id, frame = tutorial.targetID, tutorial.frame
    if id and ns.CanForgetCustomTarget and ns:CanForgetCustomTarget(id) then ns:ForgetCustomTarget(id) end
    if frame then frame:SetAlpha(1); frame:Hide() end
    if ns.Options then
        ns.Options.targetQuery = tutorial.previousQuery or ""
        if ns.Options.targetFilter then ns.Options.targetFilter:SetText(ns.Options.targetQuery) end
        if tutorial.previousSelected and ns.TargetByID[tutorial.previousSelected] then ns.Options.selected = tutorial.previousSelected end
    end
    if ns.RenderOptions then ns:RenderOptions() end
end

local function CreateHelp()
    if ns.HelpCenter then return ns.HelpCenter end
    local help = CreateFrame("Frame", "FrameGambitHelpCenter", UIParent, "BackdropTemplate")
    help:SetSize(760, 555)
    local function FitToScreen()
        local uiWidth, uiHeight = UIParent:GetSize()
        help:SetScale(math.max(0.50, math.min(1, (uiWidth - 30) / 760, (uiHeight - 30) / 555)))
    end
    FitToScreen()
    help:SetPoint("CENTER")
    help:SetFrameStrata("FULLSCREEN_DIALOG"); help:SetFrameLevel(850); help:SetToplevel(true)
    help:SetMovable(true); help:SetClampedToScreen(true); help:EnableMouse(true)
    Backdrop(help, C.window, C.accent); help:Hide()
    if ns.TrackEUIObject then ns:TrackEUIObject("panel", help) end
    CloseButton(help, function() ns:CloseHelp() end):SetPoint("TOPRIGHT", -8, -8)
    local title = Text(help, "GameFontNormalHuge", "Help & tutorial", C.accent); title:SetPoint("TOPLEFT", 20, -18)
    local subtitle = Text(help, BODY, "Choose a topic or start the tutorial.", C.muted); subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    local drag = CreateFrame("Frame", nil, help)
    drag:SetPoint("TOPLEFT"); drag:SetPoint("TOPRIGHT"); drag:SetHeight(58)
    drag:EnableMouse(true); drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() help:StartMoving() end)
    drag:SetScript("OnDragStop", function() help:StopMovingOrSizing() end)

    local topics = {
        { title = "Start here", summary = "Pick a frame, add reactions, then set Otherwise.", body = "1. Pick a visible frame.\n\n2. Add the moments that should reveal or fade it.\n\n3. Set Otherwise for every other moment." },
        { title = "Rule priority", summary = "The first matching reaction sets opacity.", body = "Reactions run from top to bottom. Once one matches, lower rows are skipped. Drag rows to change priority.\n\nSize and position (experimental): the small toggle on a card adds Instant, Size and Move; the opacity window adds Keep opacity. Opacity, size and position each come from the first matching rule that sets them, otherwise from Otherwise. Keep opacity lets a rule change only size or position." },
        { title = "Relationships", summary = "Connect frames that should respond together.", body = "Hover group: hovering any member reveals the group.\n\nLinked child: hovering the source reveals its child.\n\nVisibility child: when its own rules do not match, the child follows its parent." },
        { title = "Appearance", summary = "Choose an appearance.", body = "Use Appearance in the editor header to switch among Ellesmere, Mimezu, Luminous, Charcoal, Chalk, Tungsten, Editorial, Super NES, Famicom, GameCube, Genesis, PS1, PS2, Xbox, Xbox 360, Violet Mist, and Violet Bloom. Ellesmere is the default. Your choice is saved and every Frame Gambit window uses it whether EllesmereUI is installed or not.\n\nDrag the header to move the window. Cinematic accents stay orange." },
        { title = "Cinematic", summary = "A separate profile for a cleaner scene.", body = "Cinematic keeps its own frame rules, black bars, field of view, and shortcuts. Left camera on entry places your character to the left and adapts as you zoom; its separate shortcut switches between that composition and a centered camera. Your previous camera settings return when Cinematic ends." },
        { title = "Safety", summary = "Frame Gambit changes opacity, and size or position only where you ask.", body = "It never restyles, reparents, shows, hides, or changes secure controls owned by WoW or another addon.\n\nA frame is resized or moved only when one of its rules, or Otherwise, sets a size or position. Protected frames change only outside combat, Edit Mode always shows the normal layout, and turning the toggle off puts the frame back where its owner placed it." },
        { title = "Troubleshooting", summary = "Confirm that you selected the intended frame.", body = "Use Pick on screen for one frame, or Discover visible UI to add several. Turn on Frame outline, then use Preview to check the result." },
    }
    local rail = CreateFrame("Frame", nil, help, "BackdropTemplate")
    rail:SetPoint("TOPLEFT", 18, -76); rail:SetPoint("BOTTOMLEFT", 18, 62); rail:SetWidth(190); Backdrop(rail, C.cardAlt, C.border)
    if ns.TrackEUIObject then ns:TrackEUIObject("panel", rail, { inset = true }) end
    local page = CreateFrame("Frame", nil, help, "BackdropTemplate")
    page:SetPoint("TOPLEFT", rail, "TOPRIGHT", 12, 0); page:SetPoint("BOTTOMRIGHT", -18, 62); Backdrop(page, C.card, C.border)
    if ns.TrackEUIObject then ns:TrackEUIObject("panel", page, { inset = true }) end
    help.topicButtons, help.page = {}, page
    page.title = Text(page, "GameFontNormalHuge", "", C.teal); page.title:SetPoint("TOPLEFT", 22, -22)
    page.summary = Text(page, "GameFontHighlight", "", C.muted); page.summary:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -6)
    page.rule = page:CreateTexture(nil, "ARTWORK"); page.rule:SetTexture(WHITE); page.rule:SetPoint("TOPLEFT", page.summary, "BOTTOMLEFT", 0, -14); page.rule:SetPoint("RIGHT", page, "RIGHT", -22, 0); page.rule:SetHeight(1); page.rule:SetVertexColor(unpack(C.border))
    if ns.TrackAppearanceObject then ns:TrackAppearanceObject(page.rule, "borderVertex") end
    page.body = Text(page, "GameFontHighlight", "", C.text); page.body:SetPoint("TOPLEFT", page.rule, "BOTTOMLEFT", 0, -20); page.body:SetPoint("BOTTOMRIGHT", -22, 22); page.body:SetJustifyH("LEFT"); page.body:SetJustifyV("TOP"); page.body:SetWordWrap(true); page.body:SetSpacing(3)
    function help:ShowTopic(index)
        self.topic = index
        local topic = topics[index]
        page.title:SetText(topic.title); page.summary:SetText(topic.summary); page.body:SetText(topic.body)
        for buttonIndex, button in ipairs(self.topicButtons) do
            local selected = buttonIndex == index
            button._primary = false
            button:SetBackdropColor(unpack(selected and { 0.08, 0.22, 0.20, 1 } or C.cardAlt))
            button:SetBackdropBorderColor(unpack(selected and C.teal or C.border))
            button:GetFontString():SetTextColor(unpack(selected and C.teal or C.accent))
        end
    end
    for index, topic in ipairs(topics) do
        local topicIndex = index
        local button = Button(rail, topic.title, 174, function() help:ShowTopic(topicIndex) end)
        button:SetHeight(42); button:SetPoint("TOPLEFT", 8, -8 - (index - 1) * 47)
        button:GetFontString():ClearAllPoints(); button:GetFontString():SetPoint("LEFT", 10, 0); button:GetFontString():SetJustifyH("LEFT")
        button:HookScript("OnLeave", function(self)
            if help.topic == topicIndex then
                self:SetBackdropColor(0.08, 0.22, 0.20, 1); self:SetBackdropBorderColor(unpack(C.teal))
            end
        end)
        help.topicButtons[index] = button
    end
    local start = Button(help, "Start guided tutorial", 190, function() help:Hide(); ns:StartTutorial() end, true)
    start:SetPoint("BOTTOMLEFT", 18, 18); help.start = start
    local restart = Button(help, "Restart tutorial", 125, function() help:Hide(); ns:StartTutorial(1) end)
    restart:SetPoint("LEFT", start, "RIGHT", 8, 0); help.restart = restart
    local close = Button(help, "Close", 90, function() help:Hide() end)
    close:SetPoint("BOTTOMRIGHT", -18, 18)
    help:SetScript("OnHide", function()
        help:StopMovingOrSizing()
        ClearOutline()
    end)
    help:SetScript("OnShow", function() FitToScreen(); help:Raise() end)
    help:ShowTopic(1)
    local displayEvents = CreateFrame("Frame")
    displayEvents:RegisterEvent("DISPLAY_SIZE_CHANGED"); displayEvents:RegisterEvent("UI_SCALE_CHANGED")
    displayEvents:SetScript("OnEvent", function() if help:IsShown() then FitToScreen() end end)
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = help:GetName() end
    ns.HelpCenter = help
    return help
end

local function CreateTutorial()
    if ns.TutorialCard then return ns.TutorialCard end
    local card = CreateFrame("Frame", "FrameGambitTutorial", UIParent, "BackdropTemplate")
    -- The coach card must remain readable after the player clicks a real
    -- editor control. Keep it above the options panel; RefreshTutorial also
    -- raises it after every live-editor refresh.
    card:SetSize(390, 220); card:SetFrameStrata("FULLSCREEN_DIALOG"); card:SetFrameLevel(950); card:SetToplevel(true); card:EnableMouse(true); card:SetClampedToScreen(true)
    Backdrop(card, C.panel, C.teal); card:Hide()
    if ns.TrackEUIObject then ns:TrackEUIObject("panel", card, { inset = true }) end
    local kicker = Text(card, BODY, "GUIDED TOUR", C.teal); kicker:SetPoint("TOPLEFT", 16, -14)
    local title = Text(card, TITLE, "", C.accent); title:SetPoint("TOPLEFT", 16, -33); card.title = title
    local body = Text(card, "GameFontHighlight", "", C.muted); body:SetPoint("TOPLEFT", 16, -65); body:SetPoint("TOPRIGHT", -16, -65); body:SetJustifyH("LEFT"); body:SetJustifyV("TOP"); body:SetWordWrap(true); card.body = body
    local progress = Text(card, BODY, "", C.muted); progress:SetPoint("BOTTOMLEFT", 16, 15); card.progress = progress
    card.back = Button(card, "Back", 58, function() ns.Tutorial.step = math.max(1, ns.Tutorial.step - 1); ns:RefreshTutorial() end)
    card.back:SetPoint("BOTTOMRIGHT", -157, 12)
    card.next = Button(card, "Next", 66, function()
        local tutorial = ns.Tutorial
        if not tutorial or tutorial.paused then return end
        local ready, message = CanAdvance(tutorial)
        if not ready then
            card.validation:SetText(message or "Try this step first.")
            return
        end
        if tutorial.step >= #STEPS then ns:CancelTutorial("complete"); return end
        if tutorial.step == 3 then SeedTutorialStationaryRule(tutorial) end
        tutorial.step = tutorial.step + 1; ns:RefreshTutorial()
    end, true)
    card.next:SetPoint("LEFT", card.back, "RIGHT", 6, 0)
    card.skip = Button(card, "Skip", 48, function() ns:CancelTutorial("skipped") end)
    card.skip:SetPoint("LEFT", card.next, "RIGHT", 6, 0)
    CloseButton(card, function() ns:CancelTutorial("closed") end):SetPoint("TOPRIGHT", -5, -5)

    local validation = Text(card, BODY, "", C.amber)
    validation:SetPoint("BOTTOMLEFT", 16, 39); validation:SetPoint("BOTTOMRIGHT", -16, 39)
    validation:SetJustifyH("LEFT"); card.validation = validation

    card:SetScript("OnHide", function()
        -- Escape uses UISpecialFrames and hides the card directly.
        if ns.Tutorial and not ns.Tutorial.closing and not ns.Tutorial.hidingForCombat then ns:CancelTutorial("closed") end
    end)
    table.insert(UISpecialFrames, "FrameGambitTutorial")
    ns.TutorialCard = card
    return card
end

function ns:OpenHelp()
    if IsCombat() then Notice("Leave combat to open Help.", C.amber); return end
    if ns.HideAppearancePicker then ns:HideAppearancePicker() end
    if ns.MarkHelpRead then ns:MarkHelpRead() end
    -- Help and the coach card are mutually exclusive. Save the live step
    -- before opening Help so Resume always describes the real tour state.
    if ns.Tutorial then ns:CancelTutorial("help_opened") end
    local help = CreateHelp()
    local savedStep, completed = GetState()
    if completed then
        help.start:GetFontString():SetText("Replay guided tutorial")
        help.restart:Hide()
    elseif savedStep > 1 then
        help.start:GetFontString():SetText("Resume guided tutorial")
        help.restart:Show()
    else
        help.start:GetFontString():SetText("Start guided tutorial")
        help.restart:Hide()
    end
    help:ShowTopic(1)
    help:Show()
    help:Raise()
end

function ns:ToggleHelp()
    if ns.HelpCenter and ns.HelpCenter:IsShown() then
        ns:CloseHelp()
        return
    end
    ns:OpenHelp()
end

function ns:CloseHelp()
    if ns.HelpCenter then ns.HelpCenter:Hide() end
end

function ns:StartTutorial(requestedStep)
    if IsCombat() then Notice("Leave combat to start the tutorial.", C.amber); return false end
    if ns.HideAppearancePicker then ns:HideAppearancePicker() end
    local panel = EnsureOptions()
    if not panel then return false end
    ns:CloseHelp()
    local savedStep, completed = GetState()
    local step = tonumber(requestedStep) or (completed and 1 or savedStep)
    step = math.max(1, math.min(#STEPS, step))
    ns.Tutorial = {
        step = step,
        paused = false,
        wasCompleted = completed == true,
    }
    local started, reason = StartTutorialTarget(ns.Tutorial, step > 1)
    if not started then
        local tutorial = ns.Tutorial
        ns.Tutorial = nil
        CleanupTutorialTarget(tutorial)
        Notice(reason or "The temporary Tutorial Frame could not be created.", C.amber)
        return false
    end
    local card = CreateTutorial()
    card:Show(); ns:RefreshTutorial()
    return true
end

function ns:CancelTutorial(reason)
    local tutorial = ns.Tutorial
    if not tutorial then return end
    local completed = reason == "complete" or tutorial.wasCompleted == true
    SaveState(completed and #STEPS or tutorial.step or 1, completed)
    ClearOutline(); ClearSpotlight()
    tutorial.closing = true
    if ns.TutorialCard then ns.TutorialCard:Hide() end
    ns.Tutorial = nil
    CleanupTutorialTarget(tutorial)
    if completed then Notice("Tutorial complete. You can restart it any time from Help.", C.teal) end
end

function ns:RefreshTutorial()
    local tutorial, card = ns.Tutorial, ns.TutorialCard
    if not tutorial or not card or not card:IsShown() then return end
    if IsCombat() then ns:OnTutorialCombatStateChanged(true); return end
    local step = STEPS[tutorial.step] or STEPS[1]
    card.title:SetText(step.title); card.body:SetText(step.body)
    card.validation:SetText("")
    card.progress:SetText("Step " .. tutorial.step .. " of " .. #STEPS)
    card.back:SetShown(tutorial.step > 1); card.next:GetFontString():SetText(step.finish and "Finish" or "Next")
    card:SetHeight(220)
    local target = FindControl(step.focus)
    Highlight(target); Spotlight(target)
    -- Put the card beside the highlighted target whenever there is room; the
    -- editor stays clickable and the explanation never sits on its target.
    card:SetScale(1)
    card:ClearAllPoints()
    local panel = ns.Options
    local compact = UIParent:GetWidth() < 1000 or UIParent:GetHeight() < 650
        or (panel and (panel:GetWidth() <= 800 or panel:GetHeight() <= 540))
    if compact then
        -- On a small viewport there is no honest way to fit the card beside a
        -- large editor pane. Dock it compactly and remove the competing box.
        ClearOutline(); ClearSpotlight()
        card:SetScale(0.88)
        card:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -14, 14)
        card:Raise()
        return
    end
    -- A normal editor leaves a generous column to its left on wide screens.
    -- Docking the explanation there keeps it visible *and* prevents it from
    -- covering the real target row or button the player must click next.
    local panelLeft
    if panel and ns.GetUsableFrameRect then panelLeft = ns:GetUsableFrameRect(panel) end
    if panelLeft and panelLeft >= 422 then
        card:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 18, 18)
        card:Raise()
        return
    end
    if SafeShown(target) then
        local left, bottom, width, height
        if ns.GetUsableFrameRect then
            left, bottom, width, height = ns:GetUsableFrameRect(target)
        end
        if left and bottom and width and height and left + width + 406 < UIParent:GetWidth() then
            card:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left + width + 12, bottom + height)
        elseif left and bottom and width and height and left - 406 > 0 then
            card:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", left - 12, bottom + height)
        else
            card:SetPoint("CENTER", UIParent, "CENTER", 0, -UIParent:GetHeight() * 0.24)
        end
    else
        card:SetPoint("CENTER", UIParent, "CENTER", 0, -UIParent:GetHeight() * 0.24)
    end
    card:Raise()
end

function ns:OnTutorialCombatStateChanged(inCombat)
    local tutorial, card = ns.Tutorial, ns.TutorialCard
    if not tutorial or not card then return end
    if inCombat then
        tutorial.paused = true; tutorial.hidingForCombat = true; ClearOutline(); ClearSpotlight()
        card:Hide()
    elseif tutorial.paused then
        tutorial.paused = false; tutorial.hidingForCombat = false; card:Show(); ns:RefreshTutorial()
    end
end
