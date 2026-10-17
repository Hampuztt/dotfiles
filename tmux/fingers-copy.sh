#!/bin/sh
# Used by tmux-fingers (see tmux.conf): copies the selected match (given on stdin) to the
# system clipboard.
# (Fingers' own clipboard detection picks wl-copy whenever it's installed, even on X11 where it fails.)
text=$(cat)

if command -v clip.exe >/dev/null; then # WSL
  printf %s "$text" | clip.exe
elif [ -n "${WAYLAND_DISPLAY:-}" ]; then
  printf %s "$text" | wl-copy
else
  printf %s "$text" | xclip -selection clipboard
fi
