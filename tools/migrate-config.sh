#!/bin/bash

# Script to migrate old configuration files to the new win10 structure
# Created for one-time migration during project reorganization

set -e

echo "Migrating configuration files to win10 structure..."

# Create the new config directory if it doesn't exist
mkdir -p ~/.config/win10
mkdir -p ~/.cache/win10

# Migrate settings file
if [[ -f "~/.config/qs-settings.json" ]]; then
    if [[ ! -f "~/.config/win10/settings.json" ]]; then
        mv ~/.config/qs-settings.json ~/.config/win10/
        echo "✓ Migrated ~/.config/qs-settings.json to ~/.config/win10/settings.json"
    else
        echo "⚠ ~/.config/win10/settings.json already exists, skipping migration"
    fi
fi

# Migrate pomodoro settings
if [[ -f "~/.config/qs-pomodoro.json" ]]; then
    if [[ ! -f "~/.config/win10/settings.json" ]]; then
        echo "ERROR: settings.json not found, creating it before merging pomodoro settings"
        cp ~/.config/qs-pomodoro.json ~/.config/win10/settings.json
        echo "✓ Created settings.json from qs-pomodoro.json"
    else
        # Merge pomodoro settings into existing settings.json
        if command -v jq >/dev el 2>/dev null; then
            jq --argfile a "~/.config/qs-pomodoro.json" --argfile b "~/.config/win10/settings.json" '($a * $b)' > ~/.config/win10/settings.json
            echo "✓ Merged pomodoro settings into settings.json"
        else
            echo "⚠ jq not available, manual merge required for pomodoro settings"
            echo "  Please merge ~/.config/qs-pomodoro.json into ~/.config/win10/settings.json"
        fi
    fi
fi

# Migrate notes file
if [[ -f "~/.cache/qs7/notes.txt" ]]; then
    if [[ ! -f "~/.config/win10/notes.txt" ]]; then
        mv ~/.cache/qs7/notes.txt ~/.config/win10/
        echo "✓ Migrated ~/.cache/qs7/notes.txt to ~/.config/win10/notes.txt"
    else
        echo "⚠ ~/.config/win10/notes.txt already exists, skipping migration"
    fi
fi

# Migrate theme-active.json
if [[ -f "~/.cache/matugen-active.json" ]]; then
    if [[ ! -f "~/.config/win10/theme-active.json" ]]; then
        mv ~/.cache/matugen-active.json ~/.config/win10/
        echo "✓ Migrated ~/.cache/matugen-active.json to ~/.config/win10/theme-active.json"
    else
        echo "⚠ ~/.config/win10/theme-active.json already exists, skipping migration"
    fi
fi

# Migrate theme-md3.json
if [[ -f "~/.cache/qs-matugen-md3.json" ]]; then
    if [[ ! -f "~/.config/win10/theme-md3.json" ]]; then
        mv ~/.cache/qs-matugen-md3.json ~/.config/win10/
        echo "✓ Migrated ~/.cache/qs-matugen-md3.json to ~/.config/win10/theme-md3.json"
    else
        echo "⚠ ~/.config/win10/theme-md3.json already exists, skipping migration"
    fi
fi

# Migrate fileindex and mpd-art caches
if [[ -f "~/.cache/qs-fileindex.txt" ]]; then
    if [[ ! -f "~/.cache/win10/fileindex.txt" ]]; then
        mv ~/.cache/qs-fileindex.txt ~/.cache/win10/
        echo "✓ Migrated ~/.cache/qs-fileindex.txt to ~/.cache/win10/fileindex.txt"
    else
        echo "⚠ ~/.cache/win10/fileindex.txt already exists, skipping migration"
    fi
fi

if [[ -f "~/.cache/qs-mpd-art" ]]; then
    if [[ ! -f "~/.cache/win10/mpd-art" ]]; then
        mv ~/.cache/qs-mpd-art ~/.cache/win10/
        echo "✓ Migrated ~/.cache/qs-mpd-art to ~/.cache/win10/mpd-art"
    else
        echo "⚠ ~/.cache/win10/mpd-art already exists, skipping migration"
    fi
fi

# Migrate labwc-b cache
if [[ -d "~/.cache/labwc-b" ]]; then
    if [[ ! -d "~/.cache/win10" ]]; then
        echo "⚠ ~/.cache/win10 directory does not exist, skipping migration"
    else
        if [[ ! -d "~/.cache/win10/labwc-b" ]]; then
            mv ~/.cache/labwc-b ~/.cache/win10/
            echo "✓ Migrated ~/.cache/labwc-b to ~/.cache/win10/labwc-b"
        else
            echo "⚠ ~/.cache/win10/labwc-b already exists, skipping migration"
        fi
    fi
fi

echo ""
echo "Configuration migration complete!"
echo "Please restart the QuickShell application to ensure all changes are applied."
echo ""
echo "Your win10 configuration is now located in:"
echo "  ~/.config/win10/"
echo "  ~/.cache/win10/"