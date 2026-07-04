#!/usr/bin/env bash
# Toggles the Apple Silicon webcam's kernel driver (apple_isp) on/off from
# a waybar button, for on-demand privacy at the driver level rather than
# just an app-permission toggle -- confirmed apple_isp is a clean,
# self-contained module (lsmod shows use-count 0, nothing else depends on
# it) rather than being compiled into the kernel image, so rmmod/modprobe
# fully removes/restores /dev/video0 rather than merely gating access.
#
# Needs a narrowly-scoped NOPASSWD sudoers rule limited to exactly these
# two commands (see /etc/sudoers.d/asahi-camera-toggle, or
# writeCameraToggleSudoers in Main.hs) -- a waybar click can't answer an
# interactive sudo password prompt. `sudo -n` (non-interactive) means a
# missing/broken sudoers rule fails the toggle immediately rather than
# hanging waybar waiting on a password prompt nothing can supply.

set -euo pipefail

is_loaded() {
  lsmod | grep -q "^apple_isp "
}

status() {
  # U+F03D/U+F4E2 are Font Awesome 6 Free Solid's video/video-slash
  # glyphs -- verified via hb-shape against the installed font file
  # before use. Built via bash's $'\uXXXX' ANSI-C quoting rather than a
  # literal character: literal glyphs typed directly into this file have
  # silently come out empty or wrong on multiple separate attempts this
  # session (see the other waybar scripts' headers) -- pure-ASCII escape
  # text sidesteps that transmission problem entirely instead of hoping
  # it works this time.
  local icon_on=$''
  local icon_off=$''
  if is_loaded; then
    printf '{"text":"%s","tooltip":"Camera enabled (click to disable)","class":"on"}\n' "$icon_on"
  else
    printf '{"text":"%s","tooltip":"Camera disabled (click to enable)","class":"off"}\n' "$icon_off"
  fi
}

toggle() {
  if is_loaded; then
    sudo -n rmmod apple_isp
  else
    sudo -n modprobe apple_isp
  fi
  pkill -RTMIN+11 waybar || true
}

case "${1:-status}" in
  toggle) toggle ;;
  *) status ;;
esac
