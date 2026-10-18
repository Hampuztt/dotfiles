#!/usr/bin/env bash
# Runs Neovim inside a real tmux and checks that the two work together: tmux's own keys, moving
# between Neovim splits and tmux panes, and what Neovim draws on the screen.
#
#   tests/tmux_nvim.sh        (check.sh runs it too)
#
# It starts a separate, hidden tmux server with your tmux.conf and a hidden terminal attached to it,
# so keys go through tmux's key bindings just like real key presses. Files are throwaway ones in a
# temp folder. Your own tmux sessions, saved sessions (tmux-resurrect) and clipboard aren't touched.
set -uo pipefail

TESTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
source "$TESTS/lib.sh"
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"

echo "tmux and Neovim together"
tmp=$(mktemp -d)
server=dotfiles-test-$$
tm() { tmux -L "$server" "$@"; }
# shellcheck disable=SC2329 # (called by the trap below)
cleanup() {
  exec 3>&-
  tm kill-server 2>/dev/null
  [ -n "${terminal_pid:-}" ] && kill "$terminal_pid" 2>/dev/null
  rm -rf "$tmp"
}
trap cleanup EXIT

# Helpers
value() { tm display -p -t test "$1" 2>/dev/null; }                # a tmux format, e.g. '#{window_index}'
wait_for() {                                                       # wait_for <format> <value> (up to 10 s)
  for _ in $(seq 100); do
    [ "$(value "$1")" = "$2" ] && return 0
    sleep 0.1
  done
  return 1
}
shows() { tm capture-pane -p -t "$1" | grep -qF -- "$2"; }        # shows <pane> <text>
wait_shows() {                                                     # wait_shows <pane> <text> (up to 15 s)
  for _ in $(seq 150); do
    shows "$1" "$2" && return 0
    sleep 0.1
  done
  return 1
}
# screen_check "description" <pane> <text>: passes once the pane shows the text; else shows the screen
screen_check() {
  if wait_shows "$2" "$3"; then
    pass "$1"
  else
    fail "$1 (\"$3\" never appeared; the screen was:)"
    tm capture-pane -p -t "$2" | grep -v '^\s*$' | sed 's/^/        | /'
  fi
}
press() { tm send-keys -K -c "$client" "$@"; }                     # keys through tmux's key bindings
nvim_eval() { nvim --server "$tmp/nvim.sock" --remote-expr "$1" 2>/dev/null; }
nvim_cmd() { nvim_eval "execute('$1')" >/dev/null; }               # runs an Ex command and waits for it

# Your tmux.conf, but tmux-resurrect saves into the temp folder (never over your saved sessions)
printf 'set -g @resurrect-dir "%s/resurrect"\nsource-file ~/.config/tmux/tmux.conf\n' "$tmp" >"$tmp/tmux.conf"
mkdir -p "$tmp/work"
if ! tm -f "$tmp/tmux.conf" new-session -d -s test -x 160 -y 40 -c "$tmp/work"; then
  fail "tmux starts with your tmux.conf"
  exit 1
fi
expect "prefix is Ctrl-a" "$(tm show -gv prefix)" "C-a"
expect "windows are numbered from 1" "$(value '#{window_index}')" 1
check "the status bar shows your user name" grep -qF "$(whoami)" <<<"$(value '#{T:status-right}')"

# The hidden terminal: `script` gives tmux a terminal to attach to; fd 3 keeps it open until the end
if ! command -v script >/dev/null; then
  skip "tmux's keys and Neovim inside tmux (needs the \`script\` command, from util-linux)"
  exit "$failures"
fi
mkfifo "$tmp/keep-open"
TERM=xterm-256color script -qfec "stty cols 160 rows 40; tmux -L $server attach -t test" /dev/null \
  <"$tmp/keep-open" >/dev/null 2>&1 &
terminal_pid=$!
exec 3>"$tmp/keep-open"
client=""
for _ in $(seq 100); do
  client=$(tm list-clients -F '#{client_name}' 2>/dev/null | head -1)
  [ -n "$client" ] && break
  sleep 0.1
done
[ -n "$client" ] || {
  fail "a terminal can attach to tmux"
  exit "$failures"
}

# ── tmux's own keys ──
wait_shows test:1 'work$' # the shell's prompt: it has started (in the session's folder)
press C-a c
wait_for '#{session_windows}' 2
wait_shows test:2 'work$' # (until its shell has started, tmux can't tell which folder it's in)
expect "prefix + c opens a new window in the current folder" "$(value '#{pane_current_path}')" "$tmp/work"
press M-h
wait_for '#{window_index}' 1
expect "Alt-h goes to the previous window" "$(value '#{window_index}')" 1
press M-l
wait_for '#{window_index}' 2
expect "Alt-l goes to the next window" "$(value '#{window_index}')" 2
press C-a %
wait_for '#{window_panes}' 2
wait_shows test:2 'work$'
expect "prefix + % splits the window, in the current folder" "$(value '#{window_panes} #{pane_current_path}')" "2 $tmp/work"
press C-a m
wait_for '#{pane_synchronized}' 1
expect "prefix + m types into all panes at once" "$(value '#{pane_synchronized}')" 1
press C-a m
wait_for '#{pane_synchronized}' 0
expect "prefix + m again turns that off" "$(value '#{pane_synchronized}')" 0
press C-a f
wait_for '#{client_key_table}' fingers
expect "prefix + f starts tmux-fingers (hints to copy text)" "$(value '#{client_key_table}')" fingers
press Escape
wait_for '#{client_key_table}' root
tm kill-window -t test:2

# ── Neovim in a tmux pane, next to a shell pane ──
echo "v1" >"$tmp/work/a.txt"
nvim_pane=$(value '#{pane_id}')
tm send-keys -t "$nvim_pane" "nvim -i NONE --listen $tmp/nvim.sock $tmp/work/a.txt" Enter
for _ in $(seq 150); do # until Neovim has started and answers
  [ "$(nvim_eval 1)" = 1 ] && wait_shows "$nvim_pane" "a.txt" && break
  sleep 0.1
done
if [ "$(nvim_eval 1)" != 1 ]; then
  fail "Neovim starts in a tmux pane"
  exit "$failures"
fi
nvim_cmd 'vsplit | wincmd h'
tm split-window -h -t "$nvim_pane" -c "$tmp/work"
shell_pane=$(value '#{pane_id}')
tm select-pane -t "$nvim_pane"

press C-l
sleep 0.3
expect "Ctrl-l moves to the Neovim split on the right" "$(nvim_eval 'winnr()') $(value '#{pane_id}')" "2 $nvim_pane"
press C-l
wait_for '#{pane_id}' "$shell_pane"
expect "Ctrl-l at Neovim's right edge moves on to the tmux pane" "$(value '#{pane_id}')" "$shell_pane"

# While you're in the shell pane, another program changes the file you were editing
nvim_cmd 'normal! ihello'
echo "changed by another program" >"$tmp/work/a.txt"
touch -d '+5 seconds' "$tmp/work/a.txt"
press C-h
wait_for '#{pane_id}' "$nvim_pane"
expect "Ctrl-h from the shell pane moves back into Neovim" "$(value '#{pane_id}')" "$nvim_pane"
screen_check "coming back, Neovim notices the change and shows CHANGED ON DISK" "$nvim_pane" "CHANGED ON DISK"
press C-h
sleep 0.3
expect "Ctrl-h inside Neovim moves between its splits" "$(nvim_eval 'winnr()') $(value '#{pane_id}')" "1 $nvim_pane"

# The branch review draws its key reminder on the screen
repo="$tmp/repo"
mkdir -p "$repo"
(
  cd "$repo" || exit
  g() { git -c user.name=Test -c user.email=test@example.com "$@"; }
  g init -q -b master . && echo "original" >file.txt && g add -A && g commit -qm base
  g checkout -q -b feature && echo "changed" >file.txt && g commit -qam change
)
nvim_cmd "only | edit $repo/file.txt"
tm send-keys -t "$nvim_pane" Space g m
screen_check "<Leader>gm opens the branch picker" "$nvim_pane" "Review this branch against"
wait_shows "$nvim_pane" "2/2" # both branches are listed: the picker is ready for typing
tm send-keys -t "$nvim_pane" master
wait_shows "$nvim_pane" "1/2" # the list is down to master (1 of the 2 branches)
tm send-keys -t "$nvim_pane" Enter
screen_check "the review shows its keys on screen" "$nvim_pane" "]r [r  next/prev file"
screen_check "... and labels the old version" "$nvim_pane" "master, where your branch started"
nvim --server "$tmp/nvim.sock" --remote-send '<Esc>:qa!<CR>' 2>/dev/null

exit "$failures"
