local root = arg and arg[1] or "."
local driver
GetTime = function() return 0 end
InCombatLockdown = function() return false end
SlashCmdList = {}
C_Timer = { After = function() end }
CreateFrame = function()
    driver = { RegisterEvent = function() end, RegisterUnitEvent = function() end,
        SetScript = function(self, name, callback) self[name] = callback end }
    return driver
end
local ns = {}
assert(loadfile(root .. "/Core.lua"))("FrameGambit", ns)
-- Isolate the editor's startup lifecycle from gameplay adapters. Execute the
-- real login handler; a hidden editor must not allocate frames or skin art.
for _, name in ipairs({ "MigrateDatabase", "MigrateLegacyCinematicBinding", "EnsureCinematicProfile",
    "EnsureConnectedHoverRules", "RefreshInputModeProfile", "Wake" }) do ns[name] = function() end end
ns.IsCinematicActive = function() return false end
local builds, renders = 0, 0
ns.CreateOptions = function(self)
    if self.Options then return end
    builds = builds + 1
    self.Options = { shown = false }
    function self.Options:IsVisible() return self.shown end
    function self.Options:Show() self.shown = true; renders = renders + 1 end
    function self.Options:Hide() self.shown = false end
end
driver.OnEvent(driver, "PLAYER_LOGIN")
assert(builds == 0 and not ns.Options, "login must not build the hidden editor")

local file = assert(io.open(root .. "/Options.lua", "r"))
local source = file:read("*a"); file:close()
local first = assert(source:find("function ns:ToggleOptions()", 1, true))
local last = assert(source:find("function ns:EnterEditorPeek()", first, true))
assert((loadstring or load)("local ns = ...\n" .. source:sub(first, last - 1)))(ns)
ns:ToggleOptions()
assert(builds == 1 and renders == 1 and ns.Options:IsVisible(), "first open must build and render")
ns:ToggleOptions()
assert(builds == 1 and not ns.Options:IsVisible(), "close must retain reusable editor")
ns:ToggleOptions()
assert(builds == 1 and renders == 2 and ns.Options:IsVisible(), "reopen must reuse and render")
-- The picker is another first-use entry point. Stop at picker construction
-- after running its real combat guard and editor setup.
first = assert(source:find("function ns:StartPicker(intent)", 1, true))
last = assert(source:find("local function PickerFrame(candidate)", first, true))
assert((loadstring or load)("local ns = ...\n" .. source:sub(first, last - 1)))(ns)
ns.Options = nil
InCombatLockdown = function() return true end
ns:StartPicker()
assert(builds == 1 and not ns.Options, "combat picker attempt must not allocate editor")
InCombatLockdown = function() return false end
local reachedPicker = {}
ns.CreatePicker = function() error(reachedPicker) end
local ok, reason = pcall(ns.StartPicker, ns)
assert(not ok and reason == reachedPicker and builds == 2 and ns.Options,
    "first-use picker must create the editor before picker acceptance can reference it")
print("Frame Gambit lazy editor startup smoke passed")
