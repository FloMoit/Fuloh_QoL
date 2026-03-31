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

---

## General Commands

| Command | Description |
|---|---|
| `/fuloh help` | Show all commands |
| `/fuloh list` | List all features and status |

Settings panel: `ESC > Interface Options > AddOns > Fuloh's QoL`

---

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

**Author:** Fuloh (with lots of AI help)
