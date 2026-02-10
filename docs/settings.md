# NPC Favor -- Settings Reference

**Mod version:** 1.2.2.4
**Settings file:** `<savegame>/npc_favor_settings.xml`
**XML root tag:** `NPCSettings` (used by `NPCSettings.lua`)

All settings are persisted per-savegame and validated on load. Numeric values are clamped to their listed range. String enums fall back to their default if an invalid value is loaded.

---

## Core Settings

| Setting | Key | Type | Default | Range | Description |
|---|---|---|---|---|---|
| Enabled | `enabled` | bool | `true` | -- | Master toggle for the entire NPC system |
| Max NPCs | `maxNPCs` | int | `10` | 1 -- 16 | Maximum number of active NPCs in the world |
| Work Start Hour | `npcWorkStart` | int | `8` | 0 -- 23 | Hour (24h) when NPCs begin their work day |
| Work End Hour | `npcWorkEnd` | int | `17` | 0 -- 23 | Hour (24h) when NPCs stop working |
| Favor Frequency | `favorFrequency` | int | `3` | 1 -- 30 | How often NPCs ask for favors (in game days) |
| Spawn Distance | `npcSpawnDistance` | int | `150` | 50 -- 1000 | Radius in meters within which NPCs can spawn around the player |

## Display Settings

| Setting | Key | Type | Default | Range | Description |
|---|---|---|---|---|---|
| Show Names | `showNames` | bool | `true` | -- | Display NPC names above their heads |
| Show Notifications | `showNotifications` | bool | `true` | -- | Show NPC notification messages on screen |
| Show Favor List | `showFavorList` | bool | `true` | -- | Display the active favor list HUD element |
| Show Relationship Bars | `showRelationshipBars` | bool | `true` | -- | Show relationship progress bars near NPCs |
| Show Map Markers | `showMapMarkers` | bool | `true` | -- | Show NPC icons on the map. Toggling off removes all NPC hotspots immediately |
| Show NPC Paths | `showNPCPaths` | bool | `false` | -- | Render NPC movement paths (visual debug aid) |
| Name Display Distance | `nameDisplayDistance` | int | `50` | 10 -- 500 | Maximum distance in meters at which NPC names are visible |
| Notification Duration | `notificationDuration` | int | `4000` | 1000 -- 10000 | Duration in milliseconds that notifications remain on screen |

## Gameplay Settings

| Setting | Key | Type | Default | Range | Description |
|---|---|---|---|---|---|
| Enable Favors | `enableFavors` | bool | `true` | -- | Allow NPCs to ask the player for favors |
| Enable Gifts | `enableGifts` | bool | `true` | -- | Allow the player to give gifts to NPCs |
| Enable Relationship System | `enableRelationshipSystem` | bool | `true` | -- | Enable the 7-tier relationship progression system |
| NPC Help Player | `npcHelpPlayer` | bool | `true` | -- | Allow NPCs to offer help to the player at high relationship levels |
| NPC Socialize | `npcSocialize` | bool | `true` | -- | Allow NPCs to socialize with each other |
| NPC Drive Vehicles | `npcDriveVehicles` | bool | `true` | -- | Allow NPCs to operate vehicles |
| NPC Vehicle Mode | `npcVehicleMode` | string | `"hybrid"` | `"hybrid"`, `"realistic"`, `"visual"` | Vehicle behavior: hybrid (static prop, real when working), realistic (always real), visual (props only) |
| Allow Multiple Favors | `allowMultipleFavors` | bool | `true` | -- | Allow the player to have more than one active favor at a time |
| Max Active Favors | `maxActiveFavors` | int | `5` | 1 -- 20 | Maximum number of simultaneously active favors |
| Favor Time Limit | `favorTimeLimit` | bool | `true` | -- | Enforce a time limit on completing favors |
| Relationship Decay | `relationshipDecay` | bool | `false` | -- | Enable gradual loss of relationship over time if not maintained |
| Decay Rate | `decayRate` | float | `1.0` | 0 -- 10 | Speed multiplier for relationship decay (only applies when decay is enabled) |

## Difficulty Settings

| Setting | Key | Type | Default | Range / Valid Values | Description |
|---|---|---|---|---|---|
| Favor Difficulty | `favorDifficulty` | string | `"normal"` | `"easy"`, `"normal"`, `"hard"` | Overall difficulty of favor objectives. Maps to multiplier: easy=0.7, normal=1.0, hard=1.5 |
| Relationship Gain Multiplier | `relationshipGainMultiplier` | float | `1.0` | 0.1 -- 5.0 | Multiplier applied to all positive relationship changes |
| Relationship Loss Multiplier | `relationshipLossMultiplier` | float | `1.0` | 0.1 -- 5.0 | Multiplier applied to all negative relationship changes |
| Favor Reward Multiplier | `favorRewardMultiplier` | float | `1.0` | 0.1 -- 5.0 | Multiplier applied to favor completion rewards (money and relationship) |
| Favor Penalty Multiplier | `favorPenaltyMultiplier` | float | `1.0` | 0.1 -- 5.0 | Multiplier applied to penalties for failing or ignoring favors |

## AI Behavior Settings

| Setting | Key | Type | Default | Range / Valid Values | Description |
|---|---|---|---|---|---|
| NPC Activity Level | `npcActivityLevel` | string | `"normal"` | `"low"`, `"normal"`, `"high"` | Overall NPC activity intensity. Maps to multiplier: low=0.5, normal=1.0, high=1.5 |
| NPC Movement Speed | `npcMovementSpeed` | float | `1.0` | 0.1 -- 5.0 | Multiplier for NPC walking/movement speed |
| NPC Work Duration | `npcWorkDuration` | float | `1.0` | 0.1 -- 5.0 | Multiplier for how long NPCs spend on work tasks |
| NPC Break Frequency | `npcBreakFrequency` | float | `1.0` | 0.1 -- 5.0 | Multiplier for how often NPCs take breaks from work |
| NPC Social Frequency | `npcSocialFrequency` | float | `1.0` | 0.1 -- 5.0 | Multiplier for how often NPCs seek social interactions |

## Debug Settings

| Setting | Key | Type | Default | Description |
|---|---|---|---|---|
| Debug Mode | `debugMode` | bool | `false` | Master toggle for debug information display |
| Show Paths | `showPaths` | bool | `false` | Render NPC pathfinding routes |
| Show Spawn Points | `showSpawnPoints` | bool | `false` | Render NPC spawn point markers |
| Show AI Decisions | `showAIDecisions` | bool | `false` | Display AI decision-making info in the log |
| Show Relationship Changes | `showRelationshipChanges` | bool | `false` | Log every relationship value change |
| Log to File | `logToFile` | bool | `false` | Write debug output to a log file on disk |

## Sound Settings

| Setting | Key | Type | Default | Description |
|---|---|---|---|---|
| Sound Effects | `soundEffects` | bool | `true` | Enable ambient and interaction sound effects |
| Voice Lines | `voiceLines` | bool | `true` | Enable NPC voice lines during conversations |
| UI Sounds | `uiSounds` | bool | `true` | Enable sounds for UI interactions (dialog open/close, buttons) |
| Notification Sound | `notificationSound` | bool | `true` | Play a sound when notifications appear |

## Performance Settings

| Setting | Key | Type | Default | Range / Valid Values | Description |
|---|---|---|---|---|---|
| Update Frequency | `updateFrequency` | string | `"normal"` | `"low"`, `"normal"`, `"high"` | How often NPC logic ticks. Maps to multiplier: low=0.5, normal=1.0, high=2.0 |
| NPC Render Distance | `npcRenderDistance` | int | `200` | 50 -- 1000 | Maximum distance in meters at which NPCs are visually rendered |
| NPC Update Distance | `npcUpdateDistance` | int | `300` | 100 -- 2000 | Maximum distance in meters at which NPC AI logic runs at full rate. Beyond 2x this distance, NPCs are not updated. Between 1x and 2x, NPCs have a 10% chance per tick of being updated. |
| Batch Updates | `batchUpdates` | bool | `true` | -- | Spread NPC updates across frames to reduce per-frame cost |
| Max Updates Per Frame | `maxUpdatesPerFrame` | int | `5` | 1 -- 50 | Maximum number of NPCs updated in a single frame when batching is enabled |

## Multiplayer Sync Settings

| Setting | Key | Type | Default | Description |
|---|---|---|---|---|
| Sync NPCs | `syncNPCs` | bool | `true` | Synchronize NPC positions and states across all players |
| Sync Relationships | `syncRelationships` | bool | `true` | Synchronize relationship data across all players |
| Sync Favors | `syncFavors` | bool | `true` | Synchronize active favor data across all players |

---

## In-Game Settings UI

The following 13 settings are exposed in the FS25 general settings page under the **NPC Favor System** header:

| Setting | Widget | Notes |
|---|---|---|
| Enable NPC System | Toggle (Yes/No) | Master on/off for all NPCs |
| Max NPC Count | Dropdown (1--16) | |
| Show NPC Names | Toggle (Yes/No) | |
| Show Notifications | Toggle (Yes/No) | |
| Show Favor List | Toggle (Yes/No) | *Added in v1.2.2.4* |
| Show Relationship Bars | Toggle (Yes/No) | *Added in v1.2.2.4* |
| Show Map Markers | Toggle (Yes/No) | Immediately creates/removes map hotspots. *Added in v1.2.2.4* |
| Enable Favors | Toggle (Yes/No) | |
| Enable Gifts | Toggle (Yes/No) | *Added in v1.2.2.4* |
| Allow Multiple Favors | Toggle (Yes/No) | *Added in v1.2.2.4* |
| Max Active Favors | Dropdown (1, 2, 3, 5, 8, 10) | *Added in v1.2.2.4* |
| Relationship Decay | Toggle (Yes/No) | *Added in v1.2.2.4* |
| Debug Mode | Toggle (Yes/No) | |

Settings update in-memory immediately and persist when the game is saved. They are written to `npc_favor_settings.xml` inside the savegame directory during the `FSCareerMissionInfo.saveToXMLFile` hook (matching the UsedPlus save pattern). In multiplayer, changes broadcast to all clients via `NPCSettingsSyncEvent`.

All other settings must be edited directly in the `npc_favor_settings.xml` file within the savegame directory while the game is not running, or via console if applicable.

## Helper Functions

`NPCSettings` provides utility methods derived from settings:

| Method | Returns | Description |
|---|---|---|
| `getDifficultyMultiplier()` | 0.7 / 1.0 / 1.5 | Numeric multiplier from `favorDifficulty` |
| `getActivityLevelMultiplier()` | 0.5 / 1.0 / 1.5 | Numeric multiplier from `npcActivityLevel` |
| `getUpdateFrequencyValue()` | 0.5 / 1.0 / 2.0 | Numeric multiplier from `updateFrequency` |
| `isWorkTime(hour)` | bool | True if the given hour falls within work hours |
| `getWorkDuration()` | int | Number of work hours per day |
| `getEffectiveMaxNPCs()` | int | Max NPCs adjusted for update frequency (low: 70%, high: 130%) |
| `shouldUpdateNPC(npc, dist)` | bool | Whether an NPC at the given distance should be updated this tick |
| `shouldRenderNPC(npc, dist)` | bool | Whether an NPC at the given distance should be rendered |
