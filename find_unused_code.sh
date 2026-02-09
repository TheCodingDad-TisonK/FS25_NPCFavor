#!/bin/bash
# find_unused_code.sh — Inventory-based unused code scanner for FS25_NPCFavor
#
# Approach:
#   Phase 1: Build a complete inventory of all classes, functions, globals, and files
#   Phase 2: For each item in the inventory, search for references across the codebase
#   Phase 3: Report anything with zero external references
#
# Usage: bash find_unused_code.sh [path_to_mod_root]

set -uo pipefail

MOD_ROOT="${1:-$(cd "$(dirname "$0")" && pwd)}"
MAIN_LUA="$MOD_ROOT/main.lua"
TMPDIR=$(mktemp -d)

# Collect all Lua files
find "$MOD_ROOT" -name '*.lua' -not -path '*/.git/*' | sort > "$TMPDIR/all_lua_files.txt"
SRC_COUNT=$(wc -l < "$TMPDIR/all_lua_files.txt")

echo "=========================================="
echo " find_unused_code — Inventory Scanner"
echo " Root:  $MOD_ROOT"
echo " Files: $SRC_COUNT Lua files"
echo "=========================================="

# =============================================
# PHASE 1: BUILD INVENTORY
# =============================================
echo ""
echo "== PHASE 1: Building inventory =="
echo ""

# --- 1a: Classes (CapitalWord = {} or CapitalWord = ... at file scope) ---
echo -n "" > "$TMPDIR/classes.txt"
while IFS= read -r file; do
    rel=$(echo "$file" | sed "s|$MOD_ROOT/||")
    grep -n '^[A-Z][A-Za-z0-9_]* *=' "$file" 2>/dev/null | while IFS= read -r line; do
        name=$(echo "$line" | sed 's/^\([0-9]*\):\([A-Z][A-Za-z0-9_]*\).*/\2/')
        lineno=$(echo "$line" | cut -d: -f1)
        # Skip metatables
        case "$name" in *_mt) continue ;; esac
        echo "$name|$rel:$lineno|$file" >> "$TMPDIR/classes.txt"
    done
done < "$TMPDIR/all_lua_files.txt"
# Deduplicate by name (keep first occurrence)
sort -t'|' -k1,1 -u "$TMPDIR/classes.txt" > "$TMPDIR/classes_uniq.txt"
CLASS_COUNT=$(wc -l < "$TMPDIR/classes_uniq.txt")
echo "  Classes/globals found: $CLASS_COUNT"

# --- 1b: Functions (function ClassName:method or function ClassName.method) ---
echo -n "" > "$TMPDIR/functions.txt"
while IFS= read -r file; do
    rel=$(echo "$file" | sed "s|$MOD_ROOT/||")
    grep -n '^function ' "$file" 2>/dev/null | while IFS= read -r line; do
        lineno=$(echo "$line" | cut -d: -f1)
        sig=$(echo "$line" | cut -d: -f2- | sed 's/^function //')

        # Extract class and method
        class=""
        method=""
        if echo "$sig" | grep -q ':'; then
            class=$(echo "$sig" | sed 's/:.*//')
            method=$(echo "$sig" | sed 's/[^:]*:\([A-Za-z_][A-Za-z0-9_]*\).*/\1/')
        elif echo "$sig" | grep -q '\.'; then
            class=$(echo "$sig" | sed 's/\..*//')
            method=$(echo "$sig" | sed 's/[^.]*\.\([A-Za-z_][A-Za-z0-9_]*\).*/\1/')
        else
            # Standalone function
            method=$(echo "$sig" | sed 's/\([A-Za-z_][A-Za-z0-9_]*\).*/\1/')
        fi

        [ -z "$method" ] && continue
        echo "$class|$method|$rel:$lineno|$file" >> "$TMPDIR/functions.txt"
    done
done < "$TMPDIR/all_lua_files.txt"
FUNC_COUNT=$(wc -l < "$TMPDIR/functions.txt")
echo "  Functions found: $FUNC_COUNT"

# --- 1c: source()'d files ---
echo -n "" > "$TMPDIR/sourced.txt"
if [ -f "$MAIN_LUA" ]; then
    grep 'source(modDirectory' "$MAIN_LUA" | while IFS= read -r line; do
        rel_path=$(echo "$line" | sed -n 's/.*source(modDirectory \.\. "\([^"]*\)").*/\1/p')
        [ -z "$rel_path" ] && continue
        echo "$rel_path" >> "$TMPDIR/sourced.txt"
    done
fi
SOURCED_COUNT=$(wc -l < "$TMPDIR/sourced.txt")
echo "  source()'d files: $SOURCED_COUNT"

# --- 1d: All Lua files in src/ ---
find "$MOD_ROOT/src" -name '*.lua' 2>/dev/null | sed "s|$MOD_ROOT/||" | sort > "$TMPDIR/src_files.txt"
SRC_DIR_COUNT=$(wc -l < "$TMPDIR/src_files.txt")
echo "  Lua files in src/: $SRC_DIR_COUNT"

# --- 1e: Directories in src/ ---
find "$MOD_ROOT/src" -type d 2>/dev/null | sed "s|$MOD_ROOT/||" | sort > "$TMPDIR/src_dirs.txt"

echo ""
echo "== Inventory Summary =="
echo "  $CLASS_COUNT classes/globals"
echo "  $FUNC_COUNT functions"
echo "  $SOURCED_COUNT source() entries"
echo "  $SRC_DIR_COUNT files in src/"

# =============================================
# PHASE 2: CHECK REFERENCES
# =============================================
echo ""
echo "== PHASE 2: Checking references =="
echo ""

# Concatenate all lua files into one searchable blob for speed
cat $(cat "$TMPDIR/all_lua_files.txt") > "$TMPDIR/all_code.txt" 2>/dev/null

TOTAL_ISSUES=0

# --- 2a: Unused Classes ---
echo "[CLASSES] Checking $CLASS_COUNT classes for external references..."
echo "---"
while IFS='|' read -r name location deffile; do
    # Count references in files OTHER than the defining file
    ref_count=0
    while IFS= read -r other; do
        [ "$other" = "$deffile" ] && continue
        if grep -q "$name" "$other" 2>/dev/null; then
            ref_count=$((ref_count + 1))
            break
        fi
    done < "$TMPDIR/all_lua_files.txt"

    if [ "$ref_count" -eq 0 ]; then
        echo "  UNUSED CLASS: '$name' defined at $location"
        echo "    -> Never referenced in any other file"
        TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
    fi
done < "$TMPDIR/classes_uniq.txt"
echo ""

# --- 2b: Unused Functions ---
echo "[FUNCTIONS] Checking $FUNC_COUNT functions for references..."
echo "---"

# Engine/framework methods that are called implicitly (not by our code)
SKIP_METHODS="new|update|draw|delete|onCreate|onOpen|onClose|readStream|writeStream|run|getIsAllowed|register|init|cleanup|superClass|loadMap|deleteMap|saveToXMLFile"

while IFS='|' read -r class method location deffile; do
    # Skip engine callbacks
    if echo "$method" | grep -qE "^($SKIP_METHODS)$"; then
        continue
    fi
    # Skip XML-bound event handlers (onClick*, onFocus*, onLeave*, onBtn*)
    case "$method" in
        onClick*|onFocus*|onLeave*|onBtn*|onClose*|onOpen*|onCreate*) continue ;;
    esac
    # Skip very short method names (high false-positive rate)
    [ ${#method} -lt 4 ] && continue

    # Check for references in OTHER files
    ext_ref=0
    while IFS= read -r other; do
        [ "$other" = "$deffile" ] && continue
        if grep -q "$method" "$other" 2>/dev/null; then
            ext_ref=1
            break
        fi
    done < "$TMPDIR/all_lua_files.txt"

    if [ "$ext_ref" -eq 0 ]; then
        # Check self-references (more than just the definition line)
        self_refs=$(grep -c "$method" "$deffile" 2>/dev/null || echo 0)
        if [ "$self_refs" -le 1 ]; then
            status="DEAD"
            detail="defined once, never called (0 external, $self_refs self)"
        else
            status="FILE-LOCAL"
            detail="called only within its own file ($self_refs refs, 0 external)"
        fi
        echo "  $status: $location — ${class:+$class:}$method()"
        echo "    -> $detail"
        TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
    fi
done < "$TMPDIR/functions.txt"
echo ""

# --- 2c: Missing source() targets ---
echo "[SOURCE FILES] Checking source() targets exist..."
echo "---"
if [ -f "$TMPDIR/sourced.txt" ]; then
    while IFS= read -r rel_path; do
        if [ ! -f "$MOD_ROOT/$rel_path" ]; then
            echo "  MISSING: source('$rel_path') — file does not exist"
            TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
        fi
    done < "$TMPDIR/sourced.txt"
fi
echo ""

# --- 2d: Orphaned files (in src/ but not source()'d) ---
echo "[ORPHAN FILES] Lua files in src/ not loaded by source()..."
echo "---"
while IFS= read -r rel; do
    if ! grep -qF "$rel" "$TMPDIR/sourced.txt" 2>/dev/null; then
        echo "  ORPHAN: $rel — exists but not source()'d in main.lua"
        TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
    fi
done < "$TMPDIR/src_files.txt"
echo ""

# --- 2e: Empty directories ---
echo "[EMPTY DIRS] Checking for empty directories in src/..."
echo "---"
while IFS= read -r dir; do
    full="$MOD_ROOT/$dir"
    file_count=$(find "$full" -maxdepth 1 -type f 2>/dev/null | wc -l)
    if [ "$file_count" -eq 0 ]; then
        subdir_count=$(find "$full" -maxdepth 1 -type d 2>/dev/null | wc -l)
        # subdir_count includes the dir itself, so >1 means it has subdirs
        if [ "$subdir_count" -le 1 ]; then
            echo "  EMPTY: $dir — no files or subdirectories"
            TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
        fi
    fi
done < "$TMPDIR/src_dirs.txt"
echo ""

# --- 2f: Globals (g_*) defined but never used externally ---
echo "[GLOBALS] Checking g_* globals for external references..."
echo "---"
while IFS= read -r file; do
    rel=$(echo "$file" | sed "s|$MOD_ROOT/||")
    grep -n '^g_[A-Za-z0-9_]* *=' "$file" 2>/dev/null | while IFS= read -r line; do
        name=$(echo "$line" | sed 's/^\([0-9]*\):\(g_[A-Za-z0-9_]*\).*/\2/')
        lineno=$(echo "$line" | cut -d: -f1)
        [ -z "$name" ] && continue

        ext_ref=0
        while IFS= read -r other; do
            [ "$other" = "$file" ] && continue
            if grep -q "$name" "$other" 2>/dev/null; then
                ext_ref=1
                break
            fi
        done < "$TMPDIR/all_lua_files.txt"

        if [ "$ext_ref" -eq 0 ]; then
            echo "  UNUSED: $rel:$lineno defines '$name' — never referenced elsewhere"
        fi
    done
done < "$TMPDIR/all_lua_files.txt"
echo ""

# =============================================
# PHASE 3: SUMMARY
# =============================================
echo "=========================================="
echo " INVENTORY"
echo "   $CLASS_COUNT classes/globals"
echo "   $FUNC_COUNT functions"
echo "   $SOURCED_COUNT source() entries"
echo "   $SRC_DIR_COUNT files in src/"
echo ""
echo " ISSUES: $TOTAL_ISSUES potential problems found"
echo ""
echo " Notes:"
echo "   - FILE-LOCAL functions may be intentional (internal helpers)"
echo "   - DEAD functions are defined once and never called anywhere"
echo "   - ORPHAN files exist on disk but are never loaded"
echo "   - Review each result; some may be engine callbacks or future code"
echo "=========================================="

# Cleanup
rm -rf "$TMPDIR"
