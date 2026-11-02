-- Local Forever convenience: keep the floating beta reporter hidden until
-- requested. Session-only state deliberately resets on login and /reload.
local visible = false
local hooked = setmetatable({}, { __mode = "k" })

local function ApplyVisibility()
    local reporter = _G.PTR_IssueReporter
    -- Blizzard builds the view on PLAYER_ENTERING_WORLD, replacing OnShow.
    -- Wait for that view before adding our hook.
    if not reporter or not reporter.ReportBug then return false end
    if not hooked[reporter] then
        reporter:HookScript("OnShow", function(self)
            if not visible then self:Hide() end
        end)
        hooked[reporter] = true
    end
    if visible then reporter:Show() else reporter:Hide() end
    return true
end

local function BugCommand(message)
    local command = (message or ""):match("^%s*(.-)%s*$"):lower()
    if command == "show" then
        visible = true
    elseif command == "hide" then
        visible = false
    elseif command == "" or command == "toggle" then
        visible = not visible
    else
        print("Issue Reporter: /bug toggles; /bug show or /bug hide.")
        return
    end
    if ApplyVisibility() then
        print("Issue Reporter " .. (visible and "shown. /bug hides it again." or "hidden."))
    else
        print("Issue Reporter is not ready yet. Try /bug show after entering the world.")
    end
end

local function RegisterCommands()
    -- Reuse the built-in BUG slot instead of competing with it for /bug.
    SLASH_BUG1 = "/bug"
    SlashCmdList.BUG = BugCommand
    SLASH_FOREVERBUGREPORTER1 = "/foreverbug"
    SlashCmdList.FOREVERBUGREPORTER = BugCommand
    -- Some clients already cached the built-in command before addon loading.
    if hash_SlashCmdList then
        hash_SlashCmdList["/BUG"] = BugCommand
        hash_SlashCmdList["/FOREVERBUG"] = BugCommand
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(_, event, addon)
    if event == "ADDON_LOADED" and addon ~= "Blizzard_PTRFeedback" then return end
    RegisterCommands()
    ApplyVisibility()
    -- Run after Blizzard's event handler regardless of handler ordering.
    C_Timer.After(0, ApplyVisibility)
end)

RegisterCommands()
ApplyVisibility()
