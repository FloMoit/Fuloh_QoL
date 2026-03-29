-- FilledGroupAlert.lua
-- Feature: Plays a sound when a dungeon LFG group reaches 5 members (full)

-- Get namespace reference
local QoL = Fuloh_QoL
if not QoL then
    error("Fuloh_QoL namespace not found. Core.lua must load first.")
    return
end

-- Import constants
local Constants = QoL.Features.FilledGroupAlert_Constants
local CATEGORY_ID_DUNGEON = Constants.CATEGORY_ID_DUNGEON
local DUNGEON_GROUP_SIZE = Constants.DUNGEON_GROUP_SIZE

-- Create feature object
local FilledGroupAlert = {
    name = "FilledGroupAlert",
    label = "Filled Group Alert",
    shortcut = "fga",
    isEnabled = false,
}

-- Private state
local eventFrame = CreateFrame("Frame")
local isListedForDungeon = false
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
-- Dungeon Listing Detection
--------------------------------------------------------------------------------

-- Check if the group's active LFG entry is for a dungeon (not raid)
local function CheckActiveDungeonListing()
    if not C_LFGList.HasActiveEntryInfo() then
        return false
    end

    local entryInfo = C_LFGList.GetActiveEntryInfo()
    if not entryInfo then
        return false
    end

    local activityID = nil
    if entryInfo.activityIDs and #entryInfo.activityIDs > 0 then
        activityID = entryInfo.activityIDs[1]
    end

    if not activityID then
        DebugPrint("Active entry has no activityID")
        return false
    end

    local activityInfo = C_LFGList.GetActivityInfoTable(activityID)
    if not activityInfo then
        DebugPrint("Could not get activity info for ID:", activityID)
        return false
    end

    DebugPrint("Active entry categoryID:", activityInfo.categoryID,
               "name:", activityInfo.fullName or activityInfo.shortName or "?")

    return activityInfo.categoryID == CATEGORY_ID_DUNGEON
end

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

local function OnLFGListActiveEntryUpdate()
    if not FilledGroupAlert.isEnabled then return end

    local hasEntry = C_LFGList.HasActiveEntryInfo()

    if hasEntry then
        local isDungeon = CheckActiveDungeonListing()
        isListedForDungeon = isDungeon
        DebugPrint("Listing update: isDungeon =", tostring(isDungeon))
    else
        -- Listing removed.
        -- If group is already full (>= 5), this might be auto-delist from the
        -- 5th member joining. Keep the flag alive so GROUP_ROSTER_UPDATE can
        -- consume it (race condition protection).
        local memberCount = GetNumGroupMembers()
        if memberCount < DUNGEON_GROUP_SIZE then
            isListedForDungeon = false
            DebugPrint("Listing removed, group not full. Cleared flag.")
        else
            DebugPrint("Listing removed, group at", memberCount, "members. Keeping flag for roster update.")
        end
    end
end

local function OnGroupRosterUpdate()
    if not FilledGroupAlert.isEnabled then return end

    local currentCount = GetNumGroupMembers()

    DebugPrint("Roster update: previous =", previousMemberCount, "current =", currentCount,
               "isListedForDungeon =", tostring(isListedForDungeon))

    -- Check trigger: transition TO exactly full group while listed for dungeon
    if currentCount == DUNGEON_GROUP_SIZE
       and previousMemberCount < DUNGEON_GROUP_SIZE
       and isListedForDungeon then
        local db = GetDB()
        local soundID = db.selectedSound or Constants.DEFAULT_SOUND_ID
        PlaySound(soundID, "Master")
        DebugPrint("Group full! Played sound ID:", soundID)
    end

    -- After processing, if listing is gone AND group is full, safe to clear flag
    if currentCount >= DUNGEON_GROUP_SIZE and not C_LFGList.HasActiveEntryInfo() then
        isListedForDungeon = false
    end

    -- Player left group entirely: reset all state
    if not IsInGroup() then
        isListedForDungeon = false
        previousMemberCount = 0
        return
    end

    previousMemberCount = currentCount
end

local function OnPlayerEnteringWorld()
    if not FilledGroupAlert.isEnabled then return end

    previousMemberCount = GetNumGroupMembers()
    isListedForDungeon = CheckActiveDungeonListing()

    DebugPrint("Entering world: members =", previousMemberCount,
               "isListedForDungeon =", tostring(isListedForDungeon))
end

--------------------------------------------------------------------------------
-- Event Dispatcher
--------------------------------------------------------------------------------

local function OnEvent(self, event, ...)
    if event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
        OnLFGListActiveEntryUpdate()
    elseif event == "GROUP_ROSTER_UPDATE" then
        OnGroupRosterUpdate()
    elseif event == "PLAYER_ENTERING_WORLD" then
        OnPlayerEnteringWorld()
    end
end

-- Static event registration (12.0 security pattern)
eventFrame:SetScript("OnEvent", OnEvent)
eventFrame:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
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
    isListedForDungeon = CheckActiveDungeonListing()
end

function FilledGroupAlert:Disable()
    self.isEnabled = false
    isListedForDungeon = false
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
            print("  isListedForDungeon: " .. tostring(isListedForDungeon))
            print("  previousMemberCount: " .. previousMemberCount)
            print("  currentMembers: " .. GetNumGroupMembers())
            print("  hasActiveEntry: " .. tostring(C_LFGList.HasActiveEntryInfo()))
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
