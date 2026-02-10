# NPC Favor - Living Neighborhood

**Mod Name:** FS25_NPCFavor
**Version:** 1.2.1.0
**Game:** Farming Simulator 25
**Author:** TisonK (original creator), UsedPlus Team (AI overhaul v1.2.0)

---

## What Is This Mod?

NPC Favor transforms your Farming Simulator 25 world into a living, breathing neighborhood. Instead of farming alone in a quiet countryside, you share the land with AI-driven NPC neighbors who work their own fields, go about daily routines, and build genuine relationships with you over time.

These are not simple bystanders. Each NPC has a name, a personality, a home, and opinions about you. Talk to them, help them out with favors, give them gifts, and watch as your relationship grows from "Hostile" all the way to "Best Friend" -- unlocking discounts, equipment borrowing, and cooperative help along the way.

The mod supports both singleplayer and multiplayer, saves your NPC relationships and favor progress across sessions, and is fully localized in 10 languages.

---

## Key Features

- **Living NPC Neighbors** -- NPCs spawn at buildings around the map (shops, gas stations, production points, farms) with assigned roles like shopkeeper, mechanic, or farmer.
- **Relationship System** -- A 0-100 relationship scale with seven tiers: Hostile, Unfriendly, Neutral, Acquaintance, Friend, Close Friend, and Best Friend. Each tier unlocks new benefits and dialog options.
- **Favor System** -- NPCs ask for help with tasks like harvesting, transporting goods, fixing fences, and delivering seeds. Completing favors earns money and relationship points.
- **Dynamic Dialog** -- Context-aware conversations that change based on time of day, relationship level, NPC personality, and current activity. Greetings shift from cold ("What do you want?") to warm ("Great to see you, my good friend!") as trust builds.
- **Gift Giving** -- Spend $500 to give an NPC a gift and boost your relationship (unlocked at relationship level 30+).
- **AI State Machine** -- NPCs cycle through idle, walking, working, driving, resting, socializing, and traveling states with realistic daily schedules.
- **Persistent Save/Load** -- NPC positions, relationships, active favors, and personality data are saved to your savegame XML and restored when you reload.
- **Multiplayer Support** -- Full state sync for joining players, with settings broadcast on connect. Works in dedicated server and peer-to-peer sessions.
- **10-Language Localization** -- English, German, French, Polish, Spanish, Italian, Czech, Brazilian Portuguese, Ukrainian, and Russian.
- **In-Game Settings** -- Toggle the NPC system on/off, set max NPC count, configure work hours, favor frequency, name display, notifications, and debug mode.
- **Console Commands** -- Type `npcHelp` in the developer console for a list of available commands including `npcStatus`, `npcList`, `npcSpawn`, and `npcReset`.
- **Relationship Benefits** -- As relationships grow, you unlock favor requests (25+), gift giving (30+), equipment borrowing, NPC-offered help, and scaling discounts up to 20%.

---

## Installation

1. Download the `FS25_NPCFavor.zip` file.
2. Place it in your FS25 mods folder:
   - **Windows:** `Documents\My Games\FarmingSimulator2025\mods\`
   - **macOS:** `~/Library/Application Support/FarmingSimulator2025/mods/`
3. Launch Farming Simulator 25.
4. When starting or loading a savegame, enable **NPC Favor - Living Neighborhood** in the mod selection screen.
5. Load into your farm and start playing.

---

## Quick Start Guide

When you first load into a game with NPC Favor enabled, here is what to expect:

1. **NPCs spawn automatically.** After the mission finishes loading, NPCs will appear near buildings around the map. You will see a console message confirming initialization.
2. **Look for the [E] prompt.** Walk near an NPC and a contextual prompt will appear: "Talk to [NPC Name]". Press **E** to open the dialog.
3. **Start a conversation.** The dialog window shows the NPC's name, your current relationship level, and a greeting that reflects how well they know you. New NPCs start with a random relationship between Hostile and Neutral.
4. **Choose an action.** You can Talk (small talk that builds rapport), Ask About Work (learn what the NPC is up to), view Relationship Info, or Close the dialog.
5. **Build the relationship.** Keep chatting, complete favors when they become available (at relationship 25+), and give gifts (at relationship 30+). Each interaction nudges the relationship score upward.
7. **Adjust settings.** Open the mod settings in the game's settings menu to tweak NPC count, work hours, favor frequency, and more.
8. **Your progress is saved.** When you save your game, all NPC data (positions, relationships, favor progress) is written to your savegame. It will be restored next time you load.

---

## Documentation

For deeper details on each subsystem, see the following docs:

- [Architecture Overview](architecture.md) -- System design, module layout, and data flow
- [AI System](ai-system.md) -- NPC state machine, scheduling, pathfinding, and behavior
- [Relationship System](relationship-system.md) -- How relationship tiers, benefits, and progression work
- [Settings Reference](settings.md) -- All configurable options and their effects
- [Universal Dialog System](universaldialog.md) -- DialogLoader pattern for registering, lazy-loading, and showing FS25 GUI dialogs
- [Versioning Guide](versioning.md) -- Version number format, what to update per release, and file locations
- [Changelog](../CHANGELOG.md) -- Version history and release notes

---

## Known Limitations

- **Map markers** -- The code to create MapHotspot markers exists, but hotspots do not appear on the in-game map. This is a known issue with the FS25 MapHotspot API integration.
- **NPC vehicles and tractors** -- Vehicle and tractor prop code is in place, but the i3d models cannot be loaded from the game's pak archives at runtime. NPCs walk everywhere; no visible vehicles spawn.
- **Flavor text localization** -- The core UI and settings are localized in 10 languages. However, mood prefixes, backstories, birthday messages, and personality-flavored dialog added in v1.2.0 are English-only.

---

## Credits

- **TisonK** -- Original creator and implementation
- **Lion2009** -- Original concept and idea
- **XelaNull & Claude AI** -- AI overhaul, living neighborhood system, dialog framework, relationship engine, multiplayer sync, i18n, and ongoing development (v1.2.0)
