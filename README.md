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

## 🔧 For Modders / Contributors

The code is structured into several key classes for easy understanding and extension:
- `NPCSystem.lua` - The main coordinator.
- `NPCAI.lua` - Handles NPC behavior and pathfinding.
- `NPCRelationshipManager.lua` - Manages friendship levels and effects.
- `NPCFavorSystem.lua` - The core of the favor/task system.
- `NPCInteractionUI.lua` - Manages the player interaction dialog.

Feel free to fork and experiment! Suggestions and clean pull requests are welcome.

---

## ❓ FAQ / Troubleshooting

**Q: I don't see any NPCs!**
A: Ensure the mod is activated in your savegame. Try typing `npcStatus` in the console. If it says "not initialized," try traveling to a different part of the map or using `npcSpawn Test` to force-spawn one near you.

**Q: Can I use this in multiplayer?**
A: Yes! The mod is multiplayer-safe. However, favor states and relationships are currently tracked per-client, not synced between players.

**Q: Will this mod conflict with X?**
A: It only uses common game hooks. Conflicts are unlikely but possible with other major script mods that alter core game loops or the interaction system.

**Q: The NPCs are just floating spheres!**
A: Yes, in V1.0.0.0, detailed 3D models are a placeholder. The core systems are functional; visual upgrades are planned.

---

## 📝 License & Credits

*   **Original Idea:** Lion2008
*   **Implementation & Coding:** TisonK
*   **License:** All rights reserved. Unauthorized redistribution, copying, or claiming this code as your own is strictly prohibited. This is a free mod for the community.

---

*Enjoy your new neighborhood, and happy farming!*
