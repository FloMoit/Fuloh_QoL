-- JoinedGroupReminder.lua
-- Feature: Displays a reminder banner when joining a Mythic Plus group via LFG

-- Get namespace references
local QoL = Fuloh_QoL
if not QoL then
    error("Fuloh_QoL namespace not found. Core.lua must load first.")
    return
end

-- Create feature object
local JGR = {
    name = "JoinedGroupReminder",
    shortcut = "jgr",
}

-- Store reference to Constants and UI namespaces (loaded before this file)
local ns = {}

-- State management (private to this feature)
local applicationCache = {}
local currentReminderData = nil
local wasInGroup = false
local debugMode = false
local eventFrame = CreateFrame("Frame")
local applyToGroupHooked = false

-- Database accessor
local function GetDB()
    return Fuloh_QoLDB and Fuloh_QoLDB.JoinedGroupReminder or {}
end

-- Debug helper
local function DebugPrint(...)
    if debugMode then
        print("|cffff9900[JGR Debug]|r", ...)
    end
end

-- Clear cached state
function ns.ClearCachedState()
    currentReminderData = nil
end

-- Get activity name from activityID
local function GetActivityName(activityID)
    if not activityID then
        DebugPrint("GetActivityName: activityID is nil")
        return nil
    end

    DebugPrint("GetActivityName: looking up activityID", activityID)
    local info = C_LFGList.GetActivityInfoTable(activityID)

    if info then
        DebugPrint("  fullName:", info.fullName)
        DebugPrint("  shortName:", info.shortName)
        return info.fullName or info.shortName
    else
        DebugPrint("  GetActivityInfoTable returned nil")
    end
    return nil
end

-- Process application status updates
local function OnLFGListApplicationStatusUpdated(searchResultID, newStatus, oldStatus, groupName)
    DebugPrint("APPLICATION_STATUS_UPDATED - searchResultID:", searchResultID, "status:", newStatus)

    if newStatus == "applied" and searchResultID then
        local info = C_LFGList.GetSearchResultInfo(searchResultID)
        if info then
            local activityID = info.activityID
            if not activityID and info.activityIDs and #info.activityIDs > 0 then
                activityID = info.activityIDs[1]
                DebugPrint("  Using activityIDs[1]:", activityID)
            end

            local activityName = GetActivityName(activityID)
            DebugPrint("  Caching application info for group member/leader:")
            DebugPrint("    groupName:", info.name)
            DebugPrint("    activityName:", activityName)

            applicationCache[searchResultID] = {
                groupName = info.name,
                activityID = activityID,
                activityName = activityName,
            }
        else
            DebugPrint("  Failed to get SearchResultInfo for status update")
        end
    end
end

-- Process joining a group
local function OnLFGListJoinedGroup(searchResultID)
    DebugPrint("JOINED_GROUP - searchResultID:", searchResultID)

    local cached = searchResultID and applicationCache[searchResultID]

    -- Fallback: direct lookup if not cached
    if not cached and searchResultID then
        DebugPrint("  No cached data found, trying direct lookup...")
        local info = C_LFGList.GetSearchResultInfo(searchResultID)
        if info then
            local activityID = info.activityID
            if not activityID and info.activityIDs and #info.activityIDs > 0 then
                activityID = info.activityIDs[1]
            end
            local activityName = GetActivityName(activityID)
            cached = {
                groupName = info.name,
                activityID = activityID,
                activityName = activityName,
            }
            DebugPrint("  Direct lookup successful:", cached.activityName)
        else
            DebugPrint("  Direct lookup failed (probably already joined and delisted)")
        end
    end

    if cached then
        DebugPrint("  Found data:")
        DebugPrint("    groupName:", cached.groupName)
        DebugPrint("    activityID:", cached.activityID)
        DebugPrint("    activityName:", cached.activityName)

        local activityName = cached.activityName or "LFG Group"
        local groupName = cached.groupName or ""

        DebugPrint("  Showing reminder - Activity:", activityName, "Group:", groupName)

        currentReminderData = {
            dungeonName = activityName,
            groupName = groupName,
        }

        ns.ShowReminder(activityName, groupName)
    else
        DebugPrint("  No data found for this searchResultID!")
    end

    -- Clear the cache for this application
    if searchResultID then
        applicationCache[searchResultID] = nil
    end
end

local function OnChallengeModeStart()
    ns.HideReminder(true)
end

local function OnChallengeModeCompleted()
    ns.HideReminder(true)
end

local function OnGroupRosterUpdate()
    local inGroup = IsInGroup()

    -- Detect leaving group
    if wasInGroup and not inGroup then
        ns.HideReminder(true)
    end

    wasInGroup = inGroup
end

local function OnPlayerEnteringWorld(isInitialLogin, isReloadingUi)
    wasInGroup = IsInGroup()

    -- Restore reminder on reload if still in group
    if isReloadingUi then
        local db = GetDB()
        if db.activeReminder then
            local data = db.activeReminder
            if wasInGroup then
                currentReminderData = data
                ns.ShowReminder(data.dungeonName, data.groupName)
            else
                db.activeReminder = nil
            end
        end
    end

    -- Clean up if not in a group
    if not wasInGroup then
        ns.HideReminder(true)
        local db = GetDB()
        if db then
            db.activeReminder = nil
        end
    end
end

local function SaveState()
    local db = GetDB()
    if currentReminderData and ns.IsReminderShown() then
        db.activeReminder = currentReminderData
    elseif db then
        db.activeReminder = nil
    end
end

-- Event dispatcher
local function OnEvent(self, event, ...)
    if event == "LFG_LIST_JOINED_GROUP" then
        OnLFGListJoinedGroup(...)
    elseif event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
        OnLFGListApplicationStatusUpdated(...)
    elseif event == "CHALLENGE_MODE_START" then
        OnChallengeModeStart()
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        OnChallengeModeCompleted()
    elseif event == "GROUP_ROSTER_UPDATE" then
        OnGroupRosterUpdate()
    elseif event == "PLAYER_ENTERING_WORLD" then
        OnPlayerEnteringWorld(...)
    elseif event == "PLAYER_LOGOUT" then
        SaveState()
    end
end

-- Update from currently active LFG entry (if we are listing a group)
local function UpdateFromActiveEntry()
    local entryInfo = C_LFGList.GetActiveEntryInfo()
    if entryInfo then
        local activityID = nil
        if entryInfo.activityIDs and #entryInfo.activityIDs > 0 then
            activityID = entryInfo.activityIDs[1]
        end

        local activityName = GetActivityName(activityID) or "LFG Group"
        local groupName = entryInfo.name or ""

        currentReminderData = {
            dungeonName = activityName,
            groupName = groupName,
        }
        return true
    end
    return false
end

--------------------------------------------------------------------------------
-- Feature API Implementation
--------------------------------------------------------------------------------

function JGR:Initialize()
    -- Get references to Constants and UI functions (already loaded)
    ns.Constants = QoL.Features.JoinedGroupReminder_Constants
    ns.ShowReminder = QoL.Features.JoinedGroupReminder_ShowReminder
    ns.HideReminder = QoL.Features.JoinedGroupReminder_HideReminder
    ns.IsReminderShown = QoL.Features.JoinedGroupReminder_IsReminderShown
    ns.GetDungeonTeleportSpell = QoL.Features.JoinedGroupReminder_GetDungeonTeleportSpell
    ns.HasDungeonTeleport = QoL.Features.JoinedGroupReminder_HasDungeonTeleport

    -- Register ClearCachedState callback with UI
    if QoL.Features.JoinedGroupReminder_SetClearCachedStateCallback then
        QoL.Features.JoinedGroupReminder_SetClearCachedStateCallback(ns.ClearCachedState)
    end

    -- Hook ApplyToGroup once (global hook, not tied to enable/disable)
    if not applyToGroupHooked then
        hooksecurefunc(C_LFGList, "ApplyToGroup", function(searchResultID)
            DebugPrint("HOOK: ApplyToGroup - searchResultID:", searchResultID)

            local info = C_LFGList.GetSearchResultInfo(searchResultID)
            if info then
                DebugPrint("  SearchResultInfo fields:")
                for k, v in pairs(info) do
                    if type(v) == "table" then
                        DebugPrint("    ", k, "= (table with", #v, "items)")
                        for i, item in ipairs(v) do
                            DebugPrint("      [", i, "]:", item)
                        end
                    else
                        DebugPrint("    ", k, "=", tostring(v))
                    end
                end

                local activityID = info.activityID
                if not activityID and info.activityIDs and #info.activityIDs > 0 then
                    activityID = info.activityIDs[1]
                    DebugPrint("  Using activityIDs[1]:", activityID)
                end

                local activityName = GetActivityName(activityID)
                DebugPrint("  Resolved activityName:", activityName)

                applicationCache[searchResultID] = {
                    groupName = info.name,
                    activityID = activityID,
                    activityName = activityName,
                }
            else
                DebugPrint("  SearchResultInfo is nil!")
            end
        end)
        applyToGroupHooked = true
    end

    -- Initialize group state
    wasInGroup = IsInGroup()
end

function JGR:Enable()
    -- Register all events
    eventFrame:SetScript("OnEvent", OnEvent)
    eventFrame:RegisterEvent("LFG_LIST_JOINED_GROUP")
    eventFrame:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
    eventFrame:RegisterEvent("CHALLENGE_MODE_START")
    eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_LOGOUT")

    -- Restore state if reloading
    OnPlayerEnteringWorld(false, true)
end

function JGR:Disable()
    -- Unregister all events
    eventFrame:UnregisterAllEvents()
    eventFrame:SetScript("OnEvent", nil)

    -- Hide reminder if shown
    if ns.HideReminder then
        ns.HideReminder(true)
    end
end

function JGR:GetDefaults()
    return {
        enabled = true,
        activeReminder = nil,
        position = nil,
    }
end

function JGR:HandleCommand(args)
    local cmd = args:lower():match("^(%S+)") or args:lower()

    if cmd == "test" then
        local testDungeon = "Ara-Kara, City of Echoes"
        local testGroup = "chill 10 blast"
        ns.ShowReminder(testDungeon, testGroup)
        local spellID = ns.GetDungeonTeleportSpell(testDungeon)
        if spellID and ns.HasDungeonTeleport(spellID) then
            print("|cff00ff00[JGR]|r Test reminder shown with teleport button.")
        else
            print("|cff00ff00[JGR]|r Test reminder shown (no teleport available).")
        end

    elseif cmd == "hide" then
        ns.HideReminder()
        print("|cff00ff00[JGR]|r Reminder hidden.")

    elseif cmd == "show" then
        if UpdateFromActiveEntry() then
            ns.ShowReminder(currentReminderData.dungeonName, currentReminderData.groupName)
            print("|cff00ff00[JGR]|r Reminder updated from active LFG listing.")
        elseif currentReminderData then
            ns.ShowReminder(currentReminderData.dungeonName, currentReminderData.groupName)
            print("|cff00ff00[JGR]|r Reminder restored from last joined group.")
        else
            print("|cff00ff00[JGR]|r No active group data to show.")
        end

    elseif cmd == "debug" then
        debugMode = not debugMode
        print("|cff00ff00[JGR]|r Debug mode:", debugMode and "ON" or "OFF")

    else
        print("|cff00ff00[JGR]|r Commands:")
        print("  /fuloh jgr show - Show or refresh reminder")
        print("  /fuloh jgr hide - Hide reminder")
        print("  /fuloh jgr test - Show test reminder")
        print("  /fuloh jgr debug - Toggle debug mode")
    end
end

-- Register this feature with Fuloh_QoL
QoL:RegisterFeature(JGR)
