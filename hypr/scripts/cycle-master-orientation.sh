#!/usr/bin/env bash
# Cycles Hyprland's master-layout orientation and tracks the result in a
# state file so waybar's custom/layout module can display it.
#
# Hyprland has no query for the live orientation -- `hyprctl getoption
# master:orientation` never updates after cycling, no IPC event fires
# when orientationcycle runs, and even inferring it from window geometry
# is ambiguous (confirmed directly: "left" and "center" produce
# identical window positions/sizes with only 2 windows on screen). So
# this script is the source of truth for the tracked value, not
# Hyprland itself -- it assumes this script is the ONLY thing that ever
# changes orientation, matching Hyprland's own default cycle order
# (left, right, top, bottom, center) and starting state (left).

set -euo pipefail

STATE_FILE="$HOME/.cache/hypr-master-orientation"
ORIENTATIONS=(left right top bottom center)

current="left"
if [ -f "$STATE_FILE" ]; then
  current="$(cat "$STATE_FILE")"
fi

index=0
for i in "${!ORIENTATIONS[@]}"; do
  if [ "${ORIENTATIONS[$i]}" = "$current" ]; then
    index="$i"
    break
  fi
done

next_index=$(( (index + 1) % ${#ORIENTATIONS[@]} ))
next="${ORIENTATIONS[$next_index]}"

echo "$next" > "$STATE_FILE"
hyprctl dispatch layoutmsg orientationcycle
pkill -RTMIN+8 waybar || true
