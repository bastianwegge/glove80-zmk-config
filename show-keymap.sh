#!/bin/bash
# Watch for the Glove80 connecting (BT or USB) and show its keymap on connect.
# Runs as a launchd agent (polls every few seconds); also runnable by hand:
#   ./show-keymap.sh          # watch loop (what launchd runs)
#   ./show-keymap.sh --once   # render + open immediately, no loop
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
CFG="$REPO/keymap_drawer.config.yaml"
KEYMAP="$REPO/config/glove80.keymap"
OUT="$REPO/glove80-keymap.svg"
PNG="$REPO/glove80-keymap.png"
STATE="$REPO/.connected"

render() {
  # Regenerate only if the keymap or config changed since last render.
  if [ ! -f "$PNG" ] || [ "$KEYMAP" -nt "$PNG" ] || [ "$CFG" -nt "$PNG" ]; then
    uvx --from keymap-drawer keymap -c "$CFG" parse -z "$KEYMAP" > "$REPO/.keymap.yaml"
    uvx --from keymap-drawer keymap -c "$CFG" draw "$REPO/.keymap.yaml" > "$OUT"
    # rsvg-convert keeps the true aspect ratio (qlmanage forces a square and
    # clips the wide layout). -w sets width; height scales to match.
    rsvg-convert -w 3000 -b white "$OUT" -o "$PNG"
  fi
}

show() { render; open -g -a Preview "$PNG"; }   # -g: don't steal focus

connected() { ioreg -r -c IOHIDDevice 2>/dev/null | grep -q 'Glove80'; }

if [ "${1:-}" = "--once" ]; then show; exit 0; fi

# Poll loop: fire show() only on the disconnected -> connected edge.
while true; do
  if connected; then
    if [ ! -f "$STATE" ]; then show; touch "$STATE"; fi
  else
    rm -f "$STATE"
  fi
  sleep 5
done
