local _, ns = ...
local memberOwner = setmetatable({}, { __mode = "k" })

-- Native shoulder artwork only. Each texture retains its own host alpha and
-- shown state. No controller callbacks, scripts, hooks or frame changes.
local function Secret(value)
    return issecretvalue and issecretvalue(value) or false
end

local function Alpha(region)
    local ok, value = pcall(region.GetAlpha, region)
    if ok and not Secret(value) and type(value) == "number" and value == value and value >= 0 and value <= 1 then return value end
end

local function Usable(region)
    if not region or Secret(region) then return false end
    local ok, getAlpha, setAlpha, getRect, isShown = pcall(function()
        return region.GetAlpha, region.SetAlpha, region.GetRect, region.IsShown
    end)
    return ok and type(getAlpha) == "function" and type(setAlpha) == "function"
        and type(getRect) == "function" and type(isShown) == "function"
end

local function NewProxy(members)
    local proxy = { members = members, records = {}, active = false, applied = 1 }
    function proxy:GetAlpha() return self.active and self.applied or 1 end
    function proxy:GetRect() return self.members[1]:GetRect() end
    function proxy:GetEffectiveScale() return self.members[1]:GetEffectiveScale() end
    function proxy:IsShown()
        for _, member in ipairs(self.members) do
            local ok, shown = pcall(member.IsShown, member)
            if ok and not Secret(shown) and shown == true then return true end
        end
        return false
    end
    function proxy:Acquire()
        if self.active then return true end
        local records = {}
        for index, member in ipairs(self.members) do
            -- A retired composite may still be awaiting a rejected restore.
            -- Do not capture its faded alpha as a replacement's baseline.
            if memberOwner[member] and memberOwner[member] ~= self then return false end
            local value = Alpha(member)
            if value == nil then return false end
            records[index] = { base = value, lastApplied = value }
        end
        self.records, self.active, self.applied = records, true, 1
        for _, member in ipairs(self.members) do memberOwner[member] = self end
        return true
    end
    function proxy:SetAlpha(value)
        if Secret(value) or type(value) ~= "number" or value ~= value or value < 0 or value > 1 then error("Invalid shoulder opacity", 0) end
        if not self.active then return end
        for index, member in ipairs(self.members) do
            local record, live = self.records[index], Alpha(member)
            if live == nil then error("Shoulder alpha unavailable", 0) end
            -- A later native repaint becomes the new baseline. At steady
            -- opacity ResolveTarget calls this same bounded reconciliation.
            if math.abs(live - record.lastApplied) > 0.001 then record.base = live end
            local desired = record.base * value
            if math.abs(live - desired) > 0.001 then
                local ok = pcall(member.SetAlpha, member, desired)
                if not ok then error("Shoulder alpha write rejected", 0) end
                live = Alpha(member)
                if live == nil then error("Shoulder alpha readback unavailable", 0) end
            end
            -- Native alpha can be quantized. Compare the next sample with
            -- what was stored, not the requested value, or our own fade is
            -- mistaken for a host repaint and multiplied into the baseline.
            record.lastApplied = live
        end
        self.applied = value
    end
    function proxy:Release()
        if not self.active then return end
        self:SetAlpha(1)
        for _, member in ipairs(self.members) do
            if memberOwner[member] == self then memberOwner[member] = nil end
        end
        self.records, self.active, self.applied = {}, false, 1
    end
    return proxy
end

for _, entry in ipairs({ { "left", "Left" }, { "right", "Right" } }) do
    local key, prefix, current = entry[1], entry[2], nil
    ns:RegisterTarget({
        id = "gamepad_shoulder_" .. key, label = "Gamepad - " .. prefix .. " shoulder",
        source = "Blizzard", protected = true, skipManagedAlphaHook = true,
        capability = "Shoulder artwork", capabilityTone = "teal",
        capabilityNote = "Opacity only",
        resolve = function()
            local root = _G.GamepadMainActionBarFrame
            local unit = root and root.PageUnit
            if not unit then current = nil; return nil end
            local members = { unit[prefix .. "ShoulderBackground"], unit[prefix .. "ShoulderIcon"], unit[prefix .. "ShoulderHighlight"] }
            for index = 1, 3 do if not Usable(members[index]) then current = nil; return nil end end
            if not current or current.members[1] ~= members[1] or current.members[2] ~= members[2] or current.members[3] ~= members[3] then
                current = NewProxy(members)
            end
            if current.active then current:SetAlpha(current.applied) end
            return current
        end,
        acquire = function(proxy) return proxy:Acquire() end,
        release = function(proxy) return proxy:Release() end,
    })
end
