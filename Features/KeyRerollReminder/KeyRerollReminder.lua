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
    tooltip = "Shows a reminder to reroll your Mythic+ key after completing a timed run.",
    shortcut = "krr",
    isEnabled = false,
}

-- Private state
local eventFrame = CreateFrame("Frame")
local wantsReminder = false
local storedKeyDescription = nil
local watchingForReroll = false    -- watching CHAT_MSG_LOOT for the NPC reroll

-- UI function references (populated in Initialize)
local ns = {}

-- Database accessor
local function GetDB()
    return Fuloh_QoLDB and Fuloh_QoLDB.KeyRerollReminder or {}
end

-- Scan bags and return (hyperlink, displayDescription) for the player's keystone.
-- hyperlink  : the raw item hyperlink (used for change-detection).
-- description: the human-readable "Dungeon Name [+N]" string (used for UI).
-- Both are nil when the player has no keystone.
local function ScanOwnedKeystone()
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.hyperlink then
                -- Hyperlink format: "|H...|h[Keystone: Ara-Kara, City of Echoes [10]]|h|r"
                -- Greedy match captures from first '[' to last ']', preserving nested brackets.
                local displayName = info.hyperlink:match("%[(.+)%]")
                if displayName then
                    local dungeon = displayName:match("^Keystone: (.+)$")
                    if dungeon then
                        return info.hyperlink, dungeon
                    end
                end
            end
        end
    end
    return nil, nil
end

-- Convenience wrapper that returns only the display string (e.g. for the confirm popup).
local function BuildOwnedKeyDescription()
    local _, desc = ScanOwnedKeystone()
    return desc
end

-- Safety timer for the reroll watch window.
local rerollWatchTimer = nil

-- Stop watching for the keystone reroll.
local function StopWatchingForReroll()
    if not watchingForReroll then return end
    watchingForReroll = false
    eventFrame:UnregisterEvent("CHAT_MSG_LOOT")
    if rerollWatchTimer then
        rerollWatchTimer:Cancel()
        rerollWatchTimer = nil
    end
end

-- Cancel everything (used by Disable and new-run start).
local function StopAllWatching()
    StopWatchingForReroll()
end


--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

local function OnChallengeModeStart()
    if not KeyRerollReminder.isEnabled then return end

    -- Cancel any lingering watch state from a previous run
    StopAllWatching()

    -- Reset state for new run
    wantsReminder = false
    storedKeyDescription = nil

    -- Only ask if rerolling makes sense:
    -- Player must have a key whose level is <= the dungeon that just started
    local ownedKeyLevel = C_MythicPlus.GetOwnedKeystoneLevel()
    if not ownedKeyLevel or ownedKeyLevel == 0 then return end

    local activeKeystoneLevel, _, _ = C_ChallengeMode.GetActiveKeystoneInfo()
    if not activeKeystoneLevel or activeKeystoneLevel == 0 then return end

    if ownedKeyLevel > activeKeystoneLevel then return end

    -- If the player's keystone is for the same dungeon we just started, it's their
    -- own depleted key (starting a key replaces it with a 1-level-lower copy for the
    -- same dungeon).  No point reminding to reroll your own key.
    local ownedMapID = C_MythicPlus.GetOwnedKeystoneMapID()
    local activeMapID = C_ChallengeMode.GetActiveChallengeMapID()
    if ownedMapID and activeMapID and ownedMapID == activeMapID then return end

    -- Snapshot the key description for the confirmation popup
    _, storedKeyDescription = ScanOwnedKeystone()

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

            -- Watch for the NPC reroll via loot chat messages.
            -- The reroll message contains two keystone hyperlinks (old -> new).
            watchingForReroll = true
            eventFrame:RegisterEvent("CHAT_MSG_LOOT")

            -- Safety timeout: stop watching after 10 minutes.
            rerollWatchTimer = C_Timer.NewTimer(600, function()
                StopAllWatching()
            end)
        end

        -- Reset so we don't trigger again on a subsequent dungeon start
        wantsReminder = false
    end)
end

-- Detect keystone reroll from the loot chat message.
-- The reroll message contains two keystone hyperlinks (old -> new):
-- "Your |cff...|Hkeystone:...|h[Mythic Keystone]|h|r was changed to |cff...|Hkeystone:...|h[Mythic Keystone]|h|r"
local function OnChatMsgLoot(msg)
    if not watchingForReroll then return end
    if not KeyRerollReminder.isEnabled then
        StopAllWatching()
        return
    end

    -- Look for two |Hkeystone: hyperlinks in the message (language-independent).
    local firstPos = msg:find("|Hkeystone:")
    if not firstPos then return end
    local secondPos = msg:find("|Hkeystone:", firstPos + 10)
    if not secondPos then return end

    -- Two keystone links found - this is a reroll.
    StopAllWatching()

    -- Short delay to let the bag update before scanning for the new key name.
    C_Timer.After(0.5, function()
        local _, newDescription = ScanOwnedKeystone()
        ns.HideBigReminder()
        ns.ShowRerolledKey(newDescription)
    end)
end

local function OnEvent(self, event, ...)
    if event == "CHALLENGE_MODE_START" then
        OnChallengeModeStart()
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        OnChallengeModeCompleted()
    elseif event == "CHAT_MSG_LOOT" then
        OnChatMsgLoot(...)
    end
end

eventFrame:SetScript("OnEvent", OnEvent)
eventFrame:RegisterEvent("CHALLENGE_MODE_START")
eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
-- CHAT_MSG_LOOT is registered/unregistered dynamically per run

--------------------------------------------------------------------------------
-- Feature API Implementation
--------------------------------------------------------------------------------

function KeyRerollReminder:Initialize()
    -- Get references to UI functions (loaded before this file)
    ns.ShowConfirmPopup = QoL.Features.KeyRerollReminder_ShowConfirmPopup
    ns.HideConfirmPopup = QoL.Features.KeyRerollReminder_HideConfirmPopup
    ns.ShowBigReminder = QoL.Features.KeyRerollReminder_ShowBigReminder
    ns.HideBigReminder = QoL.Features.KeyRerollReminder_HideBigReminder
    ns.ShowRerolledKey = QoL.Features.KeyRerollReminder_ShowRerolledKey
    ns.HideRerolledKey = QoL.Features.KeyRerollReminder_HideRerolledKey

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
    StopAllWatching()

    -- Hide any active UI
    if ns.HideConfirmPopup then ns.HideConfirmPopup() end
    if ns.HideBigReminder then ns.HideBigReminder() end
    if ns.HideRerolledKey then ns.HideRerolledKey() end
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
