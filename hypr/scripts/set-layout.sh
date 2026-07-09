#!/usr/bin/env bash
# Sets Hyprland's layout to an explicit target state, or advances to the
# next state in a fixed 6-step sequence if no target is given:
#   left -> top -> right -> bottom -> center -> dwindle -> (back to left)
#
# Replaces the old cycle-master-orientation.sh, which had two real bugs:
#   1. It assumed Hyprland's default orientation-cycle order is
#      left/right/top/bottom/center. The real order (confirmed directly
#      against MasterLayout.cpp's eOrientation enum and
#      buildOrientationCycleVectorFromEOperation) is
#      left/top/right/bottom/center -- top and right were transposed.
#   2. It tracked a single global counter as a stand-in for Hyprland's
#      actual orientation state, which Hyprland tracks per-workspace
#      (getMasterWorkspaceData is keyed by workspace ID). Switching
#      workspaces and cycling on each independently let the tracked
#      global counter drift arbitrarily far from any single workspace's
#      real state.
#
# This version sidesteps both problems by never querying or inferring
# Hyprland's current state at all. Every step in this script's fixed
# sequence explicitly SETS a target (orientationleft, orientationtop, ...
# via layoutmsg, or the dwindle layout-file rewrite below) rather than
# asking Hyprland to advance relative to whatever it currently thinks the
# state is. The tracked step counter only needs to remember which of the
# 6 fixed steps comes next -- it never needs to match Hyprland's actual
# per-workspace orientation, because every step is an absolute dispatch,
# not a relative nudge, and Hyprland's own per-workspace tracking (which
# this script never touches directly) handles the rest correctly on its
# own, same as it always has.
#
# dwindle is a genuine exception to "per-workspace": general:layout is a
# single compositor-wide setting, not scoped per workspace, so switching
# into or out of dwindle here affects every workspace at once, not just
# the focused one -- unlike the 5 orientation steps, which only ever
# affect the currently focused workspace (Hyprland's own behavior, not
# something this script controls).
#
# Usage:
#   set-layout.sh              cycle to the next of the 6 states
#   set-layout.sh <state>      jump directly to <state> (left, top,
#                               right, bottom, center, or dwindle)
set -euo pipefail

STATE_FILE="$HOME/.cache/hypr-layout-cycle-step"
CONFIG_FILE="$HOME/.config/hypr/hyprland.conf"
STATES=(left top right bottom center dwindle)

current=0
if [[ -f "$STATE_FILE" ]]; then
  current="$(cat "$STATE_FILE")"
fi

target_index=-1
if [[ -n "${1:-}" ]]; then
  requested="$1"
  for i in "${!STATES[@]}"; do
    if [[ "${STATES[$i]}" == "$requested" ]]; then
      target_index="$i"
      break
    fi
  done
  if [[ "$target_index" -eq -1 ]]; then
    echo "set-layout: unknown state '${requested}' (expected one of: ${STATES[*]})" >&2
    exit 1
  fi
else
  target_index=$(( (current + 1) % ${#STATES[@]} ))
fi

target="${STATES[$target_index]}"
current_is_dwindle=0
[[ "$current" -eq 5 ]] && current_is_dwindle=1

# Rewrites general:layout in place and reloads so Hyprland actually picks
# up the change (hyprctl keyword general:layout <x> alone does NOT
# trigger the switch -- confirmed directly: CConfigManager::parseKeyword
# has no special case for "general:layout", and the actual
# g_pLayoutManager->switchToLayout(...) call only runs inside
# postConfigReload, which a plain keyword set never invokes. A full
# `hyprctl reload` re-reads the file and runs that path for real).
switch_layout() {
  local from="$1" to="$2"
  sed -i "s/^\([[:space:]]*layout = \)${from}\$/\1${to}/" "$CONFIG_FILE"
  if ! grep -qE "^[[:space:]]*layout = ${to}\$" "$CONFIG_FILE"; then
    echo "set-layout: failed to rewrite general:layout ${from} -> ${to} in ${CONFIG_FILE}" >&2
    exit 1
  fi
  hyprctl reload
}

if [[ "$target" == "dwindle" ]]; then
  [[ "$current_is_dwindle" -eq 1 ]] || switch_layout master dwindle
else
  [[ "$current_is_dwindle" -eq 1 ]] && switch_layout dwindle master
  hyprctl dispatch layoutmsg "orientation${target}"
fi

echo "$target_index" > "$STATE_FILE"
