**From a follower:**
> "Hello friend,
> I just wanted to write to you that I came across your mod realistic worker cost and that I like it because I am a fan of fs and realism myself. I was thinking and wanted to share this idea with you, since I am not good at programming I thought I could share this idea > with you. The idea is to add a living neighborhood to fs, i.e. NPCs who live around come to life and work on their fields with their own machinery. That would be the first part, and the second would be that you could ask them for a favor or they would ask you for a  > favor, so that they would be physically present on the map. If you like the idea in any way, I would be happy if you would respond.
> Your new follower,"

So i listened, and changed his idea into reality (we are not there.. yet)
Its here, but we have to improve ALOT :)

Thanks for reading; Now about the mod itself...

# FS25 NPC Favor - Living Neighborhood Mod

[![FS25 Version](https://img.shields.io/badge/FS25-Compatible-green)](https://www.farming-simulator.com/)
[![Version](https://img.shields.io/badge/Version-1.0.0.0-blue)](https://github.com/YourName/FS25_NPCFavor/releases)
[![License](https://img.shields.io/badge/License-All%20Rights%20Reserved-red)](LICENSE)

**Breathe life into your farmland!** This mod adds a living, breathing community of NPC (Non-Player Character) neighbors to Farming Simulator 25. They work their own fields, follow daily schedules, and will eventually ask you for favors, creating a dynamic layer of social simulation and small tasks alongside your main farming operations.

---

## ✨ Features

*   **Living NPCs:** AI-controlled neighbor farmers populate your map, with unique names, personalities, and homes.
*   **Daily Schedules:** They follow a realistic day/night cycle—working fields by day, heading home at night.
*   **Relationship System:** Build friendship (0-100) with each NPC through interaction and completing favors.
*   **Favor System:** Neighbors will ask for help with tasks like borrowing equipment, transporting goods, or helping with harvests.
*   **Simple Interaction:** Walk up to any NPC and press `E` to talk, check relationships, or manage active favors.
*   **Customizable:** Control the number of NPCs, their work hours, how often they ask for favors, and more via settings.
*   **Lightweight:** Designed to run efficiently in the background without impacting game performance.

---

## 🛠️ Installation

1.  Download the latest `FS25_NPCFavor.zip` from the [Releases](https://github.com/YourName/FS25_NPCFavor/releases) page.
2.  Extract the `.zip` file.
3.  Place the `FS25_NPCFavor` folder into your `Farming Simulator 25/mods/` directory.
4.  Activate the mod in the ModHub when starting or loading a game.

---

## 🎮 How to Use / In-Game Guide

Once the mod is active in your savegame:

1.  **Find NPCs:** Look for named markers or characters (currently debug spheres) near houses and fields.
2.  **Interact:** Walk close to an NPC. A hint will appear. Press **`E`** to open the dialog menu.
3.  **Build Relationships:** Talk to them regularly. Higher friendship unlocks more interaction options.
4.  **Complete Favors:** When you get a notification that an NPC needs help, talk to them. Accept the favor, complete the objective before the timer runs out, and claim your reward (cash + relationship boost).
5.  **Manage:** Type `npcHelp` into the in-game console (~ or ` key) for a list of useful debug commands like `npcStatus` or `npcSpawn`.

---

## ⚙️ Configuration

The mod creates a settings file in your savegame folder: `savegameX/npc_favor_settings.xml`. You can edit this file directly to change:
- `maxNPCs`: Maximum number of active NPCs.
- `npcWorkStart` / `npcWorkEnd`: Their working hours (0-23).
- `showNames`: Toggle names above NPC heads.
- `debugMode`: Enable visual debug info and paths.

---

## 📝 License & Credits

*   **Original Idea:** Lion2008
*   **Implementation & Coding:** TisonK
*   **License:** All rights reserved. Unauthorized redistribution, copying, or claiming this code as your own is strictly prohibited. This is a free mod for the community.

---

*Enjoy your new neighborhood, and happy farming!*

---

## 🏗️ Architecture & How It Works

Under the hood, the mod is built from **8 cooperating subsystems**, all coordinated by a central `NPCSystem`:

| Subsystem | What It Does |
|-----------|-------------|
| **NPCSystem** | The coordinator — spawns NPCs, runs the update loop, manages multiplayer sync |
| **NPCAI** | State machine driving behavior: idle, walking, working, driving, resting, socializing |
| **NPCScheduler** | Daily routines with seasonal variants (spring planting, autumn harvesting, etc.) |
| **NPCEntity** | Visual representation — 3D models, color tinting, minimap icons, LOD batching |
| **NPCRelationshipManager** | Friendship tracking (0-100), mood system, daily limits, benefit unlocks |
| **NPCFavorSystem** | Favor generation, tracking, completion with 7 favor types and timed objectives |
| **NPCInteractionUI** | World-space HUD — floating hints, active favors list with progress bars |
| **NPCDialog** | The conversation dialog you see when pressing E — 5 action buttons with hover effects |

**NPC Spawning:** NPCs spawn near non-player-owned buildings on the map (shops, production points, etc.). They never spawn on your own farm.

**AI Decision Making:** Each NPC has a personality (hardworking, lazy, social, generous, grumpy) that affects how often they work, rest, or socialize. A weighted random system picks their next action based on time of day, personality, and relationship with the player.

**Vehicle Usage:** When an NPC needs to travel more than 100 meters (e.g., from their home building to a distant field), they'll drive instead of walk — moving at ~18 km/h.

---

## 💬 Dialog System

When you press **E** near an NPC, a dialog opens with 5 action buttons:

| Button | What It Does | Requirements |
|--------|-------------|-------------|
| **Talk** | Random conversation topic, +1 relationship | Always available |
| **Ask about work** | Shows what the NPC is currently doing | Always available |
| **Ask for favor** | Check active favor progress or request a new one | Relationship 20+ |
| **Give gift** | Spend $500 for a relationship boost | Relationship 30+ |
| **Relationship info** | See your level, benefits, next unlock, favor stats | Always available |

---

## 💕 Relationship System

Friendship with each NPC ranges from 0 to 100, organized into 7 levels:

| Level | Range | Benefits Unlocked |
|-------|-------|-------------------|
| Hostile | 0-9 | None — they barely tolerate you |
| Unfriendly | 10-24 | Basic interaction |
| Neutral | 25-39 | Can ask for favors, 5% discount |
| Acquaintance | 40-59 | Borrow equipment, 10% discount |
| Friend | 60-74 | NPC may offer help, 15% discount |
| Close Friend | 75-89 | Receives gifts, shared resources, 18% discount |
| Best Friend | 90-100 | Full benefits, 20% discount |

**How to improve:** Talk regularly (+1 each time), complete favors (+15), give gifts (+varies). Relationships also have a mood system and can trend up or down over time.

---

## 🎁 Favor Types

NPCs can ask for help with 7 different kinds of tasks:

*   **Borrow my tractor** — Let an NPC use your equipment
*   **Help with harvest** — Assist during busy harvest season
*   **Transport goods to market** — Deliver items to a selling point
*   **Fix broken fence** — Repair work around their property
*   **Deliver seeds to my farm** — Bring supplies they need
*   **Loan money** — Financial assistance
*   **Watch property** — Keep an eye on things while they're away

Each favor has a time limit, progress tracking, and rewards (cash + relationship boost). Fail to complete one, and your relationship takes a small hit.

---

## 🌦️ Seasonal Schedules

Farmer NPCs follow different routines depending on the season:

*   **Spring:** Field preparation and planting (7 AM - 5 PM)
*   **Summer:** Early starts for irrigation, break during afternoon heat (5 AM - 8 PM)
*   **Autumn:** Long harvest days with extended hours (7 AM - 6 PM)
*   **Winter:** Late starts, indoor work and equipment repair (9 AM - 4 PM)

Worker and casual personality types have their own schedule templates that stay consistent year-round.

---

## 🌐 Multiplayer Support

The mod is fully multiplayer-compatible:

*   **Server** runs the NPC simulation (AI decisions, movement, favors)
*   **Clients** receive synced NPC positions and states every 5 seconds
*   **Security:** Farm ownership verification, input validation, action whitelisting
*   When a new player joins, they immediately receive the full NPC state

---

## 🖥️ Console Commands

Open the in-game console (`~` key) and type any of these:

| Command | Description |
|---------|-------------|
| `npcHelp` | Show all available commands |
| `npcStatus` | Full system status — NPCs, subsystems, player position, game time |
| `npcList` | Table of all NPCs with personality, action, distance, relationship |
| `npcSpawn [name]` | Spawn a new NPC near you (optional custom name) |
| `npcReset` | Reset and reinitialize the entire NPC system |
| `npcDebug on/off` | Toggle debug mode (shows paths, AI states, extra logging) |
| `npcReload` | Reload settings from XML without restarting |
| `npcTest` | Quick test to verify console commands are working |

---

## 📂 File Structure

```
FS25_NPCFavor/
├── main.lua                    # Entry point — hooks into FS25, E key binding
├── modDesc.xml                 # Mod config, translations (10 languages)
├── icon.dds                    # Mod icon
├── gui/
│   └── NPCDialog.xml          # Dialog layout (5 buttons + response area)
├── models/
│   └── npc_figure.i3d          # 3D NPC model with textures
├── src/
│   ├── NPCSystem.lua           # Central coordinator (spawning, update loop)
│   ├── gui/
│   │   └── NPCDialog.lua       # Dialog logic (hover effects, click handlers)
│   ├── scripts/
│   │   ├── NPCAI.lua            # AI state machine + pathfinding
│   │   ├── NPCEntity.lua        # 3D models, map icons, visibility
│   │   ├── NPCScheduler.lua     # Daily routines, seasonal schedules
│   │   ├── NPCRelationshipManager.lua  # Friendship levels, benefits
│   │   ├── NPCFavorSystem.lua   # Favor generation and tracking
│   │   └── NPCInteractionUI.lua # World-space HUD rendering
│   ├── events/
│   │   ├── NPCStateSyncEvent.lua      # Server → client NPC sync
│   │   └── NPCInteractionEvent.lua    # Client → server actions
│   ├── settings/
│   │   ├── NPCSettings.lua            # Settings persistence (XML)
│   │   └── NPCFavorGUI.lua            # Console command routing
│   └── utils/
│       ├── VectorHelper.lua           # Math utilities (distance, lerp, etc.)
│       └── TimeHelper.lua             # Game time conversion
└── README.md
```

---

## 🚧 Current Status

This mod is a **work in progress** — the core systems are functional, but there's still a lot to build. Here's where things stand:

**Working:**
- NPC spawning at map buildings (not on your farm)
- AI state machine with 7 states and personality-driven decisions
- Daily schedules with 4 seasonal variants
- Relationship system (7 tiers with benefit unlocks)
- Favor system (7 types with timers and rewards)
- Dialog with 5 interactive buttons and hover effects
- World-space HUD (interaction hints, favor progress list)
- Multiplayer sync with security validation
- 8 console commands
- 3D model loading with per-NPC color variation
- Vehicle usage for long-distance NPC travel
- Pathfinding with terrain awareness and water avoidance
- Save/load persistence (NPC positions, relationships, and favor progress survive map reload)
- In-game settings menu (6 configurable options via ESC > Settings)

**Not yet working:**
- NPC animations (walk, work, talk — tracked but not rendered)
- Auto-save (data saves on manual save only, not periodically)

See the TODO comments at the top of each source file for the full future vision.

---

## 🔨 Building from Source

If you want to build the mod yourself:

1. Clone the repository
2. The mod loads directly from the folder structure — no build step needed
3. Copy or symlink the `FS25_NPCFavor` folder to your mods directory
4. For ZIP distribution: zip the folder contents (not the folder itself) with forward-slash paths

---

*Built with care for the Farming Simulator community.*
