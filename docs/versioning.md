# Versioning Guide

This document explains how version numbers work in FS25_NPCFavor and what must be updated when releasing a new version.

---

## Version Format

Versions follow a 4-part format: `MAJOR.MINOR.PATCH.BUILD` (e.g., `1.2.0.0`).

This matches the FS25 mod ecosystem convention used in `modDesc.xml`.

---

## Single Source of Truth

The **primary source of truth** for the version number is:

**`main.lua` line 49** -- the `MOD_VERSION` constant:

```lua
local MOD_VERSION = "1.2.0.0"
```

This value is assigned to `g_NPCFavorMod.version` at runtime (line 145/173), which other systems read dynamically. For example, `NPCSystem.lua` reads it at save time:

```lua
local saveVersion = (g_NPCFavorMod and g_NPCFavorMod.version) or "1.2.0.0"
```

---

## Files That Must Be Updated

When bumping the version, **two files** require manual edits:

| # | File | Line | What to Change |
|---|------|------|----------------|
| 1 | `modDesc.xml` | 4 | `<version>X.X.X.X</version>` |
| 2 | `main.lua` | 49 | `local MOD_VERSION = "X.X.X.X"` |

You should also update the comment on line 35 of `main.lua`:

```lua
-- FS25 NPC Favor Mod (version X.X.X.X)
```

---

## Files That Read the Version at Runtime (No Manual Edit Needed)

These files consume the version dynamically from `g_NPCFavorMod.version` and do **not** need manual edits:

| File | How It Uses the Version |
|------|------------------------|
| `src/NPCSystem.lua` (line 3219) | Writes `g_NPCFavorMod.version` into the savegame XML for future migration |
| `main.lua` (line 166) | Prints version to log on initialization |
| `main.lua` (line 503) | Prints version in the startup banner |

---

## Files to Update Outside of Code

When releasing a new version, also update:

| File | What to Change |
|------|----------------|
| `CHANGELOG.md` | Add a new version section at the top with release notes |
| `docs/README.md` | Update the version number in the header block (line 4) |

---

## Checklist

When releasing version `X.X.X.X`:

1. Edit `modDesc.xml` line 4: `<version>X.X.X.X</version>`
2. Edit `main.lua` line 49: `local MOD_VERSION = "X.X.X.X"`
3. Edit `main.lua` line 35: `-- FS25 NPC Favor Mod (version X.X.X.X)`
4. Edit `docs/README.md` line 4: `**Version:** X.X.X.X`
5. Add release notes to `CHANGELOG.md`
6. Build and deploy via `build.ps1`
7. Verify `log.txt` shows the new version string on load

---

## Save File Version

The savegame XML (`savegameX/npc_favor.xml`) stores the version that wrote it:

```xml
<NPCFavorSystem version="1.2.0.0">
```

On load, `NPCSystem.lua` reads this as `savedVersion` (line 3359). This enables future migration logic if the save format changes between versions. Currently no migration is performed -- the version is recorded but not acted on.
