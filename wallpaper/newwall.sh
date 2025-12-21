#!/bin/bash
set -euo pipefail

export PATH="/usr/local/bin:/usr/bin:/bin:${PATH:-}"

#DIR VARS
WALL_DIR="${WALL_DIR_ENV:?WALL_DIR_ENV is not set}"
WALL_STATE_DIR="${WALL_STATE_DIR_ENV:?WALL_STATE_DIR_ENV is not set}"
MATUGEN_SCRIPT="${WALL_STATE_DIR}/mutagenwallscript.sh"
BAG_FILE="${WALL_STATE_DIR}/wallbag.txt"
WALL_PATH_FILE="${WALL_STATE_DIR}/wallpath.txt"

#WALL VARS
fitMode="cover"

mkdir -p "$WALL_STATE_DIR"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: required command not found: $1" >&2
    exit 127
  }
}     
need_cmd hyprctl
need_cmd matugen
need_cmd shuf
need_cmd rg
need_cmd find
need_cmd hyprpaper
need_cmd jq

hyprctl monitors >/dev/null 2>&1 || exit 0

[[ -d "$WALL_DIR" ]] || { echo "WALL_DIR does not exist: $WALL_DIR" >&2; exit 1; }

refill_bag() {
  # Regenerate and shuffle the full set
  find "$WALL_DIR" -type f -print \
    | rg -i '\.(png|jpe?g|webp|jxl)$' \
    | shuf > "$BAG_FILE.tmp"

    [[ -s "$BAG_FILE.tmp" ]] || { echo "No wallpapers found in $WALL_DIR" >&2; rm -f "$BAG_FILE.tmp"; exit 1; }

  mv -f "$BAG_FILE.tmp" "$BAG_FILE"
}

if [[ ! -s "$BAG_FILE" ]]; then
  refill_bag
fi

selected="$(head -n 1 "$BAG_FILE")"

tail -n +2 "$BAG_FILE" > "$BAG_FILE.tmp" || true
mv -f "$BAG_FILE.tmp" "$BAG_FILE"

[[ -n "$selected" ]] || { echo "Failed to select wallpaper" >&2; exit 1; }

while IFS= read -r mon; do
  hyprctl hyprpaper wallpaper "$mon,$selected,$fitMode"
done < <(hyprctl monitors -j | jq -r '.[].name')

printf '%s\n' "$selected" > "$WALL_PATH_FILE.tmp"
mv -f "$WALL_PATH_FILE.tmp" "$WALL_PATH_FILE"

[[ -f "$MATUGEN_SCRIPT" ]] || { echo "Missing matugen script: $MATUGEN_SCRIPT" >&2; exit 1; }

bash "$MATUGEN_SCRIPT"
