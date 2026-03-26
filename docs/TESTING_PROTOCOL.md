# FS25_NPCFavor Testing Protocol

**Version**: 1.2.2.6
**Purpose**: Comprehensive pre-release testing protocol for public release candidates
**Target**: Development branch → Main branch deployment

---

## Overview

This document outlines the complete testing process for **FS25_NPCFavor** before public release. All tests must pass before merging development into the main branch. Tests are organized by priority: **Critical** (must pass), **High** (should pass), and **Medium** (nice-to-have).

---

## Pre-Test Setup

### Required Test Environment

1. **Fresh Installation**
   - Delete existing `FS25_NPCFavor` from `%USERPROFILE%\Documents\My Games\FarmingSimulator2025\mods`
   - Install current development build
   - Start new savegame OR use existing savegame (test both scenarios)

2. **Log Monitoring**
   - Open `%USERPROFILE%\Documents\My Games\FarmingSimulator2025\log.txt` in a text editor with auto-refresh
   - Filter for `[NPC` prefix lines to monitor mod activity
   - Clear log before each major test section

3. **Dev Console Access**
   - Enable developer console in FS25 settings
   - Test console command: Type `npcHelp` to verify mod is loaded

4. **Test Savegames**
   - **New Save**: Fresh farm, no NPCs spawned yet
   - **Existing Save**: Farm with 10+ NPCs, established relationships
   - **Multiplayer Save**: Dedicated server or hosted session with 2+ players

---

## Critical Tests (MUST PASS)

### 1. Mod Loading & Initialization

| Test | Steps | Expected Result | Priority |
|------|-------|-----------------|----------|
| **Clean Install** | 1. Delete mod from mods folder<br>2. Copy fresh build<br>3. Launch FS25<br>4. Load any map | - No errors in log.txt<br>- Mod appears in Mod Hub menu<br>- Version shows 1.2.2.6 | CRITICAL |
| **First Spawn** | 1. Start new savegame<br>2. Wait 30 seconds<br>3. Type `npcStatus` | - NPCs spawn within 60s<br>- No Lua errors<br>- Status shows active NPCs | CRITICAL |
| **Console Commands** | Type each: `npcHelp`, `npcStatus`, `npcList`, `npcDebug` | - All commands execute without error<br>- `npcHelp` shows command list<br>- `npcDebug` toggles debug mode | CRITICAL |

### 2. Core NPC Behavior

| Test | Steps | Expected Result | Priority |
|------|-------|-----------------|----------|
| **NPC Movement** | 1. Locate an NPC (use `npcGoto 1`)<br>2. Observe for 5 minutes | - NPC walks naturally<br>- Pathfinding works (no stuck NPCs)<br>- Animation transitions smooth | CRITICAL |
| **AI State Transitions** | 1. Enable debug mode (`npcDebug`)<br>2. Watch NPC for 10 minutes<br>3. Note state changes | - NPC cycles through states (idle, walking, working, resting)<br>- State text displays above head<br>- Transitions feel natural | CRITICAL |
| **Needs System** | 1. Debug mode ON<br>2. Watch an NPC over 1 in-game day | - Energy decreases during work, recovers during rest<br>- Social decreases when alone, recovers during socializing<br>- Hunger increases over time<br>- NPCs seek to satisfy needs | HIGH |
| **E-Key Interaction** | 1. Walk near NPC<br>2. Wait for `[E] Talk to` prompt<br>3. Press E | - Prompt appears within 3m<br>- Dialog opens on E press<br>- Dialog shows NPC name, relationship tier, current favor | CRITICAL |

### 3. Relationship System

| Test | Steps | Expected Result | Priority |
|------|-------|-----------------|----------|
| **Initial Relationship** | 1. Talk to a new NPC<br>2. Check relationship tier | - Starts at Tier 1 (Stranger) or Tier 2 (Acquaintance)<br>- Relationship bar visible in dialog | CRITICAL |
| **Favor Completion** | 1. Accept a favor quest<br>2. Complete requirements<br>3. Return to NPC | - Favor marked complete<br>- Relationship points increase<br>- May tier up (visual + log message) | CRITICAL |
| **Gifting** | 1. Have an item in inventory<br>2. Talk to NPC<br>3. Select "Give Gift" | - Gift accepted<br>- Relationship increases<br>- NPC responds appropriately | HIGH |
| **7-Tier Progression** | 1. Use `npcDebug` to monitor points<br>2. Complete multiple favors with one NPC<br>3. Track tier changes | - Tiers progress: Stranger → Acquaintance → Friend → Good Friend → Close Friend → Best Friend → Soulmate<br>- Each tier unlock message appears | HIGH |

### 4. Favor System

| Test | Steps | Expected Result | Priority |
|------|-------|-----------------|----------|
| **Favor Availability** | 1. Talk to 5+ NPCs | - Some NPCs offer favors<br>- Favor types vary (delivery, borrow equipment, etc.)<br>- Favors appropriate to relationship tier | CRITICAL |
| **Active Favor Tracking** | 1. Accept a favor<br>2. Open Favor Menu (F6) | - Favor appears in list<br>- Objective text clear<br>- Progress/status accurate | CRITICAL |
| **Favor Completion** | 1. Accept favor<br>2. Complete objective<br>3. Return to NPC | - NPC acknowledges completion<br>- Rewards granted (money, relationship)<br>- Favor removed from active list | CRITICAL |
| **Multiple Active Favors** | 1. Accept 3+ favors from different NPCs<br>2. Check F6 menu | - All favors listed separately<br>- Each shows correct NPC name and objective<br>- No overlaps or confusion | HIGH |

### 5. GUI & Keybindings

| Test | Steps | Expected Result | Priority |
|------|-------|-----------------|----------|
| **F6 - Favor Menu** | Press F6 anywhere in-game | - Dialog opens immediately<br>- Shows all active favors<br>- Scrollable if > 5 favors<br>- Close button works (ESC or click) | CRITICAL |
| **F7 - NPC List** | Press F7 anywhere in-game | - Dialog opens with all NPCs<br>- Shows name, relationship tier, location<br>- "Go To" button teleports player<br>- Sorted by name or tier | CRITICAL |
| **E - Interaction** | 1. Approach NPC<br>2. Verify prompt appears<br>3. Press E | - Prompt only shows when within 3m<br>- Prompt hides when too far<br>- E opens dialog instantly<br>- Works in vehicles (if player is on foot) | CRITICAL |
| **HUD Elements** | 1. Play normally for 10 minutes<br>2. Observe HUD | - Speech bubbles appear during NPC conversations<br>- NPC name tags visible when nearby<br>- Favor list (if enabled) displays active favors<br>- No UI overlap or clipping | HIGH |
| **Dialog Responsiveness** | 1. Open NPCDialog (E key)<br>2. Click all buttons<br>3. Open F6 and F7 dialogs | - Buttons respond instantly<br>- No lag or freezing<br>- Dialogs close properly<br>- No visual glitches | CRITICAL |

### 6. Save/Load Functionality

| Test | Steps | Expected Result | Priority |
|------|-------|-----------------|----------|
| **Save State** | 1. Play for 30 minutes<br>2. Build relationships, accept favors<br>3. Save game | - No errors in log<br>- Files created: `npc_favor_data.xml`, `npc_favor_settings.xml` in savegame folder | CRITICAL |
| **Load State** | 1. Save game (see above)<br>2. Exit to menu<br>3. Load savegame | - All NPCs restored<br>- Relationships preserved<br>- Active favors intact<br>- NPC positions accurate | CRITICAL |
| **Settings Persistence** | 1. Change settings in F6 menu<br>2. Save and reload | - Settings restored correctly<br>- HUD visibility matches saved state | HIGH |

### 7. Multiplayer Sync

| Test | Steps | Expected Result | Priority |
|------|-------|-----------------|----------|
| **Host Session** | 1. Host a multiplayer game<br>2. Have 1+ players join | - Clients see same NPCs as host<br>- NPC positions sync within 5s<br>- No desync warnings in log | CRITICAL |
| **Client Interaction** | 1. Client talks to NPC<br>2. Client completes favor | - Interaction processed by server<br>- Relationship updates visible to all players<br>- No conflicts or rollbacks | CRITICAL |
| **Late Join** | 1. Host has been playing 30+ min<br>2. New client joins | - Client receives full NPC state snapshot<br>- All NPCs visible and positioned correctly<br>- Relationships sync to new client | CRITICAL |
| **Concurrent Actions** | 1. Two clients talk to different NPCs simultaneously<br>2. Both complete favors | - Both interactions succeed<br>- No race conditions or errors<br>- Server log shows both events | HIGH |

---

## High Priority Tests (SHOULD PASS)

### 8. Performance & Stability

| Test | Steps | Expected Result | Priority |
|------|-------|-----------------|----------|
| **High NPC Count** | 1. Use console to spawn max NPCs (50)<br>2. Play for 20 minutes | - FPS stable (no significant drop)<br>- NPCs update smoothly<br>- Batching visible in debug (max 5 NPCs/frame) | HIGH |
| **Long Session** | Play for 2+ real-time hours | - No memory leaks<br>- No performance degradation<br>- NPCs continue to behave correctly | HIGH |
| **Fast Travel** | 1. Teleport across map repeatedly (`npcGoto`)<br>2. Check NPC loading/unloading | - NPCs outside 200m despawn<br>- NPCs within range spawn smoothly<br>- No stuttering or freezing | HIGH |

### 9. Edge Cases

| Test | Steps | Expected Result | Priority |
|------|-------|-----------------|----------|
| **NPC Stuck Recovery** | 1. Find an NPC stuck in geometry<br>2. Wait 60s | - NPC teleports to safe location<br>- OR AI state transitions to recover | MEDIUM |
| **Invalid Favor Data** | 1. Manually edit `npc_favor_data.xml` with invalid data<br>2. Load savegame | - Mod detects corruption and logs warning<br>- Graceful fallback (reset favors or NPC) | MEDIUM |
| **Missing Translations** | 1. Switch language to one with incomplete translations<br>2. Open dialogs | - Falls back to English for missing keys<br>- No blank text or errors | MEDIUM |

### 10. Localization (10 Languages)

| Test | Steps | Expected Result | Priority |
|------|-------|-----------------|----------|
| **Language Switching** | 1. Change FS25 language setting<br>2. Restart game<br>3. Open mod dialogs | - All UI text translates correctly for: en, de, fr, pl, es, it, cz, br, uk, ru<br>- No missing translations in core UI | HIGH |
| **Dialog Text Fitting** | Check dialogs in all languages | - Text fits in buttons/labels<br>- No clipping or overflow<br>- Special characters display correctly (umlauts, Cyrillic) | MEDIUM |

---

## Release Criteria Checklist

### ✅ All Critical Tests Passed
- [ ] Mod loads without errors
- [ ] NPCs spawn and move correctly
- [ ] E-key interaction works
- [ ] F6/F7 dialogs open and function
- [ ] Relationship system tracks correctly
- [ ] Favor system works end-to-end
- [ ] Save/load preserves all state
- [ ] Multiplayer sync works (host, client, late join)

### ✅ No Critical Bugs
- [ ] No Lua errors in log.txt
- [ ] No crashes or freezes
- [ ] No save corruption
- [ ] No multiplayer desync

### ✅ High Priority Tests Passed
- [ ] Performance stable with 50 NPCs
- [ ] Long sessions (2+ hours) stable
- [ ] All 10 languages functional

### ✅ Documentation Updated
- [ ] CHANGELOG.md reflects new version
- [ ] README.md accurate
- [ ] Known issues documented (if any)

---

## Bug Reporting Guidelines

When testers find issues, report using this template:

```
**Bug**: [Short description]
**Severity**: Critical / High / Medium / Low
**Steps to Reproduce**:
1. [Step 1]
2. [Step 2]
3. [Result]

**Expected**: [What should happen]
**Actual**: [What actually happens]
**Log Excerpt**: [Paste relevant lines from log.txt with [NPC prefix]
**Savegame**: [Attach if relevant]
**Multiplayer**: Yes/No - [Host/Client]
```

---

## Final Approval

Once all tests pass:

1. **Development Team Review**: All devs verify checklist
2. **Version Bump**: Confirm version number in `modDesc.xml`
3. **CHANGELOG Update**: Document all changes since last release
4. **Branch Merge**: `development` → `main`
5. **Tag Release**: Git tag `v1.2.2.6`
6. **Public Deployment**: Upload to ModHub / distribution channels

---

## Notes for Testers

- **Be thorough, not fast**: Quality over speed
- **Test weird scenarios**: Fat-finger inputs, spam keys, do unexpected things
- **Think like a player**: Is this fun? Confusing? Annoying?
- **Check the log**: Most bugs leave traces in `log.txt`
- **Use debug mode**: `npcDebug` shows internal state - very useful for diagnosing issues

---

**Last Updated**: 2026-02-14
**Protocol Version**: 1.0
