-- HelloWorld.lua
-- Feature: Automatically greets party members when joining a group

-- Get namespace reference
local QoL = Fuloh_QoL
if not QoL then
    error("Fuloh_QoL namespace not found. Core.lua must load first.")
    return
end

-- Create feature object
local HelloWorld = {
    name = "HelloWorld",
    label = "Auto greeting in party",
    shortcut = "hello",
    isEnabled = false,
}

-- State management (private to this feature)
local state = { inHome = false, inInst = false, numMembers = 0 }
local eventFrame = CreateFrame("Frame")
local pendingLFGJoin = false


-- Database accessor
local function GetDB()
    return Fuloh_QoLDB and Fuloh_QoLDB.HelloWorld or {}
end

-- Get random greeting from settings
local function GetRandomGreeting()
    local db = GetDB()
    local Utils = QoL.Features.HelloWorld_Utils

    local greetings = (db.greetings and #db.greetings > 0)
                      and db.greetings
                      or (Utils and Utils.DefaultGreetings or {"Hello!"})

    return greetings[math.random(#greetings)]
end

-- Internal function to refresh group status
local function UpdateGroupState()
    state.inHome = IsInGroup(LE_PARTY_CATEGORY_HOME)
    state.inInst = IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
    state.numMembers = GetNumGroupMembers()
end

-- Handle group roster changes
local function OnGroupRosterUpdate()
    if not HelloWorld.isEnabled then return end
    
    local oldState = {
        inHome = state.inHome,
        inInst = state.inInst,
        numMembers = state.numMembers
    }
    UpdateGroupState()

    local db = GetDB()
    local Utils = QoL.Features.HelloWorld_Utils

    -- Check if we should greet and which channel to use
    local channel = Utils and Utils.GetGreetingChannel(oldState, state, true, pendingLFGJoin)
    
    -- Clear the flag after checking
    if pendingLFGJoin then
        pendingLFGJoin = false
    end

    if channel then
        -- Multi-second delay (5 to 8 seconds) to make it look natural
        local delay = math.random(50, 80) / 10

        C_Timer.After(delay, function()
            -- Final check before sending if still enabled
            if not HelloWorld.isEnabled then return end
            
            -- Use pcall to safely handle chat errors (throttling, silence, etc.)
            local success, err = pcall(function()
                local message = GetRandomGreeting()
                SendChatMessage(message, channel)
            end)

            if not success then
                -- Silently fail
            end
        end)
    end
end

-- Event dispatcher
local function OnEvent(self, event, ...)
    if not HelloWorld.isEnabled then return end
    
    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        OnGroupRosterUpdate()
    elseif event == "LFG_LIST_JOINED_GROUP" then
        pendingLFGJoin = true
        OnGroupRosterUpdate()
    end
end

-- Static event registration for 12.0 security
eventFrame:SetScript("OnEvent", OnEvent)
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("LFG_LIST_JOINED_GROUP")

--------------------------------------------------------------------------------
-- Feature API Implementation
--------------------------------------------------------------------------------

function HelloWorld:Initialize()
    -- Initialize settings panel
    local Settings = QoL.Features.HelloWorld_Settings
    if Settings and Settings.Initialize then
        Settings.Initialize()
    end


    -- Initialize group state
    UpdateGroupState()
end

function HelloWorld:Enable()
    self.isEnabled = true



    -- Update group state
    UpdateGroupState()
end

function HelloWorld:Disable()
    self.isEnabled = false


end

function HelloWorld:GetDefaults()
    local Utils = QoL.Features.HelloWorld_Utils
    local defaultGreetings = {}

    if Utils and Utils.DefaultGreetings then
        for _, g in ipairs(Utils.DefaultGreetings) do
            table.insert(defaultGreetings, g)
        end
    end

    return {
        enabled = false,

        greetings = defaultGreetings,
    }
end

function HelloWorld:HandleCommand(args)
    local cmd = args:lower():match("^(%S+)") or args:lower()

    if cmd == "toggle" then
        QoL:ToggleFeature("HelloWorld")

    elseif cmd == "settings" or cmd == "config" or cmd == "" then
        local OpenSettings = QoL.Features.HelloWorld_OpenSettings
        if OpenSettings then
            OpenSettings()
        else
            print("|cff00ff00[HelloWorld]|r: Settings panel not available.")
        end

    elseif cmd == "help" then
        print("|cff00ff00[HelloWorld]|r Commands:")
        print("  /fuloh hello - Open settings panel")
        print("  /fuloh hello toggle - Toggle auto-greeting on/off")
        print("  /fuloh hello settings - Open settings panel")
        print("  /fuloh hello help - Show this help message")

    else
        print("|cff00ff00[HelloWorld]|r: Unknown command. Type /fuloh hello help for commands.")
    end
end

-- Hook for additional settings in the main hub
function HelloWorld:OnSettingsUI(parent, yOffset)
    local Settings = QoL.Features.HelloWorld_Settings
    if Settings and Settings.CreateEmbeddedSettings then
        return Settings.CreateEmbeddedSettings(parent, yOffset)
    end
    return yOffset
end

-- Register this feature with Fuloh_QoL
QoL:RegisterFeature(HelloWorld)
