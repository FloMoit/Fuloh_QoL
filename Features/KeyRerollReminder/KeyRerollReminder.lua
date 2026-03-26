-- KeyRerollReminder.lua
-- Feature: Reminds the player to reroll their key after a timed Mythic+ completion

-- Get namespace reference
local QoL = Fuloh_QoL
if not QoL then
    error("Fuloh_QoL namespace not found. Core.lua must load first.")
    return
end

-- Create feature object
local KeyRerollReminder = {
    name = "KeyRerollReminder",
    label = "Key Reroll Reminder",
    shortcut = "krr",
    isEnabled = false,
}

-- Private state
local eventFrame = CreateFrame("Frame")
local wantsReminder = false

-- UI function references (populated in Initialize)
local ns = {}

-- Database accessor
local function GetDB()
    return Fuloh_QoLDB and Fuloh_QoLDB.KeyRerollReminder or {}
end

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

local function OnChallengeModeStart()
    if not KeyRerollReminder.isEnabled then return end

    -- Reset state for new run
    wantsReminder = false

    -- Only ask if rerolling makes sense:
    -- Player must have a key whose level is <= the dungeon that just started
    local ownedKeyLevel = C_MythicPlus.GetOwnedKeystoneLevel()
    if not ownedKeyLevel or ownedKeyLevel == 0 then return end

    local _, _, activeKeystoneLevel = C_ChallengeMode.GetActiveKeystoneInfo()
    if not activeKeystoneLevel or activeKeystoneLevel == 0 then return end

    if ownedKeyLevel > activeKeystoneLevel then return end

    -- Build key description (e.g. "Ara-Kara, City of Echoes +8")
    local keystoneMapID = C_MythicPlus.GetOwnedKeystoneMapID()
    local dungeonName = "?"
    if keystoneMapID then
        local name = C_ChallengeMode.GetMapUIInfo(keystoneMapID)
        if name then dungeonName = name end
    end
    local keyDescription = dungeonName .. " +" .. ownedKeyLevel

    -- Show confirmation popup with current key info
    ns.ShowConfirmPopup(keyDescription)
end

local function OnChallengeModeCompleted()
    if not KeyRerollReminder.isEnabled then return end
    if not wantsReminder then return end

    -- Small delay to ensure API data is populated (same pattern as GGGuys)
    C_Timer.After(2, function()
        if not KeyRerollReminder.isEnabled then return end
        if not wantsReminder then return end

        -- Check if dungeon was timed
        local onTime = false
        if C_ChallengeMode.GetChallengeCompletionInfo then
            local info = C_ChallengeMode.GetChallengeCompletionInfo()
            if info then onTime = info.onTime end
        elseif C_ChallengeMode.GetCompletionInfo then
            local _, _, _, isTimeScore = C_ChallengeMode.GetCompletionInfo()
            onTime = isTimeScore
        end

        if onTime then
            ns.ShowBigReminder()
        end

        -- Reset for next run
        wantsReminder = false
    end)
end

local function OnEvent(self, event, ...)
    if event == "CHALLENGE_MODE_START" then
        OnChallengeModeStart()
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        OnChallengeModeCompleted()
    end
end

eventFrame:SetScript("OnEvent", OnEvent)
eventFrame:RegisterEvent("CHALLENGE_MODE_START")
eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")

--------------------------------------------------------------------------------
-- Feature API Implementation
--------------------------------------------------------------------------------

function KeyRerollReminder:Initialize()
    -- Get references to UI functions (loaded before this file)
    ns.ShowConfirmPopup = QoL.Features.KeyRerollReminder_ShowConfirmPopup
    ns.HideConfirmPopup = QoL.Features.KeyRerollReminder_HideConfirmPopup
    ns.ShowBigReminder = QoL.Features.KeyRerollReminder_ShowBigReminder
    ns.HideBigReminder = QoL.Features.KeyRerollReminder_HideBigReminder

    -- Register popup callbacks
    if QoL.Features.KeyRerollReminder_SetPopupCallbacks then
        QoL.Features.KeyRerollReminder_SetPopupCallbacks(
            function() wantsReminder = true end,   -- OnAccept
            function() wantsReminder = false end    -- OnDecline
        )
    end
end

function KeyRerollReminder:Enable()
    self.isEnabled = true
end

function KeyRerollReminder:Disable()
    self.isEnabled = false
    wantsReminder = false

    -- Hide any active UI
    if ns.HideConfirmPopup then ns.HideConfirmPopup() end
    if ns.HideBigReminder then ns.HideBigReminder() end
end

function KeyRerollReminder:GetDefaults()
    return {
        enabled = false,
    }
end

function KeyRerollReminder:HandleCommand(args)
    local cmd = args:lower():match("^(%S+)") or args:lower()

    if cmd == "toggle" then
        QoL:ToggleFeature("KeyRerollReminder")
    elseif cmd == "test" then
        ns.ShowBigReminder()
        print("|cff00ff00[KeyRerollReminder]|r Test reminder shown. Click to dismiss.")
    elseif cmd == "help" then
        print("|cff00ff00[KeyRerollReminder]|r Commands:")
        print("  /fuloh krr toggle - Toggle feature on/off")
        print("  /fuloh krr test   - Show test reminder")
    else
        if Settings and Settings.OpenToCategory then
            Settings.OpenToCategory("Fuloh's QoL")
        end
    end
end

-- Register this feature
QoL:RegisterFeature(KeyRerollReminder)
