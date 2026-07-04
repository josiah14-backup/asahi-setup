#!/usr/bin/env bash
# Searchable keybinding cheatsheet, parsed live from hyprland.conf's own
# `bind`/`bindl`/`bindm` lines rather than a separately maintained list,
# so it can never drift out of sync with the actual config.

set -euo pipefail

CONF="$HOME/.config/hypr/hyprland.conf"

grep -E '^[[:space:]]*bind[lm]?[[:space:]]*=' "$CONF" \
  | sed -E 's/^[[:space:]]*(bind[lm]?)[[:space:]]*=[[:space:]]*/\1 = /' \
  | awk -F',' '{
      mod=$1; sub(/^bind[lm]? = /, "", mod); gsub(/^[ \t]+|[ \t]+$/, "", mod)
      gsub(/\$mod/, "mod", mod)
      key=$2; gsub(/^[ \t]+|[ \t]+$/, "", key)
      disp=$3; gsub(/^[ \t]+|[ \t]+$/, "", disp)
      rest=""
      for (i=4;i<=NF;i++) { rest = rest (i>4?",":"") $i }
      gsub(/^[ \t]+|[ \t]+$/, "", rest)
      combo = (mod == "" ? key : mod " + " key)
      action = disp (rest != "" ? " " rest : "")
      printf "%-28s %s\n", combo, action
    }' \
  | fuzzel --dmenu -p "Keybindings: " -w 70 -l 25 > /dev/null
