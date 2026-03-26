#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ==============================================================================
# find_unused_code.py — Inventory-based unused code scanner for FS25 mods
#
# Approach:
#   Phase 1: Build a complete inventory of all classes, functions, globals, and files
#   Phase 2: For each item in the inventory, search for references across the codebase
#   Phase 3: Report anything with zero external references
#
# Usage: python find_unused_code.py [path_to_mod_root]
# ==============================================================================

import sys
import os
import re
from pathlib import Path
from dataclasses import dataclass, field
from typing import List, Dict, Set, Optional

# Windows UTF-8 bootstrap
if sys.platform == 'win32':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
        sys.stderr.reconfigure(encoding='utf-8')
    except (AttributeError, OSError):
        pass


# ==============================================================================
# Data Classes
# ==============================================================================

@dataclass
class ClassInfo:
    name: str
    location: str       # relative_path:lineno
    filepath: str       # absolute path

@dataclass
class FuncInfo:
    class_name: str
    method: str
    location: str       # relative_path:lineno
    filepath: str       # absolute path

@dataclass
class GlobalInfo:
    name: str
    lineno: int
    filepath: str       # absolute path
    rel_path: str


# Engine/framework methods that are called implicitly (not by our code)
SKIP_METHODS = {
    'new', 'update', 'draw', 'delete', 'onCreate', 'onOpen', 'onClose',
    'readStream', 'writeStream', 'run', 'getIsAllowed', 'register',
    'init', 'cleanup', 'superClass', 'loadMap', 'deleteMap', 'saveToXMLFile'
}

# XML-bound event handler prefixes
SKIP_PREFIXES = ('onClick', 'onFocus', 'onLeave', 'onBtn', 'onClose', 'onOpen', 'onCreate')


# ==============================================================================
# Phase 1: Build Inventory
# ==============================================================================

def find_lua_files(root):
    """Find all Lua files under root, excluding .git directories."""
    files = []
    for p in sorted(Path(root).rglob('*.lua')):
        if '.git' not in p.parts:
            files.append(str(p))
    return files


def build_class_inventory(lua_files, root):
    """Find all class/global definitions (CapitalWord = ... at file scope)."""
    classes = {}  # name -> ClassInfo (first occurrence wins)
    pattern = re.compile(r'^([A-Z][A-Za-z0-9_]*)\s*=')

    for filepath in lua_files:
        rel = os.path.relpath(filepath, root).replace('\\', '/')
        with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
            for lineno, line in enumerate(f, 1):
                m = pattern.match(line)
                if m:
                    name = m.group(1)
                    # Skip metatables
                    if name.endswith('_mt'):
                        continue
                    if name not in classes:
                        classes[name] = ClassInfo(
                            name=name,
                            location=f'{rel}:{lineno}',
                            filepath=filepath
                        )

    return list(classes.values())


def build_function_inventory(lua_files, root):
    """Find all function definitions (function X:method or function X.method)."""
    functions = []
    pattern = re.compile(r'^function\s+(\S+)')

    for filepath in lua_files:
        rel = os.path.relpath(filepath, root).replace('\\', '/')
        with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
            for lineno, line in enumerate(f, 1):
                m = pattern.match(line)
                if not m:
                    continue
                sig = m.group(1)

                class_name = ''
                method = ''

                if ':' in sig:
                    parts = sig.split(':', 1)
                    class_name = parts[0]
                    method_match = re.match(r'([A-Za-z_][A-Za-z0-9_]*)', parts[1])
                    method = method_match.group(1) if method_match else ''
                elif '.' in sig:
                    parts = sig.split('.', 1)
                    class_name = parts[0]
                    method_match = re.match(r'([A-Za-z_][A-Za-z0-9_]*)', parts[1])
                    method = method_match.group(1) if method_match else ''
                else:
                    method_match = re.match(r'([A-Za-z_][A-Za-z0-9_]*)', sig)
                    method = method_match.group(1) if method_match else ''

                if not method:
                    continue

                functions.append(FuncInfo(
                    class_name=class_name,
                    method=method,
                    location=f'{rel}:{lineno}',
                    filepath=filepath
                ))

    return functions


def build_source_inventory(main_lua):
    """Parse source() calls from main.lua."""
    entries = []
    if not os.path.isfile(main_lua):
        return entries

    pattern = re.compile(r'source\(modDirectory\s*\.\.\s*"([^"]+)"\)')
    with open(main_lua, 'r', encoding='utf-8', errors='replace') as f:
        for line in f:
            m = pattern.search(line)
            if m:
                entries.append(m.group(1))

    return entries


def build_src_file_inventory(root):
    """Find all Lua files in src/ directory."""
    src_dir = os.path.join(root, 'src')
    if not os.path.isdir(src_dir):
        return []
    files = []
    for p in sorted(Path(src_dir).rglob('*.lua')):
        files.append(os.path.relpath(str(p), root).replace('\\', '/'))
    return files


def build_src_dir_inventory(root):
    """Find all subdirectories of src/."""
    src_dir = os.path.join(root, 'src')
    if not os.path.isdir(src_dir):
        return []
    dirs = []
    for p in sorted(Path(src_dir).rglob('*')):
        if p.is_dir():
            dirs.append(os.path.relpath(str(p), root).replace('\\', '/'))
    # Also include src/ itself
    dirs.insert(0, 'src')
    return dirs


def build_global_inventory(lua_files, root):
    """Find all g_* global definitions."""
    globals_list = []
    pattern = re.compile(r'^(g_[A-Za-z0-9_]*)\s*=')
    seen = set()

    for filepath in lua_files:
        rel = os.path.relpath(filepath, root).replace('\\', '/')
        with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
            for lineno, line in enumerate(f, 1):
                m = pattern.match(line)
                if m:
                    name = m.group(1)
                    key = (name, filepath)
                    if key not in seen:
                        seen.add(key)
                        globals_list.append(GlobalInfo(
                            name=name,
                            lineno=lineno,
                            filepath=filepath,
                            rel_path=rel
                        ))

    return globals_list


# ==============================================================================
# Phase 2: Check References
# ==============================================================================

def load_all_contents(lua_files):
    """Load all file contents into memory for fast substring search."""
    contents = {}
    for filepath in lua_files:
        with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
            contents[filepath] = f.read()
    return contents


def check_unused_classes(classes, contents, lua_files):
    """Check for classes with no external references."""
    issues = []
    for cls in classes:
        has_external_ref = False
        for filepath in lua_files:
            if filepath == cls.filepath:
                continue
            if cls.name in contents[filepath]:
                has_external_ref = True
                break

        if not has_external_ref:
            issues.append(cls)

    return issues


def check_unused_functions(functions, contents, lua_files):
    """Check for functions with no external references."""
    issues = []
    for func in functions:
        # Skip engine callbacks
        if func.method in SKIP_METHODS:
            continue
        # Skip XML-bound event handlers
        if func.method.startswith(SKIP_PREFIXES):
            continue
        # Skip very short method names (high false-positive rate)
        if len(func.method) < 4:
            continue

        # Check for references in OTHER files
        has_external_ref = False
        for filepath in lua_files:
            if filepath == func.filepath:
                continue
            if func.method in contents[filepath]:
                has_external_ref = True
                break

        if not has_external_ref:
            # Check self-references (more than just the definition line)
            self_refs = contents[func.filepath].count(func.method)
            if self_refs <= 1:
                status = 'DEAD'
                detail = f'defined once, never called (0 external, {self_refs} self)'
            else:
                status = 'FILE-LOCAL'
                detail = f'called only within its own file ({self_refs} refs, 0 external)'

            prefix = f'{func.class_name}:' if func.class_name else ''
            issues.append({
                'status': status,
                'location': func.location,
                'name': f'{prefix}{func.method}()',
                'detail': detail
            })

    return issues


def check_missing_sources(source_entries, root):
    """Check that all source() targets exist on disk."""
    issues = []
    for rel_path in source_entries:
        full_path = os.path.join(root, rel_path)
        if not os.path.isfile(full_path):
            issues.append(rel_path)
    return issues


def check_orphan_files(src_files, source_entries):
    """Find Lua files in src/ that are not loaded by source()."""
    sourced_set = set(source_entries)
    issues = []
    for rel in src_files:
        if rel not in sourced_set:
            issues.append(rel)
    return issues


def check_empty_dirs(src_dirs, root):
    """Find empty directories in src/."""
    issues = []
    for rel_dir in src_dirs:
        full_dir = os.path.join(root, rel_dir)
        if not os.path.isdir(full_dir):
            continue
        # Count files directly in this directory
        file_count = sum(1 for entry in os.listdir(full_dir) if os.path.isfile(os.path.join(full_dir, entry)))
        if file_count == 0:
            # Check for subdirectories
            subdir_count = sum(1 for entry in os.listdir(full_dir) if os.path.isdir(os.path.join(full_dir, entry)))
            if subdir_count == 0:
                issues.append(rel_dir)
    return issues


def check_unused_globals(globals_list, contents, lua_files):
    """Check for g_* globals with no external references."""
    issues = []
    for g in globals_list:
        has_external_ref = False
        for filepath in lua_files:
            if filepath == g.filepath:
                continue
            if g.name in contents[filepath]:
                has_external_ref = True
                break

        if not has_external_ref:
            issues.append(g)

    return issues


# ==============================================================================
# Main
# ==============================================================================

def main():
    # Determine mod root
    if len(sys.argv) > 1:
        mod_root = os.path.abspath(sys.argv[1])
    else:
        mod_root = os.path.abspath(os.path.dirname(__file__) or '.')

    main_lua = os.path.join(mod_root, 'main.lua')

    # Find all Lua files
    lua_files = find_lua_files(mod_root)
    src_count = len(lua_files)

    print("==========================================")
    print(" find_unused_code — Inventory Scanner")
    print(f" Root:  {mod_root}")
    print(f" Files: {src_count} Lua files")
    print("==========================================")

    # =============================================
    # PHASE 1: BUILD INVENTORY
    # =============================================
    print()
    print("== PHASE 1: Building inventory ==")
    print()

    classes = build_class_inventory(lua_files, mod_root)
    print(f"  Classes/globals found: {len(classes)}")

    functions = build_function_inventory(lua_files, mod_root)
    print(f"  Functions found: {len(functions)}")

    source_entries = build_source_inventory(main_lua)
    print(f"  source()'d files: {len(source_entries)}")

    src_files = build_src_file_inventory(mod_root)
    print(f"  Lua files in src/: {len(src_files)}")

    src_dirs = build_src_dir_inventory(mod_root)

    globals_list = build_global_inventory(lua_files, mod_root)

    print()
    print("== Inventory Summary ==")
    print(f"  {len(classes)} classes/globals")
    print(f"  {len(functions)} functions")
    print(f"  {len(source_entries)} source() entries")
    print(f"  {len(src_files)} files in src/")

    # =============================================
    # PHASE 2: CHECK REFERENCES
    # =============================================
    print()
    print("== PHASE 2: Checking references ==")
    print()

    # Load all file contents for fast substring search
    contents = load_all_contents(lua_files)

    total_issues = 0

    # --- 2a: Unused Classes ---
    print(f"[CLASSES] Checking {len(classes)} classes for external references...")
    print("---")
    unused_classes = check_unused_classes(classes, contents, lua_files)
    for cls in unused_classes:
        print(f"  UNUSED CLASS: '{cls.name}' defined at {cls.location}")
        print(f"    -> Never referenced in any other file")
        total_issues += 1
    print()

    # --- 2b: Unused Functions ---
    print(f"[FUNCTIONS] Checking {len(functions)} functions for references...")
    print("---")
    unused_funcs = check_unused_functions(functions, contents, lua_files)
    for func in unused_funcs:
        print(f"  {func['status']}: {func['location']} — {func['name']}")
        print(f"    -> {func['detail']}")
        total_issues += 1
    print()

    # --- 2c: Missing source() targets ---
    print("[SOURCE FILES] Checking source() targets exist...")
    print("---")
    missing_sources = check_missing_sources(source_entries, mod_root)
    for rel_path in missing_sources:
        print(f"  MISSING: source('{rel_path}') — file does not exist")
        total_issues += 1
    print()

    # --- 2d: Orphaned files ---
    print("[ORPHAN FILES] Lua files in src/ not loaded by source()...")
    print("---")
    orphan_files = check_orphan_files(src_files, source_entries)
    for rel in orphan_files:
        print(f"  ORPHAN: {rel} — exists but not source()'d in main.lua")
        total_issues += 1
    print()

    # --- 2e: Empty directories ---
    print("[EMPTY DIRS] Checking for empty directories in src/...")
    print("---")
    empty_dirs = check_empty_dirs(src_dirs, mod_root)
    for rel_dir in empty_dirs:
        print(f"  EMPTY: {rel_dir} — no files or subdirectories")
        total_issues += 1
    print()

    # --- 2f: Unused globals ---
    print("[GLOBALS] Checking g_* globals for external references...")
    print("---")
    unused_globals = check_unused_globals(globals_list, contents, lua_files)
    for g in unused_globals:
        print(f"  UNUSED: {g.rel_path}:{g.lineno} defines '{g.name}' — never referenced elsewhere")
        total_issues += 1
    print()

    # =============================================
    # PHASE 3: SUMMARY
    # =============================================
    print("==========================================")
    print(" INVENTORY")
    print(f"   {len(classes)} classes/globals")
    print(f"   {len(functions)} functions")
    print(f"   {len(source_entries)} source() entries")
    print(f"   {len(src_files)} files in src/")
    print()
    print(f" ISSUES: {total_issues} potential problems found")
    print()
    print(" Notes:")
    print("   - FILE-LOCAL functions may be intentional (internal helpers)")
    print("   - DEAD functions are defined once and never called anywhere")
    print("   - ORPHAN files exist on disk but are never loaded")
    print("   - Review each result; some may be engine callbacks or future code")
    print("==========================================")


if __name__ == '__main__':
    main()
