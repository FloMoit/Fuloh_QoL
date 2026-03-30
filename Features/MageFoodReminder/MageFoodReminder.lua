-- MageFoodReminder.lua
-- Feature: Reminds healers to stock Mage Food before a Mythic dungeon

local QoL = Fuloh_QoL
if not QoL then
    error("Fuloh_QoL namespace not found. Core.lua must load first.")
    return
end

-- Create feature object
local MageFoodReminder = {
    name      = "MageFoodReminder",
    label     = "Mage Food Reminder",
    tooltip   = "Reminds healers to stock Mage Food before entering a Mythic dungeon.",
    shortcut  = "mfr",
    isEnabled = false,
}

-- Private state
local dismissed = false   -- reset on each zone entry; set true on manual dismiss
local ShowUI, HideUI      -- resolved in Initialize()

-- Import constants
local Constants

-- Static event frame (registered at load time; isEnabled guard filters handlers)
local eventFrame = CreateFrame("Frame")

--------------------------------------------------------------------------------
-- Private helpers
--------------------------------------------------------------------------------

local function IsHealer()
    return GetSpecializationRole(GetSpecialization()) == "HEALER"
end

local function IsMythicDungeon()
    local inInstance, instanceType = IsInInstance()
    local _, _, difficultyID = GetInstanceInfo()
    return inInstance
        and instanceType == "party"
        and Constants.MYTHIC_DIFFICULTY_IDS[difficultyID]
end

local function CountMageFood()
    return GetItemCount(Constants.MAGE_FOOD_ITEM_ID, false)
end

-- Called by the click handler on the frame; sets dismissed so CheckAndShow
-- won't re-show within the same session/zone.
local function DismissAndHide()
    dismissed = true
    HideUI()
end

local function CheckAndShow()
    if not MageFoodReminder.isEnabled then return end
    if dismissed                       then return end
    if not IsHealer()                  then return end
    if not IsMythicDungeon()           then return end

    local count = CountMageFood()
    if count >= Constants.LOW_THRESHOLD then return end

    ShowUI(count, DismissAndHide)
end

--------------------------------------------------------------------------------
-- Event handlers
--------------------------------------------------------------------------------

local function OnPlayerEnteringWorld()
    if not MageFoodReminder.isEnabled then return end
    dismissed = false
    C_Timer.After(1.0, CheckAndShow)
end

local function OnZoneChangedNewArea()
    if not MageFoodReminder.isEnabled then return end
    dismissed = false
    C_Timer.After(1.0, CheckAndShow)
end

local function OnPlayerRegenDisabled()
    if not MageFoodReminder.isEnabled then return end
    HideUI()
end

local function OnChallengeModeStart()
    if not MageFoodReminder.isEnabled then return end
    HideUI()
end

local function OnEvent(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        OnPlayerEnteringWorld()
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        OnZoneChangedNewArea()
    elseif event == "PLAYER_REGEN_DISABLED" then
        OnPlayerRegenDisabled()
    elseif event == "CHALLENGE_MODE_START" then
        OnChallengeModeStart()
    end
end

eventFrame:SetScript("OnEvent", OnEvent)
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("CHALLENGE_MODE_START")

--------------------------------------------------------------------------------
-- Feature API
--------------------------------------------------------------------------------

function MageFoodReminder:Initialize()
    Constants = QoL.Features.MageFoodReminder_Constants
    ShowUI    = QoL.Features.MageFoodReminder_ShowUI
    HideUI    = QoL.Features.MageFoodReminder_HideUI
end

function MageFoodReminder:Enable()
    self.isEnabled = true
end

function MageFoodReminder:Disable()
    self.isEnabled = false
    HideUI()
end

function MageFoodReminder:GetDefaults()
    return { enabled = false }
end

function MageFoodReminder:HandleCommand(args)
    local cmd = args:lower():match("^(%S+)") or args:lower()

    if cmd == "test" then
        ShowUI(5, DismissAndHide)
        print("|cff00bfff[MageFoodReminder]|r Test: normal style (5 remaining). Click to dismiss.")
    elseif cmd == "test0" then
        ShowUI(0, DismissAndHide)
        print("|cff00bfff[MageFoodReminder]|r Test: alert style (0 remaining). Click to dismiss.")
    elseif cmd == "help" then
        print("|cff00bfff[MageFoodReminder]|r Commands:")
        print("  /fuloh mfr test  - Show normal reminder (5 remaining)")
        print("  /fuloh mfr test0 - Show alert reminder (0 remaining)")
        print("  /fuloh mfr help  - Show this help")
    else
        if Settings and Settings.OpenToCategory then
            Settings.OpenToCategory("Fuloh's QoL")
        end
    end
end

QoL:RegisterFeature(MageFoodReminder)
