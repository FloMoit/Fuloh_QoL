# Implementation Plan - Fuloh_QoL Feature Hub

This project aims to consolidate multiple World of Warcraft addons into a single "Feature Hub" called `Fuloh_QoL`. Each original addon will become a "Feature" that can be toggled on or off from the game's settings menu.

## Addons to Integrate
- **JoinedGroupReminder**: Reminds the player of the dungeon name and group name when joining an LFG group.
- **HelloWorld**: Automatically greets party members when joining a group.

## Project Structure
```
Fuloh_QoL/
├── Fuloh_QoL.toc          # Addon definition (with proper load order)
├── Core.lua               # Main addon initialization, feature registry, and command router
├── Libs/                  # Shared libraries (if needed)
├── Features/              # Sub-modules
│   ├── JoinedGroupReminder/
│   │   ├── JoinedGroupReminder.lua
│   │   ├── Constants.lua
│   │   └── UI.lua
│   └── HelloWorld/
│       ├── HelloWorld.lua
│       ├── Utils.lua
│       ├── UI.lua
│       └── Settings.lua
└── SavedVariables/        # (Managed by WoW)
```

## Feature Registration Contract
All features must implement the following API:
- **`Feature:Initialize()`** - Called once on ADDON_LOADED, before Enable
- **`Feature:Enable()`** - Register events and start functionality
- **`Feature:Disable()`** - Unregister events and stop functionality
- **`Feature:GetDefaults()`** - Return table of default settings
- **`Feature.name`** - Unique identifier (e.g., "JoinedGroupReminder")
- **`Feature.shortcut`** - Command shortcut (e.g., "jgr" for `/fuloh jgr`)

## Command Structure
All addon commands will use the unified format:
```
/fuloh <shortcut> <command>
```
Examples:
- `/fuloh jgr toggle` - Toggle JoinedGroupReminder on/off
- `/fuloh hello config` - Open HelloWorld config

## Step 0: Pre-Implementation Audit
- Read both source addons completely to identify:
    - Dependencies (Ace3, custom libraries, etc.)
    - Event handlers and potential conflicts
    - Current slash commands to be migrated
    - Existing SavedVariables structure
    - Any shared utility functions
- Document findings before proceeding

## Step 1: Create Core Infrastructure
- **Create `Fuloh_QoL.toc`** with:
    - `## Interface: 110002` (or current patch version)
    - `## Title: Fuloh's Quality of Life Hub`
    - `## Author: Fuloh`
    - `## Version: 1.0.0`
    - `## Notes: Consolidated QoL features with per-feature toggles`
    - `## SavedVariables: Fuloh_QoLDB`
    - File load order (Core.lua first, then all feature files)
- **Create `Core.lua`** with:
    - `Fuloh_QoL` namespace initialization
    - Feature registry system (table to track registered features)
    - `RegisterFeature(feature)` method with pcall() error handling
    - `EnableFeature(name)` and `DisableFeature(name)` with error wrapping
    - SavedVariables initialization with per-feature defaults
    - Unified command router for `/fuloh <shortcut> <command>`
    - Migration logic: check for old SavedVariables and import on first load
    - Settings category registration using Settings API

## Step 2: Port JoinedGroupReminder
- Move files from `C:\World of Warcraft\World of Warcraft\_retail_\Interface\AddOns\JoinedGroupReminder` to `Fuloh_QoL\Features\JoinedGroupReminder\`.
- Refactor the code to:
    - Implement the Feature API contract (Initialize, Enable, Disable, GetDefaults)
    - Register itself as a feature: `Fuloh_QoL:RegisterFeature(JoinedGroupReminder)`
    - Set `.name = "JoinedGroupReminder"` and `.shortcut = "jgr"`
    - Wrap all event registration in `Enable()` and unregister in `Disable()`
    - Use `Fuloh_QoLDB.JoinedGroupReminder` for settings
    - Convert slash commands to work with `/fuloh jgr` router
- Add feature files to TOC in correct load order
- **Important**: Settings persist even when feature is disabled

## Step 3: Test JoinedGroupReminder Standalone
- `/reload` and verify initialization
- Test enable/disable toggle from settings UI
- Verify slash commands work: `/fuloh jgr <command>`
- Confirm settings persist when disabled
- Check for any Lua errors in chat or BugSack

## Step 4: Port HelloWorld
- Move files from `C:\World of Warcraft\World of Warcraft\_retail_\Interface\AddOns\HelloWorld` to `Fuloh_QoL\Features\HelloWorld\`.
- Refactor similar to JoinedGroupReminder:
    - Implement Feature API contract
    - Register with `Fuloh_QoL:RegisterFeature(HelloWorld)`
    - Set `.name = "HelloWorld"` and `.shortcut = "hello"`
    - Integration with feature system (Enable/Disable pattern)
    - Use `Fuloh_QoLDB.HelloWorld` for settings
    - Convert commands to `/fuloh hello` router
- Add feature files to TOC in correct load order

## Step 5: Implement Settings UI
- Use `Settings.RegisterAddOnCategory` to create "Fuloh's QoL" category
- Use `Settings.RegisterSetting` and `Settings.CreateCheckbox` for each feature
- Add "Features" section with checkboxes:
    - When toggled ON: Call `Fuloh_QoL:EnableFeature(name)` with error handling
    - When toggled OFF: Call `Fuloh_QoL:DisableFeature(name)` with error handling
- Display error messages if feature fails to enable/disable
- Settings always persist regardless of enabled state

## Step 6: Full Integration Testing
- `/reload` to test clean initialization
- Test each feature independently (enable/disable)
- Test both features enabled simultaneously
- Verify no event conflicts or Lua errors
- Test all slash commands: `/fuloh jgr` and `/fuloh hello`
- Confirm settings persist between sessions and when features disabled
- Test migration: Install with old addons' SavedVariables present

## Step 7: Cleanup & Documentation
- Add "Uninstalling Original Addons" section to README:
    - Disable old JoinedGroupReminder and HelloWorld addons in addon list
    - Settings will auto-migrate on first Fuloh_QoL load
    - After migration confirmed, can delete old addon folders
    - Old SavedVariables will remain in WTF folder (harmless)
- Document available commands: `/fuloh help`, `/fuloh jgr`, `/fuloh hello`
- Create in-game `/fuloh help` command listing all features and shortcuts

## Constraints & Considerations
- **Namespace Collision**: All feature globals move to `Fuloh_QoL.Features.<name>` and settings to `Fuloh_QoLDB.<name>`
- **API Version**: Targeting WoW Retail API (11.0.2 or current patch)
- **Dependencies**: Copy any required libraries to `Fuloh_QoL/Libs/` and update TOC
- **Error Handling**: All feature Enable/Disable calls wrapped in pcall() to prevent cascade failures
- **Event Conflicts**: If features share events, Core.lua routes to all registered handlers
- **Settings Persistence**: Disabled features retain their settings in Fuloh_QoLDB
- **Migration Safety**: Old SavedVariables imported only once (track with migration flag)
