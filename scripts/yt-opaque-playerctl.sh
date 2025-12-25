#!/usr/bin/env bash
set -euo pipefail

RULE='yt-opaque'
INTERVAL=0.5

set_rule() {
  hyprctl keyword "windowrule[$RULE]:enable $1" >/dev/null 2>&1 || true
}

get_firefox_player() {
  # pick the first firefox instance name currently available
  playerctl --list-all 2>/dev/null | rg -m1 '^firefox(\.|$)' || true
}

want_on() {
  local p="$1"
  local st url title

  st="$(playerctl --player="$p" status 2>/dev/null || true)"
  [[ "$st" == "Playing" ]] || return 1

  # Optional: restrict to YouTube media only
  url="$(playerctl --player="$p" metadata --format '{{xesam:url}}' 2>/dev/null || true)"
  title="$(playerctl --player="$p" metadata --format '{{title}}' 2>/dev/null || true)"

  [[ "$url" == *"youtube.com"* || "$url" == *"youtu.be"* || "$title" == *"YouTube"* ]]
}

set_rule false
last="false"

while true; do
  cur="false"
  p="$(get_firefox_player)"

  if [[ -n "$p" ]] && want_on "$p"; then
    cur="true"
  fi

  if [[ "$cur" != "$last" ]]; then
    set_rule "$cur"
    last="$cur"
  fi

  sleep "$INTERVAL"
done

