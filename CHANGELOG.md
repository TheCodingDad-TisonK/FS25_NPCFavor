# NPC Favor -- Changelog

All notable changes to the FS25_NPCFavor mod are documented below, organized by version. This changelog is derived from the actual git history and issue tracker.

---

## v1.2.2.4 -- Settings Persistence & ESC Menu Expansion

**Commit:** `3e8691e` (2026-02-09)
**Authors:** XelaNull, Claude & Samantha (Claude Code)
**Issues Fixed:** #15 (Settings reset when exiting savegame)

### Settings Persistence (fixes #15)
- **Save path fix**: `NPCSettings:saveToXMLFile(missionInfo)` now writes to `missionInfo.savegameDirectory` (tempsavegame during save), matching the UsedPlus pattern. Previously wrote directly to `savegame5/` which got overwritten when the game swapped tempsavegame → savegame5.
- **Load fix**: Replaced unreliable `g_fileIO:fileExists()` with `XMLFile.loadIfExists` (proven FS25 API). Previously silently fell back to defaults every load.
- **No orphan writes**: ESC menu, console commands, and sync events now update settings in-memory only. Disk persistence happens exclusively via the `FSCareerMissionInfo.saveToXMLFile` hook (UsedPlus pattern).
- **Diagnostic logging**: Settings load/save now prints messages to game log to help debug persistence issues.

### Expanded ESC Menu Settings (6 → 13 controls)
- 7 new controls: Show Favor List, Show Relationship Bars, Show Map Markers, Enable Gifts, Allow Multiple Favors, Max Active Favors (dropdown: 1/2/3/5/8/10), Relationship Decay
- All 13 controls grouped under single "NPC Favor System" section header for easy identification in multi-mod setups
- New `showMapMarkers` setting with instant toggle via `NPCEntity:toggleAllMapHotspots()`
- 170 new i18n strings (17 entries × 10 languages)

### Dialog & Icon ZIP Fixes
- Eagerly load all 3 dialogs (NPCDialog, NPCListDialog, NPCFavorManagementDialog) during `loadMission00Finished` while the mod's ZIP filesystem context is active. Previously lazy loading failed on second session with "Failed to open xml file".
- Removed custom icon.dds overlay from map hotspots (DirectStorage can't resolve ZIP paths outside mission-load context); uses reliable built-in `PlaceableHotspot.TYPE.EXCLAMATION_MARK` icon instead.
- Removed duplicate l10n entries (`button_cancel`, `button_refresh`, `button_close`) that shadowed base game definitions and spammed warnings on every load.

---

## v1.2.2.3 -- HUD Polish & Female NPC Clothing Fix

**Commit:** `d545e17` (2026-02-09)
**Authors:** XelaNull, Claude (Claude Code)

### HUD Overlay & Name Tags
- Suppress NPC HUD rendering during pause, full-screen map, ESC menu, and dialogs
- Dynamic name tag Y scaling based on distance (1.8m close → 2.6m at 15m)
- Lower speech bubble Y offset (2.8 → 2.3) and interaction hint (2.5 → 2.0)

### Female NPC Clothing & Camera Fix
- Fix female NPCs getting male clothing by force-loading `playerF` XML config
- Replace simple headgear offset with recursive node search for hat (-0.044m) and glasses (+0.012m) adjustments
- Fix behind-camera projection in `projectWorldToScreen` with dot-product check
- Clean up dialog boilerplate in NPCFavorManagementDialog, NPCListDialog, NPCFavorGUI
- Add NPCTeleport module source loading

---

## v1.2.2.2 -- Map Hotspots, Field Work, NPC Clothing & Build System

**Commits:** `44c1a7e` through `aee4b17` (2026-02-09)
**Authors:** XelaNull, Claude (Claude Code)
**Issues Fixed:** #12 (Map hotspot visibility)

### Map Hotspots & NPC Name Labels (fixes #12)
- Convert map hotspots from abstract `MapHotspot` (invisible) to `PlaceableHotspot` with icon overlay and fallback icon type
- Remove hotspot when NPC sleeps, recreate on wakeup — fixes icons persisting at night
- Add `drawMapLabels()` method rendering NPC names above map icons via `IngameMap.drawFields` hook

### NPCFieldWork Module (new)
- Realistic boustrophedon (serpentine) row traversal replacing simplistic rectangular patterns
- Multi-worker coordination (max 2 per field with size-based caps)
- Smooth Bezier headland turns
- Personality-driven pattern selection (grumpy → perimeter, lazy → spot check)
- Legacy `initFieldWork` preserved as fallback

### NPC Clothing Overhaul
- Curate PRESET_POOL: remove beekeeper, horsebackRider, longHaulTrucker, wetwork
- Use clone-and-modify pattern for male presets (game's `applyCustomWorkStyle` approach)
- Post-apply headgear sanitization (removes helmets, veils, motorcycle gear)
- Fix property names: `selectedIndex` → `selectedItemIndex`, `selectedColor` → `selectedColorIndex`
- Use `getItemNameIndex()` API for proper item lookup
- Expand outfit tables: 7 → 12 male, 6 → 12 female (all farm-appropriate)
- Add "working" to `isWalking` check to fix animation sliding during field work

### Favor Management Dialog
- Move `NPCFavorManagementDialog.lua` from `gui/` to `src/gui/` (consistent with other dialog files)
- Rework dialog layout and button handling

### Build System (new)
- Cross-platform build script (`build.sh`) for Git Bash on Windows, native on macOS/Linux
- Uses .NET `ZipFile` API on Windows to preserve directory structure
- `--deploy` flag copies to FS25 mods folder with auto-detection
- Excludes dev files (.git, .claude, CLAUDE.md, build.sh) from zip

---

## v1.2.2.1 -- Favor Dialog Fixes & Refactor

**Commits:** `9e56d76` through `c4e293d` (2026-02-09)
**Author:** TisonK
**Fixes:** Critical load failure from v1.2.2.0

### Favor Management Dialog Fixes
- **Critical fix**: Added missing `source()` call in `main.lua` for `NPCFavorManagementDialog.lua` -- the v1.2.2.0 dialog could not actually open because its Lua code was never loaded
- Relocated `NPCFavorManagementDialog.lua` from `gui/` to `src/gui/` (consistent with other dialog files)
- Rewrote dialog XML from custom `npc*` profiles to proper FS25 dialog patterns (`fs25_dialogBg`, `fs25_dialogContentContainer`, `buttonOK`, etc.)
- Added defensive nil-checks on all GUI element access (`if elem and elem.setText then`)
- Fixed relationship method name (`modifyRelationship` → `updateRelationship`)
- Added support for both scalar (`favor.reward = 500`) and table (`favor.reward = {amount=500}`) reward formats
- Reduced max visible favors from 10 to 5 (matching the 5-row dialog layout)

---

## v1.2.2.0 -- Favor Management Dialog & Keybinds

**Commits:** `3e80c56` through `22fd032` (2026-02-09)
**Author:** TisonK
**Issues Fixed:** #5 (NPC behind player after teleport), #6 (floating text after teleport), #9 (favor management UI), #10 (NPC list keybind)

### Favor Management Dialog (new -- fixes #9)
- New `NPCFavorManagementDialog` (XML + Lua) showing active favors with NPC name, description, time remaining, and reward
- 4 action buttons per favor: View details, Cancel (with -10 relationship penalty), Go To (teleport), Complete (with money reward)
- Relationship-colored NPC names and time urgency coloring
- Accessible via F6 key or `npcFavors` console command

### Keyboard Shortcuts (fixes #10)
- **F6** (`FAVOR_MENU`) -- Opens Favor Management dialog
- **F7** (`NPC_LIST`) -- Opens NPC roster dialog (previously console-only via `npcList`)
- Both keybinds registered with full RVB pattern, localized in all 10 languages

### Teleport Improvements
- **Face-NPC rotation** (fixes #5): After all teleports (npcGoto, NPC List, Favor dialog), player now rotates 180° to face the NPC instead of having NPC behind them
- **UI stabilization** (fixes #6): Added `lastTeleportTime` tracking with 0.5 game-minute cooldown to prevent HUD text jank after teleporting

### Documentation
- Added `VISION.md` -- 211-line design pillars document with 4-phase roadmap
- Added `TODO.md` -- 130-line development roadmap organized by priority tier
- Updated `README.md` to clarify multiplayer is untested

---

## v1.2.0.0 -- NPC AI Overhaul

**Branch:** `feature/living-neighborhood-system` (PR #3, merged `bd99ca3`)
**Authors:** UsedPlus Team (XelaNull + Claude AI)
**Scope:** 38 files changed, ~17,400 lines added

A comprehensive AI overhaul transforming mechanical schedule-following NPCs into personality-driven characters with internal motivations, social dynamics, weather awareness, and visual feedback systems.

### Relationship System Overhaul
- 7-tier relationship system: Hostile (0-9), Unfriendly (10-24), Neutral (25-39), Acquaintance (40-59), Friend (60-74), Close Friend (75-89), Best Friend (90-100)
- NPCs start with randomized relationship (5-35) -- a natural mix of strangers and vaguely familiar neighbors
- Tier names now consistent across all UI surfaces (overhead display, dialog, NPC list)
- Favor requests gated behind Neutral (25+), gift giving behind Neutral (30+) -- no bribing strangers
- Passive relationship decay (-0.5/day after 2 days without interaction, floors at 25)
- Grudge system: persistent negative feelings from bad interactions, reduces positive gains
- NPC-initiated gifts: best friends (75+) have small daily chance to surprise the player

### Needs and Mood System
- 4-need system (energy, social, hunger, workSatisfaction) on 0-100 scale
- Personality-specific need rates (hardworking gets guilty when idle, social gets lonely faster)
- Mood derived from needs: happy/neutral/stressed/tired
- Mood affects walk speed (+/-20%), greeting tone, social willingness
- Mood indicator in dialog: `[+]` happy, `[!]` stressed, `[~]` tired

### NPC-NPC Social System
- NPC-NPC relationship graph with personality compatibility matrix
- Compatible pairs (hardworking+generous, social+social) drift toward friendship
- Incompatible pairs (social+grumpy, hardworking+lazy) drift toward rivalry
- Social partner selection prioritizes NPCs with higher relationship values
- Conversation topic generation based on time, weather, personality, and relationship

### Weather and Season Awareness
- Rain/storm interrupts field work (50% chance to go home in rain, always in storms)
- Seasonal schedule shifts (winter: +1hr wake, shorter work day; summer: opposite)
- Weather-aware conversation topics ("Terrible weather today...")
- Uses existing `getWeatherFactor()` API (no new dependencies)

### Daily Schedule Improvements
- Personality-specific wake/work/sleep times (hardworking wakes at 5:00, lazy at 7:00)
- Weekend variation: Sunday = no work, extended social; Saturday = half-day
- Farmers wake before sunrise for realistic agricultural schedules

### AI Behavior
- Markov chain transition probabilities integrated into fallback decision weighting (12 state-to-state entries)
- 4 field work patterns: row traversal, spiral inward, perimeter walk, spot check
- Observable personality differentiation: wider speed ranges, idle micro-behaviors
- Bezier curves for smooth path corners
- Memory system (10 records per NPC with sentiment tracking, stored but not yet driving behavior)

### Visual Feedback
- Floating relationship change text (+1, -2 popups above NPCs)
- Speech bubbles during NPC-NPC socializing
- Name tags and relationship tier above NPC heads
- Height variation per NPC (0.95-1.05 Y scale)
- Animated character models (male + female via FS25 HumanGraphicsComponent) -- walk/idle animations work in most cases; some NPCs slide without animating (known issue, root cause not yet identified)

### Dialog Improvements
- NPC backstory/bio section (visible at relationship 40+)
- "Ask about plans" button shows NPC's next 3 scheduled activities
- Relationship decay warning when NPC hasn't been talked to recently
- Personality-flavored gift thank-you messages
- Context-aware greetings that scale from hostile ("Do I know you?") to warm ("Great to see you!")

### Bug Fixes
- **Talk button spam exploit** -- case mismatch (`"DAILY_INTERACTION"` vs `"daily_interaction"`) let players gain infinite relationship points. Fixed + added "already chatted today" feedback.
- **Floating NPCs** -- tractor/vehicle props set Y offset for cab seating, but models never loaded (invisible placeholders). Removed all Y offset assignments.
- **NPCs waking too late** -- most personalities had wake=6 or later. Adjusted to 5:00-7:00 range.
- **Gift button cycling** -- multi-tier gift UI code existed but `self["btnGiftText"]` doesn't resolve in FS25's GUI system. Reverted to working simple $500 gift.

### Infrastructure
- Building classification system (residential, commercial, industrial, agricultural, services)
- Farm ownership assignment from farmlandId on placeables
- Gender system with male/female name pools
- NPCListDialog showing farm name + field count per NPC
- Version single source of truth (`g_NPCFavorMod.version` in main.lua)
- Comprehensive `docs/` folder with architecture, AI, relationship, and settings documentation
- 25 TODO items marked as completed across 10 file headers

### Known Limitations
- **NPC animation sliding** -- Some NPCs slide along the ground without their walk animation playing; root cause not yet identified *(fixed in v1.2.2.2)*
- **Silent groups and walking pairs** -- Group gatherings and walking pairs position NPCs correctly but generate no conversation content; only 1-on-1 socializing produces speech bubbles
- **Map hotspots** -- MapHotspot creation code exists but markers do not appear on the in-game map *(fixed in v1.2.2.2)*
- **NPC vehicles/tractors** -- Code exists but i3d models cannot be loaded from game pak archives at runtime; NPCs walk everywhere
- **Flavor text localization** -- Mood prefixes, backstories, birthday messages, and personality dialog added in v1.2.0 are English-only (core UI is fully localized)

---

## v1.1.0.0 -- i18n, Code Stewardship, and Documentation

**Commit:** `fcafd9f` (2026-02-08)
**Authors:** UsedPlus Team (XelaNull + Claude AI)

### Internationalization
- 77 new translation keys added to `modDesc.xml` in 10 languages (English, German, French, Polish, Spanish, Italian, Czech, Brazilian Portuguese, Ukrainian, Russian)
- 42 hardcoded English strings converted to `g_i18n:getText()` with fallback patterns across `NPCDialog.lua`, `NPCInteractionUI.lua`, and `main.lua`
- Translation categories: dialog buttons (9), relationship levels (7), relationship benefits (7), relationship unlocks (11), favor/gift responses (7), greetings (7), conversation topics (14), work status messages (9), HUD elements (3)

### Code Stewardship
- 59 original diagnostic print statements restored across 8 files that were removed during an earlier cleanup pass
- All 22 files (21 Lua + 1 XML) now have structured TODO/FUTURE VISION comment blocks documenting what's implemented `[x]` and planned `[ ]`

### Version
- Version bump: 1.0.0.0 to 1.1.0.0

---

## v1.0.1.0 -- Living Neighborhood System (Complete Rewrite)

This version encompasses three commits that took the mod from non-functional stubs to a fully working system.

### Commit 3: `719e304` -- Farm Property and Map Hotspots (2026-02-08)
- Added `ownerFarmId` from placeable buildings to NPC spawn data
- Farm property number displayed in `npcList` console command
- Replaced broken `MapIcon` API with FS25's `MapHotspot` API
- Uses `setLinkedNode()` for automatic position tracking when scene node available

### Commit 2: `2f79a7a` -- Rendering Fix (2026-02-08, Fixes #4)
- **Critical fix:** `renderOverlay`/`renderText` calls moved from `update()` to `draw()` callback
- FS25 only allows rendering functions inside draw callbacks, not update callbacks
- Split `NPCInteractionUI` into `update()` (timers/logic) and `draw()` (rendering)
- Added `NPCSystem:draw()` and hooked `FSBaseMission.draw` in `main.lua`

### Commit 1: `c6ebb22` -- Complete Living Neighborhood System (2026-02-08)

**NPC Interaction Dialog (new)**
- `gui/NPCDialog.xml` -- Full dialog layout with 3-layer button pattern (Bitmap bg + invisible Button + Text label)
- `src/gui/NPCDialog.lua` (~570 lines) -- MessageDialog subclass with 5 action buttons: Talk (+1 rel), Ask about work, Ask for favor (rel 20+), Give gift $500 (rel 30+), Relationship info
- Hover effects with color-shift on focus/leave per button
- 7-tier relationship display with benefits and next-level unlocks

**E-Key Input System**
- Added `<actions>` and `<inputBinding>` in modDesc.xml for `NPC_INTERACT` on KEY_e
- PlayerInputComponent hook with dynamic prompt: "Talk to [NPC Name]"
- Suppressed when another dialog is open

**Multiplayer Event Infrastructure (3 new files)**
- `NPCStateSyncEvent.lua` -- Server broadcasts full NPC state to all clients every 5 seconds
- `NPCInteractionEvent.lua` -- Client-to-server interaction routing with 3-layer auth
- `NPCSettingsSyncEvent.lua` -- Bidirectional settings sync with master rights verification
- OWASP protections: count caps, stream draining, input validation, string truncation

**Settings UI (ESC Menu)**
- Rewrote `NPCSettingsIntegration.lua` to inject 6 settings into ESC > Settings > Game Settings
- Enable NPC System, Show Names, Show Notifications, Enable Favors, Debug Mode (toggles)
- Max NPC Count (dropdown: 4/8/12/16/20/30/50)

**Save/Load Persistence**
- Hooks `FSCareerMissionInfo.saveToXMLFile` + `Mission00.onStartMission`
- NPC positions, relationships, AI states, and favor progress saved to `savegameX/npc_favor.xml`

**3D NPC Models**
- Basic NPC figure model (`models/npc_figure.i3d` + textures)
- Loaded via `g_i3DManager:loadSharedI3DFile()` with ZIP compatibility
- *Note: These custom models were replaced in v1.2.0 by FS25's built-in HumanGraphicsComponent; the original model files have been removed.*

**Game Loop Wiring**
- `NPCSystem:update(dt)` rewritten with server/client split
- Server: updateNPCs + scheduler + favorSystem + relationshipManager + interactionUI + periodic sync
- Client: interactionUI + proximity checks only

---

## v1.0.0.1 -- Critical Runtime Fixes

**Commit:** `7c5d65e` (2026-02-07)
**Authors:** UsedPlus Team (XelaNull + Claude AI)
**Issues Fixed:** #1 (Not Showing Ingame), #2 (No visual markers at the map)

6 critical fixes that made the mod load and function in FS25:

1. **dt double-conversion** -- `NPCFavorSystem` probability calculation used vanishingly small numbers because dt was already in seconds
2. **FS25 time API** -- `TimeHelper` + `NPCScheduler` now derive hour/minute from `dayTime` (ms) instead of broken `os.time()`
3. **Sell points** -- `getUnloadingStations()` replaces missing `sellingStations` API
4. **Case mismatch** -- `"DAILY_INTERACTION"` fixed to `"daily_interaction"` in relationship manager (first fix; re-broken and re-fixed in v1.2.0)
5. **Path cache** -- `#hashTable` is always 0 in Lua 5.1; now counts keys properly with iteration
6. **Dialog interaction** -- E key cycles options, Q closes dialog, full overlay rendering

### `modDesc.xml`
- Fixed `descVersion="92"` to `descVersion="105"` (FS25 requirement)

### `NPCSystem.lua`
- Replaced 7 stub objects with real constructor calls (`NPCEntity.new()`, `NPCAI.new()`, etc.)
- Fixed `dt` units: FS25 passes milliseconds, code assumed seconds

### `NPCEntity.lua`
- Replaced all `os.clock()` / `os.time()` with `g_currentMission.time`

### `NPCAI.lua`
- Added nil guards for `terrainRootNode` before terrain/water API calls
- Fixed stuck detection: only triggers for movement states

---

## v1.0.0.0 -- Initial Release

**Commit:** `5041bb9` (2026-02-07)
**Author:** TisonK (TheCodingDad)
**Concept:** Lion2009

The original upload establishing the mod's architecture and vision:

- 15 Lua source files across 5 directories (`src/`, `src/scripts/`, `src/settings/`, `src/utils/`)
- `NPCSystem.lua` -- Central coordinator with NPC spawning, update loop structure
- `NPCAI.lua` -- AI state machine framework (idle, walking, working, driving, resting, socializing, traveling)
- `NPCScheduler.lua` -- Daily schedule framework with time-of-day activity slots
- `NPCEntity.lua` -- 3D entity management with model loading and map markers
- `NPCFavorSystem.lua` -- Favor/quest system with 7 favor types (harvest help, transport, fence repair, seed delivery, equipment lend, animal care, field work)
- `NPCRelationshipManager.lua` -- Relationship tracking with 5-tier system and mood modifiers
- `NPCInteractionUI.lua` -- HUD rendering for interaction prompts and favor display
- `NPCSettings.lua` + `NPCSettingsUI.lua` + `NPCConfig.lua` + `NPCFavorSettingsManager.lua` + `NPCFavorGUI.lua` + `NPCSettingsIntegration.lua` -- Settings infrastructure
- `TimeHelper.lua` + `VectorHelper.lua` -- Math and time utilities
- 6 NPC names localized in 10 languages
- Basic `modDesc.xml` with multiplayer support declared
- Icon and small icon assets

**Note:** The subsystem classes existed but were not wired into the game loop. `NPCSystem.new()` created inline stub objects instead of instantiating the real classes. No input binding, no dialog, no multiplayer events, no save/load. The architecture and vision were sound; the implementation needed completion.

---

## Pre-Release

**Commits:** `02dac83` through `263dba9` (2026-02-06 to 2026-02-07)
**Author:** TisonK

- Initial repository creation with README
- `main.lua` created as mod entry point
- README iterations describing the mod concept and planned features

---

## GitHub Issues

| # | Title | Reporter | Status | Resolution |
|---|-------|----------|--------|------------|
| 1 | Not Showing Ingame | Tankieboy | Closed | Fixed in v1.0.0.1 (stub objects replaced with real constructors, descVersion corrected) |
| 2 | No visual markers at the map | Dueesberch | Closed | Fixed in v1.2.2.2 (PlaceableHotspot with icon overlay, sleep/wake hotspot management) |
| 4 | erreur lua (renderOverlay in update callback) | squall39 | Closed | Fixed in v1.0.1.0 commit `2f79a7a` (moved rendering to draw callback) |
| 5 | NPC on player backside after teleport | Dueesberch | Closed | Fixed in v1.2.2.0 (player rotates 180° to face NPC after teleport) |
| 6 | Floating text after teleport | TisonK | Closed | Fixed in v1.2.2.0 (lastTeleportTime cooldown prevents HUD jank) |
| 7 | Animations and Progress | | Closed | Fixed in v1.2.2.2 (added "working" to isWalking check for field work animation) |
| 8 | Won't load due to ZIP packaging | Wreyth | Closed | Fixed in v1.2.2.2 (build.sh creates properly structured ZIP) |
| 9 | Interaction with active favor | TisonK | Closed | Fixed in v1.2.2.0 (Favor Management Dialog with view/cancel/goto/complete) |
| 10 | Keybinding the npcList UI | TisonK | Closed | Fixed in v1.2.2.0 (F7 keybind opens NPC roster) |
| 11 | Couple of issues and a suggestion | | Open | |
| 12 | NPC Map Hotspot Icons Not Appearing | | Closed | Fixed in v1.2.2.2 (PlaceableHotspot with icon overlay) |
| 14 | Borrow tractor favor has no interaction | | Open | |
| 15 | Settings reset when exiting savegame | | Open | Fixed in v1.2.2.4 (UsedPlus save pattern, XMLFile.loadIfExists) |

## Pull Requests

| # | Title | Author | Status |
|---|-------|--------|--------|
| 3 | Feature: Living Neighborhood System v1.1.0 (Fixes #1, #2) | XelaNull | Merged |
| 17 | v1.2.2.4: Settings Persistence & ESC Menu Expansion (Fixes #15) | XelaNull | Open |

