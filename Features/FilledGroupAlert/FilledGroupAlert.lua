-- FilledGroupAlert.lua
-- Feature: Plays a sound when the group reaches 5 members

-- Get namespace reference
local QoL = Fuloh_QoL
if not QoL then
    error("Fuloh_QoL namespace not found. Core.lua must load first.")
    return
end

-- Import constants
local Constants = QoL.Features.FilledGroupAlert_Constants
local DUNGEON_GROUP_SIZE = Constants.DUNGEON_GROUP_SIZE

-- Create feature object
local FilledGroupAlert = {
    name = "FilledGroupAlert",
    label = "Filled Group Alert",
    tooltip = "Plays a sound alert when your group reaches 5 members.",
    shortcut = "fga",
    isEnabled = false,
}

-- Private state
local eventFrame = CreateFrame("Frame")
local previousMemberCount = 0
local debugMode = false

-- Database accessor
local function GetDB()
    return Fuloh_QoLDB and Fuloh_QoLDB.FilledGroupAlert or {}
end

-- Debug helper
local function DebugPrint(...)
    if debugMode then
        print("|cffff9900[FGA Debug]|r", ...)
    end
end

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

local function OnGroupRosterUpdate()
    if not FilledGroupAlert.isEnabled then return end

    local currentCount = GetNumGroupMembers()

    DebugPrint("Roster update: previous =", previousMemberCount, "current =", currentCount)

    -- Check trigger: transition TO exactly 5 members
    if currentCount == DUNGEON_GROUP_SIZE
       and previousMemberCount < DUNGEON_GROUP_SIZE then
        local db = GetDB()
        local soundID = db.selectedSound or Constants.DEFAULT_SOUND_ID
        PlaySound(soundID, "Master")
        DebugPrint("Group full! Played sound ID:", soundID)
    end

    -- Player left group entirely: reset state
    if not IsInGroup() then
        previousMemberCount = 0
        return
    end

    previousMemberCount = currentCount
end

local function OnPlayerEnteringWorld()
    if not FilledGroupAlert.isEnabled then return end

    previousMemberCount = GetNumGroupMembers()

    DebugPrint("Entering world: members =", previousMemberCount)
end

--------------------------------------------------------------------------------
-- Event Dispatcher
--------------------------------------------------------------------------------

local function OnEvent(self, event, ...)
    if event == "GROUP_ROSTER_UPDATE" then
        OnGroupRosterUpdate()
    elseif event == "PLAYER_ENTERING_WORLD" then
        OnPlayerEnteringWorld()
    end
end

-- Static event registration (12.0 security pattern)
eventFrame:SetScript("OnEvent", OnEvent)
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

--------------------------------------------------------------------------------
-- Feature API Implementation
--------------------------------------------------------------------------------

function FilledGroupAlert:Initialize()
    previousMemberCount = GetNumGroupMembers()
end

function FilledGroupAlert:Enable()
    self.isEnabled = true
    previousMemberCount = GetNumGroupMembers()
end

function FilledGroupAlert:Disable()
    self.isEnabled = false
    previousMemberCount = 0
end

function FilledGroupAlert:GetDefaults()
    return {
        enabled = false,
        selectedSound = Constants.DEFAULT_SOUND_ID,
    }
end

function FilledGroupAlert:HandleCommand(args)
    local cmd = args:lower():match("^(%S+)") or args:lower()

    if cmd == "toggle" then
        QoL:ToggleFeature("FilledGroupAlert")
    elseif cmd == "test" then
        local db = GetDB()
        local soundID = db.selectedSound or Constants.DEFAULT_SOUND_ID
        PlaySound(soundID, "Master")
        print("|cff00ff00[FilledGroupAlert]|r Test sound played (SoundKit ID: " .. soundID .. ")")
    elseif cmd == "debug" then
        debugMode = not debugMode
        print("|cff00ff00[FilledGroupAlert]|r Debug mode: " .. (debugMode and "ON" or "OFF"))
        if debugMode then
            print("  previousMemberCount: " .. previousMemberCount)
            print("  currentMembers: " .. GetNumGroupMembers())
        end
    elseif cmd == "help" then
        print("|cff00ff00[FilledGroupAlert]|r Commands:")
        print("  /fuloh fga toggle - Toggle feature on/off")
        print("  /fuloh fga test   - Play the selected alert sound")
        print("  /fuloh fga debug  - Toggle debug mode + show state")
    else
        if Settings and Settings.OpenToCategory then
            Settings.OpenToCategory("Fuloh's QoL")
        end
    end
end

function FilledGroupAlert:OnSettingsUI(parent, yOffset)
    local SettingsModule = QoL.Features.FilledGroupAlert_Settings
    if SettingsModule and SettingsModule.CreateEmbeddedSettings then
        return SettingsModule.CreateEmbeddedSettings(parent, yOffset)
    end
    return yOffset
end

-- Register this feature with Fuloh_QoL
QoL:RegisterFeature(FilledGroupAlert)
