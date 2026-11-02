local root = arg and arg[1] or "."
CreateFrame = function() return { RegisterEvent=function() end, RegisterUnitEvent=function() end,
    SetScript=function() end, GetScript=function() end } end
SlashCmdList = {}
local ns = {}
assert(loadfile(root .. "/Core.lua"))("FrameGambit", ns)
for _, oldMode in ipairs({"binder", "panel", "invalid"}) do
    local rule = { condition="combat", opacity=.8 }
    FrameGambitDB = { version=14, workspaceMode=oldMode, appearanceTheme="legacy",
        profiles={ Default={ targets={player={reactions={rule}}} } } }
    ns:MigrateDatabase()
    assert(FrameGambitDB.workspaceMode == "panel")
    assert(FrameGambitDB.appearanceTheme == "legacy")
    assert(FrameGambitDB.profiles.Default.targets.player.reactions[1] == rule)
end
assert(ns.GetWorkspaceMode == nil and ns.SetWorkspaceMode == nil)
print("PASS: saved Binder migration preserves appearance and rules; no layout switch API")
