#!/usr/bin/env bash
# Reports Bluetooth power/connection state as a waybar custom-module JSON
# blob, and (via the toggle/pair subcommands) drives Bluetooth entirely
# through bluetoothctl -- deliberately NOT blueman or any other applet.
#
# bluedevil's tray icon is a Plasma Plasmoid (org.kde.plasma.bluetooth),
# not a standalone StatusNotifierItem process, so it can't dock into
# waybar's tray at all -- confirmed directly via `rpm -ql bluedevil`
# (no standalone applet binary, only kded/QML plugins) and the fact that
# waybar's tray only speaks the generic SNI protocol. But bluedevil's
# kded plugin IS already running in this session regardless (confirmed
# via `pgrep kded6`), and it's very likely already registered as BlueZ's
# default pairing agent. Running blueman's applet alongside it would put
# two things fighting to be that agent -- same class of conflict this
# repo already hit once with tuned vs power-profiles-daemon. This script
# never registers as an agent itself, so it can't create that conflict;
# it only reads state and issues plain bluetoothctl commands.
#
# `pair` shells out to bluedevil-wizard for the actual pairing UI --
# unlike the tray applet, bluedevil ships that as a standalone binary
# (confirmed in the same `rpm -ql` output), so it works fine outside a
# Plasma session and rides on whatever agent is already registered
# (bluedevil's kded plugin here) rather than adding a new one.

set -euo pipefail

status() {
  # Font Awesome 6 Brands' "bluetooth-b" glyph (U+F294) -- verified
  # directly via a byte-level check (python3 hex-dumping ord(ch)) that
  # this literal character actually landed correctly in this file, since
  # the exact same "icon silently came out empty" failure already
  # happened once while writing this same file (see the waybar theming
  # memory).
  if ! bluetoothctl show | grep -q "Powered: yes"; then
    printf '{"text":"","tooltip":"Bluetooth off","class":"off"}\n'
    return
  fi

  local connected
  connected="$(bluetoothctl devices Connected | sed -E 's/^Device [0-9A-F:]+ //' | paste -sd ', ' -)"

  if [ -z "$connected" ]; then
    printf '{"text":"","tooltip":"Bluetooth on, no devices connected","class":"on"}\n'
  else
    printf '{"text":" %s","tooltip":"Connected: %s","class":"connected"}\n' "$connected" "$connected"
  fi
}

toggle() {
  if bluetoothctl show | grep -q "Powered: yes"; then
    bluetoothctl power off >/dev/null
  else
    bluetoothctl power on >/dev/null
  fi
  pkill -RTMIN+9 waybar || true
}

pair() {
  bluedevil-wizard >/dev/null 2>&1 &
  disown
}

case "${1:-status}" in
  toggle) toggle ;;
  pair) pair ;;
  *) status ;;
esac
