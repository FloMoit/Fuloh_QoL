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
    tooltip = "Displays a banner with dungeon info when you join a Mythic+ group via LFG.",
    shortcut = "jgr",
    isEnabled = false,
}

-- Store reference to Constants and UI namespaces (loaded before this file)
local ns = {}
local L = QoL.Features.JoinedGroupReminder_Constants.L

-- State management (private to this feature)
local applicationCache = {}
local currentReminderData = nil
local wasInGroup = false
local dismissedByUser = false
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
    if not JGR.isEnabled then return end
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
            local activityInfo = activityID and C_LFGList.GetActivityInfoTable(activityID)
            local mapID = activityInfo and activityInfo.mapID
            DebugPrint("  Caching application info for group member/leader:")
            DebugPrint("    groupName:", info.name)
            DebugPrint("    activityName:", activityName)
            DebugPrint("    mapID:", mapID)

            applicationCache[searchResultID] = {
                groupName = info.name,
                activityID = activityID,
                activityName = activityName,
                mapID = mapID,
            }
        else
            DebugPrint("  Failed to get SearchResultInfo for status update")
        end
    end
end

-- Process joining a group
local function OnLFGListJoinedGroup(searchResultID)
    if not JGR.isEnabled then return end
    DebugPrint("JOINED_GROUP - searchResultID:", searchResultID)

    -- New group joined, clear any previous dismiss
    dismissedByUser = false

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
            local activityInfo = activityID and C_LFGList.GetActivityInfoTable(activityID)
            local mapID = activityInfo and activityInfo.mapID
            cached = {
                groupName = info.name,
                activityID = activityID,
                activityName = activityName,
                mapID = mapID,
            }
            DebugPrint("  Direct lookup successful:", cached.activityName, "mapID:", mapID)
        else
            DebugPrint("  Direct lookup failed (probably already joined and delisted)")
        end
    end

    if cached then
        DebugPrint("  Found data:")
        DebugPrint("    groupName:", cached.groupName)
        DebugPrint("    activityID:", cached.activityID)
        DebugPrint("    activityName:", cached.activityName)

        local activityName = cached.activityName or L["LFG Group"]
        local groupName = cached.groupName or ""

        DebugPrint("  Showing reminder - Activity:", activityName, "Group:", groupName, "mapID:", cached.mapID)

        currentReminderData = {
            dungeonName = activityName,
            groupName = groupName,
            mapID = cached.mapID,
        }

        ns.ShowReminder(activityName, groupName, cached.mapID)
    else
        DebugPrint("  No data found for this searchResultID!")
    end

    -- Clear the cache for this application
    if searchResultID then
        applicationCache[searchResultID] = nil
    end
end


local function OnGroupRosterUpdate()
    if not JGR.isEnabled then return end
    local inGroup = IsInGroup()

    -- Detect leaving group
    if wasInGroup and not inGroup then
        dismissedByUser = false
        -- Only hide if not listing a group ourselves
        if not C_LFGList.GetActiveEntryInfo() then
            ns.HideReminder(true)
        end
    end

    wasInGroup = inGroup
end

local function OnPlayerEnteringWorld(isInitialLogin, isReloadingUi)
    if not JGR.isEnabled then return end
    wasInGroup = IsInGroup()

    -- Restore reminder on login/reload if still in group
    if isInitialLogin or isReloadingUi then
        local db = GetDB()
        if db.activeReminder then
            local data = db.activeReminder
            if wasInGroup and not dismissedByUser then
                currentReminderData = data
                ns.ShowReminder(data.dungeonName, data.groupName, data.mapID)
            elseif not wasInGroup then
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

-- Update from currently active LFG entry (if we are listing a group)
local function UpdateFromActiveEntry()
    local entryInfo = C_LFGList.GetActiveEntryInfo()
    if entryInfo then
        local activityID = nil
        if entryInfo.activityIDs and #entryInfo.activityIDs > 0 then
            activityID = entryInfo.activityIDs[1]
        end

        local activityName = GetActivityName(activityID) or L["LFG Group"]
        local groupName = entryInfo.name or ""

        local activityInfo = activityID and C_LFGList.GetActivityInfoTable(activityID)
        currentReminderData = {
            dungeonName = activityName,
            groupName = groupName,
            mapID = activityInfo and activityInfo.mapID,
        }
        return true
    end
    return false
end

-- Event dispatcher
local function OnEvent(self, event, ...)
    if event == "LFG_LIST_JOINED_GROUP" then
        OnLFGListJoinedGroup(...)
    elseif event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
        OnLFGListApplicationStatusUpdated(...)
    elseif event == "LFG_LIST_ACTIVE_ENTRY_UPDATE" then
        local oldData = currentReminderData
        if UpdateFromActiveEntry() then
            -- If the listing changed (new dungeon or new group name), reset dismiss
            if oldData and (oldData.dungeonName ~= currentReminderData.dungeonName
                        or oldData.groupName ~= currentReminderData.groupName) then
                dismissedByUser = false
            end
            if not dismissedByUser then
                ns.ShowReminder(currentReminderData.dungeonName, currentReminderData.groupName, currentReminderData.mapID)
            end
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        OnGroupRosterUpdate()
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Check active entry first (more accurate if we are the leader)
        if UpdateFromActiveEntry() then
            if not dismissedByUser then
                ns.ShowReminder(currentReminderData.dungeonName, currentReminderData.groupName, currentReminderData.mapID)
            end
        else
            OnPlayerEnteringWorld(...)
        end
    elseif event == "PLAYER_LOGOUT" then
        SaveState()
    end
end

-- Static event registration for 12.0 security
eventFrame:SetScript("OnEvent", OnEvent)
eventFrame:RegisterEvent("LFG_LIST_JOINED_GROUP")
eventFrame:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
eventFrame:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")

eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LOGOUT")

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

    -- Build localized name lookup from map IDs (game data available after ADDON_LOADED)
    if QoL.Features.JoinedGroupReminder_BuildNameLookup then
        QoL.Features.JoinedGroupReminder_BuildNameLookup()
    end

    -- Register ClearCachedState callback with UI
    if QoL.Features.JoinedGroupReminder_SetClearCachedStateCallback then
        QoL.Features.JoinedGroupReminder_SetClearCachedStateCallback(ns.ClearCachedState)
    end

    -- Register user dismiss callback with UI
    if QoL.Features.JoinedGroupReminder_SetUserDismissCallback then
        QoL.Features.JoinedGroupReminder_SetUserDismissCallback(function()
            dismissedByUser = true
        end)
    end

    -- Hook ApplyToGroup once (global hook, not tied to enable/disable)
    if not applyToGroupHooked then
        hooksecurefunc(C_LFGList, "ApplyToGroup", function(searchResultID)
            if not JGR.isEnabled then return end
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
    self.isEnabled = true
    -- Restore state if reloading
    OnPlayerEnteringWorld(false, true)
end

function JGR:Disable()
    self.isEnabled = false

    -- Hide reminder if shown
    if ns.HideReminder then
        ns.HideReminder(true)
    end
end

function JGR:GetDefaults()
    return {
        enabled = false,
        activeReminder = nil,
        position = nil,
    }
end

function JGR:HandleCommand(args)
    local cmd = args:lower():match("^(%S+)") or args:lower()

    if cmd == "test" then
        local testDungeon = "Ara-Kara, City of Echoes"
        local testGroup = "chill 10 blast"
        -- Ara-Kara challenge mode map ID = 2660
        ns.ShowReminder(testDungeon, testGroup, 2660)
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
        dismissedByUser = false
        if UpdateFromActiveEntry() then
            ns.ShowReminder(currentReminderData.dungeonName, currentReminderData.groupName, currentReminderData.mapID)
            print("|cff00ff00[JGR]|r Reminder updated from active LFG entry.")
        elseif currentReminderData then
            ns.ShowReminder(currentReminderData.dungeonName, currentReminderData.groupName, currentReminderData.mapID)
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
