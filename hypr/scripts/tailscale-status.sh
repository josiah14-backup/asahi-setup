#!/usr/bin/env bash
# Reports Tailscale connection state as a waybar custom-module JSON blob,
# same pattern as bluetooth-status.sh/mic-status.sh.
#
# `tailscale status --json`'s BackendState field is the authoritative
# state ("Running" means actually joined to the tailnet; anything else --
# Stopped, NeedsLogin, NeedsMachineAuth, Starting -- means it isn't) --
# more reliable than checking for a tailscale0 interface or pinging a
# peer, neither of which can distinguish "logged out" from "logged in
# but this specific peer is unreachable".
#
# Read-only calls (status) work for any local user regardless --
# tailscaled.sock is world read/write (srw-rw-rw-). But `tailscale
# up`/`down` do their own authorization on top of that socket access:
# confirmed directly by tracing this script, which hit "Access denied:
# prefs write access denied" on a plain `tailscale down` despite the
# permissive socket. Unlike the camera module (which needs a sudoers
# rule baked into this repo's setup), the fix here is a one-time,
# outside-this-repo host command: `sudo tailscale set
# --operator=$USER`. After that, up/down work as the invoking user with
# no sudo and no sudoers rule -- it's tailscaled's own operator concept,
# not a filesystem permission this repo can grant.

set -euo pipefail

status() {
  local json backend_state icon

  json="$(tailscale status --json)"
  backend_state="$(jq -r '.BackendState' <<<"$json")"

  # shield-halved (U+F3ED) is a Font Awesome 6 Free Solid glyph. Written
  # as a bash \uXXXX escape rather than a literal character on purpose:
  # a literal PUA byte sequence here silently came out empty on write
  # (confirmed via xxd -- the quotes ended up with nothing between them),
  # the same blank-glyph failure bluetooth-status.sh/mic-status.sh's own
  # comments already warn about. The escape form sidesteps whatever
  # mangles raw PUA bytes in the write path, since the file itself stays
  # plain ASCII and bash computes the encoding at runtime.
  icon=$''

  if [ "$backend_state" = "Running" ]; then
    local self_ip
    self_ip="$(jq -r '.TailscaleIPs[0] // "unknown"' <<<"$json")"
    printf '{"text":"%b","tooltip":"Tailscale connected\\n%s","class":"connected"}\n' "$icon" "$self_ip"
  else
    printf '{"text":"%b","tooltip":"Tailscale: %s","class":"off"}\n' "$icon" "$backend_state"
  fi
}

toggle() {
  local backend_state
  backend_state="$(tailscale status --json | jq -r '.BackendState')"

  if [ "$backend_state" = "Running" ]; then
    tailscale down
  else
    tailscale up
  fi

  pkill -RTMIN+12 waybar || true
}

case "${1:-status}" in
  toggle) toggle ;;
  *) status ;;
esac
