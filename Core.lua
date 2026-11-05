local ADDON, ns = ...

ns.NAME = "Frame Gambit"
ns.VERSION = "1.2.3"
ns.ICON_TEXTURE = "Interface\\AddOns\\FrameGambit\\Assets\\FrameGambitIcon"
-- Increment only when the player-facing Help topics materially change.
-- Missing state adopts the current revision, so a dot never appears merely
-- because this notification system was added or the addon was freshly installed.
ns.HELP_CONTENT_VERSION = 4
BINDING_HEADER_FRAMEGAMBIT = "Frame Gambit"
BINDING_NAME_FRAMEGAMBIT_TOGGLE_CINEMATIC = "Toggle Frame Gambit Cinematic Mode"
BINDING_NAME_FRAMEGAMBIT_TOGGLE_CINEMATIC_CAMERA = "Toggle Cinematic Camera Offset"
local CINEMATIC_BINDING = "FRAMEGAMBIT_TOGGLE_CINEMATIC"
local CINEMATIC_CAMERA_BINDING = "FRAMEGAMBIT_TOGGLE_CINEMATIC_CAMERA"
local LEGACY_CINEMATIC_BINDING = "PRIORITYFADER_TOGGLE_CINEMATIC"
ns.MAX_REACTIONS_PER_TARGET = 32
ns.COLORS = {
    -- Bundled skin tokens. Keep the window shell distinct from the inner
    -- panel so nested dialogs share the same surface layering.
    window = { 0.015, 0.015, 0.015, 0.985 },
    panel = { 0.08, 0.08, 0.08, 0.92 },
    card = { 0.08, 0.08, 0.08, 0.92 },
    cardAlt = { 0.04, 0.04, 0.04, 0.85 },
    raised = { 0.08, 0.08, 0.08, 0.92 },
    border = { 0.20, 0.20, 0.20, 1 },
    faint = { 0.20, 0.20, 0.20, 0.25 },
    blue = { 12 / 255, 210 / 255, 157 / 255, 1 },
    blueSoft = { 0.025, 0.20, 0.15, 1 },
    accent = { 12 / 255, 210 / 255, 157 / 255, 1 },
    teal = { 12 / 255, 210 / 255, 157 / 255, 1 },
    text = { 0.91, 0.93, 0.96, 1 },
    muted = { 0.59, 0.64, 0.71, 1 },
    red = { 0.88, 0.31, 0.34, 1 },
    -- Amber is reserved for warnings and Cinematic's supporting notices;
    -- destructive and invalid states use red.
    amber = { 0.93, 0.66, 0.25, 1 },
    cinematic = { 0.90, 0.52, 0.24, 1 },
}

-- Keep this allow-list in sync with the bundled Frame Gambit selector.  The
-- IDs are intentionally stable so profiles can move between the suite
-- addons without a migration or a dependency on BindCards at runtime.
local VALID_APPEARANCE_THEMES = {
    eui = true, mimezu = true, luminous = true, legacy = true,
    charcoal = true, chalk = true, tungsten = true, editorial = true,
    snes = true, famicom = true, gamecube = true, genesis = true,
    ps1 = true, ps2 = true, xbox = true, xbox360 = true,
    violetmist = true, violetbloom = true,
}

local DEFAULTS = {
    version = 14,
    profile = "Default",
    appearanceTheme = "eui",
    workspaceMode = "panel",
    inputModeProfiles = { enabled = false },
    help = {
        seenVersion = ns.HELP_CONTENT_VERSION,
    },
    tutorial = {
        completed = false,
        lastStep = 1,
    },
    cinematic = {
        letterboxEnabled = false,
        letterboxHeight = 0.04,
        cameraFOV = 90,
        cameraOffsetDefault = false,
    },
    profiles = {
        Default = {
            targets = {},
            groups = {},
            links = {},
            visibilityLinks = {},
            nextReactionID = 1,
            nextGroupID = 1,
        },
    },
}

local DEFAULT_REACTIONS = {
    { id = "mouseover", condition = "mouseover", opacity = 1.00 },
    { id = "combat", condition = "combat", opacity = 1.00 },
}

local CONDITION_INFO = {
    player_health = { label = "Health percentage", category = "character", kind = "state", percentage = true,
        help = "Player health as a percentage. Choose a comparison and threshold. Uses the unrounded percentage. Unavailable health does not trigger this condition." },
    player_mana = { label = "Mana percentage", category = "character", kind = "state", percentage = true,
        help = "Player mana as a percentage, even while another power type is active. Uses the unrounded percentage. Unavailable mana does not trigger this condition." },
    party_health = { label = "Health percentage", category = "party", kind = "state", percentage = true,
        help = "Choose Any for the other party members, or a displayed party-frame slot (1-5), including your own. Checks health percentage; unavailable members and raids do not match." },
    party_mana = { label = "Mana percentage", category = "party", kind = "state", percentage = true,
        help = "Choose Any for the other party members, or a displayed party-frame slot (1-5), including your own. Checks mana percentage; unavailable members and raids do not match." },

    chat_typing = { label = "Typing", category = "chat", kind = "state", pickerOrder = 1,
        help = "While a chat input box has keyboard focus, including an empty message after pressing Enter. Ends when you send, cancel, or move focus away." },
    chat_text = { label = "Chat contains text", category = "chat", kind = "moment", pickerOrder = 2, duration = 10,
        help = "A new message in any configured chat window contains your word or phrase. Case-insensitive, literal matching; each match restarts the duration." },
    mouseover = { label = "Mouseover", category = "system", kind = "state", pickerOrder = 1 },
    linked_parent_hover = { label = "Linked parent hover", category = "legacy", kind = "state", internal = true },
    combat = { label = "In combat", category = "character", kind = "state", pickerOrder = 1 },
    out_of_combat = { label = "Out of combat", category = "character", kind = "state", pickerOrder = 2 },
    movement = { label = "Movement", category = "character", kind = "state", restricted = true, pickerOrder = 3 },
    -- Retained solely for existing saved profiles. New rules use the single
    -- Movement Boolean card: Yes = moving, No = stationary.
    moving = { label = "Moving", category = "character", kind = "state", restricted = true, deprecated = true },
    stationary = { label = "Stationary", category = "character", kind = "state", restricted = true, deprecated = true },
    casting = { label = "Casting", category = "character", kind = "state", pickerOrder = 4 },
    falling = { label = "Falling", category = "character", kind = "state", pickerOrder = 5 },
    shift = { label = "Shift held", category = "system", kind = "state", pickerOrder = 3 },
    control = { label = "Ctrl held", category = "system", kind = "state", pickerOrder = 4 },
    alt = { label = "Alt held", category = "system", kind = "state", pickerOrder = 2 },
    dead = { label = "Dead or ghost", category = "character", kind = "state", pickerOrder = 6 },
    stealth = { label = "Stealthed / invisible", category = "character", kind = "state", pickerOrder = 7 },
    form = { label = "Form", category = "character", kind = "state", pickerOrder = 8 },
    spec = { label = "Talent build", category = "character", kind = "state", pickerOrder = 9 },

    target_any = { label = "Has any target", category = "target", kind = "state" },
    target_hostile = { label = "Has hostile target", category = "target", kind = "state" },
    target_friendly = { label = "Has friendly target", category = "target", kind = "state" },
    target_dead = { label = "Target is dead", category = "target", kind = "state" },
    no_target = { label = "No target", category = "target", kind = "state" },

    mounted = { label = "Mounted", category = "travel", kind = "state" },
    flying = { label = "Flying", category = "travel", kind = "state" },
    dragonriding = { label = "Dragonriding / skyriding", category = "travel", kind = "state", restricted = true },
    swimming = { label = "Swimming", category = "travel", kind = "state" },
    underwater = { label = "Underwater", category = "travel", kind = "state" },
    vehicle = { label = "In vehicle", category = "travel", kind = "state" },
    taxi = { label = "On flight path", category = "travel", kind = "state" },
    pet_battle = { label = "Pet battle", category = "travel", kind = "state" },
    fishing = { label = "Fishing", category = "travel", kind = "state" },

    class_pet = { label = "Class pet active", category = "pets", kind = "state" },
    cosmetic_pet = { label = "Cosmetic companion active", category = "pets", kind = "state" },

    group = { label = "In party", category = "social", kind = "state" },
    raid = { label = "In raid", category = "social", kind = "state" },
    solo = { label = "Solo", category = "social", kind = "state" },
    instance = { label = "In an instance", category = "social", kind = "state" },
    open_world = { label = "In open world", category = "social", kind = "state" },
    dungeon = { label = "In dungeon instance", category = "social", kind = "state" },
    raid_instance = { label = "In raid instance", category = "social", kind = "state" },
    battleground = { label = "In battleground", category = "social", kind = "state" },
    arena = { label = "In arena", category = "social", kind = "state" },
    scenario = { label = "In scenario", category = "social", kind = "state" },
    delve = { label = "In Delve", category = "social", kind = "state" },

    resting = { label = "Resting", category = "social", kind = "state" },
    pvp_flagged = { label = "PvP flagged", category = "social", kind = "state", restricted = true },
    war_mode = { label = "War Mode enabled", category = "social", kind = "state" },
    indoors = { label = "Indoors", category = "social", kind = "state" },
    outdoors = { label = "Outdoors", category = "social", kind = "state" },
    quest_update = { label = "Quest updated", category = "moment", kind = "moment", duration = 3 },
    quest_accepted = { label = "Quest accepted", category = "moment", kind = "moment", duration = 3 },
    quest_turned_in = { label = "Quest turned in", category = "moment", kind = "moment", duration = 3 },
    quest_objective = { label = "Quest objective updated", category = "moment", kind = "moment", duration = 3 },
    loot = { label = "Looted an item", category = "moment", kind = "moment", duration = 4 },
    loot_opened = { label = "Loot window opened", category = "moment", kind = "moment", duration = 5 },
    xp_gained = { label = "XP gained", category = "moment", kind = "moment", duration = 5 },
    chat_private = { label = "New private message", category = "chat", kind = "moment", duration = 10,
        help = "Incoming character or Battle.net whispers. Sent whispers do not trigger this. Each new message restarts the duration." },
    chat_guild = { label = "New guild message", category = "chat", kind = "moment", duration = 10,
        help = "Guild and officer chat messages, including guild achievement announcements. Each new message restarts the duration." },
    chat_group = { label = "New group or raid message", category = "chat", kind = "moment", duration = 10,
        help = "Party, raid and instance chat, including leaders, raid warnings and achievements earned by current group members. Each new message restarts the duration." },
    chat_general = { label = "New General chat message", category = "chat", kind = "moment", duration = 10,
        help = "Messages in the zone's General channel only, excluding Trade, Say and Yell. Each new message restarts the duration." },

    chat_friend_status = { label = "Friend logs on or off", category = "chat", kind = "moment", duration = 10,
        help = "Character friend and Battle.net friend login/logout notifications. Each notification restarts the duration." },

    cinematic_chat_input = { label = "Typing in chat", category = "legacy", kind = "state", internal = true },

    -- Kept only to make existing early saved profiles migrate invisibly.
    target = { label = "Has any target", category = "legacy", kind = "state", internal = true },
    hostile_target = { label = "Has hostile target", category = "legacy", kind = "state", internal = true },
    pvp = { label = "PvP flagged", category = "legacy", kind = "state", internal = true },
}
-- Preserve legacy data, but do not offer or evaluate Retail-only states.
for _, id in ipairs({ "flying", "dragonriding", "vehicle", "pet_battle", "cosmetic_pet", "arena", "scenario", "delve", "war_mode" }) do
    CONDITION_INFO[id].deprecated = true
    CONDITION_INFO[id].unsupported = true
end
ns.CONDITION_INFO = CONDITION_INFO

ns.PERCENTAGE_OPERATORS = {
    { id = "<", label = "Less than" }, { id = "<=", label = "At most" },
    { id = "=", label = "Equal to" }, { id = "~=", label = "Not equal to" },
    { id = ">=", label = "At least" }, { id = ">", label = "More than" },
}
local PERCENTAGE_COMPARISONS = {
    ["<"] = function(a, b) return a < b end, ["<="] = function(a, b) return a <= b end,
    ["="] = function(a, b) return a == b end, ["~="] = function(a, b) return a ~= b end,
    [">="] = function(a, b) return a >= b end, [">"] = function(a, b) return a > b end,
}
function ns:IsPercentageCondition(condition)
    return CONDITION_INFO[condition] and CONDITION_INFO[condition].percentage == true
end
function ns:GetPercentageContextValue(condition, reaction)
    local member = reaction and reaction.partyMember
    if (condition == "party_health" or condition == "party_mana") and member ~= nil then
        local members = self.runtime.context.partyMemberPercentages
        return members and members[condition] and members[condition][member]
    end
    return self.runtime.context[condition]
end

function ns:NormalizePercentageReaction(reaction)
    local member = tonumber(reaction.partyMember)
    reaction.partyMember = (reaction.condition == "party_health" or reaction.condition == "party_mana")
        and member and member >= 1 and member <= 5 and member == math.floor(member) and member or nil
    if not self:IsPercentageCondition(reaction.condition) then
        reaction.percentageOperator, reaction.percentageThreshold = nil, nil
        return
    end
    if not PERCENTAGE_COMPARISONS[reaction.percentageOperator] then reaction.percentageOperator = "<" end
    local value = tonumber(reaction.percentageThreshold)
    if not value or value ~= value then value = 50 end
    reaction.percentageThreshold = math.max(0, math.min(100, value))
end


function ns:NormalizeChatText(value)
    if type(value) ~= "string" or (issecretvalue and issecretvalue(value)) then return "" end
    return value:gsub("[%c]", " "):sub(1, 120):match("^%s*(.-)%s*$")
end

-- Parameterized Boolean cards use the same repeatable row and wire record.
function ns:GetBooleanConditionField(condition)
    if condition == "movement" then return "movementExpected" end
    local info = CONDITION_INFO[condition]
    return info and info.booleanField
end

-- AND requirements should describe a state that can actually happen. Keep
-- this deliberately conservative: only encode pairs Retail's own state APIs
-- guarantee are mutually exclusive, while preserving valid combinations such
-- as Flying + Dragonriding and Swimming + Underwater.
local EXCLUSIVE_REQUIREMENT_GROUPS = {
    { "combat", "out_of_combat" },
    { "target_hostile", "target_friendly" },
    { "group", "raid", "solo" },
    { "open_world", "dungeon", "raid_instance", "battleground", "arena", "scenario", "delve" },
    { "vehicle", "taxi", "pet_battle", "fishing" },
    -- Specific quest moments can share a brief timestamp window, but an AND
    -- of two different quest events is not a useful player-facing filter.
    -- Use separate ordered reactions when they need different responses.
    { "quest_update", "quest_accepted", "quest_turned_in", "quest_objective" },
    { "indoors", "outdoors" },
}
local EXCLUSIVE_REQUIREMENT_PAIRS = {
    { "instance", "open_world" },
    { "no_target", "target_any" }, { "no_target", "target_hostile" },
    { "no_target", "target_friendly" }, { "no_target", "target_dead" },
    { "pet_battle", "mounted" }, { "pet_battle", "flying" },
    { "pet_battle", "dragonriding" }, { "pet_battle", "swimming" },
    { "pet_battle", "underwater" },
    { "fishing", "flying" }, { "fishing", "dragonriding" },
    { "fishing", "swimming" }, { "fishing", "underwater" },
    { "taxi", "swimming" }, { "taxi", "underwater" },
}
local REQUIREMENT_CONFLICTS = {}
local function MarkRequirementConflict(first, second)
    REQUIREMENT_CONFLICTS[first] = REQUIREMENT_CONFLICTS[first] or {}
    REQUIREMENT_CONFLICTS[second] = REQUIREMENT_CONFLICTS[second] or {}
    REQUIREMENT_CONFLICTS[first][second], REQUIREMENT_CONFLICTS[second][first] = true, true
end
for _, group in ipairs(EXCLUSIVE_REQUIREMENT_GROUPS) do
    for first = 1, #group - 1 do
        for second = first + 1, #group do MarkRequirementConflict(group[first], group[second]) end
    end
end
for _, pair in ipairs(EXCLUSIVE_REQUIREMENT_PAIRS) do MarkRequirementConflict(pair[1], pair[2]) end

function ns:GetRequirementConflict(reaction, candidate, skipExisting)
    if type(reaction) ~= "table" or type(candidate) ~= "string" then return nil end
    local function Conflicts(condition)
        local candidateInfo, existingInfo = CONDITION_INFO[candidate], CONDITION_INFO[condition]
        if candidateInfo and candidateInfo.requirementCondition and existingInfo then
            local existingCondition = existingInfo.requirementCondition or condition
            local expected = existingInfo.requirementExpected
            if existingInfo.gamepad then expected = reaction.gamepadExpected ~= false end
            if existingCondition == candidateInfo.requirementCondition then
                return expected ~= candidateInfo.requirementExpected
            end
        end
        return condition ~= candidate and REQUIREMENT_CONFLICTS[candidate] and REQUIREMENT_CONFLICTS[candidate][condition]
    end
    if Conflicts(reaction.condition) then return reaction.condition end
    for _, condition in ipairs(reaction.requirements or {}) do
        if condition ~= skipExisting and Conflicts(condition) then return condition end
    end
    return nil
end

-- Form entries deliberately describe only gameplay forms that WoW exposes in
-- the player's shapeshift bar.  A reaction is skipped when its form is not
-- available to the current class/spec, which makes one profile safe to share
-- across specs without a negative Form row accidentally matching everywhere.
local FORM_OPTIONS = {
    { id = "druid_bear", label = "Bear Form", class = "DRUID", spellID = 5487, alternateSpellID = 9634 },
    { id = "druid_cat", label = "Cat Form", class = "DRUID", spellID = 768 },
    { id = "druid_travel", label = "Travel Form", class = "DRUID", spellID = 783 },
    { id = "druid_moonkin", label = "Moonkin Form", class = "DRUID", spellID = 24858 },
    { id = "priest_shadow", label = "Shadowform", class = "PRIEST", spellID = 15473 },
    { id = "shaman_ghost_wolf", label = "Ghost Wolf", class = "SHAMAN", spellID = 2645 },
    { id = "druid_aquatic", label = "Aquatic Form", class = "DRUID", spellID = 1066 },
    { id = "warrior_battle", label = "Battle Stance", class = "WARRIOR", spellID = 2457 },
    { id = "warrior_defensive", label = "Defensive Stance", class = "WARRIOR", spellID = 71 },
    { id = "warrior_berserker", label = "Berserker Stance", class = "WARRIOR", spellID = 2458 },
}
local FORM_BY_ID = {}
for _, option in ipairs(FORM_OPTIONS) do FORM_BY_ID[option.id] = option end
ns.FORM_OPTIONS, ns.FORM_BY_ID = FORM_OPTIONS, FORM_BY_ID

-- Stable addon-owned IDs cannot reinterpret a saved Retail specialization.
local SPEC_OPTIONS = {}
for _, class in ipairs({
    { "WARRIOR", "Warrior", 1 }, { "PALADIN", "Paladin", 2 },
    { "HUNTER", "Hunter", 3 }, { "ROGUE", "Rogue", 4 },
    { "PRIEST", "Priest", 5 }, { "SHAMAN", "Shaman", 7 },
    { "MAGE", "Mage", 8 }, { "WARLOCK", "Warlock", 9 }, { "DRUID", "Druid", 11 },
}) do
    for group = 1, 2 do
        SPEC_OPTIONS[#SPEC_OPTIONS + 1] = {
            class = class[1], classLabel = class[2], id = 1600100 + class[3] * 10 + group,
            label = group == 1 and "Primary" or "Secondary", group = group,
        }
    end
end
local SPEC_BY_ID, SPECS_BY_CLASS, CLASS_OPTIONS = {}, {}, {}
for _, option in ipairs(SPEC_OPTIONS) do
    SPEC_BY_ID[option.id] = option
    SPECS_BY_CLASS[option.class] = SPECS_BY_CLASS[option.class] or {}
    SPECS_BY_CLASS[option.class][#SPECS_BY_CLASS[option.class] + 1] = option
end
for classID, specs in pairs(SPECS_BY_CLASS) do CLASS_OPTIONS[#CLASS_OPTIONS + 1] = { id = classID, label = specs[1].classLabel } end
table.sort(CLASS_OPTIONS, function(a, b) return a.label < b.label end)
ns.SPEC_OPTIONS, ns.SPEC_BY_ID, ns.SPECS_BY_CLASS, ns.CLASS_OPTIONS = SPEC_OPTIONS, SPEC_BY_ID, SPECS_BY_CLASS, CLASS_OPTIONS
ns.CONDITION_CATEGORY_ORDER = {
    { id = "system", label = "System" },
    { id = "character", label = "Player" },
    { id = "party", label = "Any party member" },
    { id = "target", label = "Target" },
    { id = "travel", label = "Travel" },
    { id = "pets", label = "Pets" },
    { id = "social", label = "Group & instances" },
    { id = "moment", label = "Events" },
    { id = "chat", label = "CHAT" },
}

local EVENT_TO_MOMENT = {
    QUEST_ACCEPTED = { "quest_update", "quest_accepted" },
    QUEST_TURNED_IN = { "quest_update", "quest_turned_in" },
    QUEST_WATCH_UPDATE = { "quest_update", "quest_objective" },
    QUEST_LOG_UPDATE = "quest_update",
    LOOT_OPENED = "loot_opened",
    -- Incoming whispers only; *_INFORM events are the player's sent whispers.
    CHAT_MSG_WHISPER = "chat_private",
    CHAT_MSG_BN_WHISPER = "chat_private",
    CHAT_MSG_GUILD = "chat_guild",
    CHAT_MSG_GUILD_ACHIEVEMENT = "chat_guild",
    CHAT_MSG_OFFICER = "chat_guild",
    CHAT_MSG_PARTY = "chat_group",
    CHAT_MSG_PARTY_LEADER = "chat_group",
    CHAT_MSG_RAID = "chat_group",
    CHAT_MSG_RAID_LEADER = "chat_group",
    CHAT_MSG_RAID_WARNING = "chat_group",
    CHAT_MSG_INSTANCE_CHAT = "chat_group",
    CHAT_MSG_INSTANCE_CHAT_LEADER = "chat_group",
}

local runtime = {
    baseAlpha = setmetatable({}, { __mode = "k" }),
    currentAlpha = setmetatable({}, { __mode = "k" }),
    -- Native frames can quantize alpha. Ownership comparisons use the readback;
    -- currentAlpha retains the requested fade progression.
    managedAlphaReadback = setmetatable({}, { __mode = "k" }),
    protectedAlpha = setmetatable({}, { __mode = "k" }),
    frameByID = {},
    hovered = {},
    active = {},
    moments = {},
    context = {},
    neededConditions = {},
    hoverNeeded = {},
    fadeOutStarted = {},
    revealGoal = {},
    transitions = {},
    pendingRestore = setmetatable({}, { __mode = "k" }),
    pendingRelease = setmetatable({}, { __mode = "k" }),
    normalized = setmetatable({}, { __mode = "k" }),
    managedIDByFrame = setmetatable({}, { __mode = "k" }),
    -- Frames Frame Gambit has already taken over this session. The first
    -- capture of a frame applies its rule at once; there is no earlier
    -- appearance to fade from (and no reason to wait before fading out).
    everCaptured = setmetatable({}, { __mode = "k" }),
    -- Targets holding the host's opacity until the world has drawn (the frame
    -- containing the minimap, see FrameContainsMinimap).
    captureHold = {},
    -- Host fade animations (for example Blizzard's status bar fade-in) change
    -- alpha without SetAlpha, so the SetAlpha hook cannot see them.
    hostAnimating = setmetatable({}, { __mode = "k" }),
    hostAnimationHooks = setmetatable({}, { __mode = "k" }),
    managedAlphaHooks = setmetatable({}, { __mode = "k" }),
    managedAlphaAuditAt = setmetatable({}, { __mode = "k" }),
    managedAlphaGuard = setmetatable({}, { __mode = "k" }),
    immediateApply = {},
    cinematicBlackout = setmetatable({}, { __mode = "k" }),
    cinematicBlackoutHooks = setmetatable({}, { __mode = "k" }),
    cinematicAlphaGuard = setmetatable({}, { __mode = "k" }),
    cinematicExemptFrames = setmetatable({}, { __mode = "k" }),
    cinematicOpenWindows = setmetatable({}, { __mode = "k" }),
    cinematicPanelHooks = setmetatable({}, { __mode = "k" }),
    cinematicRootScanAt = 0,
    cinematicAuditAt = 0,
    cinematicRevealActive = nil,
    cinematicRescanToken = 0,
    -- Relationship lookups are on the shared evaluator path.  Keep a small
    -- reverse index so linked/visibility ancestry does not rescan every
    -- profile relationship for every target on every tick.
    relationshipCache = {
        valid = false,
        profile = nil,
        links = nil,
        visibilityLinks = nil,
        groups = nil,
        linkParents = {},
        visibilityParents = {},
        hoverMembers = {},
    },
    lastTick = 0,
    lastMouseTick = 0,
    playerCasting = false,
}
ns.runtime = runtime

-- Declared here so the evaluator can deliberately detach its shared OnUpdate
-- below, while the actual event driver remains created near the event list.
-- Keeping one driver (rather than per-target frame handlers) is important for
-- both performance and safe late-provider wakeups.
local driver

local SafeFrameAlpha
local QueuePendingRestore

local function IsSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

local function SafeBoolean(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, value = pcall(func, ...)
    if not ok or IsSecret(value) then return nil end
    return value and true or false
end

-- Match current roster GUIDs so nearby strangers do not reveal group chat.
local function IsGroupAchievementSender(guid)
    if IsSecret(guid) or type(guid) ~= "string" or guid == ""
        or type(UnitGUID) ~= "function" then return false end
    local function Matches(unit)
        local ok, memberGUID = pcall(UnitGUID, unit)
        return ok and not IsSecret(memberGUID) and type(memberGUID) == "string"
            and memberGUID == guid
    end
    for index = 1, 40 do if Matches("raid" .. index) then return true end end
    for index = 1, 4 do if Matches("party" .. index) then return true end end
    return SafeBoolean(IsInGroup) == true and Matches("player")
end

local function SafeValue(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, value = pcall(func, ...)
    if not ok or IsSecret(value) or value == nil then return nil end
    return value
end

local function MatchesFriendNotification(message, template)
    if IsSecret(message) or IsSecret(template) or type(message) ~= "string"
        or type(template) ~= "string" or template == "" then return false end
    -- Use the client's localized format, including its player-link markup.
    -- Escape punctuation and replace only string format arguments, never names.
    local parts, start = { "^" }, 1
    while true do
        local first, last = template:find("%%[%d%$]*s", start)
        local literal = template:sub(start, first and first - 1 or #template)
        parts[#parts + 1] = literal:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
        if not first then break end
        parts[#parts + 1] = ".+"
        start = last + 1
    end
    parts[#parts + 1] = "$"
    return message:match(table.concat(parts)) ~= nil
end

local function CallFrameIsShown(frame)
    return frame:IsShown()
end

local function CallFrameGetRect(frame)
    return frame:GetRect()
end

local function CallFrameGetEffectiveScale(frame)
    return frame:GetEffectiveScale()
end

local function CallFrameGetAlpha(frame)
    return frame:GetAlpha()
end

local function CallFrameSetAlpha(frame, alpha)
    frame:SetAlpha(alpha)
end

local function SafeSetFrameAlpha(frame, alpha)
    if type(alpha) == "table" and alpha.opaqueAlpha then alpha = alpha.value end
    return pcall(CallFrameSetAlpha, frame, alpha)
end

local function ClearTable(values)
    for key in pairs(values) do values[key] = nil end
    return values
end

local function IsLocalLootMessage(senderName, senderGUID)
    if IsSecret(senderGUID) then return false end
    if senderGUID ~= nil then
        local playerGUID = SafeValue(UnitGUID, "player")
        return playerGUID ~= nil and senderGUID == playerGUID
    end
    -- Older/nonstandard payloads may omit GUID.  Use only an exact, guarded
    -- local-name fallback; realm-normalization or chat-message parsing would
    -- risk claiming another player's loot.
    if IsSecret(senderName) or senderName == nil then return false end
    local playerName = SafeValue(UnitName, "player")
    return playerName ~= nil and senderName == playerName
end

local function CopyDefaults(defaults, value)
    if type(defaults) ~= "table" then return value == nil and defaults or value end
    local result = type(value) == "table" and value or {}
    for k, v in pairs(defaults) do
        if result[k] == nil then
            result[k] = CopyDefaults(v)
        elseif type(v) == "table" then
            result[k] = CopyDefaults(v, result[k])
        end
    end
    return result
end

local function DeepCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, child in pairs(value) do copy[DeepCopy(key, seen)] = DeepCopy(child, seen) end
    return copy
end

function ns:Profile()
    local db = FrameGambitDB
    db.profiles = db.profiles or {}
    db.profile = db.profile or "Default"
    db.profiles[db.profile] = db.profiles[db.profile] or { targets = {}, groups = {}, links = {}, visibilityLinks = {}, nextReactionID = 1, nextGroupID = 1 }
    local profile = db.profiles[db.profile]
    profile.targets = type(profile.targets) == "table" and profile.targets or {}
    profile.groups = type(profile.groups) == "table" and profile.groups or {}
    profile.links = type(profile.links) == "table" and profile.links or {}
    profile.visibilityLinks = type(profile.visibilityLinks) == "table" and profile.visibilityLinks or {}
    profile.nextReactionID = tonumber(profile.nextReactionID) or 1
    profile.nextGroupID = tonumber(profile.nextGroupID) or 1
    return profile
end

local function InvalidateRelationshipCache()
    runtime.relationshipCache.valid = false
end

local function GetRelationshipIndices(owner)
    local profile = owner:Profile()
    local links = profile.links
    local visibilityLinks = profile.visibilityLinks
    local groups = profile.groups
    local cache = runtime.relationshipCache
    if cache.valid and cache.profile == profile and cache.links == links
        and cache.visibilityLinks == visibilityLinks and cache.groups == groups then
        return cache
    end

    local linkParents, visibilityParents, hoverMembers = {}, {}, {}
    for parentID, children in pairs(links or {}) do
        if type(children) == "table" then
            for childID, enabled in pairs(children) do
                -- Link relationships historically treated any truthy value as
                -- enabled, so retain that compatibility while indexing.
                if enabled then
                    local parents = linkParents[childID]
                    if not parents then parents = {}; linkParents[childID] = parents end
                    parents[#parents + 1] = parentID
                end
            end
        end
    end
    for parentID, children in pairs(visibilityLinks or {}) do
        if type(children) == "table" then
            for childID, enabled in pairs(children) do
                if enabled == true and visibilityParents[childID] == nil then
                    visibilityParents[childID] = parentID
                end
            end
        end
    end
    for _, group in pairs(groups or {}) do
        if type(group) == "table" and type(group.members) == "table" then
            local members = {}
            for memberID, enabled in pairs(group.members) do
                if enabled then members[#members + 1] = memberID end
            end
            for _, memberID in ipairs(members) do
                local peers = hoverMembers[memberID]
                if not peers then peers = {}; hoverMembers[memberID] = peers end
                for _, peerID in ipairs(members) do peers[#peers + 1] = peerID end
            end
        end
    end

    cache.profile = profile
    cache.links = links
    cache.visibilityLinks = visibilityLinks
    cache.groups = groups
    cache.linkParents = linkParents
    cache.visibilityParents = visibilityParents
    cache.hoverMembers = hoverMembers
    cache.valid = true
    return cache
end

function ns:NextReactionID()
    local profile = self:Profile()
    local id = profile.nextReactionID
    profile.nextReactionID = id + 1
    return id
end

function ns:NextGroupID()
    local profile = self:Profile()
    local id = profile.nextGroupID
    profile.nextGroupID = id + 1
    return id
end

function ns:MigrateDatabase()
    local db = FrameGambitDB
    local oldVersion = tonumber(db.version) or 1
    local aliases = { target = "target_any", hostile_target = "target_hostile", pvp = "pvp_flagged" }
    local function RemoveProfileTargets(profile, matches)
        if type(profile) ~= "table" then return end
        profile.targets = type(profile.targets) == "table" and profile.targets or {}
        profile.groups = type(profile.groups) == "table" and profile.groups or {}
        profile.links = type(profile.links) == "table" and profile.links or {}
        profile.visibilityLinks = type(profile.visibilityLinks) == "table" and profile.visibilityLinks or {}
        local retired = {}
        for id in pairs(profile.targets) do if matches(id) then retired[#retired + 1] = id end end
        for _, id in ipairs(retired) do
            profile.targets[id] = nil
            for groupID, group in pairs(profile.groups) do
                if type(group) ~= "table" or type(group.members) ~= "table" then
                    profile.groups[groupID] = nil
                else
                    group.members[id] = nil
                    local count = 0
                    for memberID, enabled in pairs(group.members) do
                        if enabled == true and type(memberID) == "string" then count = count + 1 else group.members[memberID] = nil end
                    end
                    if count < 2 then profile.groups[groupID] = nil end
                end
            end
            profile.links[id] = nil
            for parentID, children in pairs(profile.links) do
                if type(children) ~= "table" then
                    profile.links[parentID] = nil
                else
                    children[id] = nil
                    if not next(children) then profile.links[parentID] = nil end
                end
            end
            profile.visibilityLinks[id] = nil
            for parentID, children in pairs(profile.visibilityLinks) do
                if type(children) ~= "table" then
                    profile.visibilityLinks[parentID] = nil
                else
                    children[id] = nil
                    if not next(children) then profile.visibilityLinks[parentID] = nil end
                end
            end
        end
    end
    local function RemapProfileTarget(profile, fromID, toID)
        if type(profile) ~= "table" or type(fromID) ~= "string" or fromID == toID then return end
        profile.targets = type(profile.targets) == "table" and profile.targets or {}
        profile.groups = type(profile.groups) == "table" and profile.groups or {}
        profile.links = type(profile.links) == "table" and profile.links or {}
        profile.visibilityLinks = type(profile.visibilityLinks) == "table" and profile.visibilityLinks or {}
        if profile.targets[fromID] ~= nil then
            if profile.targets[toID] == nil then profile.targets[toID] = profile.targets[fromID] end
            profile.targets[fromID] = nil
        end
        for groupID, group in pairs(profile.groups) do
            if type(group) ~= "table" or type(group.members) ~= "table" then
                profile.groups[groupID] = nil
            else
                if group.members[fromID] == true then
                    group.members[fromID] = nil
                    group.members[toID] = true
                end
                local count = 0
                for memberID, enabled in pairs(group.members) do
                    if enabled == true and type(memberID) == "string" then count = count + 1 else group.members[memberID] = nil end
                end
                if count < 2 then profile.groups[groupID] = nil end
            end
        end
        local oldChildren = profile.links[fromID]
        if type(oldChildren) == "table" then
            local children = type(profile.links[toID]) == "table" and profile.links[toID] or {}
            for childID, enabled in pairs(oldChildren) do
                local mapped = childID == fromID and toID or childID
                if enabled == true and mapped ~= toID then children[mapped] = true end
            end
            profile.links[toID] = next(children) and children or nil
        end
        profile.links[fromID] = nil
        for parentID, children in pairs(profile.links) do
            if type(children) ~= "table" then
                profile.links[parentID] = nil
            else
                if children[fromID] == true then
                    children[fromID] = nil
                    if parentID ~= toID then children[toID] = true end
                end
                children[parentID] = nil
                if not next(children) then profile.links[parentID] = nil end
            end
        end
        local inherited = profile.visibilityLinks[fromID]
        if type(inherited) == "table" then
            local children = type(profile.visibilityLinks[toID]) == "table" and profile.visibilityLinks[toID] or {}
            for childID, enabled in pairs(inherited) do
                local mapped = childID == fromID and toID or childID
                if enabled == true and mapped ~= toID then children[mapped] = true end
            end
            profile.visibilityLinks[toID] = next(children) and children or nil
        end
        profile.visibilityLinks[fromID] = nil
        for parentID, children in pairs(profile.visibilityLinks) do
            if type(children) ~= "table" then
                profile.visibilityLinks[parentID] = nil
            else
                if children[fromID] == true then
                    children[fromID] = nil
                    if parentID ~= toID then children[toID] = true end
                end
                children[parentID] = nil
                if not next(children) then profile.visibilityLinks[parentID] = nil end
            end
        end
    end
    if oldVersion < 2 then
        for _, profile in pairs(db.profiles or {}) do
            profile.targets = type(profile.targets) == "table" and profile.targets or {}
            profile.groups = type(profile.groups) == "table" and profile.groups or {}
            profile.links = type(profile.links) == "table" and profile.links or {}
            local nextID, nextGroupID = tonumber(profile.nextReactionID) or 1, tonumber(profile.nextGroupID) or 1
            for _, settings in pairs(profile.targets) do
                local reactions = type(settings) == "table" and settings.reactions or {}
                if type(settings) == "table" then settings.reactions = reactions end
                for _, reaction in ipairs(reactions) do
                    if type(reaction) == "table" then
                        reaction.condition = aliases[reaction.condition] or reaction.condition
                        if type(reaction.id) ~= "number" then reaction.id, nextID = nextID, nextID + 1 end
                    end
                end
            end
            for key, group in pairs(profile.groups) do
                if type(group) ~= "table" or type(group.members) ~= "table" then
                    profile.groups[key] = nil
                else
                    local count = 0
                    for memberID, enabled in pairs(group.members) do
                        if enabled ~= true or type(memberID) ~= "string" then group.members[memberID] = nil else count = count + 1 end
                    end
                    if count < 2 then profile.groups[key] = nil end
                end
                nextGroupID = nextGroupID + 1
            end
            profile.nextReactionID, profile.nextGroupID = nextID, nextGroupID
        end
    end
    if oldVersion < 3 then
        for _, profile in pairs(db.profiles or {}) do
            for _, settings in pairs(type(profile.targets) == "table" and profile.targets or {}) do
                for _, reaction in ipairs(type(settings) == "table" and settings.reactions or {}) do
                    if type(reaction) == "table" then
                        local requirements, seen = {}, {}
                        for _, condition in ipairs(type(reaction.requirements) == "table" and reaction.requirements or {}) do
                            if type(condition) == "string" and condition ~= reaction.condition and not seen[condition] then
                                requirements[#requirements + 1], seen[condition] = condition, true
                            end
                        end
                        reaction.requirements = requirements
                    end
                end
            end
        end
    end
    if oldVersion < 4 then
        -- This v1.1 target was an invisible 1x1 Resource Bars anchor.  It
        -- cannot provide a useful hover region and would compound child alpha.
        for _, profile in pairs(db.profiles or {}) do
            if type(profile.targets) == "table" then profile.targets.eui_resources = nil end
            if type(profile.groups) == "table" then
                for key, group in pairs(profile.groups) do
                    if type(group) ~= "table" or type(group.members) ~= "table" then
                        profile.groups[key] = nil
                    else
                        group.members.eui_resources = nil
                        local count = 0
                        for memberID, enabled in pairs(group.members) do
                            if enabled == true and type(memberID) == "string" then count = count + 1 else group.members[memberID] = nil end
                        end
                        if count < 2 then profile.groups[key] = nil end
                    end
                end
            end
            if type(profile.links) == "table" then
                profile.links.eui_resources = nil
                for parentID, children in pairs(profile.links) do
                    if type(children) ~= "table" then
                        profile.links[parentID] = nil
                    else
                        children.eui_resources = nil
                        if not next(children) then profile.links[parentID] = nil end
                    end
                end
            end
        end
    end
    if oldVersion < 5 then
        db.cinematic = type(db.cinematic) == "table" and db.cinematic or {}
    end
    if oldVersion < 6 then
        -- v1.9 temporarily exposed CDM adapters through a source-level EUI
        -- bridge. Remove every saved reference now that CDM is deliberately
        -- outside Priority Fader's standalone compatibility contract.
        for _, profile in pairs(db.profiles or {}) do
            local retired = {}
            for id in pairs(type(profile.targets) == "table" and profile.targets or {}) do
                if type(id) == "string" and id:match("^eui_cdm_") then retired[#retired + 1] = id end
            end
            for _, id in ipairs(retired) do
                profile.targets[id] = nil
                for groupID, group in pairs(type(profile.groups) == "table" and profile.groups or {}) do
                    if type(group) ~= "table" or type(group.members) ~= "table" then
                        profile.groups[groupID] = nil
                    else
                        group.members[id] = nil
                        local count = 0
                        for memberID, enabled in pairs(group.members) do
                            if enabled == true and type(memberID) == "string" then count = count + 1 else group.members[memberID] = nil end
                        end
                        if count < 2 then profile.groups[groupID] = nil end
                    end
                end
                if type(profile.links) == "table" then
                    profile.links[id] = nil
                    for parentID, children in pairs(profile.links) do
                        if type(children) ~= "table" then
                            profile.links[parentID] = nil
                        else
                            children[id] = nil
                            if not next(children) then profile.links[parentID] = nil end
                        end
                    end
                end
            end
        end
    end
    if oldVersion < 7 then
        db.customTargets = type(db.customTargets) == "table" and db.customTargets or {}
        -- Anonymous frame-picker targets intentionally last only for the UI
        -- session in which they were chosen. They cannot resolve safely after
        -- reload, so discard their saved rule graph instead of leaving ghosts.
        for _, profile in pairs(db.profiles or {}) do
            local retired = {}
            for id in pairs(type(profile.targets) == "table" and profile.targets or {}) do
                if type(id) == "string" and id:match("^session_frame_") then retired[#retired + 1] = id end
            end
            for _, id in ipairs(retired) do
                profile.targets[id] = nil
                for groupID, group in pairs(type(profile.groups) == "table" and profile.groups or {}) do
                    if type(group) ~= "table" or type(group.members) ~= "table" then
                        profile.groups[groupID] = nil
                    else
                        group.members[id] = nil
                        local count = 0
                        for memberID, enabled in pairs(group.members) do
                            if enabled == true and type(memberID) == "string" then count = count + 1 else group.members[memberID] = nil end
                        end
                        if count < 2 then profile.groups[groupID] = nil end
                    end
                end
                if type(profile.links) == "table" then
                    profile.links[id] = nil
                    for parentID, children in pairs(profile.links) do
                        if type(children) ~= "table" then profile.links[parentID] = nil
                        else children[id] = nil; if not next(children) then profile.links[parentID] = nil end end
                    end
                end
            end
        end
    end
    if oldVersion < 8 then
        -- Cinematic Mode is a screen-clearing scene. Chat, objectives, and the
        -- action bar now fall under its blackout layer rather than being quiet
        -- default scene components. Keep only the requested essentials.
        for _, profile in pairs(db.profiles or {}) do
            if type(profile) == "table" and profile.cinematicSystem then
                RemoveProfileTargets(profile, function(id)
                    return id == "chat" or id == "objectives" or id == "eui_main"
                end)
            end
        end
    end
    if oldVersion < 9 then
        -- Replace the experimental per-EUI-bar bridge with stable Blizzard
        -- viewer targets. Existing picker-created viewer rules retain their
        -- settings and graph relationships under the canonical target IDs.
        local viewerTargets = {
            EssentialCooldownViewer = "cdm_cooldowns",
            UtilityCooldownViewer = "cdm_utility",
            BuffIconCooldownViewer = "cdm_buffs",
        }
        db.customTargets = type(db.customTargets) == "table" and db.customTargets or {}
        local remapped = {}
        for customID, definition in pairs(db.customTargets) do
            local toID = type(definition) == "table" and viewerTargets[definition.name] or nil
            if type(customID) == "string" and toID then remapped[#remapped + 1] = { customID, toID } end
        end
        for _, mapping in ipairs(remapped) do
            for _, profile in pairs(db.profiles or {}) do RemapProfileTarget(profile, mapping[1], mapping[2]) end
            db.customTargets[mapping[1]] = nil
        end
        for _, profile in pairs(db.profiles or {}) do
            RemoveProfileTargets(profile, function(id)
                return type(id) == "string" and id:match("^experimental_cdm_") ~= nil
            end)
        end
    end
    if oldVersion < 10 then
        for _, profile in pairs(db.profiles or {}) do
            if type(profile) == "table" then profile.visibilityLinks = {} end
        end
    end
    if oldVersion < 11 then
        db.tutorial = type(db.tutorial) == "table" and db.tutorial or {}
    end
    if oldVersion < 13 then
        -- Promote stable Blizzard HUD frames that players previously had to
        -- discover by hand. Preserve their rules and graph relationships under
        -- one portable semantic id, then remove the redundant picker entry.
        local builtinTargets = {}
        for _, target in ipairs(ns.Targets or {}) do
            if type(target) == "table" and type(target.id) == "string" then
                for _, name in ipairs(type(target.names) == "table" and target.names or {}) do
                    if type(name) == "string" then builtinTargets[name] = target.id end
                end
            end
        end
        db.customTargets = type(db.customTargets) == "table" and db.customTargets or {}
        local remapped = {}
        for customID, definition in pairs(db.customTargets) do
            local toID = type(definition) == "table" and builtinTargets[definition.name] or nil
            if type(customID) == "string" and toID then remapped[#remapped + 1] = { customID, toID } end
        end
        table.sort(remapped, function(a, b) return a[1] < b[1] end)
        for _, mapping in ipairs(remapped) do
            for _, profile in pairs(db.profiles or {}) do RemapProfileTarget(profile, mapping[1], mapping[2]) end
            db.customTargets[mapping[1]] = nil
        end
    end
    if oldVersion < 14 then
        if not VALID_APPEARANCE_THEMES[db.appearanceTheme] then db.appearanceTheme = "eui" end
    end
    -- Session-only roots cannot survive a reload. Do this every login rather
    -- than only during the schema migration that introduced them.
    for _, profile in pairs(db.profiles or {}) do
        RemoveProfileTargets(profile, function(id) return type(id) == "string" and id:match("^session_frame_") end)
    end
    if not VALID_APPEARANCE_THEMES[db.appearanceTheme] then db.appearanceTheme = "eui" end
    db.version = 14
    db.workspaceMode = "panel" -- Retire saved Binder layouts.
    -- Migrations normalize relationship tables in place. Their identities do
    -- not change, so invalidate the evaluator index explicitly in case a
    -- startup hook inspected it before migration completed.
    InvalidateRelationshipCache()
end

function ns:GetTutorialState()
    FrameGambitDB = type(FrameGambitDB) == "table" and FrameGambitDB or {}
    FrameGambitDB.tutorial = type(FrameGambitDB.tutorial) == "table" and FrameGambitDB.tutorial or {}
    local state = FrameGambitDB.tutorial
    state.completed = state.completed == true
    state.lastStep = math.max(1, math.min(9, math.floor(tonumber(state.lastStep) or 1)))
    return state.lastStep, state.completed
end

function ns:SetTutorialState(step, completed)
    self:GetTutorialState()
    local state = FrameGambitDB.tutorial
    if step ~= nil then state.lastStep = math.max(1, math.min(9, math.floor(tonumber(step) or 1))) end
    if completed ~= nil then state.completed = completed == true end
    return state
end

function ns:GetAppearanceTheme()
    FrameGambitDB = type(FrameGambitDB) == "table" and FrameGambitDB or {}
    if not VALID_APPEARANCE_THEMES[FrameGambitDB.appearanceTheme] then
        FrameGambitDB.appearanceTheme = "eui"
    end
    return FrameGambitDB.appearanceTheme
end

function ns:SetAppearanceTheme(themeID)
    if not VALID_APPEARANCE_THEMES[themeID] then return false end
    FrameGambitDB = type(FrameGambitDB) == "table" and FrameGambitDB or {}
    FrameGambitDB.appearanceTheme = themeID
    if self.ApplyAppearanceTheme then self:ApplyAppearanceTheme(themeID) end
    return true
end

function ns:HasUnreadHelp()
    FrameGambitDB = type(FrameGambitDB) == "table" and FrameGambitDB or {}
    FrameGambitDB.help = type(FrameGambitDB.help) == "table" and FrameGambitDB.help or {}
    local current = math.max(1, math.floor(tonumber(self.HELP_CONTENT_VERSION) or 1))
    local seen = tonumber(FrameGambitDB.help.seenVersion)
    if not seen then
        seen = current
        FrameGambitDB.help.seenVersion = seen
    else
        seen = math.max(0, math.floor(seen))
    end
    return seen < current
end

function ns:MarkHelpRead()
    self:HasUnreadHelp()
    local current = math.max(1, math.floor(tonumber(self.HELP_CONTENT_VERSION) or 1))
    local seen = math.max(0, math.floor(tonumber(FrameGambitDB.help.seenVersion) or 0))
    FrameGambitDB.help.seenVersion = math.max(seen, current)
    local dot = self.Options and self.Options.helpButton and self.Options.helpButton.helpDot
    if dot then dot:Hide() end
end

local CINEMATIC_PROFILE_LABEL = "Cinematic Mode"
local CINEMATIC_TEMPLATE_VERSION = 8
local CINEMATIC_COMPONENTS = {
    { id = "eui_player", label = "Player frame", default = "context_hover", rest = 0 },
    { id = "eui_target", label = "Target frame", default = "context_hover", rest = 0 },
    { id = "eui_castbar", label = "Cast bar", default = "casting", rest = 0 },
    { id = "eui_resourcebars", label = "Resource bars", default = "combat", rest = 0 },
    { id = "minimap", label = "Minimap", default = "hover", rest = 0 },
    { id = "chat", label = "Chat", default = "typing_only", rest = 0 },
}
ns.CINEMATIC_COMPONENTS = CINEMATIC_COMPONENTS

local CINEMATIC_MODE_CONDITIONS = {
    typing_only = {},
    context_hover = { "alt", "mouseover", "combat", "target_any" },
    target_hover = { "alt", "mouseover", "target_any" },
    combat_hover = { "alt", "mouseover", "combat" },
    combat = { "alt", "combat" },
    casting = { "alt", "casting" },
    hover = { "alt", "mouseover" },
    quest_hover = { "alt", "mouseover", "quest_update", "quest_accepted", "quest_turned_in", "quest_objective" },
    loot_hover = { "alt", "mouseover", "loot", "loot_opened" },
}

local function NewCinematicSettings(profile, mode, rest, nativeMarkerMode)
    local conditions = CINEMATIC_MODE_CONDITIONS[mode]
    if not conditions then return nil end
    local settings = { enabled = true, atRest = rest or 0.05, fadeInDuration = 0.25, fadeOutDuration = 0.25, fadeDelay = 0.35, reactions = {}, cinematicMode = mode }
    if nativeMarkerMode ~= nil then settings.nativeMarkerMode = nativeMarkerMode end
    for _, condition in ipairs(conditions) do
        settings.reactions[#settings.reactions + 1] = { id = profile.nextReactionID, condition = condition, opacity = 1 }
        profile.nextReactionID = profile.nextReactionID + 1
    end
    return settings
end

local function CinematicSettingsMatch(settings, mode, rest)
    local conditions = CINEMATIC_MODE_CONDITIONS[mode]
    if type(settings) ~= "table" or not conditions
        or math.abs((settings.atRest or 0) - rest) > 0.0001
        or math.abs((settings.fadeInDuration or settings.fadeDuration or 0) - 0.25) > 0.0001
        or math.abs((settings.fadeOutDuration or settings.fadeDuration or 0) - 0.25) > 0.0001
        or math.abs((settings.fadeDelay or 0) - 0.35) > 0.0001
        or type(settings.reactions) ~= "table" or #settings.reactions ~= #conditions then return false end
    for index, condition in ipairs(conditions) do
        local reaction = settings.reactions[index]
        if not reaction or reaction.condition ~= condition or reaction.opacity ~= 1 or #(reaction.requirements or {}) > 0 then return false end
        local info = CONDITION_INFO[condition]
        if info and info.kind == "moment" and math.abs((reaction.duration or info.duration or 3) - (info.duration or 3)) > 0.0001 then return false end
    end
    return true
end

function ns:GetCinematicProfileName()
    local cinematic = FrameGambitDB and FrameGambitDB.cinematic
    return cinematic and cinematic.profileName
end

function ns:IsCinematicProfileName(name)
    return type(name) == "string" and name == self:GetCinematicProfileName()
end

function ns:EnsureCinematicProfile()
    local db = FrameGambitDB
    db.cinematic = type(db.cinematic) == "table" and db.cinematic or {}
    local cinematic = db.cinematic
    cinematic.actions = type(cinematic.actions) == "table" and cinematic.actions or {}
    cinematic.letterboxEnabled = cinematic.letterboxEnabled == true
    cinematic.letterboxHeight = math.max(0, math.min(0.25, tonumber(cinematic.letterboxHeight) or 0.04))
    cinematic.cameraFOV = math.max(40, math.min(100, math.floor((tonumber(cinematic.cameraFOV) or 90) + 0.5)))
    cinematic.cameraOffsetDefault = cinematic.cameraOffsetDefault == true
    cinematic.templateVersion = tonumber(cinematic.templateVersion) or 1
    -- The old Keep a frame shortcut duplicated profile editing and made a
    -- saved exception invisible to the player. Retire those legacy exceptions
    -- once; any intended visible UI now belongs in the Cinematic profile.
    if cinematic.templateVersion < 6 then cinematic.keepNames = {} end
    local profileName = cinematic.profileName
    local created = false
    if type(profileName) ~= "string" or not db.profiles[profileName] or not db.profiles[profileName].cinematicSystem then
        profileName = CINEMATIC_PROFILE_LABEL
        local suffix = 2
        while db.profiles[profileName] and not db.profiles[profileName].cinematicSystem do
            profileName = CINEMATIC_PROFILE_LABEL .. " " .. suffix
            suffix = suffix + 1
        end
        cinematic.profileName = profileName
        db.profiles[profileName] = db.profiles[profileName] or { targets = {}, groups = {}, links = {}, visibilityLinks = {}, nextReactionID = 1, nextGroupID = 1 }
        local profile = db.profiles[profileName]
        created = true
        profile.cinematicSystem = true
        profile.targets, profile.groups, profile.links, profile.visibilityLinks = {}, {}, {}, {}
        profile.nextReactionID, profile.nextGroupID = 1, 1
        for _, component in ipairs(CINEMATIC_COMPONENTS) do
            profile.targets[component.id] = NewCinematicSettings(profile, component.default, component.rest,
                component.id == "minimap" and "hide_zero" or nil)
        end
    end
    local profile = db.profiles[cinematic.profileName]
    if type(profile) == "table" then
        profile.nextReactionID = tonumber(profile.nextReactionID) or 1
        profile.nextGroupID = tonumber(profile.nextGroupID) or 1
    end
    if not created and cinematic.templateVersion < CINEMATIC_TEMPLATE_VERSION and type(profile) == "table" then
        profile.targets = type(profile.targets) == "table" and profile.targets or {}
        -- Upgrade only untouched v1 defaults. Advanced edits remain exactly as
        -- the user made them and simply show as Custom in the dedicated page.
        if CinematicSettingsMatch(profile.targets.eui_player, "combat_hover", 0.05) then
            profile.targets.eui_player = NewCinematicSettings(profile, "target_hover", 0)
        end
        if CinematicSettingsMatch(profile.targets.eui_target, "combat_hover", 0.05) then
            profile.targets.eui_target = NewCinematicSettings(profile, "target_hover", 0)
        end
        if CinematicSettingsMatch(profile.targets.minimap, "hover", 0.05) then
            local markerMode = profile.targets.minimap.nativeMarkerMode == "scale" and "scale" or "hide_zero"
            profile.targets.minimap = NewCinematicSettings(profile, "hover", 0, markerMode)
        end
        if CinematicSettingsMatch(profile.targets.eui_player, "target_hover", 0) then
            profile.targets.eui_player = NewCinematicSettings(profile, "context_hover", 0)
        end
        if CinematicSettingsMatch(profile.targets.eui_target, "target_hover", 0) then
            profile.targets.eui_target = NewCinematicSettings(profile, "context_hover", 0)
        end
        if cinematic.templateVersion < 4 then
            if profile.targets.eui_castbar == nil then
                profile.targets.eui_castbar = NewCinematicSettings(profile, "casting", 0)
            end
            if profile.targets.eui_resourcebars == nil then
                profile.targets.eui_resourcebars = NewCinematicSettings(profile, "combat", 0)
            end
        end
        if cinematic.templateVersion < 5 and type(profile.targets.minimap) == "table" then
            local markerMode = profile.targets.minimap.nativeMarkerMode
            if markerMode == nil or markerMode == "keep" then
                profile.targets.minimap.nativeMarkerMode = "hide_zero"
            end
        end
        if cinematic.templateVersion < 7 and profile.targets.chat == nil then
            profile.targets.chat = NewCinematicSettings(profile, "typing_only", 0)
        end
        if cinematic.templateVersion < 8 and CinematicSettingsMatch(profile.targets.chat, "loot_hover", 0) then
            profile.targets.chat = NewCinematicSettings(profile, "typing_only", 0)
        end
    end
    cinematic.templateVersion = CINEMATIC_TEMPLATE_VERSION
    return cinematic.profileName, db.profiles[cinematic.profileName]
end

function ns:GetCinematicProfile()
    local _, profile = self:EnsureCinematicProfile()
    return profile
end

function ns:IsCinematicActive()
    return FrameGambitDB and FrameGambitDB.profile == self:GetCinematicProfileName()
end

function ns:InvalidateTargetTransition(id)
    local profile = FrameGambitDB and FrameGambitDB.profiles and FrameGambitDB.profiles[FrameGambitDB.profile]
    local links = profile and profile.visibilityLinks or {}
    local function Clear(current, seen)
        if not current or seen[current] then return end
        seen[current] = true
        runtime.revealGoal[current] = nil
        runtime.fadeOutStarted[current] = nil
        runtime.transitions[current] = nil
        for childID in pairs(type(links[current]) == "table" and links[current] or {}) do Clear(childID, seen) end
    end
    Clear(id, {})
    self:Wake()
end

local CINEMATIC_LOCKED_NAMES = {
    NamePlateDriverFrame = true,
    LootFrame = true,
    GroupLootContainer = true,
    LootHistoryFrame = true,
    SpeedyAutoLoot_LootDisplayAnchor = true,
    DUIQuestFrame = true,
    QuestFrame = true,
    GossipFrame = true,
    GameTooltip = true,
    ItemRefTooltip = true,
    StaticPopup1 = true,
    StaticPopup2 = true,
    StaticPopup3 = true,
    StaticPopup4 = true,
    GameMenuFrame = true,
    SettingsPanel = true,
}

local function SafeFrameName(frame)
    if not frame then return nil end
    local ok, name = pcall(function() return frame:GetName() end)
    return ok and not IsSecret(name) and type(name) == "string" and name or nil
end

local function SafeFrameShown(frame)
    if not frame then return false end
    local ok, shown = pcall(CallFrameIsShown, frame)
    return ok and not IsSecret(shown) and shown == true
end

local function SafeFrameStrata(frame)
    if not frame then return nil end
    local ok, strata = pcall(function() return frame:GetFrameStrata() end)
    return ok and not IsSecret(strata) and type(strata) == "string" and strata or nil
end

local function SafeFrameMouseEnabled(frame)
    if not frame then return false end
    local ok, enabled = pcall(function() return frame:IsMouseEnabled() end)
    return ok and not IsSecret(enabled) and enabled == true
end

local CINEMATIC_WINDOW_STRATA = {
    DIALOG = true,
    FULLSCREEN = true,
    FULLSCREEN_DIALOG = true,
    TOOLTIP = true,
}

-- Most main Blizzard panels register with UIPanelWindows. These fallbacks cover
-- the player-facing roots that may bypass it, including bag containers and UI
-- that Blizzard has renamed or moved between Retail versions.
local CINEMATIC_BLIZZARD_PANEL_FALLBACKS = {
    "CharacterFrame",
    "PlayerSpellsFrame",
    "SpellBookFrame",
    "ClassTalentFrame",
    "QuestLogFrame",
    "WorldMapFrame",
    "FriendsFrame",
    "CommunitiesFrame",
    "GuildFrame",
    "CollectionsJournal",
    "EncounterJournal",
    "AchievementFrame",
    "ReputationFrame",
    "PVEFrame",
    "PVPUIFrame",
    "CalendarFrame",
    "ProfessionsFrame",
    "TradeSkillFrame",
    "MacroFrame",
    "KeyBindingFrame",
    "ContainerFrameCombinedBags",
    "AuctionHouseFrame",
    "MerchantFrame",
    "BankFrame",
    "GuildBankFrame",
    "MailFrame",
    "OpenMailFrame", -- Reading a letter uses a separate root from the inbox.
    "TradeFrame",
}

local function IsCinematicMapWindow(root, name)
    -- The World Map uses one top-level frame for continent, zone, dungeon,
    -- Delve, and other map views. Treat the host window as an intentional
    -- Cinematic panel rather than blacking it out when it is opened.
    local worldMap = _G and _G.WorldMapFrame
    return (root ~= nil and root == worldMap) or name == "WorldMapFrame"
end

-- Windows registered for Escape closing (UISpecialFrames) are player windows.
-- Cinematic Mode leaves them open, so they must stay visible, not blacked out.
local function IsEscapeClosableWindow(name)
    if type(name) ~= "string" or type(UISpecialFrames) ~= "table" then return false end
    for _, entry in ipairs(UISpecialFrames) do
        if entry == name then return true end
    end
    return false
end

-- A Cinematic scene still permits intentional panels.  This is deliberately
-- narrow: Blizzard's registered UI panels and normal top-level addon dialogs
-- may surface while they are open; HUD branches remain in the scene.
local function IsCinematicOpenWindow(root, name)
    if not SafeFrameShown(root) then return false end
    if IsCinematicMapWindow(root, name) then return true end
    if name and type(UIPanelWindows) == "table" and UIPanelWindows[name] then return true end
    if IsEscapeClosableWindow(name) then return true end
    local strata = SafeFrameStrata(root)
    -- Ellesmere's inventory and themed game panels are HIGH-strata roots.
    -- Keep only interactive HIGH windows, not non-interactive scene art.
    if strata == "HIGH" then return SafeFrameMouseEnabled(root) end
    return CINEMATIC_WINDOW_STRATA[strata] == true
end

local function SafeFrameMarker(frame, key)
    if not frame then return nil end
    local ok, marker = pcall(function() return frame[key] end)
    return ok and not IsSecret(marker) and marker or nil
end

local function IsCinematicNameplateFrame(frame, name)
    if not frame then return false end
    if type(name) == "string" and name:match("^NamePlate") then return true end
    -- Ellesmere's enemy and friendly nameplates are anonymous pooled
    -- UIParent roots. Once initialized they retain this exact mixin contract
    -- even while pooled/hidden, allowing Cinematic to pre-exempt them before
    -- an enemy appears without reading or changing Ellesmere's settings.
    local mixed = SafeFrameMarker(frame, "_mixedIn") == true
    local setUnit = SafeFrameMarker(frame, "SetUnit")
    local clearUnit = SafeFrameMarker(frame, "ClearUnit")
    local health = SafeFrameMarker(frame, "health")
    return mixed and type(setUnit) == "function" and type(clearUnit) == "function" and health ~= nil
end

local function IsCinematicDataBarFrame(frame)
    local name = SafeFrameName(frame)
    return name == "XIV_Databar"
        or (type(name) == "string" and name:match("^EllesmereUIDataBarsBar%d+$") ~= nil)
end

function ns:RefreshCinematicExemptions(rootSnapshot)
    local frames = setmetatable({}, { __mode = "k" })
    if self.AddSceneProviderExemptions then self:AddSceneProviderExemptions(frames) end
    -- These are presentation bars.  Let their addons retain all frame and
    -- input ownership; the LOW-strata letterbox stays behind their UI layer.
    for _, root in ipairs(rootSnapshot or self:GetUIParentFrameRoots(true)) do
        if IsCinematicDataBarFrame(root) then frames[root] = true end
        if IsCinematicOpenWindow(root, SafeFrameName(root)) then runtime.cinematicOpenWindows[root] = true end
    end
    -- Every frame registered with Blizzard's panel manager is a deliberate
    -- player window. Resolve it to its actual visual root so Character,
    -- Spellbook, Collections, social, map, and future standard panels all
    -- follow the same open-above-Cinematic policy.
    if type(UIPanelWindows) == "table" then
        for name in pairs(UIPanelWindows) do
            local panel = type(name) == "string" and _G and _G[name] or nil
            if panel then
                self:HookCinematicPanel(panel)
                if SafeFrameShown(panel) then
                    local root = self:GetFramePickerRoot(panel) or panel
                    frames[root] = true
                    runtime.cinematicOpenWindows[root] = true
                end
            end
        end
    end
    -- Windows registered for Escape closing stay open when the scene starts
    -- (see ToggleCinematic), so they follow the same policy as panels.
    if type(UISpecialFrames) == "table" then
        for _, name in ipairs(UISpecialFrames) do
            local window = type(name) == "string" and _G and _G[name] or nil
            if type(window) == "table" then
                self:HookCinematicPanel(window)
                if SafeFrameShown(window) then
                    local root = self:GetFramePickerRoot(window) or window
                    frames[root] = true
                    runtime.cinematicOpenWindows[root] = true
                end
            end
        end
    end
    for _, name in ipairs(CINEMATIC_BLIZZARD_PANEL_FALLBACKS) do
        local panel = _G and _G[name]
        if panel then
            self:HookCinematicPanel(panel)
            if SafeFrameShown(panel) then
                local root = self:GetFramePickerRoot(panel) or panel
                frames[root] = true
                runtime.cinematicOpenWindows[root] = true
            end
        end
    end
    -- Individual bags use numbered container roots on some Retail UI paths;
    -- add all supported slots without assuming that the combined-bag frame is
    -- the one the player has chosen to display.
    for index = 1, 13 do
        local panel = _G and _G["ContainerFrame" .. index]
        if panel then
            self:HookCinematicPanel(panel)
            if SafeFrameShown(panel) then
                local root = self:GetFramePickerRoot(panel) or panel
                frames[root] = true
                runtime.cinematicOpenWindows[root] = true
            end
        end
    end
    local profile = self:GetCinematicProfile()
    for id in pairs(profile.targets or {}) do
        local frame = self:ResolveTarget(id)
        local visual = frame
        local okVisual, resolvedVisual = pcall(function()
            return frame and type(frame.GetFrameGambitVisualFrame) == "function" and frame:GetFrameGambitVisualFrame() or nil
        end)
        if okVisual and resolvedVisual then visual = resolvedVisual end
        local okFrames, providerFrames = pcall(function()
            return frame and type(frame.GetFrameGambitCinematicFrames) == "function" and frame:GetFrameGambitCinematicFrames() or nil
        end)
        if okFrames and type(providerFrames) == "table" then
            for _, providerFrame in pairs(providerFrames) do
                if providerFrame then
                    frames[providerFrame] = true
                    local providerRoot = self:GetFramePickerRoot(providerFrame)
                    if providerRoot then frames[providerRoot] = true end
                end
            end
        end
        local boundary = frame and self.GetEUIUnitFrameBoundary and self:GetEUIUnitFrameBoundary(frame)
        local root = visual and self:GetFramePickerRoot(visual)
        if boundary then
            local owner = self.GetEUIUnitFrameOwner and self:GetEUIUnitFrameOwner(frame) or frame
            -- The EUI hider is only a secure structural switch. Keep it alive,
            -- exempt the exact rule-owned unit button, and lease its unwanted
            -- siblings independently in BeginCinematicBlackout.
            frames[boundary], frames[owner], frames[visual] = true, true, true
        elseif root then
            frames[root] = true
        end
    end
    for frame in pairs(runtime.cinematicKeepFrames or {}) do
        local boundary = self.GetEUIUnitFrameBoundary and self:GetEUIUnitFrameBoundary(frame)
        if boundary then
            local owner = self.GetEUIUnitFrameOwner and self:GetEUIUnitFrameOwner(frame) or frame
            frames[boundary], frames[owner], frames[frame] = true, true, true
        else
            local root = self:GetFramePickerRoot(frame)
            if root then frames[root] = true end
        end
    end
    local keepNames = FrameGambitDB and FrameGambitDB.cinematic and FrameGambitDB.cinematic.keepNames
    for name, keep in pairs(type(keepNames) == "table" and keepNames or {}) do
        local frame = keep == true and type(name) == "string" and _G[name] or nil
        local boundary = frame and self.GetEUIUnitFrameBoundary and self:GetEUIUnitFrameBoundary(frame)
        if boundary then
            local owner = self.GetEUIUnitFrameOwner and self:GetEUIUnitFrameOwner(frame) or frame
            frames[boundary], frames[owner], frames[frame] = true, true, true
        end
    end
    runtime.cinematicExemptFrames = frames
    if self.RefreshOPieFrames then self:RefreshOPieFrames() end
end

local function IsNativeBankFrame(frame)
    -- Bank windows initialize protected item controls while opening. Never
    -- pre-lease their hidden roots or install Cinematic hooks on this tree.
    for _ = 1, 16 do
        if not frame then return false end
        local name = SafeFrameName(frame)
        if name == "BankFrame" or name == "BankPanel" or name == "GuildBankFrame" then return true end
        local ok, parent = pcall(function() return frame:GetParent() end)
        if not ok or IsSecret(parent) or parent == frame then return false end
        frame = parent
    end
    return false
end

-- Native spell alerts share one parent, including anonymous pooled overlays.
-- Check ancestry live: pools can acquire children after the scene scan or reuse
-- an existing frame. Exemption only releases the blanket blackout lease; the
-- normal proc_overlay target still owns any explicitly configured alpha rules.
local function IsNativeSpellAlertFrame(frame)
    local overlay = _G and _G.SpellActivationOverlayFrame
    if not overlay then return false end
    for _ = 1, 16 do
        if IsSecret(frame) or not frame then return false end
        if frame == overlay then return true end
        local ok, parent = pcall(function() return frame:GetParent() end)
        if not ok or IsSecret(parent) or parent == frame then return false end
        frame = parent
    end
    return false
end

function ns:IsCinematicBlackoutExempt(root)
    if self.IsCinematicSuiteWindow and self:IsCinematicSuiteWindow(root) then return true end
    if IsNativeSpellAlertFrame(root) then return true end
    if IsNativeBankFrame(root) then return true end
    if not root or root == UIParent or root == WorldFrame or self:IsFrameGambitFrame(root) then return true end
    local name = SafeFrameName(root)
    if name and CINEMATIC_LOCKED_NAMES[name] then return true end
    if IsCinematicNameplateFrame(root, name) then return true end
    if self.IsOPieSceneFrame and self:IsOPieSceneFrame(root) then return true end
    if self.IsLootSceneFrame and self:IsLootSceneFrame(root) then return true end
    if self.IsMinimapStackFrame and self:IsMinimapStackFrame(root) then return true end
    if SafeFrameMarker(root, "LIKE_GLOBAL_GAMETOOLTIP") == true then return true end
    if runtime.cinematicExemptFrames and runtime.cinematicExemptFrames[root] then return true end
    -- Native IM-style edit boxes stay shown at 35% after sending. They are
    -- UIParent siblings, and their former DIALOG strata must not grant them
    -- a lasting open-window exemption. EUI-owned surfaces were handled above.
    if name and name:match("^ChatFrame%d+EditBox$") and _G[name] == root then
        return runtime.cinematicChatInput == true
    end
    if runtime.cinematicOpenWindows and runtime.cinematicOpenWindows[root]
        and SafeFrameShown(root) then return true end
    local keepNames = FrameGambitDB and FrameGambitDB.cinematic and FrameGambitDB.cinematic.keepNames
    if name and type(keepNames) == "table" and keepNames[name] == true then return true end
    return runtime.cinematicKeepFrames and runtime.cinematicKeepFrames[root] == true or false
end

function ns:RememberCinematicOpenWindow(root)
    if not self:IsCinematicActive() or not IsCinematicOpenWindow(root, SafeFrameName(root)) then return false end
    runtime.cinematicOpenWindows[root] = true
    return true
end

function ns:RememberCinematicPanel(panel)
    if not self:IsCinematicActive() or not SafeFrameShown(panel) then return false end
    local root = self:GetFramePickerRoot(panel) or panel
    if not root then return false end
    runtime.cinematicOpenWindows[root] = true
    return true
end

local function CinematicPanelShown(panel)
    if ns:RememberCinematicPanel(panel) then ns:UpdateCinematicBlackout(true) end
end

local function CinematicPanelHidden(panel)
    local root = ns:GetFramePickerRoot(panel) or panel
    if runtime.cinematicOpenWindows then runtime.cinematicOpenWindows[root] = nil end
    if ns:IsCinematicActive() then ns:UpdateCinematicBlackout(true) end
end

function ns:HookCinematicPanel(panel)
    if IsNativeBankFrame(panel) then return end
    if not panel or runtime.cinematicPanelHooks[panel] then return end
    local ok, hookScript = pcall(function() return panel.HookScript end)
    if not ok or type(hookScript) ~= "function" then return end
    local state = {}
    state.onShow = pcall(hookScript, panel, "OnShow", CinematicPanelShown) == true
    state.onHide = pcall(hookScript, panel, "OnHide", CinematicPanelHidden) == true
    if state.onShow or state.onHide then runtime.cinematicPanelHooks[panel] = state end
end

function ns:KeepCinematicFrame(frame)
    local visual = frame
    local okVisual, resolvedVisual = pcall(function()
        return frame and type(frame.GetFrameGambitVisualFrame) == "function" and frame:GetFrameGambitVisualFrame() or nil
    end)
    if okVisual and resolvedVisual then visual = resolvedVisual end
    local root = self:GetFramePickerRoot(visual)
    if not root then return false, "That frame cannot be kept safely." end
    local owner = self.GetEUIUnitFrameOwner and self:GetEUIUnitFrameOwner(frame)
    local managed = owner or root
    local name = SafeFrameName(managed)
    if name then
        FrameGambitDB.cinematic.keepNames = type(FrameGambitDB.cinematic.keepNames) == "table" and FrameGambitDB.cinematic.keepNames or {}
        FrameGambitDB.cinematic.keepNames[name] = true
    else
        runtime.cinematicKeepFrames = runtime.cinematicKeepFrames or setmetatable({}, { __mode = "k" })
        runtime.cinematicKeepFrames[visual] = true
    end
    self:RefreshCinematicExemptions()
    self:UpdateCinematicBlackout(true)
    return true, name and "This frame will stay visible in Cinematic Mode." or "This unnamed frame will stay visible until you reload."
end

function ns:ClearCinematicKeeps()
    if not FrameGambitDB or not FrameGambitDB.cinematic then return end
    FrameGambitDB.cinematic.keepNames = {}
    runtime.cinematicKeepFrames = setmetatable({}, { __mode = "k" })
    self:RefreshCinematicExemptions()
    self:BeginCinematicBlackout()
end

function ns:GetCinematicKeepCount()
    local count = 0
    for _ in pairs(FrameGambitDB and FrameGambitDB.cinematic and FrameGambitDB.cinematic.keepNames or {}) do count = count + 1 end
    for _ in pairs(runtime.cinematicKeepFrames or {}) do count = count + 1 end
    return count
end

local function SetCinematicFrameAlpha(frame, alpha)
    runtime.cinematicAlphaGuard[frame] = true
    local ok = SafeSetFrameAlpha(frame, alpha)
    runtime.cinematicAlphaGuard[frame] = nil
    return ok
end

local function CinematicHostAlphaChanged(frame, alpha)
    if runtime.cinematicAlphaGuard[frame] or not ns:IsCinematicActive() then return end
    local record = runtime.cinematicBlackout[frame]
    if not record then return end
    if IsSecret(alpha) or type(alpha) ~= "number" then
        local reveal = runtime.cinematicPickerReveal or false
        if not reveal and not ns:IsCinematicBlackoutExempt(frame) and SetCinematicFrameAlpha(frame, 0) then
            record.appliedAlpha = 0
        end
        return
    end
    record.baseAlpha = alpha
    record.appliedAlpha = alpha
    local reveal = runtime.cinematicPickerReveal or false
    if not reveal and not ns:IsCinematicBlackoutExempt(frame) and SetCinematicFrameAlpha(frame, 0) then
        record.appliedAlpha = 0
    end
end

local function CinematicRootShown(frame)
    if not ns:IsCinematicActive() then return end
    if ns:RememberCinematicOpenWindow(frame) then
        ns:UpdateCinematicBlackout(true)
        return
    end
    local record = runtime.cinematicBlackout[frame]
    if record and not ns:IsCinematicBlackoutExempt(frame)
        and not runtime.cinematicPickerReveal then
        if SetCinematicFrameAlpha(frame, 0) then record.appliedAlpha = 0 end
    end
end

local function CinematicRootHidden(frame)
    if runtime.cinematicOpenWindows then runtime.cinematicOpenWindows[frame] = nil end
end

function ns:HookCinematicRoot(root)
    if IsNativeBankFrame(root) then return end
    if not root then return end
    local state = runtime.cinematicBlackoutHooks[root]
    if type(state) ~= "table" then state = {}; runtime.cinematicBlackoutHooks[root] = state end
    local methodOK, hookScript = pcall(function() return root.HookScript end)
    if not state.onShow and methodOK and type(hookScript) == "function" then
        state.onShow = pcall(hookScript, root, "OnShow", CinematicRootShown) == true
    end
    if not state.onHide and methodOK and type(hookScript) == "function" then
        state.onHide = pcall(hookScript, root, "OnHide", CinematicRootHidden) == true
    end
    if not state.alpha and type(hooksecurefunc) == "function" then
        state.alpha = pcall(hooksecurefunc, root, "SetAlpha", CinematicHostAlphaChanged) == true
    end
end

local function LeaseCinematicFrame(self, frame)
    if not frame then return false end
    if runtime.cinematicBlackout[frame] then return true end
    if self:IsCinematicBlackoutExempt(frame) then return false end
    local alpha = SafeFrameAlpha(frame)
    if alpha == nil then return false end
    local record = runtime.cinematicBlackout[frame]
    if not record then
        record = { baseAlpha = alpha, appliedAlpha = alpha }
        runtime.cinematicBlackout[frame] = record
    end
    self:HookCinematicRoot(frame)
    return true
end

function ns:BeginCinematicBlackout()
    if not self:IsCinematicActive() or not self.GetUIParentFrameRoots then return false end
    if InCombatLockdown() then runtime.cinematicScanPending = true; return false, "Cinematic will finish hiding frames when combat ends." end
    runtime.cinematicScanPending = nil
    local roots = self:GetUIParentFrameRoots(true)
    self:RefreshCinematicExemptions(roots)
    local count = 0
    for _, root in ipairs(roots) do
        if LeaseCinematicFrame(self, root) then count = count + 1 end
    end
    -- Shared structural roots (currently Ellesmere's secure unit hider) stay
    -- visible for exact exceptions; their non-exempt child branches still join
    -- the same alpha-only ledger and restoration lifecycle.
    if self.GetCinematicNestedBlackoutFrames then
        for _, frame in ipairs(self:GetCinematicNestedBlackoutFrames()) do
            if LeaseCinematicFrame(self, frame) then count = count + 1 end
        end
    end
    runtime.cinematicBlackoutCount = count
    runtime.cinematicRootScanAt = GetTime()
    self:UpdateCinematicBlackout(true)
    return true, count
end

function ns:UpdateCinematicBlackout(force)
    if not self:IsCinematicActive() then return end
    local reveal = runtime.cinematicPickerReveal or false
    local now = GetTime()
    local revealChanged = runtime.cinematicRevealActive ~= reveal
    runtime.cinematicRevealActive = reveal
    -- SetAlpha/OnShow post-hooks handle ordinary host repaints immediately.
    -- A low-rate guarded audit remains for frames whose hooks could not be
    -- installed, while picker reveal and ownership changes still update at once.
    if not force and not revealChanged and now - (runtime.cinematicAuditAt or 0) < 0.5 then return end
    runtime.cinematicAuditAt = now
    local count = 0
    for root, record in pairs(runtime.cinematicBlackout) do
        -- Most exemptions are stable between scene ownership changes and root
        -- rescans. Minimap escape frames and pooled spell-alert ancestry can
        -- change independently, so audit those when releasing old leases.
        local exempt = (force and self:IsCinematicBlackoutExempt(root))
            or IsNativeSpellAlertFrame(root)
            or (self.IsCinematicSuiteWindow and self:IsCinematicSuiteWindow(root))
            or (not force and self.IsMinimapStackFrame and self:IsMinimapStackFrame(root))
        if exempt then
            local current = SafeFrameAlpha(root)
            if current == nil then
                QueuePendingRestore(root, record.baseAlpha, record.appliedAlpha)
            elseif math.abs(current - (record.appliedAlpha or current)) < 0.01
                and not SetCinematicFrameAlpha(root, record.baseAlpha) then
                QueuePendingRestore(root, record.baseAlpha, record.appliedAlpha)
            end
            runtime.cinematicBlackout[root] = nil
        else
            local current = SafeFrameAlpha(root)
            if current == nil then
                -- Secret or temporarily unreadable alpha is not an ownership
                -- release. Reassert blackout without comparing the secret
                -- value; pcall fails closed if the protected frame rejects it.
                if not reveal and SetCinematicFrameAlpha(root, 0) then record.appliedAlpha = 0 end
                count = count + 1
            else
                if math.abs(current - (record.appliedAlpha or current)) > 0.01 then record.baseAlpha = current end
                local desired = reveal and record.baseAlpha or 0
                if math.abs(current - desired) > 0.001 and SetCinematicFrameAlpha(root, desired) then record.appliedAlpha = desired end
                count = count + 1
            end
        end
    end
    runtime.cinematicBlackoutCount = count
end

function ns:ReconcileCinematicOwnership()
    if not self:IsCinematicActive() then return end
    self:RefreshCinematicExemptions()
    -- Release anything that just became an explicit rule-owned exception,
    -- then acquire newly unowned branches in the same synchronous editor
    -- mutation.
    self:UpdateCinematicBlackout(true)
    if InCombatLockdown() then
        runtime.cinematicScanPending = true
        return
    end
    self:BeginCinematicBlackout()
end

function ns:EndCinematicBlackout()
    for root, record in pairs(runtime.cinematicBlackout) do
        local current = SafeFrameAlpha(root)
        runtime.cinematicBlackout[root] = nil
        if current ~= nil and math.abs(current - (record.appliedAlpha or current)) < 0.01 then
            if not SetCinematicFrameAlpha(root, record.baseAlpha) then
                QueuePendingRestore(root, record.baseAlpha, record.appliedAlpha)
            end
        elseif current == nil then
            QueuePendingRestore(root, record.baseAlpha, record.appliedAlpha)
        end
    end
    runtime.cinematicBlackoutCount = 0
    runtime.cinematicRootScanAt = 0
    runtime.cinematicAuditAt = 0
    runtime.cinematicRevealActive = nil
    runtime.cinematicOpenWindows = setmetatable({}, { __mode = "k" })
end

function ns:ResetCinematicProfile()
    local profile = self:GetCinematicProfile()
    if self:IsCinematicActive() then
        local ids = {}
        for id in pairs(runtime.frameByID) do ids[#ids + 1] = id end
        for _, id in ipairs(ids) do self:RestoreControlledFrame(id) end
        for id in pairs(runtime.active) do runtime.active[id] = nil end
        for id in pairs(runtime.hovered) do runtime.hovered[id] = nil end
        for id in pairs(runtime.fadeOutStarted) do runtime.fadeOutStarted[id] = nil end
    end
    for id in pairs(runtime.revealGoal) do runtime.revealGoal[id] = nil end
    for id in pairs(runtime.transitions) do runtime.transitions[id] = nil end
    profile.targets, profile.groups, profile.links, profile.visibilityLinks = {}, {}, {}, {}
    InvalidateRelationshipCache()
    profile.nextReactionID, profile.nextGroupID = 1, 1
    for _, component in ipairs(CINEMATIC_COMPONENTS) do
        profile.targets[component.id] = NewCinematicSettings(profile, component.default, component.rest,
            component.id == "minimap" and "hide_zero" or nil)
    end
    FrameGambitDB.cinematic.letterboxEnabled = false
    FrameGambitDB.cinematic.letterboxHeight = 0.04
    if self.SetCinematicFOV then self:SetCinematicFOV(90) else FrameGambitDB.cinematic.cameraFOV = 90 end
    if self.SetCinematicCameraOffsetDefault then
        self:SetCinematicCameraOffsetDefault(false)
    else
        FrameGambitDB.cinematic.cameraOffsetDefault = false
    end
    if self.RefreshCinematicLetterbox then self:RefreshCinematicLetterbox() end
    if self:IsCinematicActive() then
        if self.PrimeCinematicTargets then self:PrimeCinematicTargets() end
        self:BeginCinematicBlackout()
    end
    self:Wake()
    self:RefreshOptions()
end

function ns:ToggleCinematic(keepOptionsOpen)
    if InCombatLockdown() then return false, "Toggle Cinematic Mode outside combat.", self:IsCinematicActive() end
    local cinematicName = self:EnsureCinematicProfile()
    local db = FrameGambitDB
    local restoreEditor = keepOptionsOpen == true and self.Options and self.Options:IsShown()
    if db.profile == cinematicName then
        local returnProfile = db.cinematic.returnProfile
        if type(returnProfile) ~= "string" or not db.profiles[returnProfile] or returnProfile == cinematicName then returnProfile = "Default" end
        local ok, reason = self:SelectProfile(returnProfile, true)
        if ok then db.cinematic.returnProfile = nil end
        if ok and restoreEditor and self.Options and not self.Options:IsShown() then self.Options:Show() end
        return ok, reason, false
    end
    db.cinematic.returnProfile = db.profile
    local ok, reason = self:SelectProfile(cinematicName, true)
    if ok then
        -- Open windows stay open above the scene. Blizzard panels and windows
        -- registered for Escape closing count as open windows, so none of them
        -- fades into an invisible mouse trap. Never close them from here: on
        -- Forever, CloseAllWindows from addon code makes Blizzard's gamepad
        -- window manager store its focus state under Frame Gambit's taint.
        -- Later window opens and closes then fail inside Blizzard's gamepad
        -- navigation, and jump/back stop working until /reload. The dedicated
        -- Cinematic control may explicitly keep this editor open.
        if not keepOptionsOpen and self.Options and self.Options:IsShown() then
            self.Options:Hide()
        end
        if self.CloseHelp then self:CloseHelp() end
        if keepOptionsOpen and self.Options then
            self.Options.selected = nil
        end
        if self.PrimeCinematicTargets then self:PrimeCinematicTargets() end
        local scanned, scanReason = self:BeginCinematicBlackout()
        if not scanned and scanReason then reason = scanReason end
    end
    return ok, reason, true
end

function ns:GetCinematicBinding()
    local primary = GetBindingKey and GetBindingKey(CINEMATIC_BINDING)
    return primary
end

function ns:SetCinematicChatInputActive(active)
    active = active == true
    if runtime.cinematicChatInput == active then return false end
    runtime.cinematicChatInput = active
    self:Wake()
    -- A close can happen just after leaving Cinematic. Clear the temporary
    -- snap flag before the profile gate so it can never leak into a normal
    -- profile's independently configured Chat transition.
    if not active then runtime.immediateApply.chat = nil end
    if not self:IsCinematicActive() then return true end
    self:InvalidateTargetTransition("chat")
    -- Snap the reveal on the next evaluator pass, but never leave that flag
    -- behind if a quick Escape/send closes chat before the pass occurs.
    runtime.immediateApply.chat = active and true or nil
    local seen = {}
    local function RefreshEditBox(name)
        local chatFrame = _G[name]
        local editBox = _G[name .. "EditBox"] or (chatFrame and chatFrame.editBox)
        if editBox and not seen[editBox] then
            seen[editBox] = true
            runtime.cinematicOpenWindows[editBox] = nil
            if not active then LeaseCinematicFrame(self, editBox) end
        end
    end
    for _, name in pairs(CHAT_FRAMES or {}) do
        if type(name) == "string" then RefreshEditBox(name) end
    end
    for index = 1, NUM_CHAT_WINDOWS or 10 do RefreshEditBox("ChatFrame" .. index) end
    self:UpdateCinematicBlackout(true)
    self:Wake()
    return true
end

function ns:GetCinematicCameraBinding()
    local primary = GetBindingKey and GetBindingKey(CINEMATIC_CAMERA_BINDING)
    return primary
end

function ns:MigrateLegacyCinematicBinding()
    if InCombatLockdown() or not GetBindingKey or not SetBinding or not SaveBindings then return end
    local newPrimary, newSecondary = GetBindingKey(CINEMATIC_BINDING)
    if newPrimary or newSecondary then return end
    local oldPrimary, oldSecondary = GetBindingKey(LEGACY_CINEMATIC_BINDING)
    if not oldPrimary and not oldSecondary then return end
    local migrated = {}
    for _, key in ipairs({ oldPrimary, oldSecondary }) do
        if key and SetBinding(key, CINEMATIC_BINDING) ~= false then migrated[#migrated + 1] = key end
    end
    if #migrated == 0 then return end
    local bindingSet = (GetCurrentBindingSet and GetCurrentBindingSet()) or 1
    if SaveBindings(bindingSet) == false then
        for _, key in ipairs(migrated) do SetBinding(key, LEGACY_CINEMATIC_BINDING) end
        SaveBindings(bindingSet)
    end
end

function ns:SetCinematicBinding(key)
    if InCombatLockdown() then return false, "Change shortcuts outside combat." end
    if not SetBinding or not SaveBindings then return false, "WoW key binding controls are unavailable." end
    local oldPrimary, oldSecondary = GetBindingKey(CINEMATIC_BINDING)
    local replacedAction = key and GetBindingAction and GetBindingAction(key)
    if key and SetBinding(key, CINEMATIC_BINDING) == false then return false, "WoW rejected that shortcut." end
    if oldPrimary and oldPrimary ~= key then SetBinding(oldPrimary, nil) end
    if oldSecondary and oldSecondary ~= key then SetBinding(oldSecondary, nil) end
    local bindingSet = (GetCurrentBindingSet and GetCurrentBindingSet()) or 1
    if SaveBindings(bindingSet) == false then
        if key then SetBinding(key, replacedAction and replacedAction ~= "" and replacedAction or nil) end
        if oldPrimary then SetBinding(oldPrimary, CINEMATIC_BINDING) end
        if oldSecondary then SetBinding(oldSecondary, CINEMATIC_BINDING) end
        SaveBindings(bindingSet)
        return false, "WoW could not save that shortcut; the previous binding was restored."
    end
    return true
end

function ns:SetCinematicCameraBinding(key)
    if InCombatLockdown() then return false, "Change shortcuts outside combat." end
    if not SetBinding or not SaveBindings then return false, "WoW key binding controls are unavailable." end
    local oldPrimary, oldSecondary = GetBindingKey(CINEMATIC_CAMERA_BINDING)
    local replacedAction = key and GetBindingAction and GetBindingAction(key)
    if key and SetBinding(key, CINEMATIC_CAMERA_BINDING) == false then return false, "WoW rejected that shortcut." end
    if oldPrimary and oldPrimary ~= key then SetBinding(oldPrimary, nil) end
    if oldSecondary and oldSecondary ~= key then SetBinding(oldSecondary, nil) end
    local bindingSet = (GetCurrentBindingSet and GetCurrentBindingSet()) or 1
    if SaveBindings(bindingSet) == false then
        if key then SetBinding(key, replacedAction and replacedAction ~= "" and replacedAction or nil) end
        if oldPrimary then SetBinding(oldPrimary, CINEMATIC_CAMERA_BINDING) end
        if oldSecondary then SetBinding(oldSecondary, CINEMATIC_CAMERA_BINDING) end
        SaveBindings(bindingSet)
        return false, "WoW could not save that shortcut; the previous binding was restored."
    end
    return true
end

function ns:GetTargetSettings(id, create)
    local profile = self:Profile()
    local settings = profile.targets[id]
    if not settings and create then
        settings = {
            enabled = true,
            atRest = 0.12,
            fadeInDuration = 0.20,
            fadeOutDuration = 0.20,
            fadeDelay = 0.80,
            reactions = CopyDefaults(DEFAULT_REACTIONS),
        }
        profile.targets[id] = settings
    end
    if settings then
        -- Saved variables outlive versions.  Keep a partial or older record
        -- harmless instead of letting the update loop index nil values.
        settings.enabled = settings.enabled ~= false
        settings.atRest = math.max(0, math.min(1, tonumber(settings.atRest) or 0.12))
        -- Seed both directions from the legacy shared duration independently.
        settings.fadeInDuration = math.max(0.05, math.min(2, tonumber(settings.fadeInDuration) or tonumber(settings.fadeDuration) or 0.20))
        settings.fadeOutDuration = math.max(0.05, math.min(2, tonumber(settings.fadeOutDuration) or tonumber(settings.fadeDuration) or 0.20))
        settings.fadeDelay = math.max(0, math.min(15, tonumber(settings.fadeDelay) or 0.80))
        if id == "minimap" and settings.nativeMarkerMode ~= nil
            and settings.nativeMarkerMode ~= "keep" and settings.nativeMarkerMode ~= "hide_zero"
            and settings.nativeMarkerMode ~= "scale" then
            settings.nativeMarkerMode = nil
        end
        settings.reactions = type(settings.reactions) == "table" and settings.reactions or {}
        if not runtime.normalized[settings] then
            local valid = {}
            for _, reaction in ipairs(settings.reactions) do
                if type(reaction) == "table" and type(reaction.condition) == "string" then
                    if type(reaction.id) ~= "number" then reaction.id = self:NextReactionID() end
                    reaction.enabled = reaction.enabled ~= false
                    reaction.opacity = math.max(0, math.min(1, tonumber(reaction.opacity) or 1))
                    local info = CONDITION_INFO[reaction.condition]
                    self:NormalizePercentageReaction(reaction)
                    reaction.chatText = reaction.condition == "chat_text" and self:NormalizeChatText(reaction.chatText) or nil
                    if reaction.condition == "form" then
                        reaction.formKey = FORM_BY_ID[reaction.formKey] and reaction.formKey or nil
                        reaction.formExpected = reaction.formExpected ~= false
                    elseif self:GetBooleanConditionField(reaction.condition) then
                        local field = self:GetBooleanConditionField(reaction.condition)
                        reaction[field] = reaction[field] ~= false
                    elseif reaction.condition == "spec" then
                        local option = SPEC_BY_ID[reaction.specID]
                        reaction.specID = option and option.class == reaction.specClass and reaction.specID or nil
                        reaction.specClass = reaction.specID and reaction.specClass or nil
                    else
                        reaction.formKey, reaction.formExpected, reaction.movementExpected, reaction.specClass, reaction.specID = nil, nil, nil, nil, nil
                    end
                    if info and info.kind == "moment" then
                        local duration = math.max(0.5, math.min(30, tonumber(reaction.duration) or info.duration or 3))
                        reaction.duration = math.floor(duration * 4 + 0.5) / 4
                    else
                        reaction.duration = nil
                    end
                    local requirements, seen = {}, {}
                    for _, condition in ipairs(type(reaction.requirements) == "table" and reaction.requirements or {}) do
                        if type(condition) == "string" and condition ~= reaction.condition
                            and condition ~= "form" and condition ~= "spec" and condition ~= "chat_text" and not self:IsPercentageCondition(condition) and not self:GetBooleanConditionField(condition)
                            and not seen[condition] then
                            requirements[#requirements + 1], seen[condition] = condition, true
                        end
                    end
                    reaction.requirements = requirements
                    if self.NormalizeLayoutReaction then self:NormalizeLayoutReaction(reaction) end
                    valid[#valid + 1] = reaction
                end
            end
            settings.reactions = valid
            if self.NormalizeLayoutDefaults then self:NormalizeLayoutDefaults(settings) end
            runtime.normalized[settings] = true
        end
    end
    return settings
end

function ns:AddTarget(id)
    local previous = self:GetTargetSettings(id)
    local ownershipChanged = not previous or previous.enabled == false
    local settings = self:GetTargetSettings(id, true)
    settings.enabled = true
    if ownershipChanged and self.ReconcileCinematicOwnership then self:ReconcileCinematicOwnership() end
    self:Wake()
    self:RefreshOptions()
    return settings
end

function ns:CopyTargetRules(id)
    local settings = self:GetTargetSettings(id)
    if not settings then return false, "Use this frame before copying its rules." end
    runtime.ruleClipboard = {
        atRest = settings.atRest,
        fadeInDuration = settings.fadeInDuration,
        fadeOutDuration = settings.fadeOutDuration,
        fadeDelay = settings.fadeDelay,
        restScale = settings.restScale,
        restOffsetX = settings.restOffsetX,
        restOffsetY = settings.restOffsetY,
        restLayoutLine = settings.restLayoutLine,
        restLayoutInstant = settings.restLayoutInstant,
        layoutPivot = settings.layoutPivot,
        reactions = DeepCopy(settings.reactions or {}),
        sourceID = id,
    }
    self:RefreshOptions()
    return true
end

function ns:CanPasteTargetRules()
    local clipboard = runtime.ruleClipboard
    return type(clipboard) == "table" and type(clipboard.reactions) == "table"
        and #clipboard.reactions <= self.MAX_REACTIONS_PER_TARGET
end

function ns:PasteTargetRules(id)
    if not self:CanPasteTargetRules() then return false, "Copy valid frame rules first." end
    local settings = self:GetTargetSettings(id, true)
    local clipboard = runtime.ruleClipboard
    settings.atRest = math.max(0, math.min(1, tonumber(clipboard.atRest) or 0.12))
    settings.fadeInDuration = math.max(0.05, math.min(2, tonumber(clipboard.fadeInDuration) or tonumber(clipboard.fadeDuration) or 0.20))
    settings.fadeOutDuration = math.max(0.05, math.min(2, tonumber(clipboard.fadeOutDuration) or tonumber(clipboard.fadeDuration) or 0.20))
    settings.fadeDelay = math.max(0, math.min(15, tonumber(clipboard.fadeDelay) or 0.80))
    settings.restScale, settings.restOffsetX, settings.restOffsetY = clipboard.restScale, clipboard.restOffsetX, clipboard.restOffsetY
    settings.restLayoutLine, settings.restLayoutInstant = clipboard.restLayoutLine, clipboard.restLayoutInstant
    settings.layoutPivot = clipboard.layoutPivot
    settings.reactions = DeepCopy(clipboard.reactions)
    for _, reaction in ipairs(settings.reactions) do reaction.id = self:NextReactionID() end
    settings.cinematicMode = nil
    runtime.normalized[settings] = nil
    runtime.fadeOutStarted[id] = nil
    runtime.revealGoal[id] = nil
    runtime.transitions[id] = nil
    runtime.immediateApply[id] = true
    self:Wake()
    self:RefreshOptions()
    return true
end

function ns:RestoreControlledFrame(id)
    runtime.revealGoal[id] = nil
    runtime.fadeOutStarted[id] = nil
    runtime.transitions[id] = nil
    local frame = runtime.frameByID[id]
    if not frame then return end
    local target = self.TargetByID[id]
    local alpha = runtime.baseAlpha[frame]
    local lastApplied = runtime.managedAlphaReadback[frame] or runtime.currentAlpha[frame]
    runtime.managedIDByFrame[frame] = nil
    local live = SafeFrameAlpha(frame)
    local restored = alpha == nil
    if alpha ~= nil and live ~= nil and lastApplied ~= nil
        and math.abs(live - lastApplied) > 0.001 then
        -- The host reclaimed its alpha after our last write. Releasing
        -- ownership must not overwrite that newer host-owned value.
        restored = true
    elseif alpha ~= nil and (live ~= nil or runtime.protectedAlpha[frame] ~= nil or type(alpha) == "table") then
        runtime.managedAlphaGuard[frame] = true
        restored = SafeSetFrameAlpha(frame, alpha)
        runtime.managedAlphaGuard[frame] = nil
    end
    if alpha ~= nil and not restored then
        QueuePendingRestore(frame, alpha, lastApplied, target and target.release)
    elseif target and target.release then
        pcall(target.release, frame)
    end
    runtime.baseAlpha[frame] = nil
    runtime.protectedAlpha[frame] = nil
    runtime.currentAlpha[frame] = nil
    runtime.managedAlphaReadback[frame] = nil
    runtime.managedAlphaAuditAt[frame] = nil
    runtime.frameByID[id] = nil
end

function ns:GetProfileNames()
    local db = FrameGambitDB
    local names = {}
    for name in pairs(db.profiles or {}) do
        if type(name) == "string" and name ~= "" then names[#names + 1] = name end
    end
    table.sort(names, function(a, b)
        if a == "Default" then return true end
        if b == "Default" then return false end
        return a:lower() < b:lower()
    end)
    return names
end

local function NormalizeProfileName(name)
    if type(name) ~= "string" then return nil end
    name = name:match("^%s*(.-)%s*$")
    if name == "" or #name > 24 or not name:match("^[%w][%w %-%_']*$") then return nil end
    return name
end

local function FindProfileName(db, name)
    local wanted = name:lower()
    for existing in pairs(db.profiles or {}) do
        if type(existing) == "string" and existing:lower() == wanted then return existing end
    end
end

function ns:SelectProfile(name, preserveCinematicReturn)
    name = NormalizeProfileName(name)
    local db = FrameGambitDB
    if not name or not db.profiles or not db.profiles[name] then return false, "That profile does not exist." end
    if db.profile == name then return true end
    local leavingCinematic = self:IsCinematicActive() and not self:IsCinematicProfileName(name)
    -- A new profile must not capture a helper's temporary faded alpha as the
    -- host baseline. Drain these leases before transferring target ownership.
    if self.ReleaseMinimapStack and not self:ReleaseMinimapStack() then
        self:Wake()
        return false, "The minimap is still restoring its opacity. Try switching again."
    end
    if self:IsCinematicActive() then
        if InCombatLockdown() then return false, "Toggle Cinematic Mode outside combat." end
        self:EndCinematicBlackout()
    end
    local ids = {}
    for id in pairs(runtime.frameByID) do ids[#ids + 1] = id end
    for _, id in ipairs(ids) do self:RestoreControlledFrame(id) end
    for id in pairs(runtime.active) do runtime.active[id] = nil end
    for id in pairs(runtime.hovered) do runtime.hovered[id] = nil end
    for id in pairs(runtime.fadeOutStarted) do runtime.fadeOutStarted[id] = nil end
    for id in pairs(runtime.revealGoal) do runtime.revealGoal[id] = nil end
    for id in pairs(runtime.transitions) do runtime.transitions[id] = nil end
    for id in pairs(runtime.immediateApply) do runtime.immediateApply[id] = nil end
    db.profile = name
    InvalidateRelationshipCache()
    if self.RefreshCinematicLetterbox then self:RefreshCinematicLetterbox() end
    if self.RefreshCinematicCamera then self:RefreshCinematicCamera() end
    if not preserveCinematicReturn and db.cinematic and db.cinematic.profileName ~= name then
        db.cinematic.returnProfile = nil
    end
    self:Profile()
    self:EnsureConnectedHoverRules()
    if leavingCinematic then
        -- Restore native leases and settle the destination profile in the
        -- same Lua turn, before the renderer can display restored baselines.
        self:PrimeProfileTargets()
        if self.UpdateMinimapStack then self:UpdateMinimapStack(true) end
    end
    if self.Options then
        self.Options.selected = nil
        self.Options.active:SetText("Profile switched to " .. name)
        self.Options.active:SetTextColor(unpack(self.COLORS.teal))
    end
    self:Wake()
    self:RefreshOptions()
    return true
end

function ns:CreateProfile(name)
    if self:IsCinematicActive() then return false, "Turn off Cinematic Mode before creating a normal profile." end
    name = NormalizeProfileName(name)
    local db = FrameGambitDB
    if not name then return false, "Use 1-24 letters, numbers, spaces, hyphens, underscores, or apostrophes." end
    if FindProfileName(db, name) then return false, "That profile name is already in use." end
    db.profiles[name] = DeepCopy(self:Profile())
    return self:SelectProfile(name)
end

-- Observe Blizzard's public UI mode without subscribing to or changing its
-- native input manager. A manual profile choice lasts until a real transition.
function ns:GetInputModeProfileSettings()
    local db = FrameGambitDB
    if type(db) ~= "table" then return nil end
    if type(db.inputModeProfiles) ~= "table" then db.inputModeProfiles = { enabled = false } end
    local settings = db.inputModeProfiles
    settings.enabled = settings.enabled == true
    for _, mode in ipairs({ "gamepad", "keyboard" }) do
        local name = settings[mode]
        if type(name) ~= "string" or type(db.profiles) ~= "table"
            or not db.profiles[name] or self:IsCinematicProfileName(name) then settings[mode] = nil end
    end
    return settings
end

function ns:RefreshInputModeProfile(force)
    local settings = self:GetInputModeProfileSettings()
    if not settings or not settings.enabled then return false end
    if not InputUtil or type(InputUtil.IsGamepadUIEnabled) ~= "function" then return false end
    local ok, enabled = pcall(InputUtil.IsGamepadUIEnabled)
    if not ok or IsSecret(enabled) or type(enabled) ~= "boolean" then return false end
    local mode = enabled and "gamepad" or "keyboard"
    if not force and runtime.inputProfileMode == mode then return false end
    runtime.inputProfileMode = mode
    -- Cinematic remains an explicit user mode, including across reloads.
    if self:IsCinematicActive() then return false end
    local name = settings[mode]
    if not name or name == FrameGambitDB.profile then return false end
    return self:SelectProfile(name)
end

function ns:SetInputModeProfilesEnabled(enabled)
    local settings = self:GetInputModeProfileSettings()
    if not settings then return false end
    settings.enabled = enabled == true
    runtime.inputProfileMode = nil
    if settings.enabled then self:RefreshInputModeProfile(true) end
    return true
end

function ns:SetInputModeProfile(mode, name)
    if mode ~= "gamepad" and mode ~= "keyboard" then return false end
    local settings = self:GetInputModeProfileSettings()
    if not settings then return false end
    if name ~= nil and (type(name) ~= "string" or not FrameGambitDB.profiles[name]
        or self:IsCinematicProfileName(name)) then return false end
    settings[mode] = name
    self:RefreshInputModeProfile(true)
    return true
end

function ns:DeleteProfile(name)
    name = NormalizeProfileName(name)
    local db = FrameGambitDB
    if not name or not db.profiles[name] then return false, "That profile does not exist." end
    if name == "Default" then return false, "Default is kept as a safe fallback." end
    if self:IsCinematicProfileName(name) then return false, "Cinematic Mode is managed from its dedicated page." end
    local resetCinematicReturn = db.cinematic and db.cinematic.returnProfile == name
    if db.profile == name then self:SelectProfile("Default") end
    db.profiles[name] = nil
    self:GetInputModeProfileSettings()
    if resetCinematicReturn then db.cinematic.returnProfile = "Default" end
    self:RefreshOptions()
    return true, resetCinematicReturn and "Profile deleted. Cinematic Mode will return to Default." or "Profile deleted."
end

local function SortedKeys(values)
    local keys = {}
    for key in pairs(values or {}) do if type(key) == "string" then keys[#keys + 1] = key end end
    table.sort(keys)
    return keys
end

local function EncodeField(value)
    return (tostring(value or ""):gsub("([^%w%-%_%.])", function(char)
        return string.format("%%%02X", string.byte(char))
    end))
end

local function DecodeField(value)
    if type(value) ~= "string" then return nil end
    local position = 1
    while true do
        local percent = value:find("%", position, true)
        if not percent then break end
        local hex = value:sub(percent + 1, percent + 2)
        if #hex ~= 2 or not hex:match("^%x%x$") then return nil end
        position = percent + 3
    end
    return (value:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end))
end

local function SplitFields(line)
    local fields = {}
    local start = 1
    while true do
        local delimiter = line:find("|", start, true)
        if not delimiter then
            fields[#fields + 1] = line:sub(start)
            break
        end
        fields[#fields + 1] = line:sub(start, delimiter - 1)
        start = delimiter + 1
    end
    return fields
end

local function IsSafeImportID(value, limit)
    return type(value) == "string" and value ~= "" and #value <= (limit or 96) and not value:find("[%c]")
end

local function ImportNumber(value, minimum, maximum)
    local number = tonumber(value)
    if not number or number ~= number or number < minimum or number > maximum then return nil end
    return number
end

local function ProfileChecksum(body)
    local checksum = 0
    for index = 1, #body do checksum = (checksum + string.byte(body, index) * index) % 65521 end
    return string.format("%04X", checksum)
end

local function ImportFailure(message)
    return nil, message
end

function ns:ExportProfile(name)
    name = NormalizeProfileName(name or FrameGambitDB.profile)
    if self:IsCinematicProfileName(name) then return nil, "Turn off Cinematic Mode before exporting a normal profile." end
    local profile = name and FrameGambitDB.profiles and FrameGambitDB.profiles[name]
    if not profile then return nil, "That profile does not exist." end
    local lines = { "PF1" }
    for _, targetID in ipairs(SortedKeys(profile.targets)) do
        local settings = profile.targets[targetID]
        if type(settings) == "table" and IsSafeImportID(targetID) then
            -- Disabled targets are not currently a user-facing profile option.
            -- Exporting them as active keeps every successful payload portable.
            local enabled = "1"
            local atRest = math.max(0, math.min(1, tonumber(settings.atRest) or 0.12))
            local fadeInDuration = math.max(0.05, math.min(2, tonumber(settings.fadeInDuration) or tonumber(settings.fadeDuration) or 0.20))
            local fadeOutDuration = math.max(0.05, math.min(2, tonumber(settings.fadeOutDuration) or tonumber(settings.fadeDuration) or 0.20))
            local fadeDelay = math.max(0, math.min(15, tonumber(settings.fadeDelay) or 0.80))
            lines[#lines + 1] = table.concat({ "T", EncodeField(targetID), enabled, atRest, fadeInDuration, fadeDelay, fadeOutDuration }, "|")
            -- Marker behavior remains an optional, independent entry.
            -- Old exports without it retain the default marker behavior.
            -- It is deliberately limited to the native Minimap marker
            -- compositor; no arbitrary per-adapter settings cross profiles.
            if targetID == "minimap" and (settings.nativeMarkerMode == "keep" or settings.nativeMarkerMode == "hide_zero" or settings.nativeMarkerMode == "scale") then
                lines[#lines + 1] = table.concat({ "M", EncodeField(targetID), settings.nativeMarkerMode }, "|")
            end
            -- Experimental size and position: Otherwise values, only when set.
            local restScale = self.NormalizeLayoutScale and self.NormalizeLayoutScale(settings.restScale)
            local restX = self.NormalizeLayoutOffset and self.NormalizeLayoutOffset(settings.restOffsetX)
            local restY = self.NormalizeLayoutOffset and self.NormalizeLayoutOffset(settings.restOffsetY)
            if not (restX and restY) then restX, restY = 0, 0 end
            if (restScale and restScale ~= 1) or restX ~= 0 or restY ~= 0 then
                lines[#lines + 1] = table.concat({ "Y", EncodeField(targetID), restScale or 1, restX, restY }, "|")
            end
            if settings.restLayoutInstant == true then
                lines[#lines + 1] = table.concat({ "N", EncodeField(targetID), "1" }, "|")
            end
            local pivot = self.NormalizeLayoutPivot and self:NormalizeLayoutPivot(settings.layoutPivot)
            if pivot then
                lines[#lines + 1] = table.concat({ "O", EncodeField(targetID), pivot }, "|")
            end
            for _, reaction in ipairs(type(settings.reactions) == "table" and settings.reactions or {}) do
                local info = type(reaction) == "table" and CONDITION_INFO[reaction.condition]
                if info and not info.internal and type(reaction.id) == "number" then
                    local requirements = {}
                    for _, requirement in ipairs(type(reaction.requirements) == "table" and reaction.requirements or {}) do
                        local requirementInfo = CONDITION_INFO[requirement]
                        if requirementInfo and not requirementInfo.internal and requirement ~= reaction.condition
                            and requirement ~= "chat_text" and not self:IsPercentageCondition(requirement) and not self:GetBooleanConditionField(requirement) then
                            requirements[#requirements + 1] = requirement
                        end
                    end
                    local duration = info.kind == "moment" and math.max(0.5, math.min(30, tonumber(reaction.duration) or info.duration or 3)) or ""
                    lines[#lines + 1] = table.concat({ "R", EncodeField(targetID), reaction.id, EncodeField(reaction.condition), math.max(0, math.min(1, tonumber(reaction.opacity) or 1)), duration, EncodeField(table.concat(requirements, ",")) }, "|")
                    if reaction.enabled == false then
                        lines[#lines + 1] = table.concat({ "E", EncodeField(targetID), reaction.id, "0" }, "|")
                    end
                    if self:IsPercentageCondition(reaction.condition) then
                        local normalized = { condition = reaction.condition, percentageOperator = reaction.percentageOperator, percentageThreshold = reaction.percentageThreshold, partyMember = reaction.partyMember }
                        self:NormalizePercentageReaction(normalized)
                        lines[#lines + 1] = table.concat({ "P", EncodeField(targetID), reaction.id, normalized.percentageOperator, normalized.percentageThreshold }, "|")
                        if normalized.partyMember then lines[#lines] = lines[#lines] .. "|" .. normalized.partyMember end
                    end
                    if reaction.condition == "chat_text" then
                        lines[#lines + 1] = table.concat({ "W", EncodeField(targetID), reaction.id, EncodeField(self:NormalizeChatText(reaction.chatText)) }, "|")
                    end
                    if reaction.condition == "form" and FORM_BY_ID[reaction.formKey] then
                        lines[#lines + 1] = table.concat({ "F", EncodeField(targetID), reaction.id, EncodeField(reaction.formKey), reaction.formExpected == false and "0" or "1" }, "|")
                    end
                    local booleanField = self:GetBooleanConditionField(reaction.condition)
                    if booleanField then
                        lines[#lines + 1] = table.concat({ "B", EncodeField(targetID), reaction.id, reaction[booleanField] == false and "0" or "1" }, "|")
                    end
                    local spec = reaction.condition == "spec" and SPEC_BY_ID[reaction.specID]
                    if spec and spec.class == reaction.specClass then
                        lines[#lines + 1] = table.concat({ "S", EncodeField(targetID), reaction.id, spec.class, spec.id }, "|")
                    end
                    if reaction.keepOpacity == true then
                        lines[#lines + 1] = table.concat({ "K", EncodeField(targetID), reaction.id, "1" }, "|")
                    end
                    local scale = self.NormalizeLayoutScale and self.NormalizeLayoutScale(reaction.scale)
                    local offsetX = self.NormalizeLayoutOffset and self.NormalizeLayoutOffset(reaction.offsetX)
                    local offsetY = self.NormalizeLayoutOffset and self.NormalizeLayoutOffset(reaction.offsetY)
                    if not (offsetX and offsetY) or (self.LayoutReactionCanMove and not self:LayoutReactionCanMove(reaction)) then offsetX, offsetY = nil, nil end
                    if scale or offsetX then
                        lines[#lines + 1] = table.concat({ "Z", EncodeField(targetID), reaction.id, scale or "-", offsetX or "-", offsetY or "-" }, "|")
                    end
                    if reaction.layoutInstant == true then
                        lines[#lines + 1] = table.concat({ "I", EncodeField(targetID), reaction.id, "1" }, "|")
                    end
                end
            end
        end
    end
    for _, groupID in ipairs(SortedKeys(profile.groups)) do
        local group = profile.groups[groupID]
        if type(group) == "table" and type(group.members) == "table" and IsSafeImportID(groupID) then
            local members = {}
            for _, memberID in ipairs(SortedKeys(group.members)) do if group.members[memberID] == true and IsSafeImportID(memberID) then members[#members + 1] = EncodeField(memberID) end end
            if #members >= 2 then lines[#lines + 1] = table.concat({ "G", EncodeField(groupID), EncodeField(group.name or "Reveal group"), EncodeField(table.concat(members, ",")) }, "|") end
        end
    end
    for _, parentID in ipairs(SortedKeys(profile.links)) do
        local children = profile.links[parentID]
        if type(children) == "table" and IsSafeImportID(parentID) then
            local childIDs = {}
            for _, childID in ipairs(SortedKeys(children)) do if children[childID] == true and IsSafeImportID(childID) then childIDs[#childIDs + 1] = EncodeField(childID) end end
            if #childIDs > 0 then lines[#lines + 1] = table.concat({ "L", EncodeField(parentID), EncodeField(table.concat(childIDs, ",")) }, "|") end
        end
    end
    for _, parentID in ipairs(SortedKeys(profile.visibilityLinks)) do
        local children = profile.visibilityLinks[parentID]
        if type(children) == "table" and IsSafeImportID(parentID) then
            local childIDs = {}
            for _, childID in ipairs(SortedKeys(children)) do
                if children[childID] == true and IsSafeImportID(childID) then childIDs[#childIDs + 1] = EncodeField(childID) end
            end
            if #childIDs > 0 then lines[#lines + 1] = table.concat({ "V", EncodeField(parentID), EncodeField(table.concat(childIDs, ",")) }, "|") end
        end
    end
    local body = table.concat(lines, "\n")
    local export = "FrameGambit-1:" .. ProfileChecksum(body) .. "\n" .. body
    local valid, reason = self:ParseProfileImport(export)
    if not valid then return nil, "This profile cannot be exported: " .. reason end
    return export
end

function ns:ParseProfileImport(text)
    if type(text) ~= "string" or #text > 60000 then return ImportFailure("Paste an exported Frame Gambit profile under 60 KB.") end
    -- Retail's multiline edit controls and the Windows clipboard do not
    -- always agree on a newline representation. Normalize CRLF, bare CR,
    -- a possible UTF-8 clipboard marker, and harmless outer whitespace before
    -- checking the checksum. Export fields percent-encode meaningful spaces,
    -- so trimming spaces/tabs at line edges cannot alter profile data.
    text = text:gsub("^\239\187\191", ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    text = text:match("^%s*(.-)%s*$") or ""
    local checksum, body = text:match("^FrameGambit%-1:([0-9A-Fa-f]+)\r?\n([%s%S]+)$")
    if not checksum then checksum, body = text:match("^PriorityFader%-1:([0-9A-Fa-f]+)\r?\n([%s%S]+)$") end
    if not checksum or not body then return ImportFailure("That export is incomplete or has been changed.") end
    -- WoW EditBox text treats a vertical bar as an escape introducer. A
    -- copied/pasted export can therefore return every visible separator as
    -- two bars. A T record has no empty fields, so its exact alternating
    -- shape is an unambiguous transport marker; decode the whole body once.
    local targetProbe = body:match("\n(T[^\n]*)")
    local transportPipeRun = targetProbe
        and (targetProbe:match("^T(|+)[^|]+%1[^|]+%1[^|]+%1[^|]+%1[^|]+$")
            or targetProbe:match("^T(|+)[^|]+%1[^|]+%1[^|]+%1[^|]+%1[^|]+%1[^|]+$"))
    local wowEscapedPipes = transportPipeRun and #transportPipeRun > 1 or false
    if wowEscapedPipes then
        -- Decode exactly the separator width proven by the T record. This
        -- also survives an extra clipboard round trip (|||| separators),
        -- while preserving genuine adjacent empty fields in R records.
        body = body:gsub(transportPipeRun, "|")
    end

    local checksumAdjusted = checksum:upper() ~= ProfileChecksum(body)
    if checksumAdjusted then
        local normalized = {}
        for line in body:gmatch("[^\n]+") do
            normalized[#normalized + 1] = line:match("^[ \t]*(.-)[ \t]*$") or line
        end
        body = table.concat(normalized, "\n")
        checksumAdjusted = checksum:upper() ~= ProfileChecksum(body)
    end
    if checksumAdjusted then
        return ImportFailure("That export is incomplete or has been changed.")
    end
    local lines = {}
    for line in body:gmatch("[^\r\n]+") do lines[#lines + 1] = line end
    if lines[1] ~= "PF1" then return ImportFailure("This is not a Frame Gambit profile export.") end
    local profile = { targets = {}, groups = {}, links = {}, visibilityLinks = {}, nextReactionID = 1, nextGroupID = 1 }
    local reactionIDs, reactionByID, reactionsByTarget, memberToGroup, visibilityParentByChild = {}, {}, {}, {}, {}
    local targetCount, reactionCount, groupCount, edgeCount = 0, 0, 0, 0
    for index = 2, #lines do
        local fields = SplitFields(lines[index])
        local tag = fields[1]
        if tag == "T" and (#fields == 6 or #fields == 7) then
            local id = DecodeField(fields[2])
            local atRest = ImportNumber(fields[4], 0, 1)
            local fadeDuration = ImportNumber(fields[5], 0.05, 2)
            local fadeDelay = ImportNumber(fields[6], 0, 15)
            local fadeOutDuration = fadeDuration
            if #fields == 7 then fadeOutDuration = ImportNumber(fields[7], 0.05, 2) end
            if not IsSafeImportID(id) or profile.targets[id] or fields[3] ~= "1" or not atRest or not fadeDuration or not fadeOutDuration or not fadeDelay then return ImportFailure("A frame entry is invalid.") end
            targetCount = targetCount + 1; if targetCount > 120 then return ImportFailure("An import can contain at most 120 frames.") end
            profile.targets[id] = { enabled = true, atRest = atRest, fadeInDuration = fadeDuration, fadeOutDuration = fadeOutDuration, fadeDelay = fadeDelay, reactions = {} }
        elseif tag == "M" and #fields == 3 then
            local targetID, mode = DecodeField(fields[2]), fields[3]
            -- Only accept the known compositor modes and only on the native
            -- Minimap target. Old exports omit the record and retain the same
            -- effective default: "keep".
            if targetID ~= "minimap" or not profile.targets[targetID]
                or (mode ~= "keep" and mode ~= "hide_zero" and mode ~= "scale")
                or profile.targets[targetID].nativeMarkerMode ~= nil then
                return ImportFailure("A Minimap marker setting is invalid.")
            end
            profile.targets[targetID].nativeMarkerMode = mode
        elseif tag == "R" and #fields >= 5 then
            -- Duration and extra requirements are optional for state rows.
            -- Some clipboard paths trim one or both trailing empty fields, so
            -- restore those empty optionals before the strict record checks.
            -- Extra separators are also harmless only when every added field
            -- is empty; never discard actual unknown reaction data.
            for fieldIndex = 8, #fields do
                if fields[fieldIndex] ~= "" then return ImportFailure("A reaction entry has unexpected data.") end
            end
            fields[6] = fields[6] or ""
            fields[7] = fields[7] or ""
            local targetID, condition, requirements = DecodeField(fields[2]), DecodeField(fields[4]), DecodeField(fields[7])
            local id = ImportNumber(fields[3], 1, 1000000000)
            local opacity = ImportNumber(fields[5], 0, 1)
            local info = condition and CONDITION_INFO[condition]
            if not IsSafeImportID(targetID) or not profile.targets[targetID] or not id or id % 1 ~= 0 or reactionIDs[id] or not opacity or not info or info.internal or requirements == nil then return ImportFailure("A reaction entry is invalid.") end
            local duration = nil
            if info.kind == "moment" then
                duration = ImportNumber(fields[6], 0.5, 30)
                if not duration then return ImportFailure("A moment duration is invalid.") end
            elseif fields[6] ~= "" then return ImportFailure("A state reaction cannot have a duration.") end
            local required, seen = {}, {}
            for requirement in (requirements or ""):gmatch("[^,]+") do
                local requirementInfo = CONDITION_INFO[requirement]
                if not requirementInfo or requirementInfo.internal or requirement == condition
                    or requirement == "form" or requirement == "spec" or requirement == "chat_text" or self:IsPercentageCondition(requirement) or self:GetBooleanConditionField(requirement)
                    or seen[requirement] then
                    return ImportFailure("A reaction requirement is invalid.")
                end
                required[#required + 1], seen[requirement] = requirement, true
            end
            reactionIDs[id] = true; reactionCount = reactionCount + 1
            if reactionCount > 800 then return ImportFailure("An import can contain at most 800 reactions.") end
            reactionsByTarget[targetID] = (reactionsByTarget[targetID] or 0) + 1
            if reactionsByTarget[targetID] > self.MAX_REACTIONS_PER_TARGET then return ImportFailure("An import can contain at most " .. self.MAX_REACTIONS_PER_TARGET .. " reactions per frame.") end
            local reaction = { id = id, condition = condition, opacity = opacity, duration = duration, requirements = required, enabled = true }
            profile.targets[targetID].reactions[#profile.targets[targetID].reactions + 1] = reaction
            reactionByID[id] = { targetID = targetID, reaction = reaction }
            profile.nextReactionID = math.max(profile.nextReactionID, id + 1)
        elseif tag == "P" and (#fields == 5 or #fields == 6) then
            local targetID, id = DecodeField(fields[2]), ImportNumber(fields[3], 1, 1000000000)
            local record = id and reactionByID[id]
            local threshold = ImportNumber(fields[5], 0, 100)
            if not IsSafeImportID(targetID) or not record or record.targetID ~= targetID
                or not self:IsPercentageCondition(record.reaction.condition) or record.reaction.percentageOperator ~= nil
                or not PERCENTAGE_COMPARISONS[fields[4]] or not threshold then
                return ImportFailure("A percentage comparison is invalid.")
            end
            if #fields == 6 then
                local member = ImportNumber(fields[6], 1, 5)
                if not member or member ~= math.floor(member)
                    or (record.reaction.condition ~= "party_health" and record.reaction.condition ~= "party_mana") then
                    return ImportFailure("A party member selection is invalid.")
                end
                record.reaction.partyMember = member
            end
            record.reaction.percentageOperator, record.reaction.percentageThreshold = fields[4], threshold
        elseif tag == "W" and #fields == 4 then
            local targetID, id, query = DecodeField(fields[2]), ImportNumber(fields[3], 1, 1000000000), DecodeField(fields[4])
            local record = id and reactionByID[id]
            if not IsSafeImportID(targetID) or not record or record.targetID ~= targetID
                or record.reaction.condition ~= "chat_text" or record.reaction.chatText ~= nil
                or query == nil or #query > 120 or self:NormalizeChatText(query) ~= query then
                return ImportFailure("A chat text setting is invalid.")
            end
            record.reaction.chatText = query
        elseif tag == "E" and #fields == 4 then
            local targetID, id, enabled = DecodeField(fields[2]), ImportNumber(fields[3], 1, 1000000000), fields[4]
            local record = id and reactionByID[id]
            if not IsSafeImportID(targetID) or not record or record.targetID ~= targetID or enabled ~= "0" or record.reaction.enabled == false then
                return ImportFailure("A reaction enabled setting is invalid.")
            end
            record.reaction.enabled = false
        elseif tag == "F" and #fields == 5 then
            local targetID, id, formKey, expected = DecodeField(fields[2]), ImportNumber(fields[3], 1, 1000000000), DecodeField(fields[4]), fields[5]
            local record = id and reactionByID[id]
            if not IsSafeImportID(targetID) or not record or record.targetID ~= targetID
                or record.reaction.condition ~= "form" or record.reaction.formKey ~= nil
                or not FORM_BY_ID[formKey] or (expected ~= "0" and expected ~= "1") then
                return ImportFailure("A form reaction setting is invalid.")
            end
            record.reaction.formKey, record.reaction.formExpected = formKey, expected == "1"
        elseif tag == "B" and #fields == 4 then
            local targetID, id, expected = DecodeField(fields[2]), ImportNumber(fields[3], 1, 1000000000), fields[4]
            local record = id and reactionByID[id]
            local booleanField = record and self:GetBooleanConditionField(record.reaction.condition)
            if not IsSafeImportID(targetID) or not record or record.targetID ~= targetID
                or not booleanField or record.reaction[booleanField] ~= nil
                or (expected ~= "0" and expected ~= "1") then
                return ImportFailure("A Boolean reaction setting is invalid.")
            end
            record.reaction[booleanField] = expected == "1"
        elseif tag == "S" and #fields == 5 then
            local targetID, id, classID, specID = DecodeField(fields[2]), ImportNumber(fields[3], 1, 1000000000), fields[4], ImportNumber(fields[5], 1, 1000000000)
            local record, spec = id and reactionByID[id], specID and SPEC_BY_ID[specID]
            if not IsSafeImportID(targetID) or not record or record.targetID ~= targetID
                or record.reaction.condition ~= "spec" or record.reaction.specID ~= nil
                or not spec or spec.class ~= classID then
                return ImportFailure("A talent build reaction setting is invalid.")
            end
            record.reaction.specClass, record.reaction.specID = classID, specID
        elseif tag == "K" and #fields == 4 then
            local targetID, id = DecodeField(fields[2]), ImportNumber(fields[3], 1, 1000000000)
            local record = id and reactionByID[id]
            if not IsSafeImportID(targetID) or not record or record.targetID ~= targetID
                or fields[4] ~= "1" or record.reaction.keepOpacity ~= nil then
                return ImportFailure("A Keep opacity setting is invalid.")
            end
            record.reaction.keepOpacity, record.reaction.layoutLine = true, true
        elseif tag == "Z" and #fields == 6 then
            local targetID, id = DecodeField(fields[2]), ImportNumber(fields[3], 1, 1000000000)
            local record = id and reactionByID[id]
            local scale = fields[4] ~= "-" and ImportNumber(fields[4], 0.5, 2) or nil
            local offsetX = fields[5] ~= "-" and ImportNumber(fields[5], -2000, 2000) or nil
            local offsetY = fields[6] ~= "-" and ImportNumber(fields[6], -2000, 2000) or nil
            if not IsSafeImportID(targetID) or not record or record.targetID ~= targetID
                or (fields[4] ~= "-" and not scale) or (fields[5] ~= "-" and not offsetX) or (fields[6] ~= "-" and not offsetY)
                or (offsetX == nil) ~= (offsetY == nil) or (scale == nil and offsetX == nil)
                or (offsetX and self.LayoutReactionCanMove and not self:LayoutReactionCanMove(record.reaction))
                or record.reaction.scale ~= nil or record.reaction.offsetX ~= nil then
                return ImportFailure("A size and position setting is invalid.")
            end
            record.reaction.scale, record.reaction.offsetX, record.reaction.offsetY = scale, offsetX, offsetY
            record.reaction.layoutLine = true
        elseif tag == "I" and #fields == 4 then
            local targetID, id = DecodeField(fields[2]), ImportNumber(fields[3], 1, 1000000000)
            local record = id and reactionByID[id]
            if not IsSafeImportID(targetID) or not record or record.targetID ~= targetID
                or fields[4] ~= "1" or record.reaction.layoutInstant ~= nil then
                return ImportFailure("An instant size and position setting is invalid.")
            end
            record.reaction.layoutInstant, record.reaction.layoutLine = true, true
        elseif tag == "O" and #fields == 3 then
            local targetID = DecodeField(fields[2])
            local settings = IsSafeImportID(targetID) and profile.targets[targetID]
            local pivot = self.NormalizeLayoutPivot and self:NormalizeLayoutPivot(fields[3])
            if not settings or not pivot or pivot ~= fields[3] or settings.layoutPivot then
                return ImportFailure("A resize pivot setting is invalid.")
            end
            settings.layoutPivot = pivot
        elseif tag == "N" and #fields == 3 then
            local targetID = DecodeField(fields[2])
            local settings = IsSafeImportID(targetID) and profile.targets[targetID]
            if not settings or fields[3] ~= "1" or settings.restLayoutInstant then
                return ImportFailure("An Otherwise instant setting is invalid.")
            end
            settings.restLayoutInstant, settings.restLayoutLine = true, true
        elseif tag == "Y" and #fields == 5 then
            local targetID = DecodeField(fields[2])
            local settings = IsSafeImportID(targetID) and profile.targets[targetID]
            local scale, offsetX, offsetY = ImportNumber(fields[3], 0.5, 2), ImportNumber(fields[4], -2000, 2000), ImportNumber(fields[5], -2000, 2000)
            if not settings or not scale or not offsetX or not offsetY or settings.restLayoutLine then
                return ImportFailure("An Otherwise size and position setting is invalid.")
            end
            settings.restScale = scale ~= 1 and scale or nil
            if offsetX ~= 0 or offsetY ~= 0 then settings.restOffsetX, settings.restOffsetY = offsetX, offsetY end
            settings.restLayoutLine = true
        elseif tag == "G" and #fields == 4 then
            local groupID, groupName, membersText = DecodeField(fields[2]), DecodeField(fields[3]), DecodeField(fields[4])
            if not IsSafeImportID(groupID, 64) or profile.groups[groupID] or not IsSafeImportID(groupName, 64) then return ImportFailure("A reveal group is invalid.") end
            local members = {}
            for encodedMemberID in (membersText or ""):gmatch("[^,]+") do
                local memberID = DecodeField(encodedMemberID)
                if not IsSafeImportID(memberID) or not profile.targets[memberID] or members[memberID] or memberToGroup[memberID] then return ImportFailure("A reveal group member is invalid.") end
                members[memberID] = true
            end
            local count = 0; for _ in pairs(members) do count = count + 1 end
            if count < 2 then return ImportFailure("A reveal group needs at least two frames.") end
            groupCount = groupCount + 1; if groupCount > 60 then return ImportFailure("An import can contain at most 60 reveal groups.") end
            for memberID in pairs(members) do memberToGroup[memberID] = groupID end
            profile.groups[groupID] = { name = groupName, members = members }
            local generatedDigits = groupID:match("^group(%d+)$")
            if generatedDigits and #generatedDigits <= 10 then
                local generatedID = tonumber(generatedDigits)
                if generatedID and generatedID <= 1000000000 then profile.nextGroupID = math.max(profile.nextGroupID, generatedID + 1) end
            end
        elseif tag == "L" and #fields == 3 then
            local parentID, childrenText = DecodeField(fields[2]), DecodeField(fields[3])
            if not IsSafeImportID(parentID) or not profile.targets[parentID] or profile.links[parentID] then return ImportFailure("A linked parent is invalid.") end
            local children = {}
            for encodedChildID in (childrenText or ""):gmatch("[^,]+") do
                local childID = DecodeField(encodedChildID)
                if not IsSafeImportID(childID) or not profile.targets[childID] or childID == parentID or children[childID] then return ImportFailure("A linked child is invalid.") end
                children[childID] = true
                edgeCount = edgeCount + 1; if edgeCount > 500 then return ImportFailure("An import can contain at most 500 links.") end
            end
            if not next(children) then return ImportFailure("A link needs at least one child.") end
            profile.links[parentID] = children
        elseif tag == "V" and #fields == 3 then
            local parentID, childrenText = DecodeField(fields[2]), DecodeField(fields[3])
            if not IsSafeImportID(parentID) or not profile.targets[parentID] or profile.visibilityLinks[parentID] then return ImportFailure("A visibility parent is invalid.") end
            local children = {}
            for encodedChildID in (childrenText or ""):gmatch("[^,]+") do
                local childID = DecodeField(encodedChildID)
                if not IsSafeImportID(childID) or not profile.targets[childID] or childID == parentID
                    or children[childID] or visibilityParentByChild[childID] then
                    return ImportFailure("A visibility child is invalid or already follows another frame.")
                end
                children[childID], visibilityParentByChild[childID] = true, parentID
                edgeCount = edgeCount + 1; if edgeCount > 500 then return ImportFailure("An import can contain at most 500 relationships.") end
            end
            if not next(children) then return ImportFailure("A visibility parent needs at least one child.") end
            profile.visibilityLinks[parentID] = children
        else
            return ImportFailure("Line " .. index .. " is not a recognized profile entry (" .. tostring(tag or "?") .. ", " .. #fields .. " fields).")
        end
    end
    for _, record in pairs(reactionByID) do
        if self:IsPercentageCondition(record.reaction.condition) and not record.reaction.percentageOperator then
            return ImportFailure("A percentage reaction needs a comparison and threshold.")
        end
        if record.reaction.condition == "form" and not FORM_BY_ID[record.reaction.formKey] then
            return ImportFailure("A Form reaction needs a valid form choice.")
        end
        local booleanField = self:GetBooleanConditionField(record.reaction.condition)
        if booleanField and type(record.reaction[booleanField]) ~= "boolean" then
            return ImportFailure("A Boolean reaction needs a Yes or No choice.")
        end
        if record.reaction.condition == "spec" then
            local spec = SPEC_BY_ID[record.reaction.specID]
            if not spec or spec.class ~= record.reaction.specClass then return ImportFailure("A talent build reaction needs a class and build.") end
        end
    end
    -- Reveal-group members need an unconditional hover row. Directional links
    -- are independent of both frames' local scripts: the source is sampled by
    -- the relationship itself, and the child may omit Mouseover so hovering it
    -- does not reveal it independently.
    local connectionTargets = {}
    for _, group in pairs(profile.groups) do
        for memberID in pairs(group.members or {}) do connectionTargets[memberID] = true end
    end
    for id in pairs(connectionTargets) do
        local hasFallback = false
        for _, reaction in ipairs(profile.targets[id].reactions) do
            if reaction.enabled ~= false and reaction.condition == "mouseover" and #(reaction.requirements or {}) == 0
                and reaction.keepOpacity ~= true then
                hasFallback = true
                break
            end
        end
        if not hasFallback then
            return ImportFailure("Every reveal-group member needs an unconditional Mouseover reaction.")
        end
    end
    local function Reaches(id, sought, seen)
        if id == sought then return true end
        if seen[id] then return false end
        seen[id] = true
        for childID in pairs(profile.links[id] or {}) do if Reaches(childID, sought, seen) then return true end end
        return false
    end
    for parentID, children in pairs(profile.links) do
        for childID in pairs(children) do if Reaches(childID, parentID, {}) then return ImportFailure("The import contains a linked-frame loop.") end end
    end
    local function VisibilityReaches(id, sought, seen)
        if id == sought then return true end
        if seen[id] then return false end
        seen[id] = true
        for childID in pairs(profile.visibilityLinks[id] or {}) do
            if VisibilityReaches(childID, sought, seen) then return true end
        end
        return false
    end
    for parentID, children in pairs(profile.visibilityLinks) do
        for childID in pairs(children) do
            if VisibilityReaches(childID, parentID, {}) then return ImportFailure("The import contains a visibility-inheritance loop.") end
        end
    end

    -- Profiles are portable rule sets, not assumptions about another
    -- player's addon stack. Resolve every target through this client's
    -- adapters: a shared EUI/Blizzard id naturally chooses the recipient's
    -- available frame, while missing addon and picker targets are skipped.
    local compatible, skippedIDs = {}, {}
    local importedTargetCount, importedReactionCount, skippedReactionCount = 0, 0, 0
    for targetID, settings in pairs(profile.targets) do
        local frame = self.ResolveTarget and self:ResolveTarget(targetID)
        if frame then
            compatible[targetID] = true
            importedTargetCount = importedTargetCount + 1
            importedReactionCount = importedReactionCount + #(settings.reactions or {})
        else
            skippedIDs[#skippedIDs + 1] = targetID
            skippedReactionCount = skippedReactionCount + #(settings.reactions or {})
        end
    end
    for _, targetID in ipairs(skippedIDs) do profile.targets[targetID] = nil end

    for groupID, group in pairs(profile.groups) do
        local memberCount = 0
        for memberID in pairs(group.members or {}) do
            if compatible[memberID] then memberCount = memberCount + 1 else group.members[memberID] = nil end
        end
        if memberCount < 2 then profile.groups[groupID] = nil end
    end
    local function PruneRelationships(graph)
        for parentID, children in pairs(graph) do
            if not compatible[parentID] then
                graph[parentID] = nil
            else
                for childID in pairs(children) do if not compatible[childID] then children[childID] = nil end end
                if not next(children) then graph[parentID] = nil end
            end
        end
    end
    PruneRelationships(profile.links)
    PruneRelationships(profile.visibilityLinks)

    return profile, {
        targets = importedTargetCount,
        reactions = importedReactionCount,
        sourceTargets = targetCount,
        sourceReactions = reactionCount,
        skippedTargets = #skippedIDs,
        skippedReactions = skippedReactionCount,
        clipboardAdjusted = wowEscapedPipes or checksumAdjusted,
    }
end

function ns:ImportProfile(name, text)
    name = NormalizeProfileName(name)
    if not name then return false, "Use a valid new profile name." end
    local db = FrameGambitDB
    if FindProfileName(db, name) then return false, "That profile name is already in use." end
    local profile, summary = self:ParseProfileImport(text)
    if not profile then return false, summary end
    -- Save the validated profile before any live-profile switch. Restoring
    -- frame leases and rebuilding the editor is a separate action and must
    -- not be able to make a successful import appear to do nothing.
    db.profiles = type(db.profiles) == "table" and db.profiles or {}
    db.profiles[name] = profile
    return true, summary
end

function ns:RemoveTarget(id)
    self:InvalidateTargetTransition(id)
    self:RestoreControlledFrame(id)
    self:Profile().targets[id] = nil
    runtime.active[id] = nil
    runtime.hovered[id] = nil
    runtime.fadeOutStarted[id] = nil
    runtime.revealGoal[id] = nil
    local profile = self:Profile()
    for key, group in pairs(profile.groups or {}) do
        if group.members then
            group.members[id] = nil
            local count = 0; for _ in pairs(group.members) do count = count + 1 end
            if count < 2 then profile.groups[key] = nil end
        end
    end
    for parentID, children in pairs(profile.links or {}) do
        if parentID == id then
            profile.links[parentID] = nil
        else
            children[id] = nil
            if not next(children) then profile.links[parentID] = nil end
        end
    end
    for parentID, children in pairs(profile.visibilityLinks or {}) do
        if parentID == id then
            profile.visibilityLinks[parentID] = nil
        elseif type(children) == "table" then
            children[id] = nil
            if not next(children) then profile.visibilityLinks[parentID] = nil end
        else
            profile.visibilityLinks[parentID] = nil
        end
    end
    InvalidateRelationshipCache()
    if self.ConnectionPicker and self.ConnectionPicker:IsShown() and self.ConnectionPicker.sourceID == id then
        self.ConnectionPicker:Hide()
    end
    if self.ReconcileCinematicOwnership then self:ReconcileCinematicOwnership() end
    self:RefreshOptions()
end

function ns:EnsureMouseoverReaction(id)
    local settings = self:GetTargetSettings(id, true)
    if self:HasUnconditionalMouseover(settings) then return true end
    if #settings.reactions >= self.MAX_REACTIONS_PER_TARGET then
        return false, "This frame already has the maximum of " .. self.MAX_REACTIONS_PER_TARGET .. " reactions. Remove one before linking it."
    end
    -- Preserve a user's more specific hover variants (for example,
    -- Mouseover + Shift) before adding the connection-safe fallback.
    local insertAt = 1
    for index, reaction in ipairs(settings.reactions) do
        if reaction.condition == "mouseover" then insertAt = index + 1 end
    end
    table.insert(settings.reactions, insertAt, { id = self:NextReactionID(), condition = "mouseover", opacity = 1 })
    return true
end

function ns:CountUnconditionalMouseover(settings)
    local count = 0
    for _, reaction in ipairs(settings.reactions) do
        if reaction.enabled ~= false and reaction.condition == "mouseover" and #(reaction.requirements or {}) == 0
            and reaction.keepOpacity ~= true then count = count + 1 end
    end
    return count
end

function ns:HasUnconditionalMouseover(settings)
    return self:CountUnconditionalMouseover(settings) > 0
end

function ns:CanEnsureMouseoverReaction(id)
    local settings = self:GetTargetSettings(id)
    if not settings or self:HasUnconditionalMouseover(settings) then return true end
    if #settings.reactions >= self.MAX_REACTIONS_PER_TARGET then
        return false, "This frame already has the maximum of " .. self.MAX_REACTIONS_PER_TARGET .. " reactions. Remove one before linking it."
    end
    return true
end

function ns:GetRevealGroup(id)
    local groups = self:Profile().groups or {}
    for key, group in pairs(groups) do
        if group.members and group.members[id] then return key, group end
    end
end

function ns:AddToRevealGroup(id, memberID)
    if id == memberID then return false, "A frame cannot join a reveal group with itself." end
    local groups = self:Profile().groups
    local _, group = self:GetRevealGroup(id)
    local memberKey, memberGroup = self:GetRevealGroup(memberID)
    local mustFit = { [id] = true, [memberID] = true }
    for existingID in pairs(group and group.members or {}) do mustFit[existingID] = true end
    for existingID in pairs(memberGroup and memberGroup.members or {}) do mustFit[existingID] = true end
    for targetID in pairs(mustFit) do
        local allowed, reason = self:CanEnsureMouseoverReaction(targetID)
        if not allowed then return false, reason end
    end
    if not group then
        local key
        key, group = "group" .. self:NextGroupID(), { name = "Reveal group", members = { [id] = true } }
        groups[key] = group
    end
    if memberGroup and memberGroup ~= group then
        for existingID in pairs(memberGroup.members or {}) do group.members[existingID] = true end
        groups[memberKey] = nil
    end
    group.members[memberID] = true
    InvalidateRelationshipCache()
    -- Group membership changes can alter several members' effective hover
    -- result while a fade is in flight. Drop those transition leases so the
    -- next evaluator tick starts from the new relationship graph.
    for targetID in pairs(mustFit) do self:InvalidateTargetTransition(targetID) end
    self:AddTarget(id)
    self:AddTarget(memberID)
    for targetID in pairs(mustFit) do
        local allowed, reason = self:EnsureMouseoverReaction(targetID)
        if not allowed then return false, reason end
    end
    return true
end

function ns:RemoveFromRevealGroup(id)
    local key, group = self:GetRevealGroup(id)
    if not group then return end
    local affected = {}
    for memberID in pairs(group.members or {}) do affected[memberID] = true end
    group.members[id] = nil
    local count = 0
    for _ in pairs(group.members) do count = count + 1 end
    if count < 2 then self:Profile().groups[key] = nil end
    InvalidateRelationshipCache()
    for memberID in pairs(affected) do self:InvalidateTargetTransition(memberID) end
end

function ns:GetLinkedChildren(parentID)
    return self:Profile().links[parentID] or {}
end

function ns:GetLinkParents(childID)
    local indexed = GetRelationshipIndices(self).linkParents[childID]
    local parents = {}
    for index, parentID in ipairs(indexed or {}) do parents[index] = parentID end
    return parents
end

function ns:RemoveLink(parentID, childID)
    local links = self:Profile().links
    if not links[parentID] then return end
    links[parentID][childID] = nil
    if not next(links[parentID]) then links[parentID] = nil end
    InvalidateRelationshipCache()
    self:InvalidateTargetTransition(childID)
    self:Wake()
end

function ns:CanAddLink(parentID, childID)
    if parentID == childID then return false, "A frame cannot link to itself." end
    local links = self:Profile().links
    local function Reaches(from, sought, seen)
        if from == sought then return true end
        if seen[from] then return false end
        seen[from] = true
        for nextID in pairs(links[from] or {}) do
            if Reaches(nextID, sought, seen) then return true end
        end
        return false
    end
    if Reaches(childID, parentID, {}) then return false, "That link would create a loop." end
    return true
end

function ns:AddLink(parentID, childID)
    local allowed, reason = self:CanAddLink(parentID, childID)
    if not allowed then return false, reason end
    local links = self:Profile().links
    links[parentID] = links[parentID] or {}
    links[parentID][childID] = true
    InvalidateRelationshipCache()
    self:InvalidateTargetTransition(childID)
    self:AddTarget(parentID)
    self:AddTarget(childID)
    return true
end

function ns:HasHoverConnection(id)
    local _, group = self:GetRevealGroup(id)
    return group ~= nil or next(self:GetLinkedChildren(id)) ~= nil or #self:GetLinkParents(id) > 0
end

function ns:RequiresUnconditionalMouseover(id)
    local _, group = self:GetRevealGroup(id)
    return group ~= nil
end

function ns:GetVisibilityChildren(parentID)
    return self:Profile().visibilityLinks[parentID] or {}
end

function ns:GetVisibilityParent(childID)
    return GetRelationshipIndices(self).visibilityParents[childID]
end

function ns:RemoveVisibilityLink(parentID, childID)
    local links = self:Profile().visibilityLinks
    if type(links[parentID]) ~= "table" then return end
    links[parentID][childID] = nil
    if not next(links[parentID]) then links[parentID] = nil end
    InvalidateRelationshipCache()
    self:InvalidateTargetTransition(childID)
    self:RefreshOptions()
end

function ns:CanAddVisibilityLink(parentID, childID)
    if parentID == childID then return false, "A frame cannot inherit its own visibility." end
    local links = self:Profile().visibilityLinks
    local function Reaches(from, sought, seen)
        if from == sought then return true end
        if seen[from] then return false end
        seen[from] = true
        for nextID in pairs(type(links[from]) == "table" and links[from] or {}) do
            if Reaches(nextID, sought, seen) then return true end
        end
        return false
    end
    if Reaches(childID, parentID, {}) then return false, "That visibility relationship would create a loop." end
    return true
end

function ns:AddVisibilityLink(parentID, childID)
    local allowed, reason = self:CanAddVisibilityLink(parentID, childID)
    if not allowed then return false, reason end
    local profile = self:Profile()
    local childWasManaged = profile.targets[childID] ~= nil
    self:AddTarget(parentID)
    self:AddTarget(childID)
    if not childWasManaged then
        -- A frame linked for the first time should genuinely follow its parent.
        -- The ordinary Mouseover/Combat starter rows would otherwise shadow
        -- inheritance immediately. Users can add deliberate local overrides
        -- afterward; already-configured children keep their existing rules.
        local childSettings = profile.targets[childID]
        childSettings.reactions = {}
        childSettings.cinematicMode = nil
        runtime.normalized[childSettings] = nil
    end
    local oldParent = self:GetVisibilityParent(childID)
    if oldParent and oldParent ~= parentID then self:RemoveVisibilityLink(oldParent, childID) end
    local links = profile.visibilityLinks
    links[parentID] = type(links[parentID]) == "table" and links[parentID] or {}
    links[parentID][childID] = true
    InvalidateRelationshipCache()
    self:InvalidateTargetTransition(childID)
    self:Wake()
    self:RefreshOptions()
    return true, childWasManaged
        and "Linked. Existing local rules still run before the parent."
        or "Linked as a clean follower. Add local rules only for exceptions."
end

function ns:EnsureConnectedHoverRules()
    local profile = self:Profile()
    local allSafe = true
    for id in pairs(profile.targets) do
        if self:RequiresUnconditionalMouseover(id) then
            local safe = self:EnsureMouseoverReaction(id)
            if not safe then allSafe = false end
        end
    end
    return allSafe
end

function ns:RestorePendingAlphas()
    if InCombatLockdown() then return end
    for frame in pairs(runtime.pendingRestore) do
        self:RestorePendingFrame(frame)
    end
end

function ns:RestorePendingFrame(frame)
    local pending = runtime.pendingRestore[frame]
    if pending == nil then return true end
    local baseAlpha, lastApplied
    if type(pending) == "table" then
        baseAlpha, lastApplied = pending.base, pending.lastApplied
    else
        -- Accept the scalar form left by older code paths during this session.
        baseAlpha, lastApplied = pending, nil
    end
    local current = SafeFrameAlpha(frame)
    if current ~= nil and lastApplied ~= nil and math.abs(current - lastApplied) > 0.001 then
        -- The host changed the frame while the restore was waiting (usually
        -- combat lockdown).  Do not overwrite that newer host-owned value.
        runtime.pendingRestore[frame] = nil
        runtime.baseAlpha[frame] = current
        runtime.currentAlpha[frame] = current
        runtime.managedAlphaAuditAt[frame] = GetTime()
        local release = runtime.pendingRelease[frame]
        runtime.pendingRelease[frame] = nil
        if release then pcall(release, frame) end
        return true
    end
    if SafeSetFrameAlpha(frame, baseAlpha) then
        runtime.pendingRestore[frame] = nil
        local release = runtime.pendingRelease[frame]
        runtime.pendingRelease[frame] = nil
        if release then pcall(release, frame) end
        return true
    end
    return false
end

function ns:HasReaction(settings, condition)
    for _, reaction in ipairs(settings.reactions or {}) do
        if reaction.condition == condition then return true end
    end
    return false
end

-- Shared read-only stand-in for missing lists in evaluator loops, which run
-- many times per second; `x or {}` there allocated a fresh table each time.
local NO_ENTRIES = {}

function ns:UsesCondition(settings, condition)
    for _, reaction in ipairs(settings.reactions or NO_ENTRIES) do
        if reaction.condition == condition then return true end
        for _, requirement in ipairs(reaction.requirements or NO_ENTRIES) do
            if requirement == condition then return true end
        end
    end
    return false
end

local function CollectNeededStateConditions(profile, needed)
    needed = ClearTable(needed or {})
    for _, settings in pairs(type(profile.targets) == "table" and profile.targets or {}) do
        if type(settings) == "table" and settings.enabled ~= false then
            for _, reaction in ipairs(type(settings.reactions) == "table" and settings.reactions or {}) do
                if type(reaction) == "table" and reaction.enabled ~= false then
                    if type(reaction.condition) == "string" then needed[reaction.condition] = true end
                    if (reaction.condition == "party_health" or reaction.condition == "party_mana")
                        and type(reaction.partyMember) == "number" and reaction.partyMember >= 1
                        and reaction.partyMember <= 5 and reaction.partyMember == math.floor(reaction.partyMember) then
                        needed.partyMembers = needed.partyMembers or {}
                        needed.partyMembers[reaction.partyMember] = true
                    end
                    for _, requirement in ipairs(type(reaction.requirements) == "table" and reaction.requirements or {}) do
                        if type(requirement) == "string" then needed[requirement] = true end
                    end
                end
            end
        end
    end
    return needed
end

local FISHING_SPELL_IDS = { [7620] = true, [7731] = true, [7732] = true, [18248] = true, [131474] = true }


-- Sample each requested unit/resource once per shared evaluator tick, never per frame.
-- Secret values must be discarded before any comparisons or arithmetic.
local function ReadUnitPercentage(unit, mana)
    if SafeBoolean(UnitExists, unit) ~= true then return nil end
    if unit ~= "player" and SafeBoolean(UnitIsConnected, unit) ~= true then return nil end
    local current, maximum
    if mana then
        maximum = SafeValue(UnitPowerMax, unit, 0)
        if type(maximum) == "number" and maximum <= 0 then return nil end
        local ok, value = pcall(UnitPower, unit, 0)
        if ok and IsSecret(value) then return { protectedPercentage = true, unit = unit, mana = true } end
        current = ok and value or nil
    else
        local ok, value = pcall(UnitHealth, unit)
        if ok and IsSecret(value) then return { protectedPercentage = true, unit = unit } end
        current, maximum = ok and value or nil, SafeValue(UnitHealthMax, unit)
    end
    if type(current) ~= "number" or type(maximum) ~= "number"
        or current ~= current or maximum ~= maximum or maximum <= 0
        or maximum == math.huge or current == math.huge or current < 0 then return nil end
    return math.min(100, current / maximum * 100)
end

-- Numbered selectors follow the actual compact party frame assignment, which
-- Blizzard can reorder. Unknown/secret assignments never fall back to another unit.
function ns:GetPartyMemberUnit(member)
    local ok, unit = pcall(function()
        local frame = _G["CompactPartyFrameMember" .. member]
            or (CompactPartyFrame and CompactPartyFrame.memberUnitFrames and CompactPartyFrame.memberUnitFrames[member])
        return frame and frame.unit
    end)
    if not ok or IsSecret(unit) or type(unit) ~= "string" then return nil end
    if unit == "player" or unit:match("^party[1-4]$") then return unit end
end

local PARTY_PERCENTAGE_CONDITIONS = { "party_health", "party_mana" }

function ns:BuildPercentageContext(needed, context)
    local samples = {}
    local function Read(unit, mana)
        local key = unit .. (mana and ":mana" or ":health")
        if samples[key] == nil then samples[key] = ReadUnitPercentage(unit, mana) or false end
        if samples[key] ~= false then return samples[key] end
    end
    if needed.player_health then context.player_health = Read("player", false) end
    if needed.player_mana then context.player_mana = Read("player", true) end
    if (needed.party_health or needed.party_mana) and SafeBoolean(IsInRaid) == false then
        context.partyMemberPercentages = {}
        for _, condition in ipairs(PARTY_PERCENTAGE_CONDITIONS) do
            if needed[condition] then
                local values, members = {}, {}
                local mana = condition == "party_mana"
                for index = 1, 4 do
                    local value = Read("party" .. index, mana)
                    if value ~= nil then values[#values + 1] = value end
                end
                for member in pairs(needed.partyMembers or {}) do
                    local unit = self:GetPartyMemberUnit(member)
                    if unit then members[member] = Read(unit, mana) end
                end
                context[condition], context.partyMemberPercentages[condition] = values, members
            end
        end
    end
end

function ns:PercentageConditionIsMet(condition, reaction)
    if not reaction then return false end
    local compare = PERCENTAGE_COMPARISONS[reaction.percentageOperator or "<"]
    local threshold = reaction.percentageThreshold
    if threshold == nil then threshold = 50 end
    if not compare or type(threshold) ~= "number" or threshold ~= threshold or threshold < 0 or threshold > 100 then return false end
    local value = self:GetPercentageContextValue(condition, reaction)
    if type(value) == "table" then
        for _, percentage in ipairs(value) do if type(percentage) == "number" and compare(percentage, threshold) then return true end end
        return false
    end
    return type(value) == "number" and compare(value, threshold) or false
end

function ns:BuildStateContext()
    if self.RefreshChatInput then self:RefreshChatInput() end
    if self.RefreshChatTextHooks then self:RefreshChatTextHooks() end
    if self.RefreshChatStack then self:RefreshChatStack() end
    local needed = CollectNeededStateConditions(self:Profile(), runtime.neededConditions)
    local context = runtime.context
    -- Form/spec lookups add short-lived caches while reactions are evaluated.
    -- Preserve their tables between ticks but clear their contents so changing
    -- forms or specialization remains observable without steady-state garbage.
    local formActivity, specActivity = context.formActivity, context.specActivity
    ClearTable(context)
    if formActivity then
        ClearTable(formActivity.known)
        ClearTable(formActivity.values)
        context.formActivity = formActivity
    end
    if specActivity then
        ClearTable(specActivity.known)
        ClearTable(specActivity.values)
        context.specActivity = specActivity
    end
    if needed.combat or needed.out_of_combat then
        -- The size and position combat-start pass runs just before lockdown.
        context.combat = runtime.layoutCombatStarting and true or SafeBoolean(InCombatLockdown)
        if context.combat ~= nil then context.out_of_combat = not context.combat end
    end
    local needsTarget = needed.target_any or needed.target or needed.no_target
        or needed.target_hostile or needed.hostile_target
        or needed.target_friendly or needed.target_dead
    if needsTarget then
        context.target_any = SafeBoolean(UnitExists, "target")
        context.target = context.target_any -- v0.1 alias
        if context.target_any ~= nil then context.no_target = not context.target_any end
        if context.target_any then
            if needed.target_hostile or needed.hostile_target then
                context.target_hostile = SafeBoolean(UnitCanAttack, "player", "target")
                context.hostile_target = context.target_hostile -- v0.1 alias
            end
            -- Friendly vendors/trainers need not be valid helpful-spell targets.
            if needed.target_friendly then context.target_friendly = SafeBoolean(UnitIsFriend, "player", "target") end
            if needed.target_dead then context.target_dead = SafeBoolean(UnitIsDeadOrGhost, "target") end
        end
    end
    if needed.movement or needed.moving or needed.stationary then
        local ok, speed = pcall(GetUnitSpeed, "player")
        if ok and not IsSecret(speed) and type(speed) == "number" then
            context.moving = speed > 0
            context.stationary = not context.moving
        end
    end
    if needed.falling then context.falling = SafeBoolean(IsFalling) end
    if needed.shift then context.shift = SafeBoolean(IsShiftKeyDown) end
    if needed.control then context.control = SafeBoolean(IsControlKeyDown) end
    if needed.alt then context.alt = SafeBoolean(IsAltKeyDown) end
    if needed.dead then context.dead = SafeBoolean(UnitIsDeadOrGhost, "player") end
    if needed.stealth then context.stealth = SafeBoolean(IsStealthed) end
    if needed.casting then context.casting = runtime.playerCasting == true end
    if needed.mounted then context.mounted = SafeBoolean(IsMounted) end
    if needed.flying then context.flying = SafeBoolean(IsFlying) end
    if needed.swimming then context.swimming = SafeBoolean(IsSwimming) end
    if needed.underwater then context.underwater = SafeBoolean(IsSubmerged) end
    if needed.vehicle then
        context.vehicle = SafeBoolean(UnitInVehicle, "player")
        if context.vehicle == false then context.vehicle = SafeBoolean(UnitHasVehicleUI, "player") end
    end
    if needed.taxi then context.taxi = SafeBoolean(UnitOnTaxi, "player") end
    if needed.pet_battle and C_PetBattles then context.pet_battle = SafeBoolean(C_PetBattles.IsInBattle) end
    if needed.fishing then
        local ok, name, _, _, _, _, _, spellID = pcall(UnitChannelInfo, "player")
        if ok and not IsSecret(spellID) and not IsSecret(name) then
            -- Classic ranks share the localized Fishing name; never persist it.
            local getter = C_Spell and C_Spell.GetSpellName or GetSpellInfo
            local nameOK, fishingName = pcall(getter, 7620)
            context.fishing = FISHING_SPELL_IDS[spellID] == true or (nameOK and not IsSecret(fishingName)
                and type(fishingName) == "string" and type(name) == "string" and name == fishingName)
        end
    end
    if needed.class_pet then context.class_pet = SafeBoolean(UnitExists, "pet") end
    if needed.cosmetic_pet and C_PetJournal and type(C_PetJournal.GetSummonedPetGUID) == "function" then
        local guid = SafeValue(C_PetJournal.GetSummonedPetGUID)
        context.cosmetic_pet = type(guid) == "string" and guid ~= ""
    end
    if needed.dragonriding and C_PlayerInfo then context.dragonriding = SafeBoolean(C_PlayerInfo.GetGlidingInfo) end
    if needed.delve and C_PartyInfo then
        local inProgress = type(C_PartyInfo.IsDelveInProgress) == "function" and SafeBoolean(C_PartyInfo.IsDelveInProgress) or nil
        local complete = type(C_PartyInfo.IsDelveComplete) == "function" and SafeBoolean(C_PartyInfo.IsDelveComplete) or nil
        if inProgress ~= nil or complete ~= nil then context.delve = inProgress == true or complete == true end
    end
    if needed.group or needed.raid or needed.solo then
        local inGroup = (needed.group or needed.solo) and SafeBoolean(IsInGroup) or nil
        local inRaid = (needed.group or needed.raid) and SafeBoolean(IsInRaid) or nil
        if needed.raid then context.raid = inRaid end
        if needed.group and inGroup ~= nil and inRaid ~= nil then context.group = inGroup and not inRaid end
        if needed.solo and inGroup ~= nil then context.solo = not inGroup end
    end
    local needsInstance = needed.instance or needed.open_world or needed.dungeon
        or needed.raid_instance or needed.battleground or needed.arena or needed.scenario
    if needsInstance then
        local instanceOK, inInstance, instanceType = pcall(IsInInstance)
        if instanceOK and not IsSecret(inInstance) and not IsSecret(instanceType) then
            context.instance = inInstance and true or false
            if inInstance then
                context.dungeon = instanceType == "party"
                context.raid_instance = instanceType == "raid"
                context.battleground = instanceType == "pvp"
                context.arena = instanceType == "arena"
                context.scenario = instanceType == "scenario"
            else
                context.open_world = true
            end
        end
    end
    if needed.resting then context.resting = SafeBoolean(IsResting) end
    if needed.pvp_flagged or needed.pvp then
        context.pvp_flagged = SafeBoolean(UnitIsPVP, "player")
        context.pvp = context.pvp_flagged -- v0.1 alias
    end
    if needed.war_mode and C_PvP then context.war_mode = SafeBoolean(C_PvP.IsWarModeDesired) end
    if needed.indoors then context.indoors = SafeBoolean(IsIndoors) end
    if needed.outdoors then context.outdoors = SafeBoolean(IsOutdoors) end
    self:BuildPercentageContext(needed, context)
    if self.BuildExtraConditionContext then self:BuildExtraConditionContext(needed, context) end
end

-- Returns nil when this entry cannot exist for the current class/spec.  That
-- is intentionally distinct from false (the form exists but is not active),
-- so a "Shadowform: No" row does not activate on a non-Shadow character.
function ns:GetFormActivity(formKey)
    local option = FORM_BY_ID[formKey]
    if not option then return nil end
    local context = runtime.context or {}
    context.formActivity = context.formActivity or { known = {}, values = {} }
    local cache = context.formActivity
    if cache.known[formKey] then return cache.values[formKey] end

    local classOK, _, classFile = pcall(UnitClass, "player")
    local result = nil
    if classOK and not IsSecret(classFile) and classFile == option.class then
        local countOK, count = pcall(GetNumShapeshiftForms)
        if countOK and not IsSecret(count) and type(count) == "number" then
            for index = 1, math.min(32, count) do
                local formOK, _, active, _, spellID = pcall(GetShapeshiftFormInfo, index)
                if formOK and not IsSecret(active) and not IsSecret(spellID) and (spellID == option.spellID or (option.alternateSpellID and spellID == option.alternateSpellID)) then
                    result = active == true
                    break
                end
            end
        end
    end
    cache.known[formKey], cache.values[formKey] = true, result
    return result
end

-- Returns nil for another class, a locked build, or an unreadable active group.
-- Talent allocation never implies a named Retail specialization.
function ns:GetSpecActivity(classID, specID)
    local option = SPEC_BY_ID[specID]
    if not option or option.class ~= classID then return nil end
    local context = runtime.context or {}
    context.specActivity = context.specActivity or { known = {}, values = {} }
    local cache = context.specActivity
    if cache.known[specID] then return cache.values[specID] end

    local classOK, _, classFile = pcall(UnitClass, "player")
    local result = nil
    if classOK and not IsSecret(classFile) and classFile == classID then
        local getter = C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup
        local groupOK, group = pcall(getter)
        local countOK, count = pcall(GetNumSpecGroups)
        if groupOK and not IsSecret(group) and (group == 1 or group == 2)
            and countOK and not IsSecret(count) and type(count) == "number"
            and count >= option.group and count >= group then
            result = group == option.group
        end
    end
    cache.known[specID], cache.values[specID] = true, result
    return result
end

function ns:ConditionIsMet(condition, id, reaction, isRequirement, evaluationNow)
    if self:IsPercentageCondition(condition) then
        return not isRequirement and self:PercentageConditionIsMet(condition, reaction) or false
    end
    if condition == "chat_typing" then return runtime.cinematicChatInput == true end
    if condition == "chat_text" then
        return not isRequirement and self.ChatTextConditionIsMet and self:ChatTextConditionIsMet(reaction, evaluationNow) or false
    end
    if CONDITION_INFO[condition] and CONDITION_INFO[condition].unsupported then return false end
    local requirementInfo = CONDITION_INFO[condition]
    if requirementInfo and requirementInfo.requirementCondition then
        if not self.GetGamepadConditionActivity then return false end
        local active = self:GetGamepadConditionActivity(requirementInfo.requirementCondition, id)
        return active ~= nil and active == requirementInfo.requirementExpected
    end
    if CONDITION_INFO[condition] and CONDITION_INFO[condition].gamepad then
        if isRequirement or not self.GetGamepadConditionActivity then return false end
        local active = self:GetGamepadConditionActivity(condition, id)
        return active ~= nil and active == (not reaction or reaction.gamepadExpected ~= false)
    end
    if condition == "mouseover" then return runtime.hovered[id] == true or self:IsConnectionHovered(id) end
    if condition == "form" then
        if isRequirement then return false end
        local active = self:GetFormActivity(reaction and reaction.formKey)
        return active ~= nil and active == (reaction.formExpected ~= false)
    end
    if condition == "movement" then
        if isRequirement then return false end
        local moving = runtime.context.moving
        return moving ~= nil and moving == (reaction.movementExpected ~= false)
    end
    if condition == "spec" then
        if isRequirement then return false end
        return self:GetSpecActivity(reaction and reaction.specClass, reaction and reaction.specID) == true
    end
    local info = CONDITION_INFO[condition]
    if info and info.kind == "moment" then
        local occurred = runtime.moments[condition]
        local duration = isRequirement and info.duration or reaction.duration or info.duration or 3
        return occurred and ((evaluationNow or GetTime()) - occurred) <= duration or false
    end
    -- A nil context value is deliberately unknown, never false.  In
    -- particular, negative rules never become accidentally true in secret UI.
    return runtime.context[condition] == true
end

function ns:ReactionIsMet(reaction, id, evaluationNow)
    if reaction.enabled == false then return false end
    if not self:ConditionIsMet(reaction.condition, id, reaction, nil, evaluationNow) then return false end
    for _, condition in ipairs(reaction.requirements or NO_ENTRIES) do
        if not self:ConditionIsMet(condition, id, reaction, true, evaluationNow) then return false end
    end
    return true
end

local LINKED_PARENT_HOVER_REACTION = { condition = "linked_parent_hover", opacity = 1, requirements = {}, linkedParent = true }

function ns:Evaluate(id, settings, seen, evaluationNow, outputScale)
    outputScale = outputScale or 1
    if self.EvaluateProtectedPercentages then
        local handled, alpha, index, reaction, inheritedFrom = self:EvaluateProtectedPercentages(id, settings, seen, evaluationNow, outputScale)
        if handled then return alpha, index, reaction, inheritedFrom end
    end
    -- Parent hover is an intrinsic part of a directional link. A child only
    -- needs its own Mouseover row when it should also reveal itself. Existing
    -- links retain their generated row and therefore keep their old behavior;
    -- removing that row opts into parent-only reveal.
    if not self:HasUnconditionalMouseover(settings) and self:IsLinkedParentHovered(id) then
        return outputScale, 0, LINKED_PARENT_HOVER_REACTION
    end
    for index, reaction in ipairs(settings.reactions or NO_ENTRIES) do
        -- A Keep opacity row changes only size or position.
        if reaction.keepOpacity ~= true and self:ReactionIsMet(reaction, id, evaluationNow) then
            return (reaction.opacity or 1) * outputScale, index, reaction
        end
    end
    seen = seen or {}
    if not seen[id] then
        seen[id] = true
        local parentID = self:GetVisibilityParent(id)
        local parentSettings = parentID and self:GetTargetSettings(parentID)
        if parentSettings and parentSettings.enabled ~= false and not seen[parentID] then
            local opacity, index, reaction, inheritedFrom = self:Evaluate(parentID, parentSettings, seen, evaluationNow, outputScale)
            return opacity, index, reaction, inheritedFrom or parentID
        end
    end
    return (settings.atRest or 0.12) * outputScale, nil, nil
end

function ns:GetUsableFrameRect(frame)
    if not frame then return end
    local shownOK, shown = pcall(CallFrameIsShown, frame)
    -- Retail can return secret values for a visible frame's geometry.  They
    -- are valid values, but addon Lua may not compare or do arithmetic with
    -- them. Treat just that frame as unreadable rather than aborting a whole
    -- on-screen discovery pass.
    if not shownOK or IsSecret(shown) then return end
    if shown ~= true and not (self.IsMinimapRendererSuppressed and self:IsMinimapRendererSuppressed(frame)) then return end
    local rectOK, left, bottom, width, height = pcall(CallFrameGetRect, frame)
    if not rectOK or IsSecret(left) or IsSecret(bottom) or IsSecret(width) or IsSecret(height)
        or type(left) ~= "number" or type(bottom) ~= "number"
        or type(width) ~= "number" or type(height) ~= "number"
        or left ~= left or bottom ~= bottom or width ~= width or height ~= height
        or math.abs(left) > 10000000 or math.abs(bottom) > 10000000
        or math.abs(width) > 10000000 or math.abs(height) > 10000000
        or width <= 0 or height <= 0 then return end
    -- GetRect uses the region's effective scale, while all consumers (picker,
    -- UIParent-anchored outlines, and cursor hit tests) use UIParent units.
    -- Include inherited/Edit Mode scaling, and convert position as well as
    -- size: converting only dimensions still displaces the hover rectangle.
    local frameScaleOK, frameScale = pcall(CallFrameGetEffectiveScale, frame)
    local uiScaleOK, uiScale = pcall(CallFrameGetEffectiveScale, UIParent)
    if not frameScaleOK or not uiScaleOK or IsSecret(frameScale) or IsSecret(uiScale)
        or type(frameScale) ~= "number" or type(uiScale) ~= "number"
        or frameScale ~= frameScale or uiScale ~= uiScale
        or frameScale <= 0 or uiScale <= 0
        or frameScale == math.huge or uiScale == math.huge then return end
    local scale = frameScale / uiScale
    left, bottom, width, height = left * scale, bottom * scale, width * scale, height * scale
    if left ~= left or bottom ~= bottom or width ~= width or height ~= height
        or math.abs(left) > 10000000 or math.abs(bottom) > 10000000
        or width > 10000000 or height > 10000000
        or width <= 0 or height <= 0 then return end
    return left, bottom, width, height
end

SafeFrameAlpha = function(frame)
    local ok, alpha = pcall(CallFrameGetAlpha, frame)
    if not ok or IsSecret(alpha) or type(alpha) ~= "number" or alpha ~= alpha or math.abs(alpha) > 1000 then return nil end
    return alpha
end

QueuePendingRestore = function(frame, baseAlpha, lastApplied, release)
    if not frame or (type(baseAlpha) ~= "number" and not (type(baseAlpha) == "table" and baseAlpha.opaqueAlpha)) then return end
    runtime.pendingRestore[frame] = {
        base = baseAlpha,
        lastApplied = type(lastApplied) == "number" and lastApplied or nil,
    }
    if release then
        runtime.pendingRelease[frame] = release
    else
        runtime.pendingRelease[frame] = nil
    end
end

local function SetManagedFrameAlpha(frame, alpha)
    runtime.managedAlphaGuard[frame] = true
    local ok = SafeSetFrameAlpha(frame, alpha)
    runtime.managedAlphaGuard[frame] = nil
    if ok then runtime.managedAlphaReadback[frame] = SafeFrameAlpha(frame) end
    return ok
end

local function ManagedHostAlphaChanged(frame, alpha)
    if runtime.managedAlphaGuard[frame] or runtime.cinematicAlphaGuard[frame] then return end
    local id = runtime.managedIDByFrame[frame]
    if not id or runtime.frameByID[id] ~= frame then return end
    if IsSecret(alpha) then
        runtime.baseAlpha[frame] = { opaqueAlpha = true, value = alpha }
        local protected = runtime.protectedAlpha[frame]
        local active = runtime.active[id]
        if protected then SetManagedFrameAlpha(frame, protected.value)
        elseif active and type(active.alpha) == "number" then SetManagedFrameAlpha(frame, active.alpha) end
        return
    end
    if type(alpha) ~= "number" or alpha ~= alpha then return end
    -- Preserve the host's newest alpha for eventual restoration, but keep the
    -- PF presentation as the top-level visibility layer while this target is
    -- controlled. This composes with addon repaints without editing their DB,
    -- scripts, layout, or styling state.
    runtime.baseAlpha[frame] = alpha
    runtime.currentAlpha[frame] = alpha
    runtime.managedAlphaReadback[frame] = SafeFrameAlpha(frame)
    runtime.managedAlphaAuditAt[frame] = GetTime()
    local active = runtime.active[id]
    local owned = active and active.alpha
    if runtime.protectedAlpha[frame] ~= nil then
        SetManagedFrameAlpha(frame, runtime.protectedAlpha[frame].value)
        return
    end
    if type(owned) == "number" and math.abs(alpha - owned) > 0.001
        and SetManagedFrameAlpha(frame, owned) then
        runtime.currentAlpha[frame] = owned
    end
end

local function IsAlphaAnimationFor(group, frame)
    local ok, animations = pcall(function() return { group:GetAnimations() } end)
    if not ok or type(animations) ~= "table" then return false end
    for _, animation in ipairs(animations) do
        local typeOK, kind = pcall(function() return animation:GetObjectType() end)
        if typeOK and kind == "Alpha" then
            local targetOK, animated = pcall(function() return animation:GetTarget() end)
            if not targetOK or animated == nil or animated == frame then return true end
        end
    end
    return false
end

-- A host fade animation ended: keep its final alpha as the host's value and
-- put the rule's opacity back at once (no wait, no fade).
local function HostAnimationEnded(frame)
    runtime.hostAnimating[frame] = nil
    local id = runtime.managedIDByFrame[frame]
    if not id or runtime.frameByID[id] ~= frame then return end
    local live = SafeFrameAlpha(frame)
    if live ~= nil then ManagedHostAlphaChanged(frame, live) end
    runtime.managedAlphaAuditAt[frame] = GetTime()
end

local function HookHostAlphaAnimations(frame)
    local ok, groups = pcall(function() return { frame:GetAnimationGroups() } end)
    if not ok or type(groups) ~= "table" then return end
    for _, group in ipairs(groups) do
        if not runtime.hostAnimationHooks[group] and IsAlphaAnimationFor(group, frame) then
            local hooked = pcall(function()
                group:HookScript("OnPlay", function()
                    if runtime.managedIDByFrame[frame] then runtime.hostAnimating[frame] = true; ns:Wake() end
                end)
                group:HookScript("OnFinished", function() HostAnimationEnded(frame) end)
                group:HookScript("OnStop", function() HostAnimationEnded(frame) end)
            end)
            runtime.hostAnimationHooks[group] = hooked or nil
        end
    end
end

-- While a host fade animation plays, keep writing the rule's opacity every
-- frame, in case the client lets the frame's own alpha win.
function ns:HoldAgainstHostAnimations()
    local frame = next(runtime.hostAnimating)
    while frame do
        local nextFrame = next(runtime.hostAnimating, frame)
        local id = runtime.managedIDByFrame[frame]
        local active = id and runtime.frameByID[id] == frame and runtime.active[id]
        if not active then
            runtime.hostAnimating[frame] = nil
        elseif type(active.alpha) == "number" and runtime.protectedAlpha[frame] == nil then
            local live = SafeFrameAlpha(frame)
            if live == nil or math.abs(live - active.alpha) > 0.001 then SetManagedFrameAlpha(frame, active.alpha) end
        end
        frame = nextFrame
    end
end

function ns:HookManagedFrameAlpha(frame)
    if not frame or runtime.managedAlphaHooks[frame] or InCombatLockdown() or type(hooksecurefunc) ~= "function" then return end
    if pcall(hooksecurefunc, frame, "SetAlpha", ManagedHostAlphaChanged) then
        runtime.managedAlphaHooks[frame] = true
        runtime.managedAlphaAuditAt[frame] = GetTime()
        HookHostAlphaAnimations(frame)
    end
end

function ns:FrameContainsCursor(frame, x, y)
    local left, bottom, width, height = self:GetUsableFrameRect(frame)
    if not left then return false end
    if type(x) ~= "number" or type(y) ~= "number" then
        local cursorOK, rawX, rawY = pcall(GetCursorPosition)
        local scaleOK, scale = pcall(function() return UIParent:GetEffectiveScale() end)
        if not cursorOK or not scaleOK or IsSecret(rawX) or IsSecret(rawY) or IsSecret(scale)
            or type(rawX) ~= "number" or type(rawY) ~= "number" or type(scale) ~= "number"
            or rawX ~= rawX or rawY ~= rawY or scale ~= scale or scale <= 0 then return false end
        x, y = rawX / scale, rawY / scale
    end
    return x >= left and x <= left + width and y >= bottom and y <= bottom + height
end

function ns:IsConnectionHovered(id)
    for _, memberID in ipairs(GetRelationshipIndices(self).hoverMembers[id] or NO_ENTRIES) do
        if runtime.hovered[memberID] then return true end
    end
    return self:IsLinkedParentHovered(id)
end

-- Called for every target on every evaluator tick. Walk the link ancestry with
-- reused scratch tables instead of a new closure and visited-set per call.
local ancestrySeen, ancestryStack = {}, {}
function ns:IsLinkedParentHovered(id)
    local linkParents = GetRelationshipIndices(self).linkParents
    if not linkParents[id] then return false end
    ClearTable(ancestrySeen)
    ancestrySeen[id] = true
    ancestryStack[1] = id
    local depth = 1
    while depth > 0 do
        local childID = ancestryStack[depth]
        ancestryStack[depth] = nil
        depth = depth - 1
        for _, parentID in ipairs(linkParents[childID] or NO_ENTRIES) do
            if runtime.hovered[parentID] then
                for index = depth, 1, -1 do ancestryStack[index] = nil end
                return true
            end
            if not ancestrySeen[parentID] then
                ancestrySeen[parentID] = true
                depth = depth + 1
                ancestryStack[depth] = parentID
            end
        end
    end
    return false
end

-- Hover checks and ApplyTarget both resolve every target in the same
-- evaluator tick. Reuse the first answer within one frame (GetTime is constant
-- for a frame), so each target's name/adapter lookup runs once per tick.
local resolvedStamp, resolvedKnown, resolvedFrames, resolvedTargets = nil, {}, {}, {}
local resolveCacheActive = false
function ns:ResolveTargetThisTick(id)
    if not resolveCacheActive then return self:ResolveTarget(id) end
    local now = GetTime()
    if resolvedStamp ~= now then
        resolvedStamp = now
        ClearTable(resolvedKnown); ClearTable(resolvedFrames); ClearTable(resolvedTargets)
    end
    if resolvedKnown[id] then return resolvedFrames[id], resolvedTargets[id] end
    local frame, target = self:ResolveTarget(id)
    resolvedKnown[id], resolvedFrames[id], resolvedTargets[id] = true, frame, target
    return frame, target
end

-- The cache is live only inside one evaluator tick; every tick starts empty.
function ns:BeginTargetResolveCache()
    resolvedStamp = nil
    resolveCacheActive = true
end

function ns:EndTargetResolveCache()
    resolveCacheActive = false
    resolvedStamp = nil
end

function ns:UpdateHover()
    local profile = self:Profile()
    local needed = ClearTable(runtime.hoverNeeded)
    for id, settings in pairs(profile.targets or NO_ENTRIES) do
        if settings.enabled and self:UsesCondition(settings, "mouseover") then needed[id] = true end
    end
    for _, group in pairs(profile.groups or NO_ENTRIES) do
        for memberID in pairs(group.members or NO_ENTRIES) do needed[memberID] = true end
    end
    for parentID in pairs(profile.links or NO_ENTRIES) do needed[parentID] = true end
    local cursorX, cursorY
    if next(needed) and self.GetUICursorPosition then
        cursorX, cursorY = self:GetUICursorPosition()
        if type(cursorX) ~= "number" or type(cursorY) ~= "number"
            or cursorX ~= cursorX or cursorY ~= cursorY then
            for id in pairs(profile.targets or {}) do runtime.hovered[id] = false end
            return
        end
    end
    for id, settings in pairs(profile.targets or NO_ENTRIES) do
        if settings.enabled and needed[id] then
            local frame = self:ResolveTargetThisTick(id)
            if frame and self.FrameInteractionContainsCursor then
                runtime.hovered[id] = self:FrameInteractionContainsCursor(frame, id == "minimap", cursorX, cursorY)
                if id == "minimap" and not runtime.hovered[id] and self.MinimapStackContainsCursor then
                    runtime.hovered[id] = self:MinimapStackContainsCursor(cursorX, cursorY)
                end
            else
                runtime.hovered[id] = frame and self:FrameContainsCursor(frame, cursorX, cursorY) or false
            end
            if not runtime.hovered[id] and self.FrameLayoutHoverContains then
                runtime.hovered[id] = self:FrameLayoutHoverContains(id, cursorX, cursorY)
            end
        else
            runtime.hovered[id] = false
        end
    end
end

local function SetActiveStatus(id, status)
    local state = runtime.active[id]
    if not state then state = {}; runtime.active[id] = state end
    state.alpha, state.desired, state.index, state.reaction, state.inheritedFrom = nil, nil, nil, nil, nil
    state.hostHidden, state.protected = nil, nil
    state.protectedPercentage = nil
    state.unavailable = status == "unavailable" or nil
    state.pendingRestore = status == "pendingRestore" or nil
    if status == "hostHidden" then state.hostHidden = true end
end

local function SetActiveResolved(id, alpha, desired, index, reaction, inheritedFrom, hostHidden, isProtected)
    local state = runtime.active[id]
    if not state then state = {}; runtime.active[id] = state end
    state.unavailable, state.pendingRestore = nil, nil
    state.protectedPercentage = nil
    state.alpha, state.desired, state.index = alpha, desired, index
    state.reaction, state.inheritedFrom = reaction, inheritedFrom
    state.hostHidden, state.protected = hostHidden == true, isProtected
end

local CINEMATIC_CHAT_INPUT_REACTION = {
    condition = "cinematic_chat_input",
    opacity = 1,
    requirements = {},
    label = "Typing in chat",
    internal = true,
}

local function HasConfiguredTypingRule(settings)
    for _, rule in ipairs(settings.reactions or NO_ENTRIES) do
        if rule.enabled ~= false then
            if rule.condition == "chat_typing" then return true end
            for _, requirement in ipairs(rule.requirements or NO_ENTRIES) do
                if requirement == "chat_typing" then return true end
            end
        end
    end
    return false
end

-- After the zoom nudge, how long the map stays at full opacity to redraw.
local MINIMAP_REDRAW_TIME = 0.5

function ns:ApplyTarget(id, tickNow)
    local settings = self:GetTargetSettings(id)
    if not settings or not settings.enabled then
        runtime.fadeOutStarted[id] = nil
        runtime.revealGoal[id] = nil
        runtime.transitions[id] = nil
        return
    end
    local frame, target = self:ResolveTargetThisTick(id)
    local previous = runtime.frameByID[id]
    if previous and previous ~= frame then self:RestoreControlledFrame(id) end
    if not frame then
        runtime.fadeOutStarted[id] = nil
        runtime.revealGoal[id] = nil
        runtime.transitions[id] = nil
        SetActiveStatus(id, "unavailable")
        return
    end
    -- Suite dialogs remain under their host's control throughout Cinematic,
    -- including explicit rules and windows created after the scene started.
    -- Releasing our lease preserves native fades instead of forcing alpha 1.
    if self:IsCinematicActive() and self.IsCinematicSuiteWindow and self:IsCinematicSuiteWindow(frame) then
        self:RestoreControlledFrame(id)
        runtime.immediateApply[id] = nil
        if self:RestorePendingFrame(frame) then
            local alpha = SafeFrameAlpha(frame)
            SetActiveResolved(id, alpha, alpha, nil, nil, nil, false, target and target.protected)
        else
            SetActiveStatus(id, "pendingRestore")
        end
        return
    end
    -- A profile switch may be waiting to restore this provider frame's old
    -- alpha. Do that first; never capture an old faded alpha as the new base.
    if not self:RestorePendingFrame(frame) then
        runtime.fadeOutStarted[id] = nil
        runtime.revealGoal[id] = nil
        runtime.transitions[id] = nil
        SetActiveStatus(id, "pendingRestore")
        return
    end
    if previous ~= frame and target and target.acquire then
        local acquired, usable = pcall(target.acquire, frame)
        if not acquired or usable == false then
            runtime.fadeOutStarted[id] = nil
            runtime.revealGoal[id] = nil
            runtime.transitions[id] = nil
            SetActiveStatus(id, "unavailable")
            return
        end
    end
    runtime.frameByID[id] = frame
    runtime.managedIDByFrame[frame] = id
    if not (target and target.skipManagedAlphaHook) then self:HookManagedFrameAlpha(frame) end
    local now = tickNow or GetTime()
    local desired, index, reaction, inheritedFrom = self:Evaluate(id, settings, nil, now)
    if self.IsGamepadEditingTarget and self:IsGamepadEditingTarget(id) then
        desired, index, reaction, inheritedFrom = 1, nil, nil, nil
        runtime.immediateApply[id] = true
    end
    if id == "chat" and self:IsCinematicActive() and runtime.cinematicChatInput
        and not HasConfiguredTypingRule(settings) then
        desired, index, reaction, inheritedFrom = 1, 0, CINEMATIC_CHAT_INPUT_REACTION, nil
    end
    local current = runtime.currentAlpha[frame]
    if current == nil then
        current = SafeFrameAlpha(frame)
        if current == nil then
            local ok, baseline = pcall(CallFrameGetAlpha, frame)
            if not ok or not IsSecret(baseline) then
                runtime.fadeOutStarted[id], runtime.revealGoal[id], runtime.transitions[id] = nil, nil, nil
                SetActiveStatus(id, "hostHidden")
                return
            end
            -- A child can inherit a protected alpha aspect from its parent.
            -- Preserve its opaque baseline for restoration, but still apply
            -- its own rule. Never treat unreadable opacity as hidden state.
            runtime.baseAlpha[frame] = { opaqueAlpha = true, value = baseline }
            current = 0
            if not IsSecret(desired) then
                if not SetManagedFrameAlpha(frame, desired) then SetActiveStatus(id, "unavailable"); return end
                current = desired
            end
        else
            runtime.baseAlpha[frame] = current
            if not runtime.everCaptured[frame] then
                runtime.everCaptured[frame] = true
                -- Only while loading: later (a frame added from the picker)
                -- the map is already drawn.
                if self:FrameContainsMinimap(frame) and not self:IsWorldSettled(now) then
                    runtime.captureHold[id] = true
                    self:NoteMinimapStartup("holding " .. tostring(id) .. " at full opacity")
                else
                    runtime.immediateApply[id] = true
                end
            end
        end
        runtime.currentAlpha[frame] = current
        runtime.managedAlphaAuditAt[frame] = now
    else
        -- A provider may have repainted alpha before its post-hook could be
        -- installed (for example, the frame first appeared during combat).
        -- Reconcile continuously until the post-hook is installed. Afterwards
        -- the hook observes host writes immediately, so a low-rate audit is
        -- enough to cover unusual native/provider changes without polling
        -- GetAlpha for every managed frame on every 20 Hz evaluator tick.
        -- Composite/semantic adapters marked skipManagedAlphaHook own their
        -- member reconciliation internally. Asking their proxy for live alpha
        -- here would repeat the same potentially multi-frame refresh at 20 Hz.
        local adapterOwnsAlpha = target and target.skipManagedAlphaHook
        local auditDue = not adapterOwnsAlpha and (not runtime.managedAlphaHooks[frame]
            or now - (runtime.managedAlphaAuditAt[frame] or 0) >= 1)
        if auditDue then
            runtime.managedAlphaAuditAt[frame] = now
            local live = SafeFrameAlpha(frame)
            if live ~= nil and math.abs(live - (runtime.managedAlphaReadback[frame] or current)) > 0.001 then
                runtime.baseAlpha[frame] = live
                runtime.managedAlphaReadback[frame] = live
                runtime.currentAlpha[frame] = live
                current = live
                runtime.transitions[id] = nil
                -- The host changed the alpha behind our back: put the rule's
                -- opacity back at once, like the SetAlpha hook does.
                runtime.immediateApply[id] = true
            end
        end
    end
    -- The minimap's frame stays at the host's opacity until the loading screen
    -- is gone and the map has drawn, then goes straight to its rule state
    -- (no wait, no fade).
    if runtime.captureHold[id] then
        if self:IsWorldSettled(now) and not runtime.minimapNudgedAt then
            -- Redraw the map while it is still at full opacity: the same zoom
            -- change that fixes an empty map by hand.
            runtime.minimapNudgedAt = now
            self:NoteMinimapStartup(self:NudgeMinimapZoom() and "zoom nudged at full opacity" or "zoom nudge unavailable")
        end
        if runtime.minimapNudgedAt and now >= runtime.minimapNudgedAt + MINIMAP_REDRAW_TIME then
            runtime.captureHold[id] = nil
            runtime.immediateApply[id] = true
            self:NoteMinimapStartup("released to the rule state")
        else
            runtime.fadeOutStarted[id], runtime.revealGoal[id], runtime.transitions[id] = nil, nil, nil
            SetActiveResolved(id, current, desired, index, reaction, inheritedFrom, false, target and target.protected)
            return
        end
    end
    -- Protected percentage results are display values, never Lua decisions.
    -- Keep them out of transition arithmetic, readback caches and editor text.
    if IsSecret(desired) then
        runtime.transitions[id], runtime.revealGoal[id], runtime.fadeOutStarted[id] = nil, nil, nil
        if SetManagedFrameAlpha(frame, desired) then
            runtime.protectedAlpha[frame] = { value = desired }
            SetActiveResolved(id, nil, nil, nil, nil, nil, false, target and target.protected)
            runtime.active[id].protectedPercentage = true
        else
            SetActiveStatus(id, "unavailable")
        end
        return
    elseif runtime.protectedAlpha[frame] ~= nil then
        -- The previous displayed alpha cannot be sampled for interpolation.
        -- A public rule (for example mouseover) takes over immediately.
        if not SetManagedFrameAlpha(frame, desired) then SetActiveStatus(id, "unavailable"); return end
        runtime.protectedAlpha[frame] = nil
        current, runtime.currentAlpha[frame] = desired, desired
        runtime.immediateApply[id] = true
    end
    -- A short-lived reveal is a complete visual action, not merely a sample
    -- of the condition's current value. Once opacity starts rising, finish at
    -- that rule's requested opacity even if Moving, Casting, Has target, etc.
    -- turns false first. Only then may the normal wait and fade-out begin.
    local revealGoal = runtime.revealGoal[id]
    if desired > current + 0.001 and (not revealGoal or desired > revealGoal.opacity + 0.001) then
        revealGoal = {
            opacity = desired,
            index = index,
            reaction = reaction,
            inheritedFrom = inheritedFrom,
        }
        runtime.revealGoal[id] = revealGoal
    end
    if revealGoal then
        -- A newly matching row above the committed row is still authoritative.
        -- This preserves the editor's first-match contract (for example a
        -- leading Mounted -> 0% suppressor) while an ended condition falling
        -- through to a later row/Otherwise still completes its reveal.
        local localRulePreemptsInherited = revealGoal.inheritedFrom and not inheritedFrom
        local earlierRulePreempts = inheritedFrom == revealGoal.inheritedFrom
            and index and revealGoal.index and index < revealGoal.index
        if desired < revealGoal.opacity and (localRulePreemptsInherited or earlierRulePreempts) then
            runtime.revealGoal[id] = nil
            revealGoal = nil
        end
    end
    if revealGoal then
        if current < revealGoal.opacity - 0.001 then
            if desired < revealGoal.opacity then
                desired = revealGoal.opacity
                index = revealGoal.index
                reaction = revealGoal.reaction
                inheritedFrom = revealGoal.inheritedFrom
            end
        else
            runtime.revealGoal[id] = nil
        end
    end
    if not SafeFrameShown(frame) then
        -- Prepare opacity while the host has the frame hidden. SetAlpha does
        -- not Show it, but it prevents a cast bar, transient window, or pooled
        -- addon frame from appearing bright for one tick (or for fadeDelay)
        -- when its owner later shows it.
        runtime.fadeOutStarted[id] = nil
        runtime.transitions[id] = nil
        if math.abs(current - desired) > 0.001 then
            if SetManagedFrameAlpha(frame, desired) then
                current = desired
                runtime.currentAlpha[frame] = desired
            end
        end
        SetActiveResolved(id, current, desired, index, reaction, inheritedFrom, true, target and target.protected)
        return
    end
    if runtime.immediateApply[id] then
        runtime.immediateApply[id] = nil
        runtime.fadeOutStarted[id] = nil
        runtime.revealGoal[id] = nil
        runtime.transitions[id] = nil
        if math.abs(current - desired) > 0.001 and SetManagedFrameAlpha(frame, desired) then
            current = desired
            runtime.currentAlpha[frame] = desired
        end
        SetActiveResolved(id, current, desired, index, reaction, inheritedFrom, false, target and target.protected)
        return
    end
    if desired < current and (settings.fadeDelay or 0) > 0 then
        -- Keep the start of this fade-out transition, not a frozen deadline.
        -- A timing edit explicitly invalidates this state and starts a fresh,
        -- predictable wait using the newly selected values.
        runtime.fadeOutStarted[id] = runtime.fadeOutStarted[id] or now
        if now < runtime.fadeOutStarted[id] + settings.fadeDelay then
            SetActiveResolved(id, current, desired, index, reaction, inheritedFrom, false, target and target.protected)
            return
        end
    else
        runtime.fadeOutStarted[id] = nil
    end
    -- Some semantic adapters expose a supported target-alpha authority while
    -- their host UI deliberately owns the physical animation. Request the
    -- final opacity once, after Frame Gambit's wait policy, instead of
    -- feeding that host a second competing interpolation.
    if target and target.timingOwner == "host" then
        runtime.transitions[id] = nil
        if math.abs(current - desired) > 0.001 and SetManagedFrameAlpha(frame, desired) then
            current = desired
            runtime.currentAlpha[frame] = desired
        end
        SetActiveResolved(id, current, desired, index, reaction, inheritedFrom, false, target.protected)
        return
    end
    -- Transitions are measured from a fixed starting point.  Repeatedly
    -- interpolating from the previous tick turns the duration into an easing
    -- time constant (a 1s setting took roughly 5s to settle).  An absolute
    -- transition makes the value in the UI the actual end-to-end duration and
    -- remains deterministic across frame-rate stalls.
    local transition = runtime.transitions[id]
    if math.abs(current - desired) <= 0.001 then
        runtime.transitions[id] = nil
    elseif not transition or transition.frame ~= frame or math.abs(transition.to - desired) > 0.001 then
        transition = { frame = frame, from = current, to = desired, startedAt = now,
            duration = math.max(0.01, (desired > current and settings.fadeInDuration or settings.fadeOutDuration) or settings.fadeDuration or 0.2) }
        runtime.transitions[id] = transition
    end
    local alpha = desired
    local transitionComplete = false
    if transition then
        local duration = math.max(0.01, (transition.to > transition.from and settings.fadeInDuration or settings.fadeOutDuration) or settings.fadeDuration or 0.2)
        local progress = math.min(1, math.max(0, (now - transition.startedAt) / duration))
        alpha = transition.from + (transition.to - transition.from) * progress
        if progress >= 1 then
            alpha = transition.to
            transitionComplete = true
        end
    end
    if math.abs(alpha - current) > 0.001 then
        local ok = SetManagedFrameAlpha(frame, alpha)
        if ok then
            runtime.currentAlpha[frame] = alpha
            if transitionComplete then runtime.transitions[id] = nil end
        else
            alpha = current
        end
    elseif transitionComplete then
        runtime.transitions[id] = nil
    end
    SetActiveResolved(id, alpha, desired, index, reaction, inheritedFrom, false, target and target.protected)
end

-- Advances opacity fades that are already running, once per game frame between
-- the 20 Hz evaluator ticks, so they are not drawn in 50 ms steps. Only the
-- interpolation is repeated: what to fade to, the wait before fading out and
-- every ownership check stay in ApplyTarget. A no-op unless a fade is running.
function ns:StepAlphaTransitions(now)
    local transitions = runtime.transitions
    local id, transition = next(transitions)
    while id do
        local nextID, nextTransition = next(transitions, id)
        local frame = transition.frame
        if frame and transition.duration and runtime.frameByID[id] == frame
            and runtime.managedIDByFrame[frame] == id and runtime.protectedAlpha[frame] == nil
            and runtime.currentAlpha[frame] ~= nil and SafeFrameShown(frame) then
            local progress = math.min(1, math.max(0, (now - transition.startedAt) / transition.duration))
            local alpha = progress >= 1 and transition.to or transition.from + (transition.to - transition.from) * progress
            if math.abs(alpha - runtime.currentAlpha[frame]) > 0.001 then
                if SetManagedFrameAlpha(frame, alpha) then
                    runtime.currentAlpha[frame] = alpha
                    if progress >= 1 then transitions[id] = nil end
                end
            elseif progress >= 1 then
                transitions[id] = nil
            end
        end
        id, transition = nextID, nextTransition
    end
end

-- True when the frame is, or contains, the minimap. The client only draws the
-- minimap terrain if it first renders at full opacity (found with
-- /fg minimapdebug: empty at 50%, drawn after a zoom at 100%), so such frames
-- keep the host's opacity until the world has drawn (captureHold), then snap
-- to their rule state.
local WORLD_DRAW_GRACE = 0.5

-- Change the minimap zoom one step and back so the client redraws its map.
function ns:NudgeMinimapZoom()
    local map = _G.Minimap
    if not map or type(map.GetZoom) ~= "function" or type(map.SetZoom) ~= "function" then return false end
    local ok, zoom = pcall(map.GetZoom, map)
    if not ok or IsSecret(zoom) or type(zoom) ~= "number" then return false end
    local levelsOK, levels = pcall(function() return map:GetZoomLevels() end)
    if not levelsOK or IsSecret(levels) or type(levels) ~= "number" then levels = 6 end
    local other = zoom + 1 < levels and zoom + 1 or zoom - 1
    if other < 0 or not pcall(map.SetZoom, map, other) then return false end
    C_Timer.After(0.1, function() pcall(map.SetZoom, map, zoom) end)
    return true
end

-- A short timeline of the minimap startup, kept in FrameGambitDB.minimapStartup
-- (last 12 lines) so a failed startup can be read from the saved variables.
function ns:NoteMinimapStartup(text)
    if type(FrameGambitDB) ~= "table" then return end
    local log = type(FrameGambitDB.minimapStartup) == "table" and FrameGambitDB.minimapStartup or {}
    FrameGambitDB.minimapStartup = log
    local map = _G.Minimap
    local alpha = map and type(map.GetEffectiveAlpha) == "function" and select(2, pcall(map.GetEffectiveAlpha, map))
    log[#log + 1] = string.format("%.2f %s (minimap alpha %s)", GetTime(), text,
        type(alpha) == "number" and not IsSecret(alpha) and string.format("%.2f", alpha) or "?")
    while #log > 12 do table.remove(log, 1) end
end

-- The loading screen is gone and the world has had a moment to draw.
function ns:IsWorldSettled(now)
    local ready = runtime.worldReadyAt
    return ready ~= nil and (now or GetTime()) >= ready + WORLD_DRAW_GRACE
end

function ns:FrameContainsMinimap(frame)
    local map = _G.Minimap
    if not map or not frame then return false end
    local current, depth = map, 0
    while current and depth < 20 do
        if current == frame then return true end
        local ok, parent = pcall(current.GetParent, current)
        current = ok and parent or nil
        depth = depth + 1
    end
    return false
end

-- skipLayout: settle opacity only. Login and loading screens use it; sizes and
-- positions are applied by the normal evaluator passes once the world is up.
function ns:PrimeProfileTargets(skipLayout)
    local now = GetTime()
    self:BuildStateContext()
    self:UpdateHover()
    local ids = {}
    for id in pairs(self:Profile().targets or {}) do
        -- Login and loading screens leave the minimap's frame alone (see
        -- FrameContainsMinimap).
        local frame = skipLayout and self:ResolveTarget(id)
        if not (frame and self:FrameContainsMinimap(frame)) then
            ids[#ids + 1] = id
            runtime.immediateApply[id] = true
        end
    end
    for _, id in ipairs(ids) do self:ApplyTarget(id, now) end
    if not skipLayout and self.UpdateFrameLayouts then self:UpdateFrameLayouts(now) end
end

function ns:PrimeCinematicTargets()
    if self:IsCinematicActive() then self:PrimeProfileTargets() end
end

local function HasRuntimeEntries(values)
    return type(values) == "table" and next(values) ~= nil
end

function ns:HasEvaluatorWork()
    -- This is intentionally conservative.  Any configured/enabled target
    -- keeps the evaluator alive for mouse, motion, moments and late adapter
    -- availability.  We only idle when there is literally no controlled UI,
    -- no Cinematic scene, and no unfinished ownership/transition work.
    if not FrameGambitDB then return true end
    if self:IsCinematicActive() then return true end
    local profile = self:Profile()
    for _, settings in pairs(type(profile.targets) == "table" and profile.targets or {}) do
        if type(settings) == "table" and settings.enabled ~= false then return true end
    end
    return HasRuntimeEntries(runtime.pendingRestore)
        or HasRuntimeEntries(runtime.pendingRelease)
        or HasRuntimeEntries(runtime.transitions)
        or HasRuntimeEntries(runtime.fadeOutStarted)
        or HasRuntimeEntries(runtime.revealGoal)
        or HasRuntimeEntries(runtime.immediateApply)
        or HasRuntimeEntries(runtime.cinematicBlackout)
        or (self.HasMinimapStackPendingWork and self:HasMinimapStackPendingWork())
        or (self.HasFrameLayoutWork and self:HasFrameLayoutWork())
        or runtime.cinematicScanPending == true
end

function ns:Sleep()
    if driver and driver:GetScript("OnUpdate") then driver:SetScript("OnUpdate", nil) end
end

function ns:Tick(elapsed)
    local now = GetTime()
    -- One shared, capped evaluator keeps the addon light even with several
    -- targets.  Alpha transitions remain smooth at 20 Hz without an OnUpdate
    -- handler per frame. Opacity, size and position transitions that are
    -- already running are advanced every frame in between (a no-op unless one
    -- is running), so they are not drawn in 20 Hz steps.
    if now - runtime.lastTick < 0.05 then
        self:StepAlphaTransitions(now)
        if next(runtime.hostAnimating) then self:HoldAgainstHostAnimations() end
        if self.StepFrameLayouts then self:StepFrameLayouts(now) end
        return
    end
    runtime.lastTick = now
    self:BeginTargetResolveCache()
    if now - runtime.lastMouseTick >= 0.08 then
        runtime.lastMouseTick = now
        self:UpdateHover()
    end
    self:BuildStateContext()
    local profile = self:Profile()
    for id in pairs(profile.targets or NO_ENTRIES) do self:ApplyTarget(id, now) end
    if next(runtime.hostAnimating) then self:HoldAgainstHostAnimations() end
    if self.UpdateFrameLayouts then self:UpdateFrameLayouts(now) end
    self:EndTargetResolveCache()
    if self.UpdateMinimapStack then
        local rescan = now - (runtime.lastMinimapStackScan or 0) >= 1
        if rescan then runtime.lastMinimapStackScan = now end
        self:UpdateMinimapStack(rescan)
    end
    if self:IsCinematicActive() then
        if not InCombatLockdown() and now - (runtime.cinematicRootScanAt or 0) >= 2.5 then
            self:BeginCinematicBlackout()
        else
            self:UpdateCinematicBlackout()
        end
    end
    if self.Options and self.Options:IsVisible() then self:RefreshActiveState() end
    -- An empty profile should not keep a 20 Hz evaluator alive forever.  All
    -- game events, editor mutations, profile selection and late addon loads
    -- already call Wake(), so this does not trade correctness for idling.
    if not self:HasEvaluatorWork() then self:Sleep() end
end

local function SafeDiagnosticText(text)
    text = tostring(text or ""):gsub("|", "||"):gsub("[\r\n]", " ")
    if #text > 240 then text = text:sub(1, 237) .. "..." end
    return text
end

local function DiagnosticID(value)
    return SafeDiagnosticText(value):sub(1, 72)
end

local function DiagnosticMessage(text, color)
    local target = DEFAULT_CHAT_FRAME
    if target and target.AddMessage then target:AddMessage("|cff9D75FFFrame Gambit|r " .. SafeDiagnosticText(text), color and color[1], color and color[2], color and color[3]) end
end

function ns:RunDiagnostics()
    local db = FrameGambitDB
    local profile = db and db.profiles and db.profiles[db.profile]
    if type(profile) ~= "table" then
        DiagnosticMessage("No active profile is loaded. Use /reload, then run the audit again.", self.COLORS.amber)
        return
    end
    local targets = type(profile.targets) == "table" and profile.targets or {}
    local groups = type(profile.groups) == "table" and profile.groups or {}
    local links = type(profile.links) == "table" and profile.links or {}
    local visibilityLinks = type(profile.visibilityLinks) == "table" and profile.visibilityLinks or {}
    local configured, configuredAvailable, groupCount, linkCount, visibilityCount = 0, 0, 0, 0, 0
    local issues, groupMembers, connected = {}, {}, {}
    if profile.targets ~= targets then issues[#issues + 1] = "Frame settings are invalid." end
    if profile.groups ~= groups then issues[#issues + 1] = "Reveal-group settings are invalid." end
    if profile.links ~= links then issues[#issues + 1] = "Linked-frame settings are invalid." end
    if profile.visibilityLinks ~= visibilityLinks then issues[#issues + 1] = "Visibility-child settings are invalid." end
    for id, settings in pairs(targets) do
        configured = configured + 1
        if type(id) ~= "string" then
            issues[#issues + 1] = "A saved frame has an invalid identifier."
        else
            local available = self:GetTargetAvailability(id)
            if available then configuredAvailable = configuredAvailable + 1 end
            if not self.TargetByID[id] then issues[#issues + 1] = "Saved frame " .. DiagnosticID(id) .. " is no longer available." end
            if type(settings) ~= "table" or settings.enabled ~= true then issues[#issues + 1] = "Saved frame " .. DiagnosticID(id) .. " has invalid settings." end
        end
    end
    for groupID, group in pairs(groups) do
        groupCount = groupCount + 1
        local members = 0
        local memberTable = type(group) == "table" and type(group.members) == "table" and group.members or {}
        if type(group) ~= "table" or group.members ~= memberTable then issues[#issues + 1] = "Reveal group " .. DiagnosticID(groupID) .. " has invalid settings." end
        for id in pairs(memberTable) do
            members = members + 1
            if type(id) ~= "string" then
                issues[#issues + 1] = "A reveal-group member has an invalid identifier."
            elseif groupMembers[id] then
                issues[#issues + 1] = "Target " .. DiagnosticID(id) .. " appears in multiple reveal groups."
            end
            groupMembers[id] = groupID
            if type(id) == "string" then
                connected[id] = true
                if not targets[id] then issues[#issues + 1] = "Reveal group " .. DiagnosticID(groupID) .. " includes a frame with no rules." end
            end
        end
        if members < 2 then issues[#issues + 1] = "Reveal group " .. DiagnosticID(groupID) .. " has fewer than two frames." end
    end
    for parentID, children in pairs(links) do
        local childTable = type(children) == "table" and children or {}
        if type(parentID) ~= "string" then
            issues[#issues + 1] = "A linked parent has an invalid identifier."
        else
            if not targets[parentID] then issues[#issues + 1] = "Linked parent " .. DiagnosticID(parentID) .. " has no rules." end
        end
        if children ~= childTable then issues[#issues + 1] = "Linked children for " .. DiagnosticID(parentID) .. " have invalid settings." end
        for childID in pairs(childTable) do
            linkCount = linkCount + 1
            if type(childID) ~= "string" then
                issues[#issues + 1] = "A linked child has an invalid identifier."
            else
                if childID == parentID then issues[#issues + 1] = "Link " .. DiagnosticID(parentID) .. " points to itself." end
                if not targets[childID] then issues[#issues + 1] = "Linked child " .. DiagnosticID(childID) .. " has no rules." end
            end
        end
    end
    local visiting, visited = {}, {}
    local function HasLinkCycle(id)
        if visiting[id] then return true end
        if visited[id] then return false end
        visiting[id] = true
        for childID in pairs(type(links[id]) == "table" and links[id] or {}) do
            if HasLinkCycle(childID) then return true end
        end
        visiting[id] = nil; visited[id] = true
        return false
    end
    for parentID in pairs(links) do
        if HasLinkCycle(parentID) then
            issues[#issues + 1] = "Linked frames contain a loop."
            break
        end
    end
    local visibilityParent = {}
    for parentID, children in pairs(visibilityLinks) do
        local childTable = type(children) == "table" and children or {}
        if type(parentID) ~= "string" then
            issues[#issues + 1] = "A visibility parent has an invalid identifier."
        elseif not targets[parentID] then
            issues[#issues + 1] = "Visibility parent " .. DiagnosticID(parentID) .. " has no rules."
        end
        if children ~= childTable then issues[#issues + 1] = "Visibility children for " .. DiagnosticID(parentID) .. " have invalid settings." end
        for childID, enabled in pairs(childTable) do
            visibilityCount = visibilityCount + 1
            if type(childID) ~= "string" or enabled ~= true then
                issues[#issues + 1] = "A visibility child has invalid settings."
            else
                if childID == parentID then issues[#issues + 1] = "Visibility parent " .. DiagnosticID(parentID) .. " points to itself." end
                if not targets[childID] then issues[#issues + 1] = "Visibility child " .. DiagnosticID(childID) .. " has no rules." end
                if visibilityParent[childID] and visibilityParent[childID] ~= parentID then
                    issues[#issues + 1] = "Visibility child " .. DiagnosticID(childID) .. " has more than one parent."
                else
                    visibilityParent[childID] = parentID
                end
            end
        end
    end
    local visibilityVisiting, visibilityVisited = {}, {}
    local function HasVisibilityCycle(id)
        if visibilityVisiting[id] then return true end
        if visibilityVisited[id] then return false end
        visibilityVisiting[id] = true
        for childID in pairs(type(visibilityLinks[id]) == "table" and visibilityLinks[id] or {}) do
            if HasVisibilityCycle(childID) then return true end
        end
        visibilityVisiting[id] = nil; visibilityVisited[id] = true
        return false
    end
    for parentID in pairs(visibilityLinks) do
        if HasVisibilityCycle(parentID) then
            issues[#issues + 1] = "Visibility children contain a loop."
            break
        end
    end
    for id in pairs(connected) do
        local settings, hasMouseover = targets[id], false
        for _, reaction in ipairs(type(settings) == "table" and type(settings.reactions) == "table" and settings.reactions or {}) do
            if type(reaction) == "table" and reaction.condition == "mouseover" and #(type(reaction.requirements) == "table" and reaction.requirements or {}) == 0 then hasMouseover = true; break end
        end
        if not hasMouseover then issues[#issues + 1] = "Reveal-group member " .. DiagnosticID(id) .. " lacks an unconditional Mouseover reaction." end
    end
    local adapterAvailable, adapterUnavailable, unavailable = 0, 0, {}
    for _, target in ipairs(self.Targets) do
        local available, _, _, note = self:GetTargetAvailability(target)
        if available then
            adapterAvailable = adapterAvailable + 1
        else
            adapterUnavailable = adapterUnavailable + 1
            unavailable[#unavailable + 1] = DiagnosticID(target.label) .. " - " .. DiagnosticID(note)
        end
    end
    DiagnosticMessage("v" .. self.VERSION .. " | Profile: " .. (db.profile or "Default"), self.COLORS.teal)
    DiagnosticMessage("Managed frames: " .. configuredAvailable .. "/" .. configured .. " available | Relationships: " .. groupCount .. " groups, " .. linkCount .. " hover links, " .. visibilityCount .. " visibility links.", self.COLORS.muted)
    DiagnosticMessage("Known frames: " .. adapterAvailable .. " available, " .. adapterUnavailable .. " unavailable.", adapterUnavailable > 0 and self.COLORS.amber or self.COLORS.teal)
    if #issues == 0 then
        DiagnosticMessage("Profile data looks healthy.", self.COLORS.teal)
    else
        DiagnosticMessage("Profile data needs attention: " .. #issues .. " issue" .. (#issues == 1 and "" or "s") .. ".", self.COLORS.amber)
        for index = 1, math.min(4, #issues) do DiagnosticMessage("- " .. issues[index], self.COLORS.amber) end
        if #issues > 4 then DiagnosticMessage("- " .. (#issues - 4) .. " more issue(s); export before changing anything.", self.COLORS.amber) end
    end
    for index = 1, math.min(6, #unavailable) do DiagnosticMessage("Waiting: " .. unavailable[index], self.COLORS.muted) end
    if #unavailable > 6 then DiagnosticMessage("Waiting: " .. (#unavailable - 6) .. " more frame(s).", self.COLORS.muted) end
end

local function RefreshPlayerCastingState()
    local ok, casting = pcall(function()
        local castName
        if type(UnitCastingInfo) == "function" then castName = UnitCastingInfo("player") end
        if IsSecret(castName) then return nil end
        if castName ~= nil then return true end
        local channelName
        if type(UnitChannelInfo) == "function" then channelName = UnitChannelInfo("player") end
        if IsSecret(channelName) then return nil end
        return channelName ~= nil
    end)
    if ok and not IsSecret(casting) and casting ~= nil then runtime.playerCasting = casting == true end
end

local function UpdatePlayerXP(trigger)
    local ok, xp = pcall(function() return UnitXP("player") end)
    if not ok or IsSecret(xp) or type(xp) ~= "number" or xp ~= xp or xp < 0 then
        runtime.playerXP = nil
        return
    end
    if trigger and runtime.playerXP ~= nil and xp > runtime.playerXP then
        runtime.moments.xp_gained = GetTime()
    end
    runtime.playerXP = xp
end

-- Forever omits some Retail events. A rejected event must not abort addon load.
local function RegisterSupportedEvent(frame, event, unit)
    if C_EventUtils and type(C_EventUtils.IsEventValid) == "function" then
        local ok, valid = pcall(C_EventUtils.IsEventValid, event)
        if not ok or IsSecret(valid) or not valid then return false end
    end
    if unit then return pcall(frame.RegisterUnitEvent, frame, event, unit) end
    return pcall(frame.RegisterEvent, frame, event)
end

driver = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_LOGIN",
    "ADDON_ACTION_BLOCKED",
    "ADDON_ACTION_FORBIDDEN",
    "PLAYER_XP_UPDATE",
    "PLAYER_LEVEL_UP",
    "INPUT_DEVICE_INTERFACE_TRANSITION",
    "PLAYER_LOGOUT",
    "ADDON_LOADED",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "PLAYER_TARGET_CHANGED",
    "GROUP_ROSTER_UPDATE",
    "PLAYER_MOUNT_DISPLAY_CHANGED",
    "PLAYER_ENTERING_WORLD",
    "LOADING_SCREEN_ENABLED",
    "LOADING_SCREEN_DISABLED",
    "ZONE_CHANGED",
    "ZONE_CHANGED_INDOORS",
    "PLAYER_FLAGS_CHANGED",
    "PLAYER_PVP_FLAG_CHANGED",
    "PLAYER_DEAD",
    "PLAYER_ALIVE",
    "PLAYER_UNGHOST",
    "UNIT_ENTERED_VEHICLE",
    "UNIT_EXITED_VEHICLE",
    "PET_BATTLE_OPENING_START",
    "PET_BATTLE_CLOSE",
    "CHAT_MSG_LOOT",
    "CHAT_MSG_CHANNEL",
    "CHAT_MSG_SYSTEM",
    "CHAT_MSG_ACHIEVEMENT",
    "CHAT_MSG_BN_INLINE_TOAST_ALERT",
    "UPDATE_BINDINGS",
    "UNIT_PET",
    "COMPANION_UPDATE",
    "SCENARIO_UPDATE",
    "UPDATE_SHAPESHIFT_FORM",
    "UPDATE_SHAPESHIFT_FORMS",
    "PLAYER_SPECIALIZATION_CHANGED",
    "SPELLS_CHANGED",
    "ACTIVE_TALENT_GROUP_CHANGED",
    "PLAYER_TALENT_UPDATE",
    "TRAIT_CONFIG_UPDATED",
}) do RegisterSupportedEvent(driver, event) end
for _, event in ipairs({
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_FAILED_QUIET",
    "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_AURA",
    "UNIT_SPELLCAST_EMPOWER_START",
    "UNIT_SPELLCAST_EMPOWER_STOP",
}) do RegisterSupportedEvent(driver, event, "player") end
for event in pairs(EVENT_TO_MOMENT) do RegisterSupportedEvent(driver, event) end

-- Memoized "^UNIT_SPELLCAST_" test: each event name is pattern-matched once.
local PLAYER_SPELLCAST_EVENTS = setmetatable({}, { __index = function(cache, event)
    local matched = type(event) == "string" and event:match("^UNIT_SPELLCAST_") ~= nil
    rawset(cache, event, matched)
    return matched
end })

function ns:Wake()
    if not driver:GetScript("OnUpdate") then
        driver:SetScript("OnUpdate", function(_, elapsed) ns:Tick(elapsed) end)
    end
end

driver:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        local addon, action = ...
        if IsSecret(addon) or addon ~= ADDON or IsSecret(action) or type(action) ~= "string" then return end
        if type(FrameGambitDB) ~= "table" then return end
        local records = FrameGambitDB.blockedActions
        if type(records) ~= "table" then records = {}; FrameGambitDB.blockedActions = records end
        local stack = type(debugstack) == "function" and SafeValue(debugstack, 2, 12, 0) or nil
        records[#records + 1] = { event = event, action = action:sub(1, 256),
            stack = type(stack) == "string" and stack:sub(1, 3000) or nil, cinematic = ns:IsCinematicActive() == true }
        while #records > 5 do table.remove(records, 1) end
        return
    end
    if event == "LOADING_SCREEN_ENABLED" then
        runtime.worldReadyAt = nil
        runtime.loadingScreenSeen = true
    elseif event == "LOADING_SCREEN_DISABLED" then
        runtime.worldReadyAt = GetTime()
        runtime.loadingScreenSeen = true
        ns:NoteMinimapStartup("loading screen gone")
    elseif event == "PLAYER_ENTERING_WORLD" and not runtime.worldReadyAt then
        -- Only a safety net if the loading-screen event never arrives. It must
        -- not end the hold while the loading screen is still up, so it is long.
        local token = {}
        runtime.worldFallbackToken = token
        C_Timer.After(10, function()
            if runtime.worldFallbackToken == token and not runtime.worldReadyAt then
                runtime.worldReadyAt = GetTime()
                ns:NoteMinimapStartup("fallback: no loading-screen event")
                ns:Wake()
            end
        end)
    end
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        -- Establish a baseline without treating login or zoning as XP gains.
        UpdatePlayerXP(false)
        -- The game refreshes the quest log while logging in, reloading and
        -- zoning. That is not a quest update: ignore those refreshes for a few
        -- seconds and forget any that arrived during loading.
        runtime.settleUntil = GetTime() + 6
        runtime.moments.quest_update, runtime.moments.quest_objective = nil, nil
    elseif event == "PLAYER_XP_UPDATE" then
        local unit = ...
        if IsSecret(unit) or unit ~= "player" then return end
        UpdatePlayerXP(true)
    elseif event == "PLAYER_LEVEL_UP" then
        -- XP rolls over on level-up, so a simple increase check misses it.
        local level = ...
        if not IsSecret(level) and type(level) == "number" and level > 0 then
            runtime.moments.xp_gained = GetTime()
        end
        UpdatePlayerXP(false)
    end
    if event == "INPUT_DEVICE_INTERFACE_TRANSITION" then
        -- Read after native event handling has settled; no native callbacks.
        if not runtime.inputProfileRefreshQueued then
            runtime.inputProfileRefreshQueued = true
            C_Timer.After(0, function()
                runtime.inputProfileRefreshQueued = nil
                if runtime.inputProfilesReady then ns:RefreshInputModeProfile() end
            end)
        end
        return
    end
    if ns.RefreshGamepadIntegration and (event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD") then
        ns:RefreshGamepadIntegration()
    elseif ns.RefreshGamepadIntegration and event == "ADDON_LOADED" and not runtime.gamepadRefreshQueued then
        -- Addons load in bursts (EllesmereUI alone is 21 modules); one refresh
        -- after the burst sees them all.
        runtime.gamepadRefreshQueued = true
        C_Timer.After(0, function()
            runtime.gamepadRefreshQueued = nil
            ns:RefreshGamepadIntegration()
        end)
    end
    if event == "PLAYER_LOGOUT" then
        if ns.ReleaseCinematicCamera then ns:ReleaseCinematicCamera() end
        if ns.ReleaseAllFrameLayouts then ns:ReleaseAllFrameLayouts() end
        return
    end
    if event == "PLAYER_REGEN_DISABLED" and ns.OnLayoutCombatStart then
        ns:OnLayoutCombatStart()
    end
    if event == "UNIT_AURA" then
        local unit = ...
        -- Stealth/invisibility changes are player-only for this addon.  Do
        -- not wake the shared evaluator for every party/nameplate aura.
        if type(unit) ~= "string" or IsSecret(unit) or unit ~= "player" then return end
    end
    if event == "PLAYER_ENTERING_WORLD" then
        if ns.RefreshCinematicCamera then ns:RefreshCinematicCamera() end
    end
    if PLAYER_SPELLCAST_EVENTS[event] then
        local unit = ...
        if type(unit) == "string" and not IsSecret(unit) and unit == "player" then
            if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START"
                or event == "UNIT_SPELLCAST_EMPOWER_START" then
                runtime.playerCasting = true
            elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED"
                or event == "UNIT_SPELLCAST_FAILED_QUIET" or event == "UNIT_SPELLCAST_INTERRUPTED"
                or event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_EMPOWER_STOP" then
                runtime.playerCasting = false
            end
            -- Some stop/start pairs arrive in the same update (for example when a
            -- normal cast flows into a channel). Re-read on the next frame so the
            -- condition reflects the player's final casting state, not event order.
            C_Timer.After(0, RefreshPlayerCastingState)
        end
    end
    if event == "PLAYER_LOGIN" then
        if ns.CaptureStorageStage then ns.CaptureStorageStage("preLogin") end
        FrameGambitDB = type(FrameGambitDB) == "table" and FrameGambitDB or {}
        FrameGambitDB = CopyDefaults(DEFAULTS, FrameGambitDB)
        ns:MigrateDatabase()
        if ns.ApplyAppearanceTheme then ns:ApplyAppearanceTheme(ns:GetAppearanceTheme()) end
        ns:MigrateLegacyCinematicBinding()
        if ns.RegisterStoredCustomFrames then ns:RegisterStoredCustomFrames() end
        ns:EnsureCinematicProfile()
        if ns.RefreshCinematicLetterbox then ns:RefreshCinematicLetterbox() end
        if ns.RefreshCinematicCamera then ns:RefreshCinematicCamera() end
        if ns.RefreshOPieFrames then ns:RefreshOPieFrames() end
        ns:EnsureConnectedHoverRules()
        RefreshPlayerCastingState()
        ns:Wake()
        -- Build the editor and its skin only on first use.
        runtime.inputProfilesReady = true
        ns:RefreshInputModeProfile(true)
        if ns:IsCinematicActive() then
            ns:PrimeCinematicTargets()
            ns:BeginCinematicBlackout()
        else
            -- Frames that already exist start in their rule state, not at
            -- full opacity until the first evaluator tick.
            ns:PrimeProfileTargets(true)
        end
        return
    end
    if event == "ADDON_LOADED" then
        if ns.RefreshOPieFrames then ns:RefreshOPieFrames() end
        if ns:IsCinematicActive() and not InCombatLockdown() then
            -- Load-on-demand addons often arrive in bursts. Coalesce them so
            -- Cinematic discovers their roots once after the burst instead of
            -- rescanning the entire UI twice for every ADDON_LOADED event.
            runtime.cinematicRescanToken = (runtime.cinematicRescanToken or 0) + 1
            local token = runtime.cinematicRescanToken
            C_Timer.After(0.35, function()
                if token == runtime.cinematicRescanToken and ns:IsCinematicActive()
                    and not InCombatLockdown() then ns:BeginCinematicBlackout() end
            end)
        end
    end
    if event == "PLAYER_ENTERING_WORLD" then
        RefreshPlayerCastingState()
        if runtime.inputProfilesReady then
            ns:RefreshInputModeProfile()
            -- Loading screens create and repaint frames: settle them now.
            if not ns:IsCinematicActive() then ns:PrimeProfileTargets(true) end
        end
    end
    if ns.CancelPicker and (event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_ENTERING_WORLD" or event == "PET_BATTLE_OPENING_START") then
        ns:CancelPicker(event == "PLAYER_REGEN_DISABLED" and "combat" or "interrupted")
    end
    if event == "PLAYER_REGEN_DISABLED" and ns.OnTutorialCombatStateChanged then
        ns:OnTutorialCombatStateChanged(true)
    elseif event == "PLAYER_REGEN_ENABLED" and ns.OnTutorialCombatStateChanged then
        ns:OnTutorialCombatStateChanged(false)
    elseif (event == "PLAYER_ENTERING_WORLD" or event == "PET_BATTLE_OPENING_START") and ns.CancelTutorial then
        ns:CancelTutorial("interrupted")
    end
    if event == "PLAYER_REGEN_DISABLED" and ns.CinematicKeyCapture and ns.CinematicKeyCapture:IsShown() then
        ns.CinematicKeyCapture:Hide()
    end
    if event == "CHAT_MSG_LOOT" and IsLocalLootMessage(select(2, ...), select(12, ...)) then
        runtime.moments.loot = GetTime()
    end
    if event == "CHAT_MSG_CHANNEL" then
        -- The seventh argument is the channel type, not the player's channel
        -- number (eighth argument). General stays type 1 across zones/locales
        -- even when the player joins it under a different chat number.
        local channelType = select(7, ...)
        if not IsSecret(channelType) and channelType == 1 then
            runtime.moments.chat_general = GetTime()
        end
    end
    if (event == "CHAT_MSG_ACHIEVEMENT" or event == "CHAT_MSG_GUILD_ACHIEVEMENT")
        and IsGroupAchievementSender(select(12, ...)) then
        runtime.moments.chat_group = GetTime()
    end
    if event == "CHAT_MSG_SYSTEM" then
        local message = ...
        if MatchesFriendNotification(message, ERR_FRIEND_ONLINE_SS)
            or MatchesFriendNotification(message, ERR_FRIEND_OFFLINE_S) then
            runtime.moments.chat_friend_status = GetTime()
        end
    elseif event == "CHAT_MSG_BN_INLINE_TOAST_ALERT" then
        local notification = ...
        if not IsSecret(notification) and (notification == "FRIEND_ONLINE" or notification == "FRIEND_OFFLINE") then
            runtime.moments.chat_friend_status = GetTime()
        end
    end
    local moment = EVENT_TO_MOMENT[event]
    if (event == "QUEST_LOG_UPDATE" or event == "QUEST_WATCH_UPDATE")
        and (not runtime.settleUntil or GetTime() < runtime.settleUntil) then
        moment = nil
    end
    if type(moment) == "table" then
        local now = GetTime()
        for _, momentID in ipairs(moment) do runtime.moments[momentID] = now end
    elseif moment then
        runtime.moments[moment] = GetTime()
    end
    if event == "PLAYER_REGEN_ENABLED" then
        ns:RestorePendingAlphas()
        if ns:IsCinematicActive() then ns:BeginCinematicBlackout() end
    end
    if event == "PLAYER_ENTERING_WORLD" and ns:IsCinematicActive() and not InCombatLockdown() then
        ns:BeginCinematicBlackout()
    end
    if event == "UPDATE_BINDINGS" and ns.Options and ns.Options:IsShown() then
        ns:RenderOptions()
    end
    ns:Wake()
    -- The option panel updates its live-state chip from Tick.  Rebuilding its
    -- dynamic rows for every game event would continually create hidden UI
    -- objects, so only explicit editor actions redraw it.
end)

SLASH_FRAMEGAMBIT1 = "/framegambit"
SLASH_FRAMEGAMBITBLOCKED1 = "/fgblocked"
SlashCmdList.FRAMEGAMBITBLOCKED = function()
    local records = FrameGambitDB and FrameGambitDB.blockedActions
    local last = type(records) == "table" and records[#records]
    if type(last) == "table" then
        print("Frame Gambit: " .. tostring(last.event) .. " - " .. tostring(last.action))
    else
        print("Frame Gambit: no protected-action blocks recorded since this diagnostic was installed.")
    end
end
SLASH_FRAMEGAMBIT2 = "/fg"
SLASH_FRAMEGAMBIT3 = "/fgambit"
-- Legacy entry points deliberately remain available for existing macros.
SLASH_FRAMEGAMBIT4 = "/pfader"
SLASH_FRAMEGAMBIT5 = "/priorityfader"
function FrameGambit_ToggleCinematic()
    local ok, reason, enabled = ns:ToggleCinematic()
    if not ok and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff9D75FFFrame Gambit|r " .. tostring(reason or "Cinematic Mode could not be toggled."))
    elseif ok and ns.Options and ns.Options.active then
        ns.Options.active:SetText(enabled and "Cinematic Mode on" or "Cinematic Mode off")
        ns.Options.active:SetTextColor(unpack(ns.COLORS.teal))
    end
end

function FrameGambit_ToggleCinematicCamera()
    local ok, enabledOrReason = ns:ToggleCinematicCameraOffset()
    if not ok and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff9D75FFFrame Gambit|r " .. tostring(enabledOrReason or "The Cinematic camera could not be toggled."))
    elseif ok and ns.Options and ns.Options.active then
        ns.Options.active:SetText(enabledOrReason and "Cinematic camera left" or "Cinematic camera centered")
        ns.Options.active:SetTextColor(unpack(ns.COLORS.teal))
    end
end

SlashCmdList.FRAMEGAMBIT = function(message)
    local command = (message or ""):match("^%s*(.-)%s*$"):lower()
    if command == "pick" then
        ns:StartPicker()
    elseif command == "partyborder" and ns.PrintPartySelectionDiagnostics then
        ns:PrintPartySelectionDiagnostics()
    elseif command == "minimapdebug" and ns.PrintMinimapDiagnostics then
        ns:PrintMinimapDiagnostics()
    elseif command == "healthdebug" and ns.PrintHealthDiagnostics then
        ns:PrintHealthDiagnostics()
    elseif command == "audit" or command == "status" then
        ns:RunDiagnostics()
    elseif command:match("^campfire") and ns.HandleCampfireCommand then
        ns:HandleCampfireCommand(command:match("^campfire%s*(.*)$"))
    elseif command == "cinematic" or command == "cinema" then
        FrameGambit_ToggleCinematic()
    else
        ns:ToggleOptions()
    end
end

PriorityFader_ToggleCinematic = FrameGambit_ToggleCinematic
SlashCmdList.PRIORITYFADER = SlashCmdList.FRAMEGAMBIT
