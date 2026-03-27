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
local storedKeyDescription = nil

-- UI function references (populated in Initialize)
local ns = {}

-- Database accessor
local function GetDB()
    return Fuloh_QoLDB and Fuloh_QoLDB.KeyRerollReminder or {}
end

-- Build a display string for the player's owned keystone (e.g. "Ara-Kara, City of Echoes [10]")
-- Returns nil if the player has no key.
-- Reads the full display name from the keystone item's hyperlink in bags (always synchronously available).
-- The item name already includes the key level, so no separate level lookup is needed.
local function BuildOwnedKeyDescription()
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.hyperlink then
                -- Hyperlink format: "|H...|h[Keystone: Ara-Kara, City of Echoes [10]]|h|r"
                -- Use greedy match to capture from first '[' to last ']', preserving nested brackets
                local displayName = info.hyperlink:match("%[(.+)%]")
                if displayName then
                    local dungeon = displayName:match("^Keystone: (.+)$")
                    if dungeon then return dungeon end
                end
            end
        end
    end
    return nil
end


--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

local function OnChallengeModeStart()
    if not KeyRerollReminder.isEnabled then return end

    -- Reset state for new run
    wantsReminder = false
    storedKeyDescription = nil

    -- Only ask if rerolling makes sense:
    -- Player must have a key whose level is <= the dungeon that just started
    local ownedKeyLevel = C_MythicPlus.GetOwnedKeystoneLevel()
    if not ownedKeyLevel or ownedKeyLevel == 0 then return end

    local activeKeystoneLevel = C_ChallengeMode.GetActiveKeystoneInfo()
    if not activeKeystoneLevel or activeKeystoneLevel == 0 then return end

    if ownedKeyLevel > activeKeystoneLevel then return end

    -- Build key description (e.g. "Ara-Kara, City of Echoes +8")
    storedKeyDescription = BuildOwnedKeyDescription()

    -- Show confirmation popup with current key info
    ns.ShowConfirmPopup(storedKeyDescription)
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
            ns.ShowBigReminder(storedKeyDescription)
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
        local desc = BuildOwnedKeyDescription() or "No key found"
        ns.ShowBigReminder(desc)
        print("|cff00ff00[KeyRerollReminder]|r Test reminder shown. Click to dismiss.")
    elseif cmd == "testpopup" then
        local desc = BuildOwnedKeyDescription() or "No key found"
        ns.ShowConfirmPopup(desc)
        print("|cff00ff00[KeyRerollReminder]|r Test confirmation popup shown.")
    elseif cmd == "help" then
        print("|cff00ff00[KeyRerollReminder]|r Commands:")
        print("  /fuloh krr toggle    - Toggle feature on/off")
        print("  /fuloh krr test      - Show test big reminder")
        print("  /fuloh krr testpopup - Show test confirmation popup")
    else
        if Settings and Settings.OpenToCategory then
            Settings.OpenToCategory("Fuloh's QoL")
        end
    end
end

-- Register this feature
QoL:RegisterFeature(KeyRerollReminder)
