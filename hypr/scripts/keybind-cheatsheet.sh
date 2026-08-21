#!/usr/bin/env bash
# Searchable keybinding cheatsheet, read from Hyprland's live bind list
# rather than a separately maintained list,
# so it can never drift out of sync with the actual config.

set -euo pipefail

hyprctl binds -j \
  | jq -r '.[] | select(.description != "") | [.description, (.dispatcher + if .arg == "" then "" else " " + .arg end)] | @tsv' \
  | awk -F '\t' '{ printf "%-28s %s\n", $1, $2 }' \
  | fuzzel --dmenu -p "Keybindings: " -w 70 -l 25 > /dev/null
