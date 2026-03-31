# Fuloh's Quality of Life Hub

A consolidated WoW addon combining multiple QoL features with per-feature toggles.
Obviously made with AI.

## Context7 Documentation
This project is configured to use **Context7** for up-to-date WoW API documentation.
- **Workflow:** See [.agent/workflows/use-wow-api-context7.md](.agent/workflows/use-wow-api-context7.md) for usage.
- **Prompting:** Use `use context7` or `use library wowwiki-archive_fandom_wiki_world_of_warcraft_api` to trigger live documentation lookups.
- **API Key:** Pre-configured in [.cursorrules](.cursorrules).

---

## Features

### JoinedGroupReminder
Banner when joining a Mythic+ group via LFG, with one-click teleport if available.

| Command | Description |
|---|---|
| `/fuloh jgr show` | Show/refresh reminder |
| `/fuloh jgr hide` | Hide reminder |
| `/fuloh jgr test` | Show test reminder |
| `/fuloh jgr debug` | Toggle debug mode |

### GGGuys (Auto GG)
Sends a random congratulations message in party chat on timed M+ completions (8–15 s delay).

| Command | Description |
|---|---|
| `/fuloh gg toggle` | Toggle on/off |
| `/fuloh gg help` | Show help |

### KeyRerollReminder
Opt-in popup at dungeon start; pulses center-screen on timed completion to remind you to reroll.

| Command | Description |
|---|---|
| `/fuloh krr toggle` | Toggle on/off |
| `/fuloh krr test` | Show test reminder |
| `/fuloh krr help` | Show help |

### HelloWorld
Auto-greets party members when joining a group.

| Command | Description |
|---|---|
| `/fuloh hello toggle` | Toggle on/off |
| `/fuloh hello settings` | Open customization panel |
| `/fuloh hello help` | Show help |

### FilledGroupAlert
Plays a sound when your group reaches 5 members.

| Command | Description |
|---|---|
| `/fuloh fga toggle` | Toggle on/off |
| `/fuloh fga test` | Trigger test sound |
| `/fuloh fga debug` | Toggle debug mode |
| `/fuloh fga help` | Show help |

### KeyVote
Polls the party on which key to run. Uses addon messages for cross-client sync; also responds to `!vote` / `!keyvote` in party chat.

| Command | Description |
|---|---|
| `/fuloh vote start` | Start a key vote |
| `/fuloh vote cancel` | Cancel current vote |
| `/fuloh vote test` | Preview vote UI |
| `/fuloh vote testresult` | Preview results UI |
| `/fuloh vote help` | Show help |

### MageFoodReminder
Reminds healers to stock Mage Food before entering a Mythic dungeon.

| Command | Description |
|---|---|
| `/fuloh mfr test` | Show test reminder |
| `/fuloh mfr help` | Show help |

---

## Installation

1. Extract `Fuloh_QoL` to `World of Warcraft\_retail_\Interface\AddOns\`
2. **Migrating from standalone addons** (JoinedGroupReminder / HelloWorld):
   - Keep old addon folders, launch the game — settings auto-migrate on first load
   - Disable or delete old addons after confirming migration

---

## General Commands

| Command | Description |
|---|---|
| `/fuloh help` | Show all commands |
| `/fuloh list` | List all features and status |

Settings panel: `ESC > Interface Options > AddOns > Fuloh's QoL`

---

## Architecture

```
Fuloh_QoL.toc
    └── Core.lua  (namespace, registry, commands, settings UI, migration)
            ├── JoinedGroupReminder/  (Constants, UI, JGR)
            ├── HelloWorld/           (Utils, Settings, HelloWorld)
            ├── GGGuys/               (Utils, Settings, GGGuys)
            ├── KeyRerollReminder/    (UI, KeyRerollReminder)
            ├── FilledGroupAlert/     (Constants, Settings, FilledGroupAlert)
            ├── KeyVote/              (Constants, Utils, UI, Settings, KeyVote)
            └── MageFoodReminder/     (Constants, UI, MageFoodReminder)
```

**DB structure:**
```lua
Fuloh_QoLDB = {
    [FeatureName] = { enabled = bool, -- feature-specific settings },
}
```

---

## Developer Guide

### Adding a Feature

1. Create `Features/MyFeature/MyFeature.lua` (split into Constants/Utils/UI as needed)
2. Implement the Feature API:
   - **Required:** `name`, `shortcut`, `Initialize()`, `Enable()`, `Disable()`, `GetDefaults()`
   - **Optional:** `label`, `tooltip`, `HandleCommand(args)`, `OnSettingsUI(panel)`
3. Register: `QoL:RegisterFeature(MyFeature)`
4. Add files to `Fuloh_QoL.toc` after `Core.lua`, in dependency order

**Minimal example:**
```lua
local QoL = Fuloh_QoL
local MyFeature = { name = "MyFeature", shortcut = "mf" }
local eventFrame = CreateFrame("Frame")

function MyFeature:GetDefaults() return { enabled = true } end
function MyFeature:Initialize() end
function MyFeature:Enable()
    eventFrame:SetScript("OnEvent", function(_, event) end)
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
end
function MyFeature:Disable()
    eventFrame:UnregisterAllEvents()
    eventFrame:SetScript("OnEvent", nil)
end

QoL:RegisterFeature(MyFeature)
```

### Key Patterns

- **DB access:** `local db = Fuloh_QoLDB and Fuloh_QoLDB.MyFeature or {}`
- **Export:** `QoL.Features.MyFeature_FunctionName = fn`
- **Colors:** `|cff00bfff` (blue), `|cff44ff44` (green), `|cffff4444` (red)
- **Font:** `Fonts\\FRIZQT__.TTF`
- **Frame style:** `BackdropTemplate`, dark bg `(0.08, 0.08, 0.12)`, gold bar `(0.9, 0.7, 0.2)`

### Core API

| Method | Description |
|---|---|
| `QoL:RegisterFeature(feature)` | Register a feature |
| `QoL:EnableFeature(name)` | Enable by name |
| `QoL:DisableFeature(name)` | Disable by name |
| `QoL:ToggleFeature(name)` | Toggle by name |

### Debugging

```lua
-- List registered features
/run for k,v in pairs(Fuloh_QoL.RegisteredFeatures) do print(k, v.shortcut) end
-- Inspect DB
/run for k,v in pairs(Fuloh_QoLDB.MyFeature) do print(k,v) end
-- Force enable
/run Fuloh_QoL:EnableFeature("MyFeature")
```

---

## Technical Details

- **Interface:** 120000, 120001, 120005 (TWW)
- **SavedVariables:** `Fuloh_QoLDB`
- **Error handling:** All feature calls wrapped in `pcall()`

---

## Version History

### v1.1.0
- Added FilledGroupAlert, KeyVote, MageFoodReminder

### v1.0.0 (2026-02-01)
- Initial release: JoinedGroupReminder, HelloWorld, GGGuys, KeyRerollReminder
- Unified `/fuloh` command structure, modular feature system, auto-migration

---

**Author:** Fuloh (with lots of AI help)
