local _, ns = ...

-- Frame Gambit's page in Esc > Options > AddOns: open the window, the slash
-- command, the minimap icon and every key. A keycap listens for the next key
-- in place (Esc cancels, Del clears, modifiers combine).

local page
local listening

local function Refresh()
    if not page then return end
    page.minimap:SetChecked(ns:IsMinimapButtonShown())
    for _, row in ipairs(page.keys) do
        if row.keycap ~= listening then
            local key = ns:GetActionKey(row.entry.action)
            row.keycap:SetText(key and ns.KeyText(key) or "Not bound")
        end
    end
end
ns.RefreshSettingsPage = Refresh

local function StopListening()
    local keycap = listening
    listening = nil
    -- Setting OnKeyDown turns the keyboard on, so the handler exists only while listening.
    if keycap then keycap:SetScript("OnKeyDown", nil); keycap:EnableKeyboard(false); keycap:UnlockHighlight() end
    Refresh()
end

local function Say(text, warn)
    page.status:SetText(text or "")
    if warn then page.status:SetTextColor(1, 0.72, 0.25) else page.status:SetTextColor(0.6, 0.6, 0.6) end
end

local function Bind(entry, key)
    local conflict = key and ns:KeyConflict(key, entry.action)
    local ok, reason = ns:SetActionBinding(entry.action, key)
    if not ok then Say(reason, true)
    elseif conflict then Say("Replaced " .. conflict, true)
    else Say("") end
end

local function KeyRow(entry, anchor)
    local label = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -14)
    label:SetWidth(160); label:SetJustifyH("LEFT")
    label:SetText(entry.label)
    local keycap = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    keycap:SetSize(170, 24)
    keycap:SetPoint("LEFT", label, "RIGHT", 8, 0)
    local function OnKeyDown(self, key)
        if listening ~= self then return end
        if key == "ESCAPE" then Say(""); StopListening(); return end
        if key == "BACKSPACE" or key == "DELETE" then Bind(entry, nil); StopListening(); return end
        local chord = ns.KeyChord(key)
        if not chord then return end
        Bind(entry, chord)
        StopListening()
    end
    keycap:SetScript("OnClick", function(self)
        if InCombatLockdown() then Say("Not in combat", true); return end
        if listening == self then StopListening(); return end
        StopListening()
        listening = self
        self:SetText("Press a key")
        self:LockHighlight()
        self:SetScript("OnKeyDown", OnKeyDown)
        self:EnableKeyboard(true)
        if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
        Say("Esc: cancel. Del: clear")
    end)
    keycap:SetScript("OnHide", function(self) if listening == self then StopListening() end end)
    return { entry = entry, label = label, keycap = keycap }
end

local function Build()
    -- Hidden until the Settings window shows it; a parentless frame is otherwise visible.
    page = CreateFrame("Frame")
    page:Hide()
    page.name = ns.NAME
    local heading = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 16, -16)
    heading:SetText(ns.NAME)

    local open = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    open:SetSize(140, 26)
    open:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -14)
    open:SetText("Open")
    open:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        ns:CreateOptions()
        if not ns.Options:IsVisible() then ns:ToggleOptions() end
    end)
    local slash = page:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    slash:SetPoint("LEFT", open, "RIGHT", 12, 0)
    slash:SetText("/framegambit")

    page.minimap = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    page.minimap:SetPoint("TOPLEFT", open, "BOTTOMLEFT", -4, -14)
    local minimapText = page.minimap.Text or page.minimap.text
    if minimapText then minimapText:SetFontObject("GameFontHighlight"); minimapText:SetText("Minimap icon") end
    page.minimap:SetScript("OnClick", function(self) ns:SetMinimapButtonShown(self:GetChecked() and true or false) end)

    local keysHeading = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    keysHeading:SetPoint("TOPLEFT", page.minimap, "BOTTOMLEFT", 4, -18)
    keysHeading:SetText("Keys")
    page.keys = {}
    local anchor = keysHeading
    for _, entry in ipairs(ns.KEY_ACTIONS) do
        local row = KeyRow(entry, anchor)
        page.keys[#page.keys + 1] = row
        anchor = row.label
    end
    page.status = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    page.status:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -16)

    page:SetScript("OnShow", Refresh)
    page:SetScript("OnHide", function() StopListening(); Say("") end)
    local category = Settings.RegisterCanvasLayoutCategory(page, ns.NAME)
    Settings.RegisterAddOnCategory(category)
    ns.SettingsCategory = category
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("UPDATE_BINDINGS")
loader:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
            local ok, err = pcall(Build)
            if not ok and geterrorhandler then geterrorhandler()(err) end
        end
    elseif page and page:IsVisible() then
        Refresh()
    end
end)
