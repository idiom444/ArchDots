#!/usr/bin/env bash
set -euo pipefail

export PATH="/usr/local/bin:/usr/bin:/bin:${PATH:-}"

MATERIAL_PATH="${1:-${MATERIAL_PATH_ENV:-$HOME/.config/wallpaper/material.json}}"
SPICETIFY_DIR="${SPICETIFY_DIR_ENV:-$HOME/.config/spicetify}"
THEME_NAME="Quickshell"
THEME_DIR="$SPICETIFY_DIR/Themes/$THEME_NAME"
COLOR_PATH="$THEME_DIR/color.ini"
CSS_PATH="$THEME_DIR/user.css"
CONFIG_PATH="$SPICETIFY_DIR/config-xpui.ini"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: required command not found: $1" >&2
    exit 127
  }
}

need_cmd jq
need_cmd rg

if [[ ! -f "$MATERIAL_PATH" ]]; then
  echo "Material file not found: $MATERIAL_PATH" >&2
  exit 1
fi

if [[ ! -d "$SPICETIFY_DIR" ]]; then
  echo "Spicetify config dir not found: $SPICETIFY_DIR" >&2
  exit 0
fi

pick_color() {
  local role="$1"
  local fallback="$2"
  jq -r --arg role "$role" --arg fallback "$fallback" '.colors[$role].dark // $fallback' "$MATERIAL_PATH"
}

hex_no_hash() {
  local value="${1#\#}"
  printf '%s' "$value" | tr '[:lower:]' '[:upper:]'
}

text=$(hex_no_hash "$(pick_color on_surface "#E5E1E9")")
subtext=$(hex_no_hash "$(pick_color on_surface_variant "#B3ADB7")")
main=$(hex_no_hash "$(pick_color surface_dim "#201F25")")
main_elevated=$(hex_no_hash "$(pick_color surface_container "#2A2530")")
highlight=$(hex_no_hash "$(pick_color surface_variant "#2B2730")")
highlight_elevated=$(hex_no_hash "$(pick_color surface_container_high "#2F2A33")")
sidebar=$(hex_no_hash "$(pick_color surface_container_low "#241F28")")
player=$(hex_no_hash "$(pick_color surface_container "#2A2530")")
card=$(hex_no_hash "$(pick_color surface_container_high "#2F2A33")")
shadow=$(hex_no_hash "$(pick_color outline "#928F99")")
selected_row=$(hex_no_hash "$(pick_color primary "#C7BFFF")")
button=$(hex_no_hash "$(pick_color primary_container "#4F4A5A")")
button_active=$(hex_no_hash "$(pick_color primary "#C7BFFF")")
button_disabled=$(hex_no_hash "$(pick_color outline_variant "#7F7A85")")
tab_active=$(hex_no_hash "$(pick_color primary_container "#4F4A5A")")
notification=$(hex_no_hash "$(pick_color primary "#C7BFFF")")
notification_error=$(hex_no_hash "$(pick_color error "#FF6B6B")")
misc=$(hex_no_hash "$(pick_color outline "#928F99")")

mkdir -p "$THEME_DIR"

cat > "$COLOR_PATH" <<EOF
[$THEME_NAME]
text               = $text
subtext            = $subtext
main               = $main
main-elevated      = $main_elevated
highlight          = $highlight
highlight-elevated = $highlight_elevated
sidebar            = $sidebar
player             = $player
card               = $card
shadow             = $shadow
selected-row       = $selected_row
button             = $button
button-active      = $button_active
button-disabled    = $button_disabled
tab-active         = $tab_active
notification       = $notification
notification-error = $notification_error
misc               = $misc
EOF

if [[ ! -f "$CSS_PATH" ]]; then
  cat > "$CSS_PATH" <<'EOF'
/* Quickshell theme sync - custom CSS */
EOF
fi

ensure_setting_value() {
  local key="$1"
  local value="$2"
  local tmp="${CONFIG_PATH}.tmp"

  if [[ ! -f "$CONFIG_PATH" ]]; then
    cat > "$CONFIG_PATH" <<EOF
[Setting]
$key = $value
EOF
    return
  fi

  if ! rg -q '^[[:space:]]*\\[Setting\\]' "$CONFIG_PATH"; then
    printf '\n[Setting]\n%s = %s\n' "$key" "$value" >> "$CONFIG_PATH"
    return
  fi

  awk -v key="$key" -v value="$value" '
    BEGIN { in_setting = 0; done = 0 }
    /^\[Setting\]/ { in_setting = 1; print; next }
    /^\[/ {
      if (in_setting && !done) {
        print key " = " value
        done = 1
      }
      in_setting = 0
      print
      next
    }
    {
      if (in_setting && $0 ~ "^[[:space:]]*" key "[[:space:]]*=") {
        if (!done) {
          print key " = " value
          done = 1
        }
        next
      }
      print
    }
    END {
      if (in_setting && !done) {
        print key " = " value
      }
    }
  ' "$CONFIG_PATH" > "$tmp"
  mv -f "$tmp" "$CONFIG_PATH"
}

ensure_setting_value "current_theme" "$THEME_NAME"
ensure_setting_value "color_scheme" "$THEME_NAME"
ensure_setting_value "inject_css" "1"
ensure_setting_value "replace_colors" "1"

if command -v spicetify >/dev/null 2>&1; then
  spotify_status=""
  if command -v playerctl >/dev/null 2>&1; then
    spotify_status="$(playerctl -p spotify status 2>/dev/null || true)"
  fi

  should_apply=false
  case "$spotify_status" in
    Playing)
      should_apply=false
      ;;
    Paused|Stopped)
      should_apply=true
      ;;
    *)
      should_apply=false
      ;;
  esac

  if [[ "$should_apply" == "true" ]]; then
    spotify_cmd="${SPOTIFY_CMD_ENV:-}"
    if [[ -z "$spotify_cmd" ]]; then
      if command -v spotify >/dev/null 2>&1; then
        spotify_cmd="spotify"
      elif command -v spotify-launcher >/dev/null 2>&1; then
        spotify_cmd="spotify-launcher"
      fi
    fi

    target_ws=""
    had_spotify=false
    if command -v hyprctl >/dev/null 2>&1; then
      clients_json="$(hyprctl clients -j 2>/dev/null || echo '[]')"
      target_ws="$(jq -r '
        map(select((.class // "" | ascii_downcase | test("spotify")) or
                   (.title // "" | ascii_downcase | test("spotify")))) |
        .[0].workspace.id // empty
      ' <<<"$clients_json")"
    fi
    if pgrep -x spotify >/dev/null 2>&1 || pgrep -x spotify-launcher >/dev/null 2>&1; then
      had_spotify=true
    fi

    if [[ "$had_spotify" == "true" ]]; then
      pkill -x spotify >/dev/null 2>&1 || true
      pkill -x spotify-launcher >/dev/null 2>&1 || true
      for _ in {1..20}; do
        pgrep -x spotify >/dev/null 2>&1 || break
        sleep 0.25
      done
    fi

    spicetify apply >/dev/null 2>&1 || spicetify apply || true

    if [[ "$had_spotify" == "true" ]]; then
      started_addr=""
      if command -v hyprctl >/dev/null 2>&1; then
        for _ in {1..20}; do
          started_addr="$(hyprctl clients -j 2>/dev/null | jq -r '
            map(select((.class // "" | ascii_downcase | test("spotify")) or
                       (.title // "" | ascii_downcase | test("spotify")))) |
            .[0].address // empty
          ' | tr -d '\r')"
          [[ -n "$started_addr" ]] && break
          sleep 0.25
        done
      fi

      if [[ -n "$started_addr" && -n "$target_ws" ]] && command -v hyprctl >/dev/null 2>&1; then
        current_ws="$(hyprctl clients -j 2>/dev/null | jq -r --arg addr "$started_addr" '
          map(select(.address == $addr)) | .[0].workspace.id // empty
        ' | tr -d '\r')"
        if [[ -n "$current_ws" && "$current_ws" != "$target_ws" ]]; then
          hyprctl dispatch movetoworkspacesilent "$target_ws,address:$started_addr" >/dev/null 2>&1 || \
            hyprctl dispatch movetoworkspace "$target_ws,address:$started_addr" >/dev/null 2>&1 || true
        fi
      elif [[ -z "$started_addr" && -n "$spotify_cmd" ]]; then
        if [[ -n "$target_ws" ]] && command -v hyprctl >/dev/null 2>&1; then
          hyprctl dispatch exec "[workspace ${target_ws} silent] ${spotify_cmd}" >/dev/null 2>&1 || true
        else
          nohup ${spotify_cmd} >/dev/null 2>&1 &
        fi
      fi
    fi
  else
    spicetify refresh -s >/dev/null 2>&1 || spicetify refresh -s || true
  fi
fi

echo "Updated Spicetify theme: $COLOR_PATH"
