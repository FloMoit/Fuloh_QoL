-- GGGuys.lua
-- Feature: Automatically says "GG" when a Mythic+ dungeon is completed in time

-- Get namespace reference
local QoL = Fuloh_QoL
if not QoL then
    error("Fuloh_QoL namespace not found. Core.lua must load first.")
    return
end

-- Create feature object
local GGGuys = {
    name = "GGGuys",
    label = "Auto GG on timed M+",
    shortcut = "gg",
    isEnabled = false,
}

-- Private vars
local eventFrame = CreateFrame("Frame")

-- Database accessor
local function GetDB()
    return Fuloh_QoLDB and Fuloh_QoLDB.GGGuys or {}
end

-- Get random message
local function GetRandomMessage()
    local db = GetDB()
    local Utils = QoL.Features.GGGuys_Utils
    local defaults = Utils and Utils.DefaultGGs or {"GG :)"}

    local list = (db.messages and #db.messages > 0)
                 and db.messages
                 or defaults

    return list[math.random(#list)]
end

-- Event Handler
local function OnEvent(self, event, ...)
    if not GGGuys.isEnabled then return end
    
    if event == "CHALLENGE_MODE_COMPLETED" then
        -- Delay checking and sending to ensure API data is ready and simulate human reaction
        -- Random delay between 4.0 and 6.0 seconds
        local delay = math.random(40, 60) / 10
        
        C_Timer.After(delay, function()
            -- Double check enabled state
            if not GGGuys.isEnabled then return end

            -- Check completion info NOW (after delay) to ensure data is populated
            local onTime = false
            if C_ChallengeMode.GetChallengeCompletionInfo then
                local info = C_ChallengeMode.GetChallengeCompletionInfo()
                if info then onTime = info.onTime end
            elseif C_ChallengeMode.GetCompletionInfo then
                local _, _, _, isTimeScore = C_ChallengeMode.GetCompletionInfo()
                onTime = isTimeScore
            end

            if onTime then
                local msg = GetRandomMessage()
                if msg and msg ~= "" and IsInGroup() then
                    SendChatMessage(msg, "PARTY")
                end
            end
        end)
    end
end

eventFrame:SetScript("OnEvent", OnEvent)
eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")

--------------------------------------------------------------------------------
-- Feature API Implementation
--------------------------------------------------------------------------------

function GGGuys:Initialize()
    -- Nothing special to init besides ensuring DB defaults are ready later
end

function GGGuys:Enable()
    self.isEnabled = true
end

function GGGuys:Disable()
    self.isEnabled = false
end

function GGGuys:GetDefaults()
    local Utils = QoL.Features.GGGuys_Utils
    
    -- Ensure Utils are loaded (they should be due to TOC order)
    local defaults = Utils and Utils.DefaultGGs or {}
    
    return {
        enabled = false,
        messages = defaults,
    }
end

function GGGuys:HandleCommand(args)
    local cmd = args:lower():match("^(%S+)") or args:lower()

    if cmd == "toggle" then
        QoL:ToggleFeature("GGGuys")
    elseif cmd == "help" then
        print("|cff00ff00[GGGuys]|r Commands:")
        print("  /fuloh gg toggle - Toggle feature on/off")
    else
        -- Default to opening main settings since we don't have a specific sub-command
        if Settings and Settings.OpenToCategory then
             Settings.OpenToCategory("Fuloh's QoL")
        end
    end
end

-- Hook for additional settings in the main hub
function GGGuys:OnSettingsUI(parent, yOffset)
    local Settings = QoL.Features.GGGuys_Settings
    if Settings and Settings.CreateEmbeddedSettings then
        return Settings.CreateEmbeddedSettings(parent, yOffset)
    end
    return yOffset
end

-- Register this feature
QoL:RegisterFeature(GGGuys)
