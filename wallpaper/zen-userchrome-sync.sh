#!/usr/bin/env bash
set -euo pipefail

AUTOCONFIG_ONLY=false
if [[ "${1:-}" == "--autoconfig-only" ]]; then
  AUTOCONFIG_ONLY=true
  shift
fi
if [[ "${ZEN_AUTOCONFIG_ONLY:-0}" == "1" || "${ZEN_AUTOCONFIG_ONLY:-}" == "true" ]]; then
  AUTOCONFIG_ONLY=true
fi

MATERIAL_PATH="${1:-${MATERIAL_PATH_ENV:-$HOME/.config/wallpaper/material.json}}"
ZEN_PROFILE_DIR="${ZEN_PROFILE_DIR_ENV:-${ZEN_PROFILE_DIR:-}}"
USERCHROME_PATH="${USERCHROME_PATH_ENV:-}"
ZEN_INSTALL_DIR="${ZEN_INSTALL_DIR_ENV:-${ZEN_INSTALL_DIR:-/opt/zen-browser-bin}}"
ZEN_AUTOCONFIG_INSTALL="${ZEN_AUTOCONFIG_INSTALL:-1}"

BEGIN_MARKER="/* BEGIN QUICKSHELL THEME SYNC */"
END_MARKER="/* END QUICKSHELL THEME SYNC */"
AUTOCONFIG_MARKER="Quickshell theme sync autoconfig"
AUTOCONFIG_PREF_PATH="$ZEN_INSTALL_DIR/defaults/pref/zen-quickshell-autoconfig.js"
AUTOCONFIG_CFG_PATH="$ZEN_INSTALL_DIR/zen-quickshell.cfg"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: required command not found: $1" >&2
    exit 127
  }
}

ensure_autoconfig_installed() {
  if [[ "$ZEN_AUTOCONFIG_INSTALL" == "0" || "$ZEN_AUTOCONFIG_INSTALL" == "false" ]]; then
    return 0
  fi

  if [[ ! -d "$ZEN_INSTALL_DIR" ]]; then
    echo "Warning: Zen install dir not found; skipping autoconfig install: $ZEN_INSTALL_DIR" >&2
    return 0
  fi

  local pref_dir
  pref_dir="$(dirname "$AUTOCONFIG_PREF_PATH")"

  local other_autoconfig=""
  shopt -s nullglob
  for f in "$pref_dir"/*.js; do
    [[ -f "$f" ]] || continue
    if grep -q "general.config.filename" "$f"; then
      if [[ "$f" != "$AUTOCONFIG_PREF_PATH" ]]; then
        other_autoconfig="$f"
        break
      fi
    fi
  done
  shopt -u nullglob

  if [[ -n "$other_autoconfig" ]]; then
    echo "Warning: existing autoconfig pref detected ($other_autoconfig); skipping auto-install." >&2
    return 0
  fi

  local manage_pref="true"
  local manage_cfg="true"
  if [[ -f "$AUTOCONFIG_PREF_PATH" ]] && ! grep -q "$AUTOCONFIG_MARKER" "$AUTOCONFIG_PREF_PATH"; then
    echo "Warning: autoconfig pref exists but is not managed by Quickshell; skipping install." >&2
    manage_pref="false"
  fi
  if [[ -f "$AUTOCONFIG_CFG_PATH" ]] && ! grep -q "$AUTOCONFIG_MARKER" "$AUTOCONFIG_CFG_PATH"; then
    echo "Warning: autoconfig cfg exists but is not managed by Quickshell; skipping install." >&2
    manage_cfg="false"
  fi

  if [[ ! -w "$ZEN_INSTALL_DIR" || ! -w "$pref_dir" ]]; then
    echo "Warning: insufficient permissions to install autoconfig. Run with sudo." >&2
    return 0
  fi

  if [[ "$manage_pref" == "true" ]]; then
    cat > "$AUTOCONFIG_PREF_PATH" <<'PREFS'
/* Quickshell theme sync autoconfig */
pref("general.config.obscure_value", 0);
pref("general.config.filename", "zen-quickshell.cfg");
pref("general.config.sandbox_enabled", false);
PREFS
  fi

  if [[ "$manage_cfg" == "true" ]]; then
    cat > "$AUTOCONFIG_CFG_PATH" <<'CFG'
// Quickshell theme sync autoconfig
try {
  var { classes: Cc, interfaces: Ci, utils: Cu } = Components;
  var consoleSvc = Cc["@mozilla.org/consoleservice;1"].getService(Ci.nsIConsoleService);
  var prefs = Cc["@mozilla.org/preferences-service;1"].getService(Ci.nsIPrefBranch);
  var obs = Cc["@mozilla.org/observer-service;1"].getService(Ci.nsIObserverService);
  var dirsvc = Cc["@mozilla.org/file/directory_service;1"].getService(Ci.nsIProperties);
  var io = Cc["@mozilla.org/network/io-service;1"].getService(Ci.nsIIOService);
  var sss = Cc["@mozilla.org/content/style-sheet-service;1"].getService(Ci.nsIStyleSheetService);
  var sssAgent = Cc["@mozilla.org/content/style-sheet-service;1"].getService(Ci.nsIStyleSheetService);
  var zenQuickshellTimer = null;

  function log(msg) {
    try {
      consoleSvc.logStringMessage("Quickshell theme sync: " + msg);
    } catch (e) {}
  }

  function startWatcher() {
    var file = dirsvc.get("ProfD", Ci.nsIFile);
    file.append("chrome");
    file.append("userChrome.css");
    var uri = io.newFileURI(file);
    var lastMtime = 0;

    function reloadSheet() {
      try {
        if (sss.sheetRegistered(uri, sss.USER_SHEET)) {
          sss.unregisterSheet(uri, sss.USER_SHEET);
        }
        if (sss.sheetRegistered(uri, sss.AGENT_SHEET)) {
          sss.unregisterSheet(uri, sss.AGENT_SHEET);
        }
        sss.loadAndRegisterSheet(uri, sss.USER_SHEET);
        sss.loadAndRegisterSheet(uri, sss.AGENT_SHEET);
        log("reloaded " + file.path);
      } catch (e) {
        try { Cu.reportError(e); } catch (err) {}
      }
    }

    function check() {
      try {
        if (!file.exists()) {
          return;
        }
        var mtime = file.lastModifiedTime;
        if (mtime !== lastMtime) {
          lastMtime = mtime;
          reloadSheet();
        }
      } catch (e) {
        try { Cu.reportError(e); } catch (err) {}
      }
    }

    zenQuickshellTimer = Cc["@mozilla.org/timer;1"].createInstance(Ci.nsITimer);
    zenQuickshellTimer.initWithCallback(check, 750, Ci.nsITimer.TYPE_REPEATING_SLACK);
    check();
    log("watching " + file.path);
  }

  obs.addObserver({
    observe: function(subject, topic) {
      obs.removeObserver(this, topic);
      try {
        prefs.setBoolPref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
      } catch (e) {}
      startWatcher();
    }
  }, "final-ui-startup");
} catch (e) {
  try { Components.utils.reportError(e); } catch (err) {}
}
CFG
  fi
}

ensure_autoconfig_installed

if [[ "$AUTOCONFIG_ONLY" == "true" ]]; then
  exit 0
fi

need_cmd jq
need_cmd awk

if [[ ! -f "$MATERIAL_PATH" ]]; then
  echo "Material file not found: $MATERIAL_PATH" >&2
  exit 1
fi

trim() {
  local value="$1"
  value="${value#${value%%[![:space:]]*}}"
  value="${value%${value##*[![:space:]]}}"
  printf '%s' "$value"
}

resolve_profile_dir() {
  if [[ -n "$ZEN_PROFILE_DIR" ]]; then
    if [[ -d "$ZEN_PROFILE_DIR" ]]; then
      printf '%s' "$ZEN_PROFILE_DIR"
      return 0
    fi
    echo "Zen profile directory not found: $ZEN_PROFILE_DIR" >&2
    return 1
  fi

  local profiles_ini="$HOME/.zen/profiles.ini"
  [[ -f "$profiles_ini" ]] || { echo "Missing profiles.ini at $profiles_ini" >&2; return 1; }

  local install_default
  install_default=$(awk -F= '
    BEGIN { in_section = 0 }
    /^\[Install/ { in_section = 1; next }
    /^\[/ { in_section = 0; next }
    in_section && $1 == "Default" { print $2; exit }
  ' "$profiles_ini")

  install_default="$(trim "$install_default")"
  if [[ -n "$install_default" ]]; then
    local candidate="$HOME/.zen/$install_default"
    if [[ -d "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  fi

  local profile_spec
  profile_spec=$(awk -F= '
    function trim(v) { gsub(/^[ \t]+|[ \t]+$/, "", v); return v }
    BEGIN { in_section = 0; path = ""; isrel = "1"; def = "0" }
    /^\[Profile/ {
      if (in_section && def == "1" && path != "") {
        print (isrel == "1" ? "REL:" path : "ABS:" path); exit
      }
      in_section = 1; path = ""; isrel = "1"; def = "0"; next
    }
    /^\[/ {
      if (in_section && def == "1" && path != "") {
        print (isrel == "1" ? "REL:" path : "ABS:" path); exit
      }
      in_section = 0; next
    }
    in_section && $1 == "Path" { path = trim($2); next }
    in_section && $1 == "IsRelative" { isrel = trim($2); next }
    in_section && $1 == "Default" { def = trim($2); next }
    END {
      if (in_section && def == "1" && path != "") {
        print (isrel == "1" ? "REL:" path : "ABS:" path)
      }
    }
  ' "$profiles_ini")

  if [[ "$profile_spec" == REL:* ]]; then
    printf '%s' "$HOME/.zen/${profile_spec#REL:}"
    return 0
  fi

  if [[ "$profile_spec" == ABS:* ]]; then
    printf '%s' "${profile_spec#ABS:}"
    return 0
  fi

  echo "Unable to locate Zen profile directory" >&2
  return 1
}

hex_to_rgba() {
  local color="$1"
  local alpha="$2"
  local hex="${color#\#}"

  case ${#hex} in
    3)
      hex="${hex:0:1}${hex:0:1}${hex:1:1}${hex:1:1}${hex:2:1}${hex:2:1}"
      ;;
    4)
      hex="${hex:0:1}${hex:0:1}${hex:1:1}${hex:1:1}${hex:2:1}${hex:2:1}${hex:3:1}${hex:3:1}"
      ;;
  esac

  if [[ ${#hex} -ne 6 && ${#hex} -ne 8 ]]; then
    printf '%s' "$color"
    return
  fi

  local r=$((16#${hex:0:2}))
  local g=$((16#${hex:2:2}))
  local b=$((16#${hex:4:2}))
  local base_alpha="1"
  if [[ ${#hex} -eq 8 ]]; then
    base_alpha=$((16#${hex:6:2}))
  fi

  local final_alpha
  if [[ ${#hex} -eq 8 ]]; then
    final_alpha=$(awk -v a="$base_alpha" -v b="$alpha" 'BEGIN { v=(a/255.0)*b; if (v<0) v=0; if (v>1) v=1; printf "%.3f", v }')
  else
    final_alpha=$(awk -v b="$alpha" 'BEGIN { v=b; if (v<0) v=0; if (v>1) v=1; printf "%.3f", v }')
  fi

  printf 'rgba(%d, %d, %d, %s)' "$r" "$g" "$b" "$final_alpha"
}

use_dark=$(jq -r 'if (.is_dark_mode == true) or (.mode == "dark") then "true" else "false" end' "$MATERIAL_PATH")
color_scheme="light"
if [[ "$use_dark" == "true" ]]; then
  color_scheme="dark"
fi

pick_color() {
  local role="$1"
  local fallback="$2"
  if [[ "$use_dark" == "true" ]]; then
    jq -r --arg role "$role" --arg fallback "$fallback" '.colors[$role].dark // $fallback' "$MATERIAL_PATH"
  else
    jq -r --arg role "$role" --arg fallback "$fallback" '.colors[$role].light // $fallback' "$MATERIAL_PATH"
  fi
}

bg="#201f25"
fg="#e5e1e9"
accent="#c7bfff"
outline="#928f99"

background=$(pick_color background "$bg")
on_background=$(pick_color on_background "$fg")
surface_dim=$(pick_color surface_dim "$bg")
surface_container=$(pick_color surface_container "$bg")
surface_container_low=$(pick_color surface_container_low "$bg")
surface_variant=$(pick_color surface_variant "$bg")
on_surface=$(pick_color on_surface "$fg")
on_surface_variant=$(pick_color on_surface_variant "$fg")
primary=$(pick_color primary "$accent")
on_primary=$(pick_color on_primary "$fg")
primary_container=$(pick_color primary_container "$accent")
on_primary_container=$(pick_color on_primary_container "$fg")
secondary=$(pick_color secondary "$accent")
tertiary=$(pick_color tertiary "$accent")
outline_variant=$(pick_color outline_variant "$outline")
outline_color=$(pick_color outline "$outline")
text_primary="$on_primary_container"
text_secondary="$on_surface_variant"
text_active="$on_primary"

# Keep colors opaque so Hyprland handles transparency/blur.
bar_bg="$surface_dim"
field_bg="$primary_container"
outline_border="$outline_variant"
active_bg="$primary"
hover_bg="$primary_container"
panel_bg="$surface_container"
sidebar_bg="$surface_container_low"
menu_text="$on_primary_container"

css_block=$(cat <<CSS
${BEGIN_MARKER}
#main-window,
:root {
  color-scheme: ${color_scheme} !important;

  --zen-primary-color: ${primary} !important;
  --zen-branding-dark: ${background} !important;
  --zen-branding-paper: ${background} !important;
  --zen-branding-bg: ${background} !important;
  --zen-branding-bg-reverse: ${on_background} !important;

  --zen-colors-primary: ${primary} !important;
  --zen-colors-secondary: ${secondary} !important;
  --zen-colors-tertiary: ${tertiary} !important;
  --zen-colors-hover-bg: ${hover_bg} !important;
  --zen-colors-primary-foreground: ${on_primary} !important;
  --zen-colors-border: ${outline_color} !important;
  --zen-colors-border-contrast: ${outline_variant} !important;
  --zen-colors-input-bg: ${field_bg} !important;

  --zen-dialog-background: ${panel_bg} !important;
  --zen-urlbar-background: ${field_bg} !important;
  --zen-urlbar-background-base: ${field_bg} !important;
  --zen-urlbar-background-transparent: ${field_bg} !important;
  --zen-input-border-color: ${outline_border} !important;

  --zen-main-browser-background: ${bar_bg} !important;
  --zen-main-browser-background-toolbar: ${bar_bg} !important;
  --zen-main-browser-background-old: ${bar_bg} !important;
  --zen-main-browser-background-toolbar-old: ${bar_bg} !important;
  --zen-background-opacity: 1 !important;
  --zen-navigator-toolbox-background: ${bar_bg} !important;
  --zen-themed-toolbar-bg-transparent: ${bar_bg} !important;
  --zen-toolbar-element-bg: ${bar_bg} !important;
  --zen-toolbar-element-bg-hover: ${hover_bg} !important;
  --zen-appcontent-border: 1px solid ${outline_border} !important;

  --toolbar-bgcolor: ${bar_bg} !important;
  --toolbar-color: ${text_primary} !important;
  --toolbox-textcolor: ${text_primary} !important;
  --toolbox-textcolor-inactive: ${text_secondary} !important;

  --toolbarbutton-hover-background: ${hover_bg} !important;
  --toolbarbutton-active-background: ${active_bg} !important;

  --toolbar-field-background-color: ${field_bg} !important;
  --toolbar-field-color: ${on_primary_container} !important;
  --toolbar-field-border-color: ${outline_border} !important;
  --toolbar-field-focus-background-color: ${active_bg} !important;
  --toolbar-field-focus-color: ${on_primary} !important;
  --toolbar-field-focus-border-color: ${outline_border} !important;

  --urlbar-box-hover-bgcolor: ${hover_bg} !important;
  --urlbar-box-active-bgcolor: ${active_bg} !important;
  --input-bgcolor: ${field_bg} !important;
  --input-border-color: ${outline_border} !important;

  --panel-background: ${panel_bg} !important;
  --panel-color: ${on_surface} !important;
  --panel-border-color: ${outline_border} !important;
  --panel-separator-color: ${outline_border} !important;
  --zen-menu-text: ${menu_text} !important;

  --arrowpanel-background: ${panel_bg} !important;
  --arrowpanel-color: ${on_surface} !important;
  --arrowpanel-border-color: ${outline_border} !important;

  --sidebar-background-color: ${sidebar_bg} !important;
  --sidebar-text-color: ${text_primary} !important;
  --sidebar-border-color: ${outline_border} !important;

  --toolbarbutton-icon-fill-attention: ${primary} !important;
  --toolbarbutton-icon-fill: ${on_surface} !important;

  --link-color: ${primary} !important;
  --link-color-hover: ${active_bg} !important;
  --link-color-active: ${active_bg} !important;

  --lwt-accent-color: ${bar_bg} !important;
  --lwt-text-color: ${on_surface} !important;
  --lwt-toolbar-field-background-color: ${field_bg} !important;
  --lwt-toolbar-field-color: ${on_primary_container} !important;
}

/* Core Zen UI overrides using generated variables. */
#navigator-toolbox,
#titlebar,
#nav-bar,
#TabsToolbar,
#PersonalToolbar,
#toolbar-menubar,
#TabsToolbar-customization-target {
  background-color: var(--toolbar-bgcolor) !important;
  color: var(--toolbar-color) !important;
}

#browser,
#appcontent,
#tabbrowser-tabbox {
  background-color: var(--zen-main-browser-background) !important;
}

#tabbrowser-tabs {
  background-color: var(--toolbar-bgcolor) !important;
}

.tabbrowser-tab .tab-background {
  background-color: transparent !important;
}

.tabbrowser-tab:hover .tab-background {
  background-color: var(--toolbarbutton-hover-background) !important;
}

.tabbrowser-tab[selected] .tab-background {
  background-color: var(--toolbar-field-focus-background-color) !important;
  outline: 1px solid var(--toolbar-field-border-color) !important;
}

.tabbrowser-tab[selected] .tab-label,
.tabbrowser-tab:hover .tab-label {
  color: var(--toolbar-field-focus-color) !important;
}

#tabbrowser-tabs .tab-label {
  color: var(--toolbox-textcolor-inactive) !important;
}

#tabbrowser-tabs .tabbrowser-tab[selected] .tab-label,
#tabbrowser-tabs .tabbrowser-tab[selected] .tab-label-container,
#tabbrowser-tabs .tabbrowser-tab[selected] .tab-icon-stack,
#tabbrowser-tabs .tabbrowser-tab[selected] .tab-icon-image,
#tabbrowser-tabs .tabbrowser-tab[selected] .tab-icon-overlay,
#tabbrowser-tabs .tabbrowser-tab[selected] .tab-icon-sound,
#tabbrowser-tabs .tabbrowser-tab[selected] .tab-icon-pending {
  color: var(--toolbar-field-focus-color) !important;
  fill: currentColor !important;
}

#urlbar,
#searchbar,
#urlbar-background,
.urlbar-background {
  appearance: none !important;
  -moz-appearance: none !important;
  background: var(--toolbar-field-background-color) !important;
  background-color: var(--toolbar-field-background-color) !important;
  color: var(--toolbar-field-color) !important;
  border-color: var(--toolbar-field-border-color) !important;
}

#urlbar[focused="true"] #urlbar-background,
#searchbar[focused="true"] {
  background: var(--toolbar-field-focus-background-color) !important;
  background-color: var(--toolbar-field-focus-background-color) !important;
  color: var(--toolbar-field-focus-color) !important;
  border-color: var(--toolbar-field-focus-border-color) !important;
}

#urlbar-input,
#searchbar input,
#urlbar .urlbar-input-box {
  color: var(--toolbar-field-color) !important;
}

.urlbarView,
.urlbarView-body-outer,
.urlbarView-row {
  background-color: var(--panel-background) !important;
  color: var(--panel-color) !important;
}

.urlbarView-row[selected],
.urlbarView-row:hover {
  background-color: var(--urlbar-box-active-bgcolor) !important;
}

.panel-arrowcontainer,
panelview,
.panel-subview-body,
.panel-header,
.panel-footer {
  background-color: var(--panel-background) !important;
  color: var(--panel-color) !important;
  border-color: var(--panel-border-color) !important;
}

menupopup,
menupopup > menuitem,
menupopup > menu {
  background-color: var(--panel-background) !important;
  color: var(--zen-menu-text) !important;
}

#sidebar-box,
#sidebar-header,
#sidebar,
#zen-sidebar-top-buttons,
#zen-sidebar-foot-buttons,
#zen-sidebar-top-buttons-customization-target,
#zen-sidebar-foot-buttons-customization-target,
#tabbrowser-tabs {
  appearance: none !important;
  -moz-appearance: none !important;
  background: var(--sidebar-background-color) !important;
  background-color: var(--sidebar-background-color) !important;
  color: var(--sidebar-text-color) !important;
  border-color: var(--sidebar-border-color) !important;
}

#tabbrowser-tabs .tab-label,
#tabbrowser-tabs .tab-label-container,
#tabbrowser-tabs .tab-icon-stack,
#tabbrowser-tabs .tab-icon-image,
#tabbrowser-tabs .tab-icon-overlay,
#tabbrowser-tabs .tab-icon-sound,
#tabbrowser-tabs .tab-icon-pending,
#zen-sidebar-top-buttons .toolbarbutton-text,
#zen-sidebar-foot-buttons .toolbarbutton-text {
  color: var(--sidebar-text-color) !important;
  fill: currentColor !important;
}

#zen-sidebar-top-buttons .toolbarbutton-icon,
#zen-sidebar-foot-buttons .toolbarbutton-icon,
#zen-sidebar-top-buttons .toolbarbutton-badge-stack,
#zen-sidebar-foot-buttons .toolbarbutton-badge-stack {
  fill: currentColor !important;
}

#TabsToolbar .toolbarbutton-1,
#nav-bar .toolbarbutton-1 {
  color: var(--toolbar-color) !important;
  fill: var(--toolbarbutton-icon-fill) !important;
}

#TabsToolbar .toolbarbutton-1:hover,
#nav-bar .toolbarbutton-1:hover {
  background-color: var(--toolbarbutton-hover-background) !important;
}

#TabsToolbar .toolbarbutton-1:active,
#nav-bar .toolbarbutton-1:active {
  background-color: var(--toolbarbutton-active-background) !important;
}
${END_MARKER}
CSS
)

if [[ -z "$USERCHROME_PATH" ]]; then
  profile_dir=$(resolve_profile_dir)
  USERCHROME_PATH="$profile_dir/chrome/userChrome.css"
fi

userchrome_dir=$(dirname "$USERCHROME_PATH")
mkdir -p "$userchrome_dir"

if [[ -f "$USERCHROME_PATH" ]] && grep -q "$BEGIN_MARKER" "$USERCHROME_PATH"; then
  tmp_file="$USERCHROME_PATH.tmp"
  awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" -v block="$css_block" '
    $0 == begin { print block; inblock = 1; next }
    $0 == end { inblock = 0; next }
    !inblock { print }
  ' "$USERCHROME_PATH" > "$tmp_file"
  mv -f "$tmp_file" "$USERCHROME_PATH"
else
  {
    if [[ -f "$USERCHROME_PATH" ]]; then
      cat "$USERCHROME_PATH"
      printf '\n\n'
    fi
    printf '%s\n' "$css_block"
  } > "$USERCHROME_PATH"
fi

echo "Updated $USERCHROME_PATH"
