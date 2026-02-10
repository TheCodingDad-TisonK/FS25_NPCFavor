#!/usr/bin/env bash
# =============================================================================
# FS25_NPCFavor — Cross-Platform Build & Deploy
# =============================================================================
#
# Creates a properly structured FS25_NPCFavor.zip ready for Farming Simulator 25.
# The zip contains mod files at the root (no wrapper folder), exactly as FS25 expects.
#
# Supports:
#   Windows  — Git Bash + PowerShell .NET ZipFile API (no third-party tools)
#   macOS    — Native zip command
#   Linux    — Native zip command
#
# Usage:
#   ./build.sh              Build zip in the repo root directory
#   ./build.sh --deploy     Build zip and copy it to the FS25 mods folder
#   ./build.sh -d           Short form of --deploy
#
# Deploy auto-detects the FS25 mods folder by checking common locations:
#   Windows:  %USERPROFILE%\Documents\My Games\FarmingSimulator2025\mods
#             %USERPROFILE%\OneDrive\Documents\My Games\FarmingSimulator2025\mods
#   macOS:    ~/Library/Application Support/FarmingSimulator2025/mods
#   Linux:    ~/.local/share/FarmingSimulator2025/mods
#
# Override auto-detection with:
#   export FS25_MODS_DIR="/your/custom/path/mods"
#   ./build.sh --deploy
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZIP_NAME="FS25_NPCFavor.zip"
OUTPUT="$SCRIPT_DIR/$ZIP_NAME"
DEPLOY=false

# ---- Parse arguments --------------------------------------------------------

for arg in "$@"; do
    case "$arg" in
        --deploy|-d) DEPLOY=true ;;
        *)
            echo "Unknown option: $arg"
            echo "Usage: ./build.sh [--deploy]"
            exit 1
            ;;
    esac
done

# ---- Detect OS --------------------------------------------------------------

IS_WINDOWS=false
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) IS_WINDOWS=true ;;
esac

# ---- Build ------------------------------------------------------------------
# Files excluded from the zip (dev-only, not part of the mod):
#   Directories: .git, .claude, .vscode, .idea, node_modules
#   Files:       build.sh, find_unused_code.sh, CLAUDE.md, .gitignore, nul
#   Extensions:  .zip, .swp, .swo
#   OS junk:     Thumbs.db, .DS_Store

rm -f "$OUTPUT"
cd "$SCRIPT_DIR"

if [ "$IS_WINDOWS" = true ]; then
    # PowerShell + .NET System.IO.Compression (ships with every Win10/11).
    # We use the .NET ZipFile API directly because PowerShell's Compress-Archive
    # cmdlet flattens directory structure — which breaks the mod.
    WIN_SCRIPT_DIR=$(cygpath -w "$SCRIPT_DIR")
    WIN_OUTPUT=$(cygpath -w "$OUTPUT")

    powershell.exe -NoProfile -Command "
        \$ErrorActionPreference = 'Stop'
        Add-Type -AssemblyName System.IO.Compression
        Add-Type -AssemblyName System.IO.Compression.FileSystem

        \$source = '${WIN_SCRIPT_DIR}'
        \$dest   = '${WIN_OUTPUT}'

        # Exclusion lists — keep in sync with the zip command below
        \$excludeDirs  = @('.git', '.claude', '.vscode', '.idea', 'node_modules')
        \$excludeFiles = @('build.sh', 'find_unused_code.sh', 'CLAUDE.md',
                           'Thumbs.db', '.DS_Store', '.gitignore', 'nul')
        \$excludeExts  = @('.zip', '.swp', '.swo')

        # Gather files, applying exclusions
        \$files = Get-ChildItem -Path \$source -Recurse -File | Where-Object {
            \$rel   = \$_.FullName.Substring(\$source.Length + 1)
            \$parts = \$rel -split '[/\\\\]'
            \$skip  = \$false
            foreach (\$d in \$excludeDirs) {
                if (\$parts[0] -eq \$d) { \$skip = \$true; break }
            }
            if (-not \$skip -and \$_.Name -in \$excludeFiles) { \$skip = \$true }
            if (-not \$skip) {
                foreach (\$ext in \$excludeExts) {
                    if (\$_.Extension -eq \$ext) { \$skip = \$true; break }
                }
            }
            -not \$skip
        }

        if (\$files.Count -eq 0) {
            Write-Error 'No files found to archive'
            exit 1
        }

        # Create zip with correct relative paths (no wrapper folder)
        \$zip = [System.IO.Compression.ZipFile]::Open(
            \$dest, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            foreach (\$f in \$files) {
                \$rel = \$f.FullName.Substring(\$source.Length + 1) -replace '\\\\', '/'
                [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                    \$zip, \$f.FullName, \$rel,
                    [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
            }
        } finally {
            \$zip.Dispose()
        }
    "
else
    # macOS / Linux — the zip command preserves directory structure natively.
    if ! command -v zip &> /dev/null; then
        echo "ERROR: 'zip' command not found."
        echo "  macOS:  brew install zip    (or xcode-select --install)"
        echo "  Linux:  sudo apt install zip"
        exit 1
    fi

    # Exclusion list — keep in sync with the PowerShell exclusions above
    zip -r "$OUTPUT" . \
        -x ".git/*"            \
        -x ".git*"             \
        -x ".claude/*"         \
        -x ".vscode/*"         \
        -x ".idea/*"           \
        -x "node_modules/*"    \
        -x "*.zip"             \
        -x "build.sh"          \
        -x "find_unused_code.sh" \
        -x "CLAUDE.md"         \
        -x "*.swp"             \
        -x "*.swo"             \
        -x "*~"                \
        -x "Thumbs.db"         \
        -x ".DS_Store"         \
        -x "nul"
fi

# ---- Verify -----------------------------------------------------------------

if [ ! -f "$OUTPUT" ]; then
    echo "ERROR: zip not created"
    exit 1
fi

SIZE=$(wc -c < "$OUTPUT" | tr -d ' ')
echo "Built: $ZIP_NAME ($SIZE bytes)"

# ---- Deploy (optional) ------------------------------------------------------

if [ "$DEPLOY" = true ]; then
    # Auto-detect FS25 mods folder if not set via environment variable
    if [ -z "$FS25_MODS_DIR" ]; then
        if [ "$IS_WINDOWS" = true ]; then
            WIN_HOME=$(cmd.exe //c "echo %USERPROFILE%" 2>/dev/null | tr -d '\r')
            for p in \
                "$WIN_HOME/OneDrive/Documents/My Games/FarmingSimulator2025/mods" \
                "$WIN_HOME/Documents/My Games/FarmingSimulator2025/mods" \
                "$WIN_HOME/My Documents/My Games/FarmingSimulator2025/mods"; do
                [ -d "$p" ] && FS25_MODS_DIR="$p" && break
            done
        else
            for p in \
                "$HOME/Library/Application Support/FarmingSimulator2025/mods" \
                "$HOME/Library/Containers/com.focus-home.farmingsimulator2025/Data/Documents/FarmingSimulator2025/mods" \
                "$HOME/.local/share/FarmingSimulator2025/mods" \
                "$HOME/Documents/My Games/FarmingSimulator2025/mods"; do
                [ -d "$p" ] && FS25_MODS_DIR="$p" && break
            done
        fi
    fi

    if [ -z "$FS25_MODS_DIR" ] || [ ! -d "$FS25_MODS_DIR" ]; then
        echo "WARNING: FS25 mods folder not found at any standard location."
        echo ""
        echo "  Set it manually and re-run:"
        echo "    export FS25_MODS_DIR=\"/path/to/FarmingSimulator2025/mods\""
        echo "    ./build.sh --deploy"
        exit 1
    fi

    cp "$OUTPUT" "$FS25_MODS_DIR/$ZIP_NAME"
    echo "Deployed: $FS25_MODS_DIR/$ZIP_NAME"
fi
