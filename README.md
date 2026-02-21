# Fuloh's Quality of Life Hub

A consolidated addon for World of Warcraft that combines multiple QoL features into a single, manageable hub with per-feature toggles.

## 📚 Context7 Documentation
This project is configured to use **Context7** for up-to-date WoW API documentation.
- **Workflow:** See [.agent/workflows/use-wow-api-context7.md](.agent/workflows/use-wow-api-context7.md) for usage.
- **Prompting:** Use the phrase `use context7` or `use library wowwiki-archive_fandom_wiki_world_of_warcraft_api` in your prompts to trigger live documentation lookups.
- **API Key:** Pre-configured in [.cursorrules](.cursorrules).

## Table of Contents
- [Features](#features)
- [Installation](#installation)
- [User Guide](#user-guide)
- [Architecture](#architecture)
- [Developer Guide](#developer-guide)
- [Technical Reference](#technical-reference)

---

## Features

### JoinedGroupReminder
Displays a reminder banner when joining a Mythic Plus group via LFG, showing the dungeon name and group name. Includes teleport buttons for dungeons where you have Hero's Path teleports available.

**Commands:**
- `/fuloh jgr show` - Show or refresh reminder
- `/fuloh jgr hide` - Hide reminder
- `/fuloh jgr test` - Show test reminder
- `/fuloh jgr debug` - Toggle debug mode

**Features:**
- Automatic reminder when joining LFG groups
- Draggable banner (position saved)
- One-click dungeon teleport button (if available)
- Auto-hides when M+ starts or when leaving group
- Persists across `/reload`

### HelloWorld
Automatically greets party members when joining a group with customizable greeting messages.

**Commands:**
- `/fuloh hello` - Open greeting settings
- `/fuloh hello toggle` - Toggle auto-greeting on/off
- `/fuloh hello settings` - Open greeting customization panel
- `/fuloh hello help` - Show help

**Features:**
- Random greeting selection from custom list
- Natural delay (4-6 seconds) before greeting
- Smart channel detection (PARTY vs INSTANCE_CHAT)

- Customizable greeting messages

---

## Installation

1. Extract the `Fuloh_QoL` folder to `World of Warcraft\_retail_\Interface\AddOns\`
2. **If migrating from standalone addons:**
   - Keep your old `JoinedGroupReminder` and `HelloWorld` folders initially
   - Launch the game - your settings will auto-migrate on first load
   - After confirming settings migrated correctly, you can disable or delete the old addons

---

## User Guide

### General Commands

- `/fuloh help` - Show all available commands
- `/fuloh list` - List all features and their status

### Settings

Access the settings panel via:
- In-game: `ESC > Interface Options > AddOns > Fuloh's QoL`
- Command: Open individual feature settings using `/fuloh <shortcut> settings`

In the main settings panel, you can:
- Enable/disable each feature independently
- Changes take effect immediately (no reload required)

### Migrating from Standalone Addons

If you previously used `JoinedGroupReminder` or `HelloWorld` as standalone addons:

1. **Install Fuloh_QoL** (don't delete old addons yet)
2. **Launch the game** - You'll see migration messages in chat
3. **Verify your settings** - Check that your custom greetings, positions, etc. carried over
4. **Disable old addons** in the addon list (or delete their folders)
5. **Old SavedVariables remain** in the WTF folder (harmless, can be left alone)

#### What Gets Migrated

**JoinedGroupReminder:**
- Banner position
- Active reminder state (if you reload while in a group)

**HelloWorld:**
- Custom greeting messages

- Enabled/disabled state

### Uninstalling

To completely remove Fuloh_QoL:

1. Delete the `Fuloh_QoL` folder from `Interface\AddOns`
2. (Optional) Remove saved settings:
   - Delete `Fuloh_QoLDB` from your SavedVariables file
   - Location: `WTF\Account\<YourAccount>\SavedVariables\Fuloh_QoL.lua`

---

## Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────┐
│                     Fuloh_QoL.toc                       │
│              (Defines load order)                        │
└──────────────────┬──────────────────────────────────────┘
                   │
         ┌─────────▼──────────┐
         │     Core.lua       │
         │  - Namespace       │
         │  - Registry        │
         │  - Commands        │
         │  - Settings UI     │
         │  - Migration       │
         └─────────┬──────────┘
                   │
         ┌─────────▼──────────────────────┐
         │    Feature Registration        │
         └─────────┬──────────────────────┘
                   │
    ┌──────────────┴───────────────┐
    │                              │
┌───▼────────────────┐  ┌─────────▼─────────────┐
│ JoinedGroupReminder│  │     HelloWorld        │
│  - Constants.lua   │  │  - Utils.lua          │
│  - UI.lua          │  
│  - JoinedGroup...  │  │  - Settings.lua       │
│                    │  │  - HelloWorld.lua     │
└────────────────────┘  └───────────────────────┘
```

### Core Components

#### 1. Core.lua
Central hub that provides:
- **Namespace**: `Fuloh_QoL` global table
- **Feature Registry**: Tracks and manages all registered features
- **Command Router**: Parses `/fuloh` commands and routes to features
- **Settings Management**: Database initialization and migration
- **Settings UI**: Main settings panel integration
- **Error Handling**: pcall() wrapping for all feature operations

#### 2. Feature Modules
Self-contained modules in `Features/<FeatureName>/` that:
- Implement the Feature API contract
- Export functions to `Fuloh_QoL.Features` namespace
- Register themselves with Core on load
- Handle their own events and UI

#### 3. Database Structure
```lua
Fuloh_QoLDB = {
    _migrationComplete = true,  -- Migration flag

    JoinedGroupReminder = {
        enabled = true,
        position = { point, relativePoint, x, y },
        activeReminder = { dungeonName, groupName },
    },

    HelloWorld = {
        enabled = true,

        greetings = { "o/", "Hey!", ... },
    },
}
```

### Data Flow

#### Feature Enable Flow
```
User clicks checkbox
    ↓
Core.lua:EnableFeature(name)
    ↓
Feature:Enable() [pcall wrapped]
    ↓
Feature registers events
    ↓
Database updated: enabled = true
    ↓
Success message to chat
```

#### Command Routing Flow
```
User types: /fuloh jgr test
    ↓
Core.lua SlashCmdList handler
    ↓
Parse: shortcut="jgr", args="test"
    ↓
Core.lua:RouteCommand(shortcut, args)
    ↓
Find feature by shortcut
    ↓
Feature:HandleCommand(args) [pcall wrapped]
    ↓
Feature executes command logic
```

---

## Developer Guide

### Adding a New Feature

#### Step 1: Create Feature Structure

```
Features/
└── MyFeature/
    ├── MyFeature.lua     # Main feature file (required)
    ├── Utils.lua         # Helper functions (optional)
    └── UI.lua            # UI components (optional)
```

#### Step 2: Implement Feature API

**Required Properties:**
- `Feature.name` (string) - Unique identifier
- `Feature.shortcut` (string) - Command shortcut (2-5 chars)

**Required Methods:**
- `Feature:Initialize()` - One-time setup
- `Feature:Enable()` - Start functionality
- `Feature:Disable()` - Stop functionality
- `Feature:GetDefaults()` - Return default settings table

**Optional Methods:**
- `Feature:HandleCommand(args)` - Handle commands

#### Step 3: Complete Example

```lua
-- Features/MyFeature/MyFeature.lua

-- Get namespace reference
local QoL = Fuloh_QoL
if not QoL then
    error("Fuloh_QoL namespace not found. Core.lua must load first.")
    return
end

-- Create feature object
local MyFeature = {
    name = "MyFeature",
    shortcut = "mf",
}

-- Private state
local eventFrame = CreateFrame("Frame")
local isActive = false

-- Database accessor
local function GetDB()
    return Fuloh_QoLDB and Fuloh_QoLDB.MyFeature or {}
end

-- Event handler
local function OnEvent(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        print("MyFeature: Player entered world!")
    end
end

--------------------------------------------------------------------------------
-- Feature API Implementation
--------------------------------------------------------------------------------

function MyFeature:Initialize()
    -- One-time setup (called once on addon load)
    print("MyFeature initialized")

    -- Get references to other components if needed
    -- local Utils = QoL.Features.MyFeature_Utils
end

function MyFeature:Enable()
    -- Register events and start functionality
    eventFrame:SetScript("OnEvent", OnEvent)
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    isActive = true
end

function MyFeature:Disable()
    -- Unregister events and stop functionality
    eventFrame:UnregisterAllEvents()
    eventFrame:SetScript("OnEvent", nil)
    isActive = false
end

function MyFeature:GetDefaults()
    -- Return default settings structure
    return {
        enabled = true,
        customSetting = "default value",
        numberSetting = 42,
    }
end

function MyFeature:HandleCommand(args)
    -- Handle /fuloh mf <args>
    local cmd = args:lower():match("^(%S+)") or ""

    if cmd == "test" then
        print("MyFeature: Test command executed!")
    elseif cmd == "help" or cmd == "" then
        print("MyFeature Commands:")
        print("  /fuloh mf test - Run test")
        print("  /fuloh mf help - Show help")
    else
        print("MyFeature: Unknown command. Type '/fuloh mf help'")
    end
end

-- Register with Fuloh_QoL
QoL:RegisterFeature(MyFeature)
```

#### Step 4: Update TOC File

Add your feature files to `Fuloh_QoL.toc` **after** Core.lua and **in dependency order**:

```
Core.lua
Features\MyFeature\Utils.lua
Features\MyFeature\MyFeature.lua
```

#### Step 5: Test Your Feature

1. `/reload` in game
2. Check for load errors
3. Test: `/fuloh list` - Your feature should appear
4. Test: `/fuloh mf help` - Commands should work
5. Test toggle: Settings panel checkbox

---

## Technical Reference

### Feature API Reference

#### Feature.name (string)
Unique identifier for the feature. Used in:
- Database keys (`Fuloh_QoLDB[name]`)
- Settings panel
- Enable/Disable operations

**Example:** `"JoinedGroupReminder"`

#### Feature.shortcut (string)
Command shortcut for routing. Should be:
- Short (2-5 characters recommended)
- Lowercase
- Unique across all features

**Example:** `"jgr"` (for JoinedGroupReminder)

#### Feature:Initialize()
Called once when the addon loads (ADDON_LOADED event).

**Purpose:**
- Set up references to other components
- Initialize UI elements that persist (like minimap buttons)
- Register global hooks (not tied to enable/disable)
- Set up one-time state

**Example:**
```lua
function MyFeature:Initialize()
    -- Get references to exported functions
    self.Utils = QoL.Features.MyFeature_Utils

    -- Create persistent UI
    self.frame = CreateFrame("Frame", "MyFeatureFrame", UIParent)

    -- Register global hooks (not disabled)
    hooksecurefunc("SomeGlobalFunction", function()
        -- Hook logic
    end)
end
```

#### Feature:Enable()
Called when feature is enabled (startup or user toggle).

**Purpose:**
- Register WoW events
- Start timers or background tasks
- Show UI elements
- Begin functionality

**Important:**
- Must be idempotent (safe to call multiple times)
- Should check if already enabled to avoid double-registration
- All events MUST be unregistered in Disable()

**Example:**
```lua
function MyFeature:Enable()
    -- Register events
    self.eventFrame:SetScript("OnEvent", self.OnEvent)
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:RegisterEvent("PLAYER_LEAVING_WORLD")

    -- Start functionality
    self:StartWatching()

    -- Show UI
    if self.frame then
        self.frame:Show()
    end
end
```

#### Feature:Disable()
Called when feature is disabled (user toggle).

**Purpose:**
- Unregister ALL WoW events
- Cancel timers
- Hide UI elements
- Stop functionality

**Important:**
- Must completely stop all feature activity
- Feature should be "silent" when disabled
- Settings should persist (don't clear them)

**Example:**
```lua
function MyFeature:Disable()
    -- Unregister all events
    self.eventFrame:UnregisterAllEvents()
    self.eventFrame:SetScript("OnEvent", nil)

    -- Stop functionality
    self:StopWatching()

    -- Hide UI
    if self.frame then
        self.frame:Hide()
    end
end
```

#### Feature:GetDefaults()
Returns default settings structure for this feature.

**Purpose:**
- Define default values for all settings
- Used by Core during database initialization
- Merged with existing settings (doesn't overwrite)

**Return:** Table with default values

**Example:**
```lua
function MyFeature:GetDefaults()
    return {
        enabled = true,              -- Should default to true
        showNotifications = true,
        threshold = 100,
        messages = { "Hello", "Hi" },
        position = nil,              -- nil = use default positioning
    }
end
```

#### Feature:HandleCommand(args) [Optional]
Handles commands routed via `/fuloh <shortcut> <args>`.

**Parameters:**
- `args` (string) - Everything after the shortcut

**Purpose:**
- Provide feature-specific commands
- Parse arguments and execute logic
- Display help messages

**Example:**
```lua
function MyFeature:HandleCommand(args)
    local cmd, param = args:match("^(%S+)%s*(.*)$")
    cmd = cmd and cmd:lower() or ""

    if cmd == "set" then
        if param ~= "" then
            local db = GetDB()
            db.customSetting = param
            print("MyFeature: Setting updated to: " .. param)
        else
            print("MyFeature: Usage: /fuloh mf set <value>")
        end

    elseif cmd == "toggle" then
        QoL:ToggleFeature("MyFeature")

    elseif cmd == "help" or cmd == "" then
        print("MyFeature Commands:")
        print("  /fuloh mf set <value> - Update setting")
        print("  /fuloh mf toggle - Toggle feature")
        print("  /fuloh mf help - Show this help")

    else
        print("MyFeature: Unknown command '" .. cmd .. "'")
        print("Type '/fuloh mf help' for available commands")
    end
end
```

### Core API Reference

#### QoL:RegisterFeature(feature)
Registers a feature with the hub.

**Parameters:**
- `feature` (table) - Feature object implementing Feature API

**Returns:** boolean (success)

**Validation:**
- Checks for required properties and methods
- Validates uniqueness of name and shortcut
- Returns false and prints error if validation fails

**Usage:**
```lua
local MyFeature = { name = "MyFeature", shortcut = "mf" }
-- ... implement API methods ...
QoL:RegisterFeature(MyFeature)
```

#### QoL:EnableFeature(name)
Enables a feature by name.

**Parameters:**
- `name` (string) - Feature name

**Returns:** boolean (success)

**Side Effects:**
- Calls `Feature:Enable()` (pcall wrapped)
- Updates `Fuloh_QoLDB[name].enabled = true`
- Prints success/error message

**Usage:**
```lua
QoL:EnableFeature("MyFeature")
```

#### QoL:DisableFeature(name)
Disables a feature by name.

**Parameters:**
- `name` (string) - Feature name

**Returns:** boolean (success)

**Side Effects:**
- Calls `Feature:Disable()` (pcall wrapped)
- Updates `Fuloh_QoLDB[name].enabled = false`
- Prints success/error message

**Usage:**
```lua
QoL:DisableFeature("MyFeature")
```

#### QoL:ToggleFeature(name)
Toggles a feature on or off.

**Parameters:**
- `name` (string) - Feature name

**Returns:** boolean (success)

**Usage:**
```lua
QoL:ToggleFeature("MyFeature")
```

### Namespace Conventions

#### Fuloh_QoL (global)
Main addon namespace. Contains:
- `Features` - Table of all registered features and exported functions
- `RegisteredFeatures` - Registry of feature objects
- Core methods (RegisterFeature, EnableFeature, etc.)

#### Fuloh_QoL.Features (table)
Storage for exported functions from features.

**Naming Convention:**
```lua
QoL.Features.<FeatureName>_<FunctionName>
QoL.Features.<FeatureName>_<ComponentName>
```

**Examples:**
```lua
-- Exported functions
QoL.Features.JoinedGroupReminder_ShowReminder
QoL.Features.HelloWorld_Utils
QoL.Features.MyFeature_OpenSettings

-- Usage in other files
local ShowReminder = QoL.Features.JoinedGroupReminder_ShowReminder
ShowReminder(dungeonName, groupName)
```

#### Fuloh_QoLDB (global SavedVariable)
Persisted settings. Structure:
```lua
Fuloh_QoLDB = {
    _migrationComplete = boolean,

    [FeatureName] = {
        enabled = boolean,
        -- ... feature-specific settings ...
    },
}
```

**Accessing:**
```lua
local function GetDB()
    return Fuloh_QoLDB and Fuloh_QoLDB.MyFeature or {}
end

-- Usage
local db = GetDB()
local value = db.customSetting
```

### Event Handling Patterns

#### Pattern 1: Frame per Feature
Each feature maintains its own event frame.

```lua
local eventFrame = CreateFrame("Frame")

function Feature:Enable()
    eventFrame:SetScript("OnEvent", OnEvent)
    eventFrame:RegisterEvent("EVENT_NAME")
end

function Feature:Disable()
    eventFrame:UnregisterAllEvents()
    eventFrame:SetScript("OnEvent", nil)
end
```

#### Pattern 2: Conditional Event Processing
Process events only when feature is enabled.

```lua
local function OnEvent(self, event, ...)
    -- Double-check enabled state
    local db = GetDB()
    if not db.enabled then return end

    -- Process event
    if event == "PLAYER_ENTERING_WORLD" then
        -- Handle event
    end
end
```

#### Pattern 3: State Tracking
Track previous state to detect changes.

```lua
local previousState = nil

local function OnUpdate()
    local currentState = GetCurrentState()

    if currentState ~= previousState then
        -- State changed, do something
        HandleStateChange(previousState, currentState)
    end

    previousState = currentState
end
```

### Common Patterns

#### Database Access Pattern
Always use accessor function for safety.

```lua
local function GetDB()
    return Fuloh_QoLDB and Fuloh_QoLDB.MyFeature or {}
end

-- Usage - safe even if Fuloh_QoLDB doesn't exist yet
local db = GetDB()
local value = db.setting or "default"
```

#### Feature Reference Pattern
Get references in Initialize(), use throughout.

```lua
function Feature:Initialize()
    self.Utils = QoL.Features.MyFeature_Utils
    self.UI = QoL.Features.MyFeature_UI
end

function Feature:Enable()
    self.Utils.DoSomething()
    self.UI.Show()
end
```

#### Export Pattern
Export functions to namespace for inter-feature access.

```lua
-- At end of file
local function MyUtilityFunction()
    -- Implementation
end

-- Export
QoL.Features.MyFeature_UtilityFunction = MyUtilityFunction

-- Or export entire table
local Utils = {
    DoThis = function() end,
    DoThat = function() end,
}
QoL.Features.MyFeature_Utils = Utils
```

#### Error Message Pattern
Use consistent color coding for user messages.

```lua
local COLOR_PREFIX = "|cff00bfff"   -- Light blue
local COLOR_ERROR = "|cffff4444"    -- Red
local COLOR_SUCCESS = "|cff44ff44"  -- Green
local COLOR_RESET = "|r"

print(COLOR_PREFIX .. "[MyFeature]" .. COLOR_RESET .. " Message")
print(COLOR_PREFIX .. "[MyFeature]" .. COLOR_RESET .. " " ..
      COLOR_ERROR .. "Error!" .. COLOR_RESET)
```

### File Organization

#### Single Feature, Single File
For simple features:
```lua
-- Features/SimpleFeature/SimpleFeature.lua
-- Contains everything: API implementation, helpers, UI
```

#### Multi-File Features
For complex features, split by responsibility:

```
Features/ComplexFeature/
├── Constants.lua     # Constants, lookup tables
├── Utils.lua         # Pure functions, no side effects
├── UI.lua            # Frame creation, UI logic
├── Events.lua        # Event handlers (optional)
└── ComplexFeature.lua # Main file, Feature API, coordination
```

**Load Order in TOC:**
```
Core.lua
Features\ComplexFeature\Constants.lua
Features\ComplexFeature\Utils.lua
Features\ComplexFeature\UI.lua
Features\ComplexFeature\Events.lua
Features\ComplexFeature\ComplexFeature.lua
```

### Debugging Tips

#### Enable Debug Mode
```lua
local debugMode = false

local function Debug(...)
    if debugMode then
        print("|cffff9900[MyFeature Debug]|r", ...)
    end
end

-- In HandleCommand
if cmd == "debug" then
    debugMode = not debugMode
    print("MyFeature debug:", debugMode and "ON" or "OFF")
end
```

#### Inspect Database
```lua
-- View entire feature database
/run for k,v in pairs(Fuloh_QoLDB.MyFeature) do print(k,v) end

-- Check if feature is enabled
/run print(Fuloh_QoLDB.MyFeature.enabled)

-- Force enable in console
/run Fuloh_QoL:EnableFeature("MyFeature")
```

#### Check Registration
```lua
-- List all registered features
/run for name,feat in pairs(Fuloh_QoL.RegisteredFeatures) do print(name, feat.shortcut) end

-- Verify feature exists
/run print(Fuloh_QoL.RegisteredFeatures["MyFeature"] and "Found" or "Not found")
```

### Migration System

If your feature replaces a standalone addon, implement migration:

```lua
-- In Core.lua, add to MigrateOldSettings()
if MyOldAddonDB then
    Print("Migrating settings from MyOldAddon...")
    Fuloh_QoLDB.MyFeature = Fuloh_QoLDB.MyFeature or {}

    -- Copy settings
    for k, v in pairs(MyOldAddonDB) do
        Fuloh_QoLDB.MyFeature[k] = v
    end

    -- Ensure enabled
    if Fuloh_QoLDB.MyFeature.enabled == nil then
        Fuloh_QoLDB.MyFeature.enabled = true
    end

    migrated = true
end
```

---

## Technical Details

- **Interface Version:** 120000, 120001 (TWW)
- **SavedVariables:** `Fuloh_QoLDB`
- **Architecture:** Feature-based modular system
- **Settings API:** Modern Dragonflight/TWW Settings API
- **Error Handling:** All feature operations wrapped in pcall() for safety
- **Load Order:** Core.lua → Feature files (in dependency order)
- **Namespace:** Global `Fuloh_QoL`, local feature references

## Support & Issues

Report issues or request features at: [Your GitHub/Contact]

## Version History

### v1.0.0 (2026-02-01)
- Initial release
- Consolidated JoinedGroupReminder and HelloWorld
- Added unified command structure (`/fuloh`)
- Implemented automatic settings migration
- Created modular feature system

## Credits

**Author:** Fuloh (with lots of AI help)

## License

