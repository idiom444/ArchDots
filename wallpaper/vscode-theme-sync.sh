#!/usr/bin/env bash
set -euo pipefail

MATERIAL_PATH="${1:-${MATERIAL_PATH_ENV:-$HOME/.config/wallpaper/material.json}}"
SETTINGS_PATH="${VSCODE_SETTINGS_PATH_ENV:-$HOME/.config/Code/User/settings.json}"

if [[ ! -f "$MATERIAL_PATH" ]]; then
  echo "Material file not found: $MATERIAL_PATH" >&2
  exit 1
fi

python - "$MATERIAL_PATH" "$SETTINGS_PATH" <<'PY'
import json
import sys
from pathlib import Path

material_path = Path(sys.argv[1])
settings_path = Path(sys.argv[2])

data = json.loads(material_path.read_text())
colors = data.get("colors", {})
is_dark = bool(data.get("is_dark_mode")) or data.get("mode") == "dark"

def pick(role, fallback):
    bucket = colors.get(role, {})
    if isinstance(bucket, dict):
        value = bucket.get("dark" if is_dark else "light")
        return value or fallback
    return fallback

def with_alpha(value, alpha_hex):
    if not isinstance(value, str) or not value.startswith("#"):
        return value
    hex_part = value.lstrip("#")
    if len(hex_part) != 6:
        return value
    return f"#{hex_part}{alpha_hex}"

background = pick("surface_dim", "#1b1b1f")
background_alt = pick("surface_container", "#222225")
background_low = pick("surface_container_low", "#1e1e22")
background_high = pick("surface_container_high", "#2a2a2e")
background_variant = pick("surface_variant", "#2b2b2f")
foreground = pick("on_surface", "#e3e3e7")
foreground_muted = pick("on_surface_variant", "#b5b5bb")
accent = pick("primary", "#8ab4f8")
accent_fg = pick("on_primary", "#0b0d12")
accent_container = pick("primary_container", "#2d3b55")
accent_container_fg = pick("on_primary_container", "#d7e3ff")
secondary = pick("secondary", "#a8c7fa")
tertiary = pick("tertiary", "#c58af9")
error = pick("error", "#ff6b6b")
outline = pick("outline", "#7f838a")
outline_variant = pick("outline_variant", "#6b6f76")

selection_bg = with_alpha(accent_container, "66")
selection_bg_inactive = with_alpha(accent_container, "33")

color_customizations = {
    "focusBorder": accent,
    "foreground": foreground,
    "disabledForeground": foreground_muted,
    "descriptionForeground": foreground_muted,

    "editor.background": background,
    "editor.foreground": foreground,
    "editorLineNumber.foreground": outline_variant,
    "editorLineNumber.activeForeground": foreground,
    "editorCursor.foreground": accent,
    "editor.selectionBackground": selection_bg,
    "editor.inactiveSelectionBackground": selection_bg_inactive,
    "editor.selectionHighlightBackground": selection_bg_inactive,
    "editorIndentGuide.background1": background_variant,
    "editorIndentGuide.activeBackground1": outline_variant,
    "editorWidget.background": background_alt,
    "editorWidget.border": background_variant,
    "editorSuggestWidget.background": background_alt,
    "editorSuggestWidget.border": background_variant,
    "editorSuggestWidget.selectedBackground": selection_bg,

    "sideBar.background": background_low,
    "sideBar.foreground": foreground,
    "sideBar.border": background_variant,
    "sideBarTitle.foreground": foreground,
    "sideBarSectionHeader.background": background,
    "sideBarSectionHeader.foreground": foreground,

    "activityBar.background": background,
    "activityBar.foreground": accent,
    "activityBar.inactiveForeground": foreground_muted,
    "activityBar.border": background_variant,
    "activityBarBadge.background": accent,
    "activityBarBadge.foreground": accent_fg,

    "statusBar.background": background,
    "statusBar.foreground": foreground,
    "statusBar.border": background_variant,
    "statusBarItem.remoteBackground": background_high,
    "statusBarItem.remoteForeground": foreground,

    "titleBar.activeBackground": background,
    "titleBar.activeForeground": foreground,
    "titleBar.inactiveBackground": background_variant,
    "titleBar.inactiveForeground": foreground_muted,

    "tab.activeBackground": background_alt,
    "tab.inactiveBackground": background,
    "tab.activeForeground": foreground,
    "tab.inactiveForeground": foreground_muted,
    "tab.border": background_variant,

    "panel.background": background_low,
    "panel.border": background_variant,
    "panelTitle.activeForeground": foreground,
    "panelTitle.inactiveForeground": foreground_muted,

    "terminal.background": background,
    "terminal.foreground": foreground,
    "terminalCursor.foreground": accent,
    "terminal.selectionBackground": selection_bg,
    "terminal.ansiBlack": background_variant,
    "terminal.ansiBlue": accent,
    "terminal.ansiCyan": accent_container,
    "terminal.ansiGreen": secondary,
    "terminal.ansiMagenta": tertiary,
    "terminal.ansiRed": error,
    "terminal.ansiWhite": foreground,
    "terminal.ansiYellow": tertiary,

    "list.activeSelectionBackground": selection_bg,
    "list.activeSelectionForeground": accent_container_fg,
    "list.inactiveSelectionBackground": selection_bg_inactive,
    "list.inactiveSelectionForeground": foreground,
    "list.hoverBackground": background_variant,
    "list.focusBackground": selection_bg,

    "input.background": background_alt,
    "input.foreground": foreground,
    "input.border": background_variant,
    "dropdown.background": background_alt,
    "dropdown.foreground": foreground,
    "dropdown.border": background_variant,

    "badge.background": accent,
    "badge.foreground": accent_fg,
    "button.background": accent,
    "button.foreground": accent_fg,
    "button.hoverBackground": accent,

    "notification.background": background_alt,
    "notification.foreground": foreground,
    "notificationToast.border": background_variant,
}

settings = {}
if settings_path.exists():
    settings = json.loads(settings_path.read_text())

settings["settingsSync.enabled"] = False
settings["workbench.colorTheme"] = "Default Dark+"
settings["workbench.iconTheme"] = None

existing_customizations = settings.get("workbench.colorCustomizations")
if not isinstance(existing_customizations, dict):
    existing_customizations = {}
existing_customizations.update(color_customizations)
settings["workbench.colorCustomizations"] = existing_customizations

settings_path.parent.mkdir(parents=True, exist_ok=True)
settings_path.write_text(json.dumps(settings, indent=4, sort_keys=False) + "\n")
PY

echo "Updated VS Code theme settings: $SETTINGS_PATH"
