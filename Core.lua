-- Core.lua
-- Fuloh_QoL Feature Hub - Core infrastructure
-- Provides feature registration, command routing, and settings management

-- Initialize main namespace
Fuloh_QoL = Fuloh_QoL or {}
local QoL = Fuloh_QoL

-- Feature registry
QoL.Features = {}
QoL.RegisteredFeatures = {}

-- Event frame for core events
local eventFrame = CreateFrame("Frame")

-- Migration flag (set to true after first migration)
local MIGRATION_COMPLETE_KEY = "_migrationComplete"

-- Settings Category (stored for access by slash command)
local settingsCategory = nil

-- Color codes for consistent messaging
local COLOR_PREFIX = "|cff00bfff"  -- Light blue
local COLOR_ERROR = "|cffff4444"   -- Red
local COLOR_SUCCESS = "|cff44ff44" -- Green
local COLOR_RESET = "|r"

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

local function Print(msg)
    print(COLOR_PREFIX .. "[Fuloh QoL]" .. COLOR_RESET .. " " .. msg)
end

local function PrintError(msg)
    print(COLOR_PREFIX .. "[Fuloh QoL]" .. COLOR_RESET .. " " .. COLOR_ERROR .. msg .. COLOR_RESET)
end

local function PrintSuccess(msg)
    print(COLOR_PREFIX .. "[Fuloh QoL]" .. COLOR_RESET .. " " .. COLOR_SUCCESS .. msg .. COLOR_RESET)
end

--------------------------------------------------------------------------------
-- Feature Registration API
--------------------------------------------------------------------------------

--- Register a feature with the hub
-- @param feature table - Feature object implementing the Feature API
-- @return boolean - Success status
function QoL:RegisterFeature(feature)
    if not feature then
        PrintError("RegisterFeature: feature is nil")
        return false
    end

    if not feature.name then
        PrintError("RegisterFeature: feature.name is required")
        return false
    end

    if not feature.shortcut then
        PrintError("RegisterFeature: feature.shortcut is required for " .. feature.name)
        return false
    end

    -- Validate API methods
    local requiredMethods = {"Initialize", "Enable", "Disable", "GetDefaults"}
    for _, method in ipairs(requiredMethods) do
        if type(feature[method]) ~= "function" then
            PrintError("RegisterFeature: feature." .. method .. " is required for " .. feature.name)
            return false
        end
    end

    -- Check for duplicate names or shortcuts
    if self.RegisteredFeatures[feature.name] then
        PrintError("RegisterFeature: feature '" .. feature.name .. "' already registered")
        return false
    end

    for _, registered in pairs(self.RegisteredFeatures) do
        if registered.shortcut == feature.shortcut then
            PrintError("RegisterFeature: shortcut '" .. feature.shortcut .. "' already in use by " .. registered.name)
            return false
        end
    end

    -- Register the feature
    self.RegisteredFeatures[feature.name] = feature
    self.Features[feature.name] = feature  -- Also store in Features table for easy access

    return true
end

--- Enable a feature
-- @param name string - Feature name
-- @return boolean - Success status
function QoL:EnableFeature(name)
    local feature = self.RegisteredFeatures[name]
    if not feature then
        PrintError("EnableFeature: Unknown feature '" .. tostring(name) .. "'")
        return false
    end

    -- Check if already enabled
    if Fuloh_QoLDB[name] and Fuloh_QoLDB[name].enabled then
        Print(feature.name .. " is already enabled.")
        return true
    end

    -- Call Enable with error handling
    local success, err = pcall(function()
        feature:Enable()
    end)

    if not success then
        PrintError("Failed to enable " .. feature.name .. ": " .. tostring(err))
        return false
    end

    -- Update database
    Fuloh_QoLDB[name] = Fuloh_QoLDB[name] or {}
    Fuloh_QoLDB[name].enabled = true

    PrintSuccess(feature.name .. " enabled.")
    return true
end

--- Disable a feature
-- @param name string - Feature name
-- @return boolean - Success status
function QoL:DisableFeature(name)
    local feature = self.RegisteredFeatures[name]
    if not feature then
        PrintError("DisableFeature: Unknown feature '" .. tostring(name) .. "'")
        return false
    end

    -- Check if already disabled
    if Fuloh_QoLDB[name] and not Fuloh_QoLDB[name].enabled then
        Print(feature.name .. " is already disabled.")
        return true
    end

    -- Call Disable with error handling
    local success, err = pcall(function()
        feature:Disable()
    end)

    if not success then
        PrintError("Failed to disable " .. feature.name .. ": " .. tostring(err))
        return false
    end

    -- Update database
    Fuloh_QoLDB[name] = Fuloh_QoLDB[name] or {}
    Fuloh_QoLDB[name].enabled = false

    PrintSuccess(feature.name .. " disabled.")
    return true
end

--- Toggle a feature on/off
-- @param name string - Feature name
-- @return boolean - Success status
function QoL:ToggleFeature(name)
    if not Fuloh_QoLDB[name] or not Fuloh_QoLDB[name].enabled then
        return self:EnableFeature(name)
    else
        return self:DisableFeature(name)
    end
end

--------------------------------------------------------------------------------
-- Settings Migration
--------------------------------------------------------------------------------

local function MigrateOldSettings()
    -- Only migrate once
    if Fuloh_QoLDB[MIGRATION_COMPLETE_KEY] then
        return
    end

    local migrated = false

    -- Migrate JoinedGroupReminderDB
    if JoinedGroupReminderDB then
        Print("Migrating settings from JoinedGroupReminder...")
        Fuloh_QoLDB.JoinedGroupReminder = Fuloh_QoLDB.JoinedGroupReminder or {}

        -- Copy all data
        for k, v in pairs(JoinedGroupReminderDB) do
            Fuloh_QoLDB.JoinedGroupReminder[k] = v
        end

        -- Ensure enabled flag exists (default to true since addon was active)
        if Fuloh_QoLDB.JoinedGroupReminder.enabled == nil then
            Fuloh_QoLDB.JoinedGroupReminder.enabled = true
        end

        migrated = true
    end

    -- Migrate HelloWorldDB
    if HelloWorldDB then
        Print("Migrating settings from HelloWorld...")
        Fuloh_QoLDB.HelloWorld = Fuloh_QoLDB.HelloWorld or {}

        -- Copy all data
        for k, v in pairs(HelloWorldDB) do
            Fuloh_QoLDB.HelloWorld[k] = v
        end

        -- Ensure enabled flag exists
        if Fuloh_QoLDB.HelloWorld.enabled == nil then
            Fuloh_QoLDB.HelloWorld.enabled = true
        end

        migrated = true
    end

    if migrated then
        PrintSuccess("Settings migration complete!")
        Print("You can now disable the old JoinedGroupReminder and HelloWorld addons.")
    end

    -- Mark migration as complete
    Fuloh_QoLDB[MIGRATION_COMPLETE_KEY] = true
end

--------------------------------------------------------------------------------
-- SavedVariables Initialization
--------------------------------------------------------------------------------

local function InitializeDatabase()
    Fuloh_QoLDB = Fuloh_QoLDB or {}

    -- Migrate old settings if present
    MigrateOldSettings()

    -- Initialize each registered feature's settings with defaults
    for name, feature in pairs(QoL.RegisteredFeatures) do
        Fuloh_QoLDB[name] = Fuloh_QoLDB[name] or {}

        -- Get defaults from feature
        local success, defaults = pcall(function()
            return feature:GetDefaults()
        end)

        if success and type(defaults) == "table" then
            -- Merge defaults (don't overwrite existing values)
            for k, v in pairs(defaults) do
                if Fuloh_QoLDB[name][k] == nil then
                    Fuloh_QoLDB[name][k] = v
                end
            end
        end

        -- Ensure enabled flag exists (default to true)
        if Fuloh_QoLDB[name].enabled == nil then
            Fuloh_QoLDB[name].enabled = false
        end
    end
end

--------------------------------------------------------------------------------
-- Feature Initialization
--------------------------------------------------------------------------------

local function InitializeFeatures()
    for name, feature in pairs(QoL.RegisteredFeatures) do
        -- Initialize feature
        local success, err = pcall(function()
            feature:Initialize()
        end)

        if not success then
            PrintError("Failed to initialize " .. name .. ": " .. tostring(err))
        end

        -- Enable if enabled in settings
        if Fuloh_QoLDB[name] and Fuloh_QoLDB[name].enabled then
            success, err = pcall(function()
                feature:Enable()
            end)

            if not success then
                PrintError("Failed to enable " .. name .. ": " .. tostring(err))
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Command Router
--------------------------------------------------------------------------------

local function ShowHelp()
    Print("Available commands:")
    Print("  /fuloh help - Show this help message")
    Print("  /fuloh list - List all features and their status")
    Print(" ")
    Print("Feature commands:")

    for name, feature in pairs(QoL.RegisteredFeatures) do
        Print("  /fuloh " .. feature.shortcut .. " - " .. (feature.label or name) .. " commands")
    end
end

local function ShowFeatureList()
    Print("Registered features:")

    for name, feature in pairs(QoL.RegisteredFeatures) do
        local enabled = Fuloh_QoLDB[name] and Fuloh_QoLDB[name].enabled
        local status = enabled and COLOR_SUCCESS .. "Enabled" or COLOR_ERROR .. "Disabled"
        Print("  " .. (feature.label or name) .. " [" .. feature.shortcut .. "] - " .. status .. COLOR_RESET)
    end
end

local function RouteCommand(shortcut, args)
    -- Find feature by shortcut
    local targetFeature = nil
    for name, feature in pairs(QoL.RegisteredFeatures) do
        if feature.shortcut == shortcut then
            targetFeature = feature
            break
        end
    end

    if not targetFeature then
        PrintError("Unknown feature shortcut: " .. shortcut)
        Print("Type '/fuloh help' for available commands.")
        return
    end

    -- Check if feature has a HandleCommand method
    if type(targetFeature.HandleCommand) == "function" then
        local success, err = pcall(function()
            targetFeature:HandleCommand(args)
        end)

        if not success then
            PrintError("Error in " .. targetFeature.name .. " command handler: " .. tostring(err))
        end
    else
        PrintError(targetFeature.name .. " does not support commands.")
    end
end

-- Main slash command handler
SLASH_FULOH1 = "/fuloh"
SlashCmdList["FULOH"] = function(msg)
    msg = strtrim(msg or "")

    if msg == "" then
        -- Open options if available
        if settingsCategory and Settings and Settings.OpenToCategory then
            local categoryID = settingsCategory.GetID and settingsCategory:GetID() or settingsCategory.ID
            Settings.OpenToCategory(categoryID)
        else
            ShowHelp()
        end
        return
    end

    if msg == "help" then
        ShowHelp()
        return
    end

    if msg == "list" then
        ShowFeatureList()
        return
    end

    -- Parse: /fuloh <shortcut> <args>
    local shortcut, args = msg:match("^(%S+)%s*(.*)$")
    if not shortcut then
        shortcut = msg
        args = ""
    end

    RouteCommand(shortcut, args)
end

--------------------------------------------------------------------------------
-- Settings UI Registration
--------------------------------------------------------------------------------



local function RegisterSettings()
    -- Use modern Settings API (Dragonflight/TWW)
    if not Settings or not Settings.RegisterCanvasLayoutCategory then
        Print("Warning: Modern Settings API not available. Settings panel will not be registered.")
        return
    end

    -- Create main settings panel
    local panel = CreateFrame("Frame", "Fuloh_QoL_SettingsPanel")
    panel.name = "Fuloh's QoL"

    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Fuloh's Quality of Life Hub")

    -- Description
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Enable or disable individual features. Changes take effect immediately.")

    -- Register category FIRST
    settingsCategory = Settings.RegisterCanvasLayoutCategory(panel, "Fuloh's QoL")
    Settings.RegisterAddOnCategory(settingsCategory)

    -- Now create feature checkboxes
    local yOffset = -60

    -- Sort features by name for consistent UI
    local sortedFeatureNames = {}
    for name in pairs(QoL.RegisteredFeatures) do
        table.insert(sortedFeatureNames, name)
    end
    table.sort(sortedFeatureNames)

    for _, name in ipairs(sortedFeatureNames) do
        local feature = QoL.RegisteredFeatures[name]
        local featureLabel = feature.label or feature.name
        -- Create checkbox using Settings API
        local checkboxSetting = Settings.RegisterProxySetting(
            settingsCategory,
            name .. "_Enabled",
            Settings.VarType.Boolean,
            featureLabel,
            Fuloh_QoLDB[name] and Fuloh_QoLDB[name].enabled or false,
            function() return Fuloh_QoLDB[name] and Fuloh_QoLDB[name].enabled end,
            function(value)
                if value then
                    QoL:EnableFeature(name)
                else
                    QoL:DisableFeature(name)
                end
            end
        )

        -- Create checkbox frame manually for canvas layout
        local checkbox = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
        checkbox:SetPoint("TOPLEFT", 20, yOffset)
        checkbox.Text:SetText(featureLabel)

        -- Bind checkbox to setting
        checkbox:SetChecked(Fuloh_QoLDB[name] and Fuloh_QoLDB[name].enabled or false)
        checkbox:SetScript("OnClick", function(self)
            local isChecked = self:GetChecked()
            if isChecked then
                QoL:EnableFeature(name)
            else
                QoL:DisableFeature(name)
            end
        end)

        yOffset = yOffset - 30

        -- Hook for additional settings
        if type(feature.OnSettingsUI) == "function" then
            local newY = feature:OnSettingsUI(panel, yOffset)
            if newY then
                yOffset = newY
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

local function OnAddonLoaded(loadedAddonName)
    if loadedAddonName ~= "Fuloh_QoL" then return end

    -- Initialize database and migrate old settings
    InitializeDatabase()

    -- Initialize all features
    InitializeFeatures()

    -- Register settings panel
    RegisterSettings()

    -- Print load message
    PrintSuccess("Loaded! Type /fuloh help for commands.")

    -- Unregister ADDON_LOADED
    eventFrame:UnregisterEvent("ADDON_LOADED")
end

local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        OnAddonLoaded(...)
    end
end

-- Register core events
eventFrame:SetScript("OnEvent", OnEvent)
eventFrame:RegisterEvent("ADDON_LOADED")
