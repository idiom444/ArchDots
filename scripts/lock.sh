#!/usr/bin/env bash
set -euo pipefail

EXCLUDE="${EXCLUDE_MONITOR:-eDP-1}"   # internal panel to keep on
DELAY="${LOCK_DELAY:-0.25}"          # seconds; allow hyprlock surfaces to appear

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 1; }; }
need hyprctl
need hyprlock

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
LOCKFILE="$RUNTIME_DIR/hyprlock-dpms.lock"
STATEFILE="$RUNTIME_DIR/hyprlock-dpms.state"

# Prevent concurrent runs (e.g. multiple lock triggers)
exec 9>"$LOCKFILE"
if command -v flock >/dev/null 2>&1; then
  flock -n 9 || exit 0
fi 

get_external_monitors() {
  # Prefer JSON output if jq exists
  if command -v jq >/dev/null 2>&1; then
    # We treat monitors with .disabled == true as not usable.
    # Some versions expose different fields; this keeps it tolerant.
    hyprctl -j monitors 2>/dev/null | jq -r --arg ex "$EXCLUDE" '
      .[]?
      | select((.name? // "") != $ex)
      | select((.disabled? // false) == false)
      | .name? // empty
    ' | sort -u
    return 0
  fi

  # Fallback: parse text output. This isn’t perfect but usually works.
  hyprctl monitors 2>/dev/null \
    | awk '/^Monitor /{print $2}' \
    | grep -vx "$EXCLUDE" \
    | sort -u
}

dpms_off_list() {
  local mons=("$@")
  : > "$STATEFILE"
  for m in "${mons[@]}"; do
    # Record what we attempted to power off so we can restore it.
    echo "$m" >> "$STATEFILE"
    hyprctl dispatch dpms off "$m" >/dev/null 2>&1 || true
  done
}

dpms_on_from_state() {
  [[ -f "$STATEFILE" ]] || return 0
  while IFS= read -r m; do
    [[ -n "$m" ]] || continue
    hyprctl dispatch dpms on "$m" >/dev/null 2>&1 || true
  done < "$STATEFILE"
  rm -f "$STATEFILE" || true
}

cleanup() {
  # Always restore DPMS on exit
  dpms_on_from_state
}
trap cleanup EXIT INT TERM HUP

# Gather external monitors now (before DPMS changes)
mapfile -t EXTERNALS < <(get_external_monitors)

# Start hyprlock if not already running
if ! pgrep -x hyprlock >/dev/null 2>&1; then
  hyprlock &
fi

# Give hyprlock a moment to create surfaces, then DPMS off externals
sleep "$DELAY"
if ((${#EXTERNALS[@]})); then
  dpms_off_list "${EXTERNALS[@]}"
fi

# Wait until hyprlock is gone (unlock)
# (Works even if we didn’t start it as a child)
while pgrep -x hyprlock >/dev/null 2>&1; do
  sleep 0.2
done

# Unlock happened -> restore DPMS
dpms_on_from_state

