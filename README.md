<div align="center">

# 🌾 FS25 NPC Favor
### *Living Neighborhood Mod*

[![Downloads](https://img.shields.io/github/downloads/TheCodingDad-TisonK/FS25_NPCFavor/total?style=for-the-badge&logo=github&color=4caf50&logoColor=white)](https://github.com/TheCodingDad-TisonK/FS25_NPCFavor/releases)
[![Release](https://img.shields.io/github/v/release/TheCodingDad-TisonK/FS25_NPCFavor?style=for-the-badge&logo=tag&color=76c442&logoColor=white)](https://github.com/TheCodingDad-TisonK/FS25_NPCFavor/releases/latest)
[![License](https://img.shields.io/badge/license-All%20Rights%20Reserved-red?style=for-the-badge&logo=shield&logoColor=white)](#license--credits)
[![Status](https://img.shields.io/badge/status-Active%20Development-orange?style=for-the-badge&logo=hammer&logoColor=white)](#)


**From a follower:**
> "Hello friend,
> I just wanted to write to you that I came across your mod realistic worker cost and that I like it because I am a fan of fs and realism myself. I was thinking and wanted to share this idea with you, since I am not good at programming I thought I could share this idea > with you. The idea is to add a living neighborhood to fs, i.e. NPCs who live around come to life and work on their fields with their own machinery. That would be the first part, and the second would be that you could ask them for a favor or they would ask you for a  > favor, so that they would be physically present on the map. If you like the idea in any way, I would be happy if you would respond.
> Your new follower,"

<br>

**Breathe life into your farmland.** NPC neighbors walk the roads, follow daily routines, build relationships with each other and with you, and ask for help. Each NPC has a personality, a home, and opinions about you that change over time.

`Singleplayer` • `Multiplayer (beta)` • `Persistent saves` • `10 languages`

</div>

---

## ✨ Features at a Glance

> [!NOTE]
> This mod is in **active development** — not yet the final version. Expect rapid improvements!

<br>

| | Feature | Description |
|---|---|---|
| 🧍 | **Animated NPC Neighbors** | NPCs spawn at buildings around the map with walk & idle animations |
| 🧠 | **Needs-Based AI** | Driven by energy, social, hunger & work satisfaction — not rigid schedules |
| 🎭 | **Personality System** | 5 types: *hardworking, lazy, social, grumpy, generous* — affects everything |
| 🛣️ | **Road Pathfinding** | Follows FS25's road spline network; paths are cached for performance |
| 💚 | **Relationship System** | 0–100 scale across 7 tiers from **Hostile** → **Best Friend** |
| 🕸️ | **NPC–NPC Social Graph** | NPCs form their own friendships and rivalries based on compatibility |
| 🤝 | **Favor System** | NPCs ask for help with tasks; complete them for cash & relationship boosts |
| 💬 | **Dynamic Dialog** | Context-aware conversations by time of day, relationship, personality & activity |
| 🎁 | **Gift Giving** | Spend $500 to boost a relationship (unlocked at relationship 30+) |
| 🌧️ | **Weather Awareness** | Rain interrupts field work; NPCs comment on weather; seasonal schedule shifts |
| 💭 | **Speech Bubbles** | World-space speech bubbles appear when NPCs socialize with each other |
| 💾 | **Persistent Save/Load** | Positions, relationships, favors & needs all save with your savegame |
| 🌍 | **10-Language Localization** | 1,500+ strings in EN, DE, FR, PL, ES, IT, CZ, PT-BR, UK, RU |
| ⚙️ | **In-Game Settings** | Toggle NPC system, max count, work hours, favor frequency & more |
| 🖥️ | **Console Commands** | Type `npcHelp` in the developer console for a full command list |

---

## 🛠️ Installation

> [!TIP]
> Already have the mod installed? Skip straight to [Quick Start](#-quick-start).

**1. Download** the `FS25_NPCFavor.zip` from the [latest release](https://github.com/TheCodingDad-TisonK/FS25_NPCFavor/releases/latest).

**2. Place it** in your FS25 mods folder:

| Platform | Path |
|---|---|
| 🪟 Windows | `Documents\My Games\FarmingSimulator2025\mods\` |
| 🍎 macOS | `~/Library/Application Support/FarmingSimulator2025/mods/` |

**3. Enable it** in the mod selection screen when starting or loading a savegame.

---

## 🎮 Quick Start

```
1. NPCs spawn automatically after the map loads — watch for the console confirmation.
2. Walk near any NPC → look for the [E] prompt → "Talk to [Name]"
3. Press E to open the dialog.
4. Choose: Talk / Ask About Work / Ask for Favor / Give Gift / Relationship Info
5. Chat regularly, complete favors, give gifts — build your community!
6. All progress saves automatically with your savegame.
```

---

## 💬 Dialog System

Press **E** near any NPC to open the interaction dialog:

| Button | What It Does | Requirement |
|---|---|---|
| 💬 **Talk** | Random conversation topic, +1 relationship (once per day) | Always available |
| 🔨 **Ask about work** | Shows what the NPC is currently doing | Always available |
| 🤝 **Ask for favor** | Check active favor or request a new one | Relationship **25+** |
| 🎁 **Give gift** | Spend $500 for a relationship boost | Relationship **30+** |
| 📊 **Relationship info** | See your level, benefits, next unlock & favor stats | Always available |

---

## 💚 Relationship System

Friendship with each NPC runs from **0 to 100** across 7 tiers:

| Tier | Range | Benefits |
|---|---|---|
| ❌ Hostile | 0–9 | None |
| 😒 Unfriendly | 10–24 | Basic interaction |
| 😐 Neutral | 25–39 | Ask for favors · 5% discount |
| 🙂 Acquaintance | 40–59 | Borrow equipment · 10% discount |
| 😊 Friend | 60–74 | NPC may offer help · 15% discount |
| 🥰 Close Friend | 75–89 | Shared resources · 18% discount |
| ⭐ Best Friend | 90–100 | Full benefits · 20% discount |

**How to grow a relationship:**

```
💬 Talk daily        → +1 per day
✅ Complete favors   → +15 per completion
🎁 Give gifts        → +varies
⚠️  Ignore them      → -0.5/day after 2 days without contact (above relationship 25)
```

---

## 🎁 Favor Types

NPCs can ask for 7 kinds of help:

| # | Favor | Description |
|---|---|---|
| 1 | 🌾 **Help with harvest** | Assist during the busy harvest season |
| 2 | 🚚 **Transport goods to market** | Deliver items to a selling point |
| 3 | 🪚 **Fix broken fence** | Repair work around their property |
| 4 | 🌱 **Deliver seeds to my farm** | Bring supplies they need |
| 5 | 🚜 **Borrow my tractor** | Let an NPC use your equipment |
| 6 | 💰 **Loan money** | Financial assistance |
| 7 | 👁️ **Watch property** | Keep an eye on things while they're away |

> [!IMPORTANT]
> Each favor has a **time limit**. Fail to complete one and your relationship takes a hit — plan accordingly!

---

## 🖥️ Console Commands

Open the in-game console with the **`~`** key:

| Command | Description |
|---|---|
| `npcHelp` | Show all available commands |
| `npcStatus` | Full system status — NPCs, subsystems, player position, game time |
| `npcList` | GUI table of all NPCs with personality, action, distance & teleport buttons |
| `npcGoto <number>` | Teleport to an NPC by number |

---

## 🏗️ Architecture

The mod is built from cooperating subsystems coordinated by a central `NPCSystem`:

```
NPCSystem                   Central coordinator — spawning, update loop, save/load, multiplayer sync
├── NPCAI                   Needs-based AI state machine + road spline pathfinding
├── NPCScheduler            Personality-specific daily routines with seasonal adjustments
├── NPCEntity               Animated character models via FS25 HumanGraphicsComponent
├── NPCRelationshipManager  Player-NPC & NPC-NPC graph, compatibility, grudges, gifts
├── NPCFavorSystem          Favor generation, tracking & completion (7 types, timed)
├── NPCInteractionUI        World-space HUD — speech bubbles, name tags, mood indicators
├── NPCDialog               Press-E conversation dialog (5 actions + hover effects)
├── NPCListDialog           Console-triggered roster table with teleport buttons
└── DialogLoader            Lazy-loading dialog registry wrapping FS25's g_gui system
```

<details>
<summary>📂 <strong>Full File Structure</strong></summary>

```
FS25_NPCFavor/
├── main.lua                             Entry point — hooks, E key binding, draw/save/load
├── modDesc.xml                          Mod config, input bindings, 1500+ i18n strings
├── icon.dds / icon_small.dds            Mod icons
│
├── gui/
│   ├── NPCDialog.xml                    Interaction dialog layout
│   └── NPCListDialog.xml                NPC roster table layout
│
├── src/
│   ├── NPCSystem.lua                    Central coordinator
│   ├── gui/
│   │   ├── DialogLoader.lua
│   │   ├── NPCDialog.lua
│   │   └── NPCListDialog.lua
│   ├── scripts/
│   │   ├── NPCAI.lua
│   │   ├── NPCEntity.lua
│   │   ├── NPCScheduler.lua
│   │   ├── NPCRelationshipManager.lua
│   │   ├── NPCFavorSystem.lua
│   │   └── NPCInteractionUI.lua
│   ├── events/
│   │   ├── NPCStateSyncEvent.lua        Server → client NPC state sync
│   │   ├── NPCInteractionEvent.lua      Client → server interaction routing
│   │   └── NPCSettingsSyncEvent.lua     Bidirectional settings sync
│   ├── settings/
│   │   ├── NPCSettings.lua
│   │   ├── NPCSettingsUI.lua
│   │   ├── NPCSettingsIntegration.lua
│   │   └── NPCFavorGUI.lua
│   └── utils/
│       ├── VectorHelper.lua             Math utilities (distance, lerp, normalize)
│       └── TimeHelper.lua               Game time conversion from dayTime ms
│
└── docs/                                Architecture & system documentation
```

</details>

---

## ⚠️ Known Limitations

> [!WARNING]
> These are known issues currently in the backlog — they do not break the mod.

| Issue | Status | Details |
|---|---|---|
| 🚜 **NPC Vehicles** | 🔧 In progress | Vehicle prop code exists but nothing spawns yet — NPCs walk everywhere |
| 👥 **Silent Groups** | 🔧 In progress | Group gatherings work positionally but produce no dialog — only 1-on-1 gets speech bubbles |
| 🌍 **Flavor Text i18n** | 📋 Planned | Mood prefixes, backstories & personality dialog are English-only; core UI is fully localized |

---

## 📖 Documentation

| Doc | Description |
|---|---|
| [Architecture Overview](docs/architecture.md) | How the subsystems fit together |
| [AI System](docs/ai-system.md) | Needs-based AI & pathfinding deep dive |
| [Relationship System](docs/relationship-system.md) | Tiers, decay, compatibility explained |
| [Settings Reference](docs/settings.md) | All configurable options |
| [Changelog](CHANGELOG.md) | Version history & release notes |

---

## 📝 License & Credits

> [!CAUTION]
> Unauthorized redistribution, copying, or claiming this code as your own is **strictly prohibited**.

| Role | Person |
|---|---|
| 💡 Original Idea | Lion2008 |
| 💻 Implementation & Coding | TisonK |
| 🤖 AI Overhaul (v1.2.0) | XelaNull & Claude AI |

This is a **free mod for the community** — all rights reserved.

---

<div align="center">

*Enjoy your new neighborhood, and happy farming!* 🌾
