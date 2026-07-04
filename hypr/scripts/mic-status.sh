#!/usr/bin/env bash
# Reports the default microphone's name, record volume, and mute state as
# a waybar custom-module JSON blob; `toggle` mutes/unmutes it. Waybar's
# built-in pulseaudio module can't do this: its {desc}/{volume}/{icon}/
# on-click/scroll all target the default *sink* (speaker) specifically --
# format-source/format-source-muted only let you embed the mic's volume
# as text inside the sink module's own label, with no device-name
# placeholder and no way to scope a click to the source alone (confirmed
# via `man waybar-pulseaudio`). So this is a plain custom module instead,
# same pattern as bluetooth-status.sh.
#
# Uses wpctl for volume (its `Volume: 0.xx` output is a plain fraction,
# simplest to parse) and pactl for mute state and the description lookup
# (pactl list sources' text is easy to grep/awk; wpctl's own mute
# indicator is a suffix on the same Volume line, not worth juggling two
# formats from one tool when pactl's Mute: yes/no is unambiguous).

set -euo pipefail

status() {
  local default_source volume_frac volume_pct muted desc icon

  default_source="$(pactl get-default-source)"
  volume_frac="$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | awk '{print $2}')"
  volume_pct="$(awk -v v="$volume_frac" 'BEGIN { printf "%d", v * 100 }')"
  muted="no"
  if pactl get-source-mute @DEFAULT_SOURCE@ | grep -q "yes"; then
    muted="yes"
  fi

  desc="$(pactl list sources | awk -v name="$default_source" '
    /^Source #/ { insrc=0 }
    $0 ~ ("Name: " name) { insrc=1 }
    insrc && /Description:/ { sub(/^\tDescription: /, ""); print; exit }
  ')"
  [ -z "$desc" ] && desc="$default_source"

  # Font Awesome 6 Free Solid's microphone/microphone-slash glyphs
  # (U+F130/U+F131) -- verified via a byte-level check (python3
  # hex-dumping ord(ch)) that these literal characters actually landed
  # correctly in this file and that the script's own JSON output carries
  # the right codepoint, rather than trusting it renders.
  if [ "$muted" = "yes" ]; then
    icon=''
    printf '{"text":"%b %d%%","tooltip":"%s (muted)\\nVolume: %d%%","class":"muted"}\n' \
      "$icon" "$volume_pct" "$desc" "$volume_pct"
  else
    icon=''
    printf '{"text":"%b %d%%","tooltip":"%s\\nVolume: %d%%","class":"unmuted"}\n' \
      "$icon" "$volume_pct" "$desc" "$volume_pct"
  fi
}

toggle() {
  pactl set-source-mute @DEFAULT_SOURCE@ toggle
  pkill -RTMIN+10 waybar || true
}

case "${1:-status}" in
  toggle) toggle ;;
  *) status ;;
esac
