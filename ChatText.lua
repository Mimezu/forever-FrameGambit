local ADDON, ns = ...

-- Observe the text actually added to configured chat windows. This covers
-- public/custom channels, whispers, guild, party, raid and addon messages
-- without parsing channel IDs or retaining a transcript.
local matches = setmetatable({}, { __mode = "k" })
local hooked = setmetatable({}, { __mode = "k" })
local lifecycle = {}
local nextScan = 0

local function ReadableText(value)
    return not (issecretvalue and issecretvalue(value)) and type(value) == "string"
end

local function Fold(value)
    return (strlower or string.lower)(value)
end

local function VisibleText(value)
    -- Item links match their displayed item name, never their hidden item ID.
    return value:gsub("|H.-|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", "")
        :gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("||", "|")
end

function ns:ObserveChatTextMessage(text)
    if not FrameGambitDB or not ReadableText(text) then return end
    local message, now, found = Fold(VisibleText(text)), GetTime(), false
    for _, settings in pairs(self:Profile().targets or {}) do
        if type(settings) == "table" and settings.enabled ~= false then
            for _, rule in ipairs(settings.reactions or {}) do
                if rule.enabled ~= false and rule.condition == "chat_text" then
                    local query = self:NormalizeChatText(rule.chatText)
                    if query ~= "" and message:find(Fold(query), 1, true) then
                        matches[rule] = { query = query, time = now }
                        found = true
                    end
                end
            end
        end
    end
    if found then self:Wake() end
end

function ns:ChatTextConditionIsMet(rule, now)
    local record = rule and matches[rule]
    return record ~= nil and record.query == self:NormalizeChatText(rule.chatText)
        and (now or GetTime()) - record.time <= (rule.duration or 10)
end

function ns:GetChatTextMatchTime(rule)
    local record = rule and matches[rule]
    return record and record.query == self:NormalizeChatText(rule.chatText) and record.time or nil
end

function ns:RefreshChatTextHooks(force)
    local now = GetTime()
    if not force and now < nextScan then return end
    nextScan = now + 1
    if type(hooksecurefunc) ~= "function" then return end
    local function Hook(frame)
        if not frame or hooked[frame] then return end
        local ok, method = pcall(function() return frame.AddMessage end)
        if ok and type(method) == "function" then
            hooked[frame] = pcall(hooksecurefunc, frame, "AddMessage", function(_, text)
                ns:ObserveChatTextMessage(text)
            end)
        end
    end
    for _, name in pairs(type(CHAT_FRAMES) == "table" and CHAT_FRAMES or {}) do
        if type(name) == "string" then Hook(_G[name]) end
    end
    for index = 1, NUM_CHAT_WINDOWS or 10 do Hook(_G["ChatFrame" .. index]) end
    for _, name in ipairs({ "FCF_OpenNewWindow", "FCF_OpenTemporaryWindow" }) do
        if not lifecycle[name] and type(_G[name]) == "function" then
            lifecycle[name] = pcall(hooksecurefunc, name, function() ns:RefreshChatTextHooks(true) end)
        end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function() ns:RefreshChatTextHooks(true) end)
ns:RefreshChatTextHooks(true)
