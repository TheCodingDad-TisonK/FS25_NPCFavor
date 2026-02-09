# NPC Favor -- Changelog

All notable changes to the FS25_NPCFavor mod are documented below, organized by version. This changelog is derived from the actual git history and issue tracker.

---

## v1.2.0.0 -- NPC AI Overhaul (in progress)

**Branch:** `feature/living-neighborhood-system` (not yet merged)
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
- **NPC animation sliding** -- Some NPCs slide along the ground without their walk animation playing; root cause not yet identified
- **Silent groups and walking pairs** -- Group gatherings and walking pairs position NPCs correctly but generate no conversation content; only 1-on-1 socializing produces speech bubbles
- **Map hotspots** -- MapHotspot creation code exists but markers do not appear on the in-game map
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
| 1 | Not Showing Ingame | Tankieboy | Open | Fixed in v1.0.0.1 (stub objects replaced with real constructors, descVersion corrected) |
| 2 | No visual markers at the map | Dueesberch | Open | Partially addressed: MapIcon replaced with MapHotspot API, but markers still don't appear in-game. Listed as known limitation. |
| 4 | erreur lua (renderOverlay in update callback) | squall39 | Open | Fixed in v1.0.1.0 commit `2f79a7a` (moved rendering to draw callback) |

## Pull Requests

| # | Title | Author | Status |
|---|-------|--------|--------|
| 3 | Feature: Living Neighborhood System - Complete Implementation v1.1.0 (Fixes #1, #2) | XelaNull (UsedPlus Team) | Open |

