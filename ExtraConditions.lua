local ADDON, ns = ...

-- Shared by Forever and Retail. All observations are read-only; unreadable
-- combat data must never become an affirmative condition.
local function Secret(value)
    return issecretvalue and issecretvalue(value) or false
end

local function Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if not ok or Secret(value) then return nil end
    return value
end

local function Number(value)
    return not Secret(value) and type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end

ns.CONDITION_INFO.party_combat = {
    label = "Party member in combat", category = "party", kind = "state", pickerOrder = 3,
    help = nil,
}
ns.CONDITION_INFO.major_city = {
    label = "In a major city", category = "social", kind = "state",
    help = nil,
}
ns.CONDITION_INFO.elite_combat = {
    label = "Fighting an elite", category = "character", kind = "state", restricted = true,
    help = nil,
}
ns.CONDITION_INFO.chat_party_loot = {
    label = "Party member loots", category = "chat", kind = "moment", duration = 10,
    help = nil,
}
ns.CONDITION_INFO.chat_loot_winner = {
    label = "Loot roll won", category = "chat", kind = "moment", duration = 10,
    help = nil,
}

ns.CONDITION_INFO.campfire_sitting = {
    label = "At a campfire", category = "character", kind = "state",
    help = "Not detected? /fg campfire",
}

-- UI map IDs, not localized zone names. Child maps inherit their city's ID.
local CITY_MAPS = {
    [84] = true, [85] = true, [87] = true, [88] = true, [89] = true, [90] = true,
    [103] = true, [110] = true, [111] = true, [125] = true, [126] = true,
    [627] = true, [628] = true, [1161] = true, [1165] = true,
    [1670] = true, [2112] = true, [2339] = true, [2393] = true,
    [1453] = true, [1454] = true, [1455] = true, [1456] = true,
    [1457] = true, [1458] = true,
}

local function InMajorCity()
    -- Dungeon maps can have the outdoor city as a parent.
    if Read(IsInInstance) ~= false then return nil end
    local mapID = C_Map and Read(C_Map.GetBestMapForUnit, "player")
    for _ = 1, 8 do
        if not Number(mapID) or mapID <= 0 then return nil end
        if CITY_MAPS[mapID] then return true end
        local info = C_Map and Read(C_Map.GetMapInfo, mapID)
        if type(info) ~= "table" then return nil end
        local parent = info.parentMapID
        if not Number(parent) then return nil end
        if parent == 0 or parent == mapID then return false end
        mapID = parent
    end
    return nil
end

local ELITE_UNITS = { "target", "focus" }
for i = 1, 4 do ELITE_UNITS[#ELITE_UNITS + 1] = "party" .. i .. "target" end
for i = 1, 5 do ELITE_UNITS[#ELITE_UNITS + 1] = "boss" .. i end
for i = 1, 40 do ELITE_UNITS[#ELITE_UNITS + 1] = "nameplate" .. i end

local function InEliteCombat()
    if Read(UnitAffectingCombat, "player") ~= true then return false end
    for _, unit in ipairs(ELITE_UNITS) do
        if Read(UnitExists, unit) == true and Read(UnitCanAttack, "player", unit) == true
            and Read(UnitIsDeadOrGhost, unit) == false then
            local classification = Read(UnitClassification, unit)
            if classification == "elite" or classification == "rareelite" or classification == "worldboss" then
                local threat = Read(UnitThreatSituation, "player", unit)
                if Number(threat) and threat >= 1 and threat <= 3 then return true end
                -- Status zero includes ordinary non-tanking damage dealers.
                -- Confirm positive threat rather than equating zero with either
                -- guaranteed engagement or guaranteed absence from the fight.
                if threat == 0 and type(UnitDetailedThreatSituation) == "function" then
                    local ok, _, _, _, _, rawThreat = pcall(UnitDetailedThreatSituation, "player", unit)
                    if ok and Number(rawThreat) and rawThreat > 0 then return true end
                end
            end
        end
    end
    return false
end

-- Forever's campfire timer is a server aura. Known IDs are built in; other
-- campfire variants can be taught with /fg campfire (stored account-wide).
local CAMPFIRE_TIMER_MAX = 75
local CAMPFIRE_TIMER_AURAS = {
    [1229739] = true, -- Welcoming Campfire (confirmed in game, build 70009)
}

local function CampfireAuras()
    local learned = type(FrameGambitDB) == "table" and FrameGambitDB.campfireAuras
    return type(learned) == "table" and learned or nil
end

local function SittingAtCampfire()
    local getAura = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
    if type(getAura) ~= "function" then return nil end
    local function Has(spellID)
        local ok, aura = pcall(getAura, spellID)
        return ok and not Secret(aura) and type(aura) == "table"
    end
    for spellID in pairs(CAMPFIRE_TIMER_AURAS) do
        if Has(spellID) then return true end
    end
    for spellID in pairs(CampfireAuras() or {}) do
        if Has(spellID) then return true end
    end
    return false
end

local function ReadPlayerAuras()
    local byIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if type(byIndex) ~= "function" then return nil end
    local auras, now = {}, GetTime()
    for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
        for index = 1, 40 do
            local aura = Read(byIndex, "player", index, filter)
            if type(aura) ~= "table" then break end
            local spellID, name = aura.spellId, aura.name
            if Number(spellID) and not Secret(name) and type(name) == "string" then
                local duration, expires = aura.duration, aura.expirationTime
                local short = Number(duration) and Number(expires) and duration > 0
                    and duration <= CAMPFIRE_TIMER_MAX and expires > now
                auras[#auras + 1] = { spellID = spellID, name = name, short = short,
                    remaining = short and math.floor(expires - now + 0.5) or nil }
            end
        end
    end
    return auras
end

local function Say(text)
    print("|cff9D75FFFrame Gambit|r " .. text)
end

local function Learn(aura)
    FrameGambitDB.campfireAuras = CampfireAuras() or {}
    FrameGambitDB.campfireAuras[aura.spellID] = aura.name
    Say(("Learned campfire timer: %s (%d). \"Sitting at a campfire\" now follows it."):format(aura.name, aura.spellID))
    ns:Wake()
end

function ns:HandleCampfireCommand(argument)
    if type(FrameGambitDB) ~= "table" then return end
    argument = argument or ""
    if argument == "clear" then
        FrameGambitDB.campfireAuras = nil
        Say("Campfire timer forgotten")
        return self:Wake()
    elseif argument == "list" then
        local learned = CampfireAuras()
        if not learned or next(learned) == nil then return Say("No campfire timer") end
        for spellID, name in pairs(learned) do Say(("Campfire timer: %s (%d)"):format(tostring(name), spellID)) end
        return
    end
    local auras = ReadPlayerAuras()
    if not auras then return Say("Auras unreadable") end
    local pick = tonumber(argument)
    if pick then
        if auras[pick] then return Learn(auras[pick]) end
        return Say("No aura with that number")
    end
    local short = {}
    for _, aura in ipairs(auras) do if aura.short then short[#short + 1] = aura end end
    if #short == 1 then return Learn(short[1]) end
    if #auras == 0 then
        return Say("No auras. Sit at a campfire first")
    end
    Say(#short == 0 and "Pick the campfire aura:"
        or "Pick the campfire aura:")
    for index, aura in ipairs(auras) do
        Say(("  %d. %s (%d)%s"):format(index, aura.name, aura.spellID,
            aura.remaining and (" - " .. aura.remaining .. "s left") or ""))
    end
    Say("/fg campfire <number>")
end

function ns:BuildExtraConditionContext(needed, context)
    if needed.party_combat then
        context.party_combat = false
        if Read(IsInRaid) == false then
            for i = 1, 4 do
                local unit = "party" .. i
                if Read(UnitExists, unit) == true and Read(UnitIsConnected, unit) == true
                    and Read(UnitAffectingCombat, unit) == true then
                    context.party_combat = true
                    break
                end
            end
        end
    end
    if needed.major_city then context.major_city = InMajorCity() end
    if needed.elite_combat then context.elite_combat = InEliteCombat() end
    if needed.campfire_sitting then context.campfire_sitting = SittingAtCampfire() end
end

-- Compile localized printf templates, preserving positional argument indices.
-- Match only the complete notification; punctuation and links remain literal.
local formats = {}
local function MatchFormat(message, template)
    if Secret(message) or Secret(template) or type(message) ~= "string"
        or type(template) ~= "string" or template == "" then return nil end
    local compiled = formats[template]
    if not compiled then
        local parts, indices, cursor, argument = { "^" }, {}, 1, 0
        while cursor <= #template do
            local first = template:find("%", cursor, true)
            local literal = template:sub(cursor, first and first - 1 or #template)
            parts[#parts + 1] = literal:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
            if not first then break end
            if template:sub(first + 1, first + 1) == "%" then
                parts[#parts + 1], cursor = "%%", first + 2
            else
                local token = template:sub(first):match("^%%[%d%$]*[sd]")
                if not token then return nil end
                argument = argument + 1
                indices[#indices + 1] = tonumber(token:match("%%(%d+)%$")) or argument
                parts[#parts + 1] = token:sub(-1) == "d" and "(%d+)" or "(.-)"
                cursor = first + #token
            end
        end
        parts[#parts + 1] = "$"
        compiled = { pattern = table.concat(parts), indices = indices }
        formats[template] = compiled
    end
    local captures = { message:match(compiled.pattern) }
    if #captures == 0 then return nil end
    local arguments = {}
    for i, value in ipairs(captures) do arguments[compiled.indices[i] or i] = value end
    return arguments
end

local function PartySender(name, guid)
    if Secret(name) or Secret(guid) or Read(IsInRaid) ~= false then return false end
    if type(name) == "string" then
        name = name:gsub("|H.-|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        name = name:match("^%[(.*)%]$") or name
    end
    for i = 1, 4 do
        local unit = "party" .. i
        if Read(UnitExists, unit) == true then
            if type(guid) == "string" and guid ~= "" then
                if Read(UnitGUID, unit) == guid then return true end
            elseif type(name) == "string" and name ~= "" and type(UnitName) == "function" then
                local ok, unitName, realm = pcall(UnitName, unit)
                if ok and not Secret(unitName) and not Secret(realm) and type(unitName) == "string" then
                    if type(realm) == "string" and realm ~= "" then
                        unitName = unitName .. "-" .. realm:gsub("%s", "")
                    end
                    if name == unitName then return true end
                end
            end
        end
    end
    return false
end

local RECEIVED_FORMATS = { "LOOT_ITEM", "LOOT_ITEM_MULTIPLE", "LOOT_ITEM_PUSH", "LOOT_ITEM_PUSH_MULTIPLE" }
local WINNER_FORMATS = {
    "LOOT_ROLL_WON", "LOOT_ROLL_YOU_WON",
    "LOOT_ROLL_WON_NO_SPAM_NEED", "LOOT_ROLL_WON_NO_SPAM_GREED", "LOOT_ROLL_WON_NO_SPAM_DE",
    "LOOT_ROLL_YOU_WON_NO_SPAM_NEED", "LOOT_ROLL_YOU_WON_NO_SPAM_GREED", "LOOT_ROLL_YOU_WON_NO_SPAM_DE",
    "LOOT_ROLL_WON_NO_SPAM_TRANSMOG", "LOOT_ROLL_YOU_WON_NO_SPAM_TRANSMOG",
}
function ns:ObserveExtraLootMessage(message, senderName, senderGUID)
    if Secret(message) or type(message) ~= "string" then return end
    local changed = false
    for _, key in ipairs(WINNER_FORMATS) do
        if MatchFormat(message, _G[key]) then
            self.runtime.moments.chat_loot_winner, changed = GetTime(), true
            break
        end
    end
    for _, key in ipairs(RECEIVED_FORMATS) do
        local args = MatchFormat(message, _G[key])
        if args then
            if not Secret(senderName) and not Secret(senderGUID)
                and PartySender(type(senderName) == "string" and senderName ~= "" and senderName or args[1], senderGUID) then
                self.runtime.moments.chat_party_loot, changed = GetTime(), true
            end
            break
        end
    end
    if changed then self:Wake() end
end

local events = CreateFrame("Frame")
events:RegisterEvent("CHAT_MSG_LOOT")
events:SetScript("OnEvent", function(_, _, ...)
    ns:ObserveExtraLootMessage(select(1, ...), select(2, ...), select(12, ...))
end)
