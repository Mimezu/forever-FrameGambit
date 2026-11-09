-- Clean screenshot: one key hides the whole interface (the same switch as
-- Alt+Z), takes the game's own screenshot, and puts the interface back as soon
-- as the game reports the picture saved (or failed).
-- The hide and the Screenshot() call happen in the same frame, so the picture
-- is of the very next frame drawn: no delay, no fade.
-- If the interface was already hidden (you pressed Alt+Z yourself), it stays
-- hidden afterwards.

BINDING_NAME_FRAMEGAMBIT_CLEAN_SCREENSHOT = "Screenshot without interface"

local SAFETY = 2 -- seconds: bring the interface back even if no event arrives

local pending -- { ui = true if we hid UIParent, world = true if we hid nameplates }

local function Restore()
    local p = pending
    if not p then return end
    pending = nil
    if p.world and SetInWorldUIVisibility then pcall(SetInWorldUIVisibility, true) end
    if p.ui and not UIParent:IsShown() then pcall(SetUIVisibility, true) end
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("SCREENSHOT_SUCCEEDED")
watcher:RegisterEvent("SCREENSHOT_FAILED")
watcher:SetScript("OnEvent", Restore)

function FrameGambit_CleanScreenshot()
    if pending or type(Screenshot) ~= "function" then return end
    local p = {}
    pending = p
    if UIParent:IsShown() and SetUIVisibility then
        pcall(SetUIVisibility, false)
        p.ui = not UIParent:IsShown()
    end
    if SetInWorldUIVisibility then p.world = pcall(SetInWorldUIVisibility, false) end
    if not pcall(Screenshot) then Restore(); return end
    C_Timer.After(SAFETY, function() if pending == p then Restore() end end)
end
