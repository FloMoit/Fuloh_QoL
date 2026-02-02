# Audit Findings - Source Addon Analysis

## JoinedGroupReminder

### Files
- `JoinedGroupReminder.toc` - Addon manifest
- `Core.lua` - Main logic and event handling
- `Constants.lua` - Constants, dungeon teleport mappings, utility functions
- `UI.lua` - Reminder banner UI creation and display

### Dependencies
- **None** - No external libraries (no Ace3, no custom libs)
- Uses native WoW API only

### SavedVariables
- **Variable Name**: `JoinedGroupReminderDB`
- **Structure**:
  ```lua
  {
    activeReminder = {     -- Persists current reminder for /reload
      dungeonName = string,
      groupName = string
    },
    position = {           -- Reminder banner position
      point = string,
      relativePoint = string,
      x = number,
      y = number
    }
  }
  ```

### Events Registered
- `ADDON_LOADED` - Initialize DB and hook ApplyToGroup
- `LFG_LIST_JOINED_GROUP` - Trigger reminder when joining group
- `LFG_LIST_APPLICATION_STATUS_UPDATED` - Cache group data when applying
- `CHALLENGE_MODE_START` - Hide reminder when M+ starts
- `CHALLENGE_MODE_COMPLETED` - Hide reminder when M+ completes
- `GROUP_ROSTER_UPDATE` - Detect leaving group
- `PLAYER_ENTERING_WORLD` - Restore reminder on reload
- `PLAYER_LOGOUT` - Save state

### Slash Commands
- `/jgr` and `/joinedgroupreminder`
- **Subcommands**:
  - `test` - Show test reminder
  - `hide` - Hide current reminder
  - `show` - Show/refresh reminder
  - `debug` - Toggle debug mode

### Key Functions to Preserve
- `ns.ShowReminder(dungeonName, groupName)` - Display banner
- `ns.HideReminder(clearState)` - Hide banner
- `ns.IsReminderShown()` - Check if shown
- `ns.ClearCachedState()` - Clear internal state
- `ns.GetDungeonTeleportSpell(dungeonName)` - Get teleport spell ID
- `ns.HasDungeonTeleport(spellID)` - Check if player has teleport

### Global State
- `applicationCache` - Temporary cache keyed by searchResultID
- `currentReminderData` - Active reminder data
- `wasInGroup` - Previous group state for detecting leave
- `debugMode` - Debug logging toggle

### Special Considerations
- Uses `hooksecurefunc(C_LFGList, "ApplyToGroup")` to capture data
- Has complex event-driven state machine for tracking LFG applications
- Supports dungeon teleport buttons (Hero's Path spells)
- Persists reminder across `/reload`
- Frame is draggable and saves position

---

## HelloWorld

### Files
- `HelloWorld.toc` - Addon manifest
- `HelloWorld.lua` - Main logic and event handling
- `HelloWorldUtils.lua` - Pure greeting logic functions (testable)
- `HelloWorldSettings.lua` - Settings panel UI
- `HelloWorldUI.lua` - Minimap button
- `Test_HelloWorldUtils.lua` - Unit test file (not loaded in TOC)
- `icon.png` - Minimap button icon

### Dependencies
- **None** - No external libraries
- Uses native WoW API only

### SavedVariables
- **Variable Name**: `HelloWorldDB`
- **Structure**:
  ```lua
  {
    enabled = boolean,         -- Auto-greeting toggle (default: true)
    minimapPos = number,       -- Minimap button angle (default: 45)
    greetings = {              -- Custom greeting messages
      [1] = string,
      [2] = string,
      ...
    }
  }
  ```

### Events Registered
- `PLAYER_LOGIN` - Initialize DB and print load message
- `GROUP_ROSTER_UPDATE` - Detect group changes and send greeting
- `PLAYER_ENTERING_WORLD` - Update group state on entering world
- `ADDON_LOADED` - Initialize settings panel

### Slash Commands
- `/helloworld` and `/hw`
- **Subcommands**:
  - `toggle` - Toggle auto-greeting on/off
  - `settings` / `config` / `` (empty) - Open settings panel
  - `help` - Show help message

### Key Functions to Preserve
- `HelloWorldUtils.GetGreetingChannel(oldState, newState, enabled)` - Determine greeting logic
- `HelloWorldUtils.DefaultGreetings` - Default greeting list
- `HelloWorldUI.CreateMinimapButton()` - Create minimap button
- `HelloWorldUI.OpenSettings()` - Open settings panel
- `HelloWorldUI.UpdateVisual()` - Update minimap button state

### Global State
- `state` - Group tracking: `{ inHome, inInst, numMembers }`
- `HelloWorldUtils` - Global table for utility functions
- `HelloWorldUI` - Global table for UI functions

### Special Considerations
- Has Settings panel integration (modern Dragonflight API)
- Creates minimap button with drag support
- Uses randomized delay (4-6 seconds) before greeting for natural feel
- Handles both PARTY and INSTANCE_CHAT channels
- Supports custom greeting messages via multi-line EditBox
- Uses `pcall()` for safe chat error handling

---

## Migration Strategy

### Settings Migration Map
```
JoinedGroupReminderDB → Fuloh_QoLDB.JoinedGroupReminder
HelloWorldDB → Fuloh_QoLDB.HelloWorld
```

### Namespace Consolidation
- Both addons use addon-local namespaces (`local addonName, ns = ...`)
- JoinedGroupReminder uses `ns` for shared functions
- HelloWorld uses global `HelloWorldUtils` and `HelloWorldUI` tables
- **Target**: Move all to `Fuloh_QoL.Features.FeatureName` namespace

### Event Overlap Analysis
| Event | JGR | HW | Conflict? |
|-------|-----|----|----|
| `ADDON_LOADED` | ✓ | ✓ | No - different addon names |
| `GROUP_ROSTER_UPDATE` | ✓ | ✓ | **No** - Different purposes (JGR detects leave, HW sends greeting) |
| `PLAYER_ENTERING_WORLD` | ✓ | ✓ | **No** - Different purposes (JGR restores UI, HW updates state) |
| `PLAYER_LOGIN` | - | ✓ | No |
| `LFG_LIST_*` | ✓ | - | No |
| `CHALLENGE_MODE_*` | ✓ | - | No |
| `PLAYER_LOGOUT` | ✓ | - | No |

**Conclusion**: No event conflicts. Both can register the same events independently.

### Command Migration Map
```
/jgr [subcommand]         → /fuloh jgr [subcommand]
/joinedgroupreminder      → /fuloh jgr [subcommand]
/helloworld [subcommand]  → /fuloh hello [subcommand]
/hw [subcommand]          → /fuloh hello [subcommand]
```

### Feature Shortcuts
- **JoinedGroupReminder**: shortcut = `"jgr"`
- **HelloWorld**: shortcut = `"hello"`

---

## File Copy Plan

### JoinedGroupReminder
```
Source: C:\World of Warcraft\World of Warcraft\_retail_\Interface\AddOns\JoinedGroupReminder\
Destination: c:\World of Warcraft\World of Warcraft\_retail_\Interface\AddOns\Fuloh_QoL\Features\JoinedGroupReminder\

Files to copy:
- Core.lua → JoinedGroupReminder.lua (rename for clarity)
- Constants.lua → Constants.lua
- UI.lua → UI.lua
```

### HelloWorld
```
Source: C:\World of Warcraft\World of Warcraft\_retail_\Interface\AddOns\HelloWorld\
Destination: c:\World of Warcraft\World of Warcraft\_retail_\Interface\AddOns\Fuloh_QoL\Features\HelloWorld\

Files to copy:
- HelloWorld.lua → HelloWorld.lua
- HelloWorldUtils.lua → Utils.lua (rename to match plan)
- HelloWorldSettings.lua → Settings.lua (rename to match plan)
- HelloWorldUI.lua → UI.lua (rename to match plan)
- icon.png → icon.png (for minimap button)
```

---

## TOC Load Order

Based on dependencies within each feature:

```
Core.lua
Features\JoinedGroupReminder\Constants.lua
Features\JoinedGroupReminder\UI.lua
Features\JoinedGroupReminder\JoinedGroupReminder.lua
Features\HelloWorld\Utils.lua
Features\HelloWorld\UI.lua
Features\HelloWorld\Settings.lua
Features\HelloWorld\HelloWorld.lua
```

**Rationale**:
- Core.lua must load first to establish namespace and registry
- JGR: Constants → UI → Main (UI needs Constants, Main needs both)
- HW: Utils → UI → Settings → Main (Settings needs UI.OpenSettings, Main needs Utils)
