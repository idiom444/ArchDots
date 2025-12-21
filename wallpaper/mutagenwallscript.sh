#!/usr/bin/env bash
set -euo pipefail

export PATH="/usr/local/bin:/usr/bin:/bin:${PATH:-}"

WALLPAPER_FILE="${1:-$HOME/.config/wallpaper/wallpath.txt}"
OUT_DIR="$HOME/.config/wallpaper"
OUT="$OUT_DIR/material.json"
TMP="$OUT_DIR/material.json.tmp"
MATUGEN_TYPE="${MATUGEN_TYPE:-scheme-tonal-spot}"
MATUGEN_CONTRAST="${MATUGEN_CONTRAST:--0.25}"

mkdir -p "$OUT_DIR"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: required command not found: $1" >&2
    exit 127
  }
}
need_cmd matugen
need_cmd jq

wp="$(head -n 1 "$WALLPAPER_FILE")"
[[ -n "$wp" && -f "$wp" ]] || exit 0

matugen image "$wp" --json hex --type "$MATUGEN_TYPE" --contrast "$MATUGEN_CONTRAST" > "$TMP"

mode="dark"
is_dark_mode=true

jq --arg mode "$mode" --argjson is_dark_mode "$is_dark_mode" \
  '.mode=$mode | .is_dark_mode=$is_dark_mode' \
  "$TMP" > "$TMP.mode"

mv -f "$TMP.mode" "$OUT"

SYNC_SCRIPT="$OUT_DIR/zen-userchrome-sync.sh"
if [[ -x "$SYNC_SCRIPT" ]]; then
  "$SYNC_SCRIPT" "$OUT"
else
  echo "Warning: missing or non-executable sync script: $SYNC_SCRIPT" >&2
fi

KITTY_SCRIPT="$OUT_DIR/kitty-theme-sync.sh"
if [[ -x "$KITTY_SCRIPT" ]]; then
  KITTY_BIN_ENV="/usr/bin/kitty" "$KITTY_SCRIPT" "$OUT"
else
  echo "Warning: missing or non-executable sync script: $KITTY_SCRIPT" >&2
fi

SPICETIFY_SCRIPT="$OUT_DIR/spicetify-theme-sync.sh"
if [[ -x "$SPICETIFY_SCRIPT" ]]; then
  "$SPICETIFY_SCRIPT" "$OUT"
else
  echo "Warning: missing or non-executable sync script: $SPICETIFY_SCRIPT" >&2
fi

VSCODE_SCRIPT="$OUT_DIR/vscode-theme-sync.sh"
if [[ -x "$VSCODE_SCRIPT" ]]; then
  "$VSCODE_SCRIPT" "$OUT"
else
  echo "Warning: missing or non-executable sync script: $VSCODE_SCRIPT" >&2
fi
