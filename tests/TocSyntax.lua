-- Every Lua file in the TOC must at least compile (catches a broken string or
-- typo in a file that no other test loads, such as Tutorial.lua's help text).
-- Run from the addon folder: lua5.1 tests/TocSyntax.lua .
local root = arg and arg[1] or "."
local toc = assert(io.open(root .. "/FrameGambit.toc", "rb"))
local count, failures = 0, {}
for line in toc:read("*a"):gmatch("[^\r\n]+") do
    local file = line:match("^%s*([%w_%.%-/\\]+%.lua)%s*$")
    if file then
        count = count + 1
        local chunk, err = loadfile(root .. "/" .. file:gsub("\\", "/"))
        if not chunk then failures[#failures + 1] = err end
    end
end
toc:close()
assert(count > 20, "TOC lists too few Lua files: " .. count)
assert(#failures == 0, "Lua files fail to compile:\n" .. table.concat(failures, "\n"))
print("PASS: all " .. count .. " Lua files listed in the TOC compile")
