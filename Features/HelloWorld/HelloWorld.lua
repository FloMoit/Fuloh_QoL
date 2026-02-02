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
    shortcut = "hello",
}

-- State management (private to this feature)
local state = { inHome = false, inInst = false, numMembers = 0 }
local eventFrame = CreateFrame("Frame")

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
    local oldState = {
        inHome = state.inHome,
        inInst = state.inInst,
        numMembers = state.numMembers
    }
    UpdateGroupState()

    local db = GetDB()
    local Utils = QoL.Features.HelloWorld_Utils

    -- Check if we should greet and which channel to use
    local channel = Utils and Utils.GetGreetingChannel(oldState, state, db.enabled)

    if channel then
        -- Multi-second delay (4 to 6 seconds) to make it look natural
        local delay = math.random(40, 60) / 10

        C_Timer.After(delay, function()
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
    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        OnGroupRosterUpdate()
    end
end

--------------------------------------------------------------------------------
-- Feature API Implementation
--------------------------------------------------------------------------------

function HelloWorld:Initialize()
    -- Initialize settings panel
    local Settings = QoL.Features.HelloWorld_Settings
    if Settings and Settings.Initialize then
        Settings.Initialize()
    end

    -- Create minimap button
    local UI = QoL.Features.HelloWorld_UI
    if UI and UI.CreateMinimapButton then
        UI.CreateMinimapButton()
    end

    -- Initialize group state
    UpdateGroupState()
end

function HelloWorld:Enable()
    -- Register events
    eventFrame:SetScript("OnEvent", OnEvent)
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

    -- Update UI
    local UI = QoL.Features.HelloWorld_UI
    if UI and UI.UpdateVisual then
        UI.UpdateVisual()
    end

    -- Update group state
    UpdateGroupState()
end

function HelloWorld:Disable()
    -- Unregister events
    eventFrame:UnregisterAllEvents()
    eventFrame:SetScript("OnEvent", nil)

    -- Update UI
    local UI = QoL.Features.HelloWorld_UI
    if UI and UI.UpdateVisual then
        UI.UpdateVisual()
    end
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
        enabled = true,
        minimapPos = 45,
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

-- Register this feature with Fuloh_QoL
QoL:RegisterFeature(HelloWorld)
