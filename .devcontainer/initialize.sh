#!/usr/bin/env bash
# Runs on the HOST before the container is created/started.
set -u

# Bind-mount sources must exist or the container won't start.
mkdir -p "$HOME/.claude"
[ -f "$HOME/.claude.json" ] || echo '{}' > "$HOME/.claude.json"
mkdir -p /tmp/.X11-unix 2>/dev/null || true

# Let the container (same UID as you) open windows on your X server / XWayland.
if command -v xhost >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
  xhost "+SI:localuser:$(id -un)" >/dev/null 2>&1 || true
fi

exit 0
