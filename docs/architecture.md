# FS25_NPCFavor -- Architecture Reference

Version 1.2.0.0 | Living Neighborhood System

---

## 1. File Structure

Every Lua source file in the mod, grouped by directory, with a one-line description.

### Root

| File | Purpose |
|------|---------|
| `main.lua` | Entry point. Sources all modules in dependency order, installs FS25 game hooks (load, update, draw, save, unload), registers the E-key input binding, and handles multiplayer initial-state sync. |

### src/ (core)

| File | Purpose |
|------|---------|
| `src/NPCSystem.lua` | Central coordinator. Owns every subsystem, manages the NPC lifecycle (spawn, update, save/load, delete), building classification, field assignment, farmland ownership, vehicle spawning, event scheduling, and console commands. |

### src/scripts/

| File | Purpose |
|------|---------|
| `src/scripts/NPCAI.lua` | AI state machine (idle, walking, working, driving, resting, socializing, traveling, gathering) with personality-driven schedules, Markov-chain fallback transitions, stuck detection, vehicle usage logic, social pairing, and group activities. Also contains `NPCPathfinder` -- a waypoint pathfinder with road-spline following, terrain/slope/water avoidance, building collision checks, and an LRU path cache. |
| `src/scripts/NPCScheduler.lua` | Drives NPC daily routines via three schedule template types (farmer, worker, casual) with seasonal variants. Tracks game time, fires daily events (favor opportunities, social chances), manages NPC-NPC scheduled interactions, and applies weather-based activity modifiers. |
| `src/scripts/NPCEntity.lua` | Visual representation layer. Loads 3D models via `g_i3DManager` (or falls back to debug cube placeholders), manages per-NPC color tinting, map hotspots (`MapHotspot` API), LOD-based batch updates, visibility culling, tractor/vehicle prop loading and parking, animation state tracking, name-tag rendering, and terrain-height clamping. |
| `src/scripts/NPCRelationshipManager.lua` | Manages player-NPC relationships on a 0-100 scale across seven tiers (Hostile through Best Friend). Handles relationship change reasons with mood effects, temporary mood system with expiration, passive decay, grudge tracking, gift system with per-day limits and personality modifiers, and tier-based benefits (discounts, equipment borrowing, help offers, shared resources). |
| `src/scripts/NPCFavorSystem.lua` | Favor request generation, tracking, and completion. Defines seven favor types across six categories (vehicle, fieldwork, transport, repair, delivery, financial, security). Manages active/completed/failed/abandoned favor lists, weighted NPC selection for favor generation, time-of-day probability scaling, multi-step progression, notification queue, statistics tracking, and save/restore of active favors. |
| `src/scripts/NPCInteractionUI.lua` | World-space HUD rendering and dialog helper methods. Renders floating "Press [E]" hints with pulse animation, NPC name/relationship display, corner HUD favor list with color-coded progress bars. Provides helper methods used by `NPCDialog`: time-of-day greetings, personality-aware conversation topics, AI-state work descriptions, and personality color mapping. Also manages floating text popups for relationship changes. |

### src/events/

| File | Purpose |
|------|---------|
| `src/events/NPCStateSyncEvent.lua` | Server-to-client bulk sync of all NPC positions, AI states, names, personalities, relationships, and actions. Sent every 5 seconds and on player join. Includes DoS prevention (50-NPC cap), stream drain for oversized packets, and string truncation. |
| `src/events/NPCInteractionEvent.lua` | Client-to-server routing for player interactions. Handles five action types: favor accept, favor complete, favor abandon, gift, and relationship change. Includes action-type whitelist, farm ownership verification, NaN/infinity checks, distance validation, and sendToServer/execute pattern for single-player compatibility. |
| `src/events/NPCSettingsSyncEvent.lua` | Multiplayer settings synchronization. Two modes: TYPE_SINGLE (individual key/value change) and TYPE_BULK (full snapshot on player join). Enforces master-rights verification, maxNPCs range clamping, and typed value serialization (boolean, number, string). |

### src/gui/

| File | Purpose |
|------|---------|
| `src/gui/DialogLoader.lua` | Centralized dialog registration and lazy-loading manager. Dialogs are registered at startup with their XML path and class, then loaded into `g_gui` on first use. Provides `register()`, `ensureLoaded()`, `show()`, `close()`, `getDialog()`, and `cleanup()`. |
| `src/gui/NPCDialog.lua` | `MessageDialog` subclass for face-to-face NPC conversations. Five action buttons (Talk, Ask about work, Ask for favor, Give gift, Relationship info) with 3-layer hover effects (Bitmap background + invisible Button + Text label). Context-aware button states, relationship-gated actions, rich response area with favor progress, greeting generation, and mood indicators. |
| `src/gui/NPCListDialog.lua` | `MessageDialog` subclass displaying all active NPCs in a styled table popup. Shows up to 16 rows with columns for number, name, activity, distance, relationship, and farm. Includes per-row "Go" buttons for teleportation and color-coded relationship indicators. |

### src/settings/

| File | Purpose |
|------|---------|
| `src/settings/NPCConfig.lua` | Static configuration data: NPC name pools (with i18n keys), 12 personality type definitions, vehicle types and colors, clothing sets, and age range mappings. Provides randomized accessors for names, personalities, and vehicle configurations. |
| `src/settings/NPCSettings.lua` | Settings data object holding all mod configuration values organized into categories: core, display, gameplay, difficulty, AI, debug, sound, performance, and multiplayer. Provides `resetToDefaults()`, full XML save/load with per-field read/write, validation with numeric clamping, and helper methods (difficulty multiplier, work-time check, NPC culling distance). |
| `src/settings/NPCSettingsUI.lua` | Injects NPC settings widgets into the FS25 general settings layout via `UIHelper`. Creates BinaryOption toggles (enabled, show names, notifications, debug, favors) and a NumberOption for max NPCs. Each widget saves on change and supports refresh from the settings object. |
| `src/settings/NPCSettingsIntegration.lua` | Hooks `InGameMenuSettingsFrame.onFrameOpen` to add NPC settings to the ESC > Settings > Game Settings page. Dynamically creates section headers, binary toggles, and a multi-text dropdown for max NPC count using standard FS25 profiles. Includes multiplayer event routing for setting changes. |
| `src/settings/NPCFavorGUI.lua` | Console command registration and routing. Registers commands (`npcStatus`, `npcSpawn`, `npcList`, `npcReset`, `npcHelp`, `npcDebug`, `npcReload`, `npcTest`, `npcGoto`, `npcProbe`, `npcVehicleMode`) and routes them to `g_NPCSystem` methods. `npcList` opens the `NPCListDialog` popup when available, falling back to console text output. |

### src/utils/

| File | Purpose |
|------|---------|
| `src/utils/VectorHelper.lua` | Math utilities for 2D/3D distance, lerp, smoothstep, Bezier curves, dot/cross product, point-in-circle/rectangle tests, random point generation, vector normalization, rotation, perpendicular/reflection, and moveTowards. |
| `src/utils/TimeHelper.lua` | Time conversion (ms to HMS/DHMS), formatting (long/short), game-time accessors (hour, minute, day, month, year), time-of-day classification (morning, afternoon, evening, night), season detection (spring/summer/autumn/winter, growing season), time comparison helpers, and time prediction utilities. |
| `src/utils/SettingsHelper.lua` | UI helper functions for settings menu integration: settings button creation, section header and enable-toggle injection, generic get/set with default fallback, and auto-save on toggle change. |

### gui/ (XML layouts)

| File | Purpose |
|------|---------|
| `gui/NPCDialog.xml` | XML layout for the NPC conversation dialog. Defines the 5-button panel, response text area, NPC name/relationship display, and hover effect bitmap layers. |
| `gui/NPCListDialog.xml` | XML layout for the NPC roster popup. Defines the 16-row table grid with per-column text elements, row backgrounds, "Go" buttons, title/subtitle, and close button. |

---

## 2. Module Loading Order

`modDesc.xml` declares a single `<sourceFile>`:

```xml
<extraSourceFiles>
    <sourceFile filename="main.lua" />
</extraSourceFiles>
```

`main.lua` then uses `source()` to load all modules in strict dependency order:

```
Phase 1: Utilities (no dependencies)
  1. src/utils/VectorHelper.lua
  2. src/utils/TimeHelper.lua

Phase 2: Configuration and Settings (depend on utilities)
  3. src/settings/NPCConfig.lua
  4. src/settings/NPCSettings.lua
  5. src/settings/NPCSettingsIntegration.lua

Phase 3: Multiplayer Events (must load before NPCSystem references them)
  7. src/events/NPCStateSyncEvent.lua
  8. src/events/NPCInteractionEvent.lua
  9. src/events/NPCSettingsSyncEvent.lua

Phase 4: Core Systems (depend on config, settings, events)
 10. src/scripts/NPCRelationshipManager.lua
 11. src/scripts/NPCFavorSystem.lua
 12. src/scripts/NPCEntity.lua
 13. src/scripts/NPCAI.lua
 14. src/scripts/NPCScheduler.lua
 15. src/scripts/NPCInteractionUI.lua

Phase 5: GUI (depends on core systems)
 16. src/gui/DialogLoader.lua
 17. src/gui/NPCDialog.lua
 18. src/gui/NPCListDialog.lua
 19. src/settings/NPCFavorGUI.lua

Phase 6: Main Coordinator (depends on everything above)
 20. src/NPCSystem.lua
```

Note: `src/utils/SettingsHelper.lua` exists in the repository but is **not** sourced by `main.lua`. It appears to be a standalone utility that may be used via direct require or is a legacy/unused file.

---

## 3. Core Systems

### NPCSystem (Coordinator)

**File:** `src/NPCSystem.lua`

The central hub that owns and coordinates all subsystems. It is the only module instantiated directly from `main.lua`.

**Subsystem ownership (created in `NPCSystem.new()`):**

```
NPCSystem
  |-- settings              : NPCSettings
  |-- entityManager         : NPCEntity
  |-- aiSystem              : NPCAI
  |-- scheduler             : NPCScheduler
  |-- relationshipManager   : NPCRelationshipManager
  |-- favorSystem           : NPCFavorSystem
  |-- interactionUI         : NPCInteractionUI
  |-- settingsIntegration   : NPCSettingsIntegration
  |-- gui                   : NPCFavorGUI
  |-- config                : inline config table (name/personality getters)
```

**Lifecycle:**

```
new(mission, modDir, modName)
  --> Creates all subsystem instances
  --> Initializes name pools (male/female), personality list
  --> Sets up timers (sync, relocate, vehicle check)

onMissionLoaded()
  --> Delayed initialization via a counter in update()
  --> Waits for terrain + environment to be ready
  --> Then calls initializeNPCs()

initializeNPCs()
  --> classifyBuildings() -- categorizes placeables
  --> findNPCSpawnLocations() -- identifies buildings for NPC homes
  --> generateNewNPCs() -- creates NPC data objects at spawn locations
  --> assignFarmlands() -- assigns field ownership
  --> initializeNPCVehicles() -- spawns tractors/vehicles
  --> scheduler:start() -- begins daily routine system
  --> initEventScheduler() -- sets up emergent events

update(dt) -- called every frame
  --> Server: full simulation (AI, scheduler, favors, relationships, events, sync)
  --> Client: display only (UI updates, proximity checks from synced positions)

draw() -- called every frame in FSBaseMission.draw
  --> Routes to interactionUI:draw() for all HUD rendering

delete()
  --> Cleans up entities, vehicles, hotspots, console commands
```

**Key responsibilities beyond coordination:**
- Building classification (shop, gas station, production point, barn, etc.)
- NPC spawn location discovery from non-player-owned placeables
- Field assignment via `g_fieldManager` (nearest field to NPC home)
- Farmland ownership allocation
- Player position detection (4 fallback methods)
- NPC relocation when too far from player
- Vehicle mode management (hybrid/realistic/visual)
- Town reputation tracking (aggregate of all NPC relationships)
- Emergent event scheduling (Friday parties, harvest gatherings, morning markets, Sunday rest, rainy days)

### NPCAI (Decision-Making)

**File:** `src/scripts/NPCAI.lua`

Drives NPC behavior through an 8-state AI machine:

| State | Description |
|-------|-------------|
| `idle` | Standing still, waiting for next activity |
| `walking` | Moving on foot to a destination |
| `working` | Performing field work or tasks |
| `driving` | Operating a vehicle for travel |
| `resting` | Taking a break (lunch, fatigue) |
| `socializing` | Interacting with another NPC |
| `traveling` | Long-distance commuting |
| `gathering` | Participating in a group event |

**Decision pipeline:**
1. Scheduler provides the scheduled activity for the current time and personality
2. If no schedule applies, Markov-chain transition probabilities guide the fallback
3. Personality modifiers weight each decision (hardworking favors work, social favors socializing)
4. Seasonal and day-type adjustments (shorter work on Sundays, longer in summer)

**Pathfinding (`NPCPathfinder`):**
- Waypoint-based path generation with road-spline discovery
- Terrain height snapping with spiral search fallback
- Water detection and avoidance
- Building footprint avoidance (pushes waypoints out of building bounds)
- Steep terrain detection with perpendicular rerouting
- LRU path cache (50 paths, 60-second cleanup cycle)

**Vehicle logic:**
- Distance > 100m triggers vehicle travel mode
- Transport mode selection: walk / car / tractor based on distance and NPC profession
- Vehicle prop integration (visual only -- not registered FS25 Vehicles)

### NPCScheduler (Daily Routines)

**File:** `src/scripts/NPCScheduler.lua`

Three schedule template types, each defining time slots with activity names and priority levels:

| Template | Personalities | Variants |
|----------|--------------|----------|
| `farmer` | hardworking, grumpy | 4 seasonal (spring, summer, autumn, winter) |
| `worker` | generic | 1 default |
| `casual` | lazy, social | 1 default |

**Time slot format:**
```lua
{ start = 6, ["end"] = 12, activity = "field_preparation", priority = 2 }
```

Overnight ranges (start > end, e.g., 22:00 to 06:00) are handled correctly.

**Responsibilities:**
- Syncs game time from `g_currentMission.environment` each frame
- Throttled schedule updates (1-second interval)
- Daily event scheduling (favor opportunities, schedule checks, social chances)
- NPC-NPC interaction scheduling (socializing pairs based on proximity)
- Weather factor calculation affecting favor generation likelihood
- Energy/fatigue system affecting work duration and break timing

### NPCEntity (Visual Rendering)

**File:** `src/scripts/NPCEntity.lua`

**Entity lifecycle:** `initialize()` -> `createNPCEntity()` per NPC -> `updateNPCEntity()` per frame -> `removeNPCEntity()` on despawn

**Visual features:**
- Attempts `HumanGraphicsComponent`-based animated characters; falls back to debug cube
- Per-NPC color tinting via `colorScale` shader parameter
- Deterministic appearance from `npc.appearanceSeed` (scale, color)
- Height variation (0.95-1.05 Y-scale)
- Tractor prop: raw i3d node shown when NPC is doing field work
- Vehicle prop: car/pickup shown during commuting, parked at destination
- Name tags: world-to-screen projected text with personality-colored names and mood icons
- Terrain height clamping every frame to prevent floating/sinking

**Performance:**
- `maxVisibleDistance = 200` -- NPCs beyond this are hidden
- Batch updates: max 5 entities per `batchUpdate()` call (round-robin)
- LOD-based update frequency: closer NPCs update more often

**Map integration:**
- Map hotspots via FS25 `MapHotspot` API (replaces the unavailable `MapIcon` class)

### NPCRelationshipManager

**File:** `src/scripts/NPCRelationshipManager.lua`

**7-tier system (0-100 scale):**

| Range | Tier | Key Benefits |
|-------|------|-------------|
| 0-9 | Hostile | No favors, 30% gift effectiveness |
| 10-24 | Unfriendly | Minimal favor frequency |
| 25-39 | Neutral | Can ask favors, 5% discount |
| 40-59 | Acquaintance | Borrow equipment, 10% discount |
| 60-74 | Friend | NPC may offer help, 15% discount |
| 75-89 | Close Friend | NPC gives gifts, 18% discount |
| 90-100 | Best Friend | Shared resources, 20% discount |

**Mechanics:**
- Relationship change reasons with mood effects (FAVOR_COMPLETED: +15, GIFT_GIVEN: +8, etc.)
- Temporary mood system with expiration timers
- Passive relationship decay over time for inactive NPCs
- Per-day gift limits with personality modifiers on effectiveness
- NPC memory of past interactions with grudge tracking
- Color-coded relationship levels for UI display

### NPCFavorSystem

**File:** `src/scripts/NPCFavorSystem.lua`

**7 favor types across 6 categories:**

| Favor | Category | Difficulty | Duration | Reward |
|-------|----------|-----------|----------|--------|
| Borrow Tractor | vehicle | 1 | 24h | +15 rel, $500 |
| Help Harvest | fieldwork | 2 | 48h | +20 rel, $1000 |
| Transport Goods | transport | 1 | 12h | +10 rel, $300 |
| Fix Fence | repair | 1 | 6h | +10 rel, $200 |
| Deliver Seeds | delivery | 2 | 36h | +15 rel, $700 |
| Loan Money | financial | 3 | 168h | +25 rel, $1500 |
| Watch Property | security | 2 | 72h | +18 rel, $800 |

**Mechanics:**
- Weighted random NPC selection based on relationship level and personality
- Time-of-day probability scaling for favor generation
- Multi-step favor progression with location-based checkpoints
- Failure and abandonment penalties with reputation impact
- Notification queue with 5-second cooldown between messages
- Statistics tracking (total completed/failed, earnings, fastest completion)
- Favor cooldown per NPC to prevent spam

### NPCInteractionUI

**File:** `src/scripts/NPCInteractionUI.lua`

Split into two responsibilities:

**1. HUD Rendering (draw callback):**
- Floating "Press [E] to talk" hint with sine-wave pulse animation above nearby NPCs
- NPC name + relationship level text below the hint
- Corner HUD showing active favors list with progress bars
- Time-remaining color coding: green (>6h), yellow (2-6h), red (<2h)
- Floating text popups ("+5 relationship") that drift upward and fade

**2. Dialog Helper Methods (called by NPCDialog.lua):**
- `getGreetingForNPC()` -- time-of-day + relationship-level greeting (hostile is curt, best friend is warm)
- `getRandomConversationTopic()` -- personality-aware topics scaled by relationship tier (low: weather/farm, medium: family/market, high: memories/compliments)
- `getWorkStatusMessage()` -- translates AI state to first-person NPC voice
- `getPersonalityColor()` -- RGB color per personality trait for UI display

---

## 4. Event System (Multiplayer Sync)

All three event classes extend FS25's `Event` base class and use `InitEventClass()` for network registration.

### NPCStateSyncEvent

**Direction:** Server -> Client

**Trigger:** Every 5 seconds (periodic) + on `syncDirty` flag + on player join via `FSBaseMission.sendInitialClientState`

**Payload per NPC:** id, name, personality, x/y/z position, aiState, relationship, isActive, currentAction

**Security:** 50-NPC cap per packet, stream drain for excess entries, client-only execution gate, string truncation on all fields.

### NPCInteractionEvent

**Direction:** Client -> Server

**Pattern:** `sendToServer()` -- executes directly in single-player/on server, routes via network on multiplayer client.

**5 action types:**
1. `ACTION_FAVOR_ACCEPT` (1)
2. `ACTION_FAVOR_COMPLETE` (2)
3. `ACTION_FAVOR_ABANDON` (3)
4. `ACTION_GIFT` (4)
5. `ACTION_RELATIONSHIP` (5)

**Validation:** Action type whitelist (1-5), farm ownership via `userManager`, NaN/infinity checks on value field, NPC existence check, interaction distance check, data string truncation to 256 characters.

### NPCSettingsSyncEvent

**Direction:** Bidirectional (client requests change -> server validates -> server broadcasts to all)

**Two sync types:**
- `TYPE_SINGLE` -- single key/value pair (used when player changes one setting)
- `TYPE_BULK` -- full settings snapshot (used on player join)

**Security:** Master rights verification before applying changes. maxNPCs clamped to 1-50. Server saves after single changes; clients receive bulk sync without disk write.

---

## 5. GUI Layer

### Dialog Loading Pattern

```
DialogLoader.init(modDirectory)         -- set base path once
DialogLoader.register(name, class, xml) -- register at startup
DialogLoader.ensureLoaded(name)         -- lazy-load into g_gui on first use
DialogLoader.show(name)                 -- ensure loaded + g_gui:showDialog()
DialogLoader.getDialog(name)            -- return instance for data injection
DialogLoader.close(name)               -- g_gui:closeDialogByName()
DialogLoader.cleanup()                 -- called on mod unload
```

### NPCDialog

Opened when the player presses E near an NPC. The callback in `main.lua` finds the nearest interactable NPC, sets `npc.isTalking = true` (freezes AI movement), injects NPC data via `setNPCData()`, and shows the dialog.

**5 buttons with context-aware behavior:**

| Button | Action | Gate |
|--------|--------|------|
| Talk | Random conversation topic, +1 relationship (once/day) | Always enabled |
| Ask about work | Shows current AI activity description | Always enabled |
| Ask for favor | Generate new favor or show active progress | Neutral (25+) |
| Give gift | Spend $500 for relationship boost | Neutral (30+) |
| Relationship info | Shows tier, benefits, next unlock, trend, favor stats | Always enabled |

**UI pattern:** Each button is a 3-layer stack: Bitmap background for color fill, invisible Button for hit detection (captures onFocus/onLeave), and Text label. Hover effects shift background and text colors.

### NPCListDialog

Opened via `npcList` console command or programmatically. Shows a table of all active NPCs with up to 16 rows.

**Columns:** #, Name, Activity, Distance, Relationship, Farm

Each row has a "Go" button that teleports the player to that NPC's position.

### NPCFavorGUI

Not a visual dialog but the console command router. Registers 11 console commands that route to `g_NPCSystem` methods:

| Command | Action |
|---------|--------|
| `npcStatus` | System overview (NPC count, server/client, settings) |
| `npcSpawn` | Spawn NPC with optional name |
| `npcList` | Open NPC roster dialog (or console fallback) |
| `npcReset` | Reinitialize the NPC system |
| `npcHelp` | Print all available commands |
| `npcDebug` | Toggle debug mode |
| `npcReload` | Reload settings from XML |
| `npcTest` | Connectivity test |
| `npcGoto` | Teleport to NPC by number |
| `npcProbe` | Probe animation system APIs |
| `npcVehicleMode` | Switch vehicle mode (hybrid/realistic/visual) |

---

## 6. Settings System

Settings flow through four cooperating modules:

```
NPCSettings           -- Data object (holds all values, validates, save/load to XML)
     |
NPCSettingsIntegration   -- ESC menu hook (injects widgets into game settings page)
     |
NPCSettingsUI            -- Alternative injection path via UIHelper (general settings layout)
```

### Settings Categories

| Category | Examples |
|----------|---------|
| Core | enabled, maxNPCs, npcWorkStart/End, favorFrequency, spawnDistance |
| Display | showNames, showNotifications, showFavorList, showRelationshipBars, nameDisplayDistance |
| Gameplay | enableFavors, enableGifts, enableRelationshipSystem, allowMultipleFavors, relationshipDecay |
| Difficulty | favorDifficulty, relationshipGainMultiplier, favorRewardMultiplier |
| AI | npcActivityLevel, npcMovementSpeed, npcWorkDuration, npcBreakFrequency |
| Debug | debugMode, showPaths, showSpawnPoints, showAIDecisions, logToFile |
| Sound | soundEffects, voiceLines, uiSounds, notificationSound |
| Performance | updateFrequency, npcRenderDistance, npcUpdateDistance, batchUpdates |
| Multiplayer | syncNPCs, syncRelationships, syncFavors |

### Settings Persistence

Settings are saved to `{savegameDirectory}/npc_favor_settings.xml` under the root tag `<NPCSettings>`. `NPCSettings` resolves the path from `g_currentMission.missionInfo.savegameDirectory` and handles per-field XML read/write with type-appropriate accessors (`setBool`, `setInt`, `setFloat`, `setString`).

### Multiplayer Settings Sync

When a player with master rights changes a setting:
1. `NPCSettingsIntegration` callback fires
2. Setting is applied locally to `NPCSettings`
3. `NPCSettingsSyncEvent.newSingle(key, value)` is broadcast to all clients
4. Clients receive and apply the change

On player join:
1. Server sends `NPCSettingsSyncEvent.newBulk(settings)` via `sendInitialClientState`
2. Client receives full settings snapshot and replaces local values

---

## 7. Utilities

### VectorHelper

Pure math functions with no external dependencies. Used throughout the codebase for:
- Distance calculations (`distance2D`, `distance3D`) -- used in proximity checks, pathfinding
- Interpolation (`lerp`, `lerpVector`, `smoothstep`) -- used in NPC movement smoothing
- Bezier curves (`bezier`) -- used in curved walking paths
- Geometry tests (`isPointInCircle`, `isPointInRectangle`) -- used in area detection
- Vector ops (`normalize`, `rotateVector`, `perpendicular`, `reflect`) -- used in pathfinding avoidance

### TimeHelper

Game time abstraction layer. Used by NPCScheduler, NPCAI, and NPCInteractionUI for:
- Time conversion (`msToHMS`, `msToDHMS`) -- converting FS25 millisecond timestamps
- Time formatting (`formatTime`, `formatShortTime`) -- HUD display of favor timers
- Game time access (`getGameHour`, `getGameDay`, `getGameMonth`) -- schedule decisions
- Time-of-day classification (`getTimeOfDay`) -- greeting selection, activity modifiers
- Season detection (`getSeason`, `isGrowingSeason`, `isWinter`) -- schedule variants
- Time prediction (`predictFutureTime`, `getTimeUntil`) -- favor deadline calculation

### SettingsHelper

UI utility for menu integration. Provides factory functions to create settings buttons, section headers, and enable toggles for injection into FS25 menu layouts.

---

## 8. Data Flow

### NPC Creation Flow

```
NPCSystem:initializeNPCs()
  |
  +--> classifyBuildings()
  |      Iterates g_currentMission.placeables.placeables
  |      Categorizes each building (shop, gas_station, production, barn, ...)
  |      Records position, radius, owner farm
  |
  +--> findNPCSpawnLocations()
  |      Filters buildings by ownership (non-player farms)
  |      Assigns role based on building category (shopkeeper, mechanic, farmer)
  |      Returns array of {position, buildingName, role, category}
  |
  +--> generateNewNPCs() / createNPCAtLocation(location)
  |      Assigns unique ID, name (gender-specific pool), personality
  |      Generates appearance seed, age, movement speed
  |      Creates AI personality modifiers (workEthic, sociability, generosity, punctuality)
  |      Initializes needs system (energy, social, hunger, workSatisfaction)
  |      Assigns home position from building location
  |
  +--> findNearestField(x, z, npcId)
  |      Queries g_fieldManager for nearest unowned field
  |      Assigns field to NPC for work activities
  |
  +--> assignFarmlands()
  |      Allocates farmland ownership to NPCs
  |      Generates farm names based on personality
  |
  +--> entityManager:createNPCEntity(npc)
         Loads 3D model (or debug fallback)
         Creates map hotspot
         Loads tractor/vehicle props
```

### Per-Frame Update Flow (Server)

```
NPCSystem:update(dt)
  |
  +--> updatePlayerPosition()
  |      4 fallback methods: g_localPlayer, mission.player, controlledVehicle, camera
  |
  +--> relocateFarNPCs()  (every RELOCATE_INTERVAL seconds)
  |      Moves distant NPCs closer to player for visible population density
  |
  +--> updateNPCs(dt)
  |      For each active NPC:
  |        aiSystem:makeAIDecision(npc, hour, minute)  -- decide next state
  |        aiSystem:updateMovement(npc, dt)             -- move along path
  |        entityManager:updateNPCEntity(npc)           -- sync 3D position
  |        checkPlayerProximity(npc)                    -- set canInteract flag
  |
  +--> scheduler:update(dt)
  |      Sync game time from environment
  |      Update NPC schedules
  |      Check/fire scheduled events
  |      Update weather effects
  |
  +--> favorSystem:update(dt)
  |      Tick favor timers
  |      Check for expired favors
  |      Generate new favor opportunities (weighted random)
  |
  +--> relationshipManager:update(dt)
  |      Process mood decay/expiration
  |      Apply passive relationship decay
  |
  +--> interactionUI:update(dt)
  |      Update animation timers
  |      Update floating text lifetimes
  |
  +--> updateEventScheduler(hour, day, weatherFactor)  (once per game hour)
  |      Check for emergent events (Friday party, harvest gathering, etc.)
  |
  +--> NPCStateSyncEvent.broadcastState()  (every 5 seconds)
         Serialize all NPC states and broadcast to clients
```

### Player Interaction Flow

```
Player presses E near NPC
  |
  +--> npcInteractActionCallback() in main.lua
  |      Check: system exists, no dialog open, NPC in range
  |      Find nearest interactable NPC
  |      Set npc.isTalking = true (freezes AI)
  |
  +--> DialogLoader.show("NPCDialog")
  |      Lazy-load XML if first use
  |      NPCDialog:setNPCData(npc, npcSystem)
  |      g_gui:showDialog("NPCDialog")
  |
  +--> Player clicks button (e.g., "Give gift")
  |      NPCDialog handler validates conditions
  |      Calls NPCInteractionEvent.sendToServer(ACTION_GIFT, npcId, farmId, 500)
  |
  +--> Server receives event
  |      NPCInteractionEvent:execute() validates action
  |      Routes to NPCSystem:serverGiveGift(npc, farmId, giftValue)
  |      relationshipManager:changeRelationship(npc, +8, "GIFT_GIVEN")
  |      interactionUI:addFloatingText("+8")
  |
  +--> State change triggers syncDirty flag
         Next sync cycle broadcasts updated state to all clients
```

---

## 9. Save/Load (XML Persistence)

### NPC State Persistence

**Save hook:** `FSCareerMissionInfo.saveToXMLFile` -- appended function in `main.lua`

**Load hook:** `Mission00.onStartMission` -- appended function in `main.lua`

**Save file:** `{savegameDirectory}/npc_favor_data.xml` (constant `NPC_SAVE_FILE`)

**Root tag:** Defined by `NPC_SAVE_ROOT` constant

### Save Structure

```xml
<NPCFavorData version="1.2.0.0" npcCount="8">
  <npcs>
    <npc uniqueId="..." name="..." personality="..." age="35">
      <position x="123.4" y="56.7" z="890.1" />
      <rotation y="1.57" />
      <home x="..." y="..." z="..." buildingName="Shop_01" />
      <stats relationship="65" favorsCompleted="3" favorsFailed="0" favorCooldown="0" />
      <ai state="working" action="field_preparation" />
      <personality workEthic="1.2" sociability="0.8" generosity="1.0" punctuality="0.9" />
      <visual appearanceSeed="42" isFemale="false" movementSpeed="1.1" />
      <needs energy="75" social="45" hunger="20" workSatisfaction="60" mood="happy" />
      <encounters>
        <encounter type="talk" time="12345" details="..." partner="Farmer Joe" sentiment="positive" />
      </encounters>
    </npc>
  </npcs>
  <favors>
    <favor npcId="3" npcName="Mrs. Henderson" type="help_harvest"
           description="..." timeRemaining="24000" progress="50" reward="1000" />
  </favors>
  <npcRelationships>
    <rel key="npc1_npc3" value="65" lastInteraction="98765" interactionCount="12" />
  </npcRelationships>
</NPCFavorData>
```

### What Gets Saved

| Data | Location in XML |
|------|----------------|
| NPC identity (uniqueId, name, personality, age) | `npcs.npc#attributes` |
| World position and rotation | `npcs.npc.position`, `npcs.npc.rotation` |
| Home position and building name | `npcs.npc.home` |
| Relationship level and favor stats | `npcs.npc.stats` |
| Current AI state and action | `npcs.npc.ai` |
| Personality modifier floats | `npcs.npc.personality` |
| Visual appearance (seed, gender, speed) | `npcs.npc.visual` |
| Needs system (energy, social, hunger, mood) | `npcs.npc.needs` |
| Recent encounters (up to 10) | `npcs.npc.encounters` |
| Active favors from NPCFavorSystem | `favors.favor` |
| NPC-NPC relationships | `npcRelationships.rel` |

### Load Process

1. `loadFromXMLFile()` opens the XML file
2. Reads version tag (for future migration support)
3. Iterates saved NPCs, matching to spawned NPCs by `uniqueId` or `name`
4. Restores position, relationship, stats, AI state, personality modifiers, needs, mood, encounters
5. Active favors are restored via `NPCFavorSystem:restoreFavor()`
6. NPC-NPC relationships are restored to `relationshipManager.npcRelationships`

### Settings Persistence (Separate File)

Settings are saved to `{savegameDirectory}/npc_favor_settings.xml` by `NPCSettings`, independently of NPC state data. This allows settings to persist even if NPC data is reset.
