#!/usr/bin/env bash
# Checks that install.sh set everything up. Runs inside the test container (see tests/run.sh),
# but also works on your own machine: tests/check.sh
# shellcheck disable=SC2088 # "~/..." in check descriptions is meant literally
set -uo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
failures=0

pass() { printf '  \033[32mPASS\033[0m %s\n' "$*"; }
fail() {
  printf '  \033[31mFAIL\033[0m %s\n' "$*"
  failures=$((failures + 1))
}
# check "description" command...   passes when the command succeeds
check() {
  local description=$1
  shift
  if "$@" >/dev/null 2>&1; then pass "$description"; else fail "$description"; fi
}
# expect "description" "actual" "wanted"
expect() {
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1: got [$2], wanted [$3]"; fi
}

echo "Config links"
eval "$(sed -n '/^LINKS=(/,/^)/p' "$DOTFILES/install.sh")" # the LINKS list from install.sh
for link in "${LINKS[@]}"; do
  read -r src dest <<<"$link"
  expect "~/$dest -> $src" "$(readlink "$HOME/$dest")" "$DOTFILES/$src"
done
check "~/.bashrc.local exists and only you can read it" test "$(stat -c %a "$HOME/.bashrc.local")" = 600
backups=$(find "$HOME" -maxdepth 4 -name '*.backup-*' -not -path '*/.local/share/*' | wc -l)
expect "only the original ~/.bashrc was backed up (second install changed nothing)" "$backups" 1

echo "Tools from mise"
check "every tool in mise/config.toml is installed" test -z "$(mise ls --missing 2>/dev/null)"
for cmd in nvim node uv rg fd fzf lazygit lazydocker btm gdu alacritty; do
  check "$cmd runs" "$cmd" --version
done
wanted_nvim=$(sed -nE 's/^neovim = "([^"]*)".*/\1/p' "$DOTFILES/mise/config.toml")
expect "Neovim version" "$(nvim --version | head -1)" "NVIM v$wanted_nvim"

echo "Shell"
bash_errors=$(bash -ic 'true' 2>&1 | grep -v -e 'cannot set terminal process group' -e 'no job control')
expect "interactive bash starts without errors" "$bash_errors" ""
expect "vim is an alias for nvim" "$(bash -ic 'alias vim' 2>/dev/null)" "alias vim='nvim'"
expect "fzf key bindings are loaded" "$(bash -ic 'type -t __fzf_history__' 2>/dev/null)" "function"

echo "Font and Alacritty launcher"
check "JetBrainsMono Nerd Font is installed" sh -c 'fc-list | grep -qi "JetBrainsMono Nerd Font"'
launcher="$HOME/.local/share/applications/Alacritty.desktop"
check "Alacritty launcher exists" test -f "$launcher"
check "the launcher's command runs" "$(sed -n 's/^Exec=//p' "$launcher")" --version

echo "tmux"
for plugin in tpm tmux-yank vim-tmux-navigator tmux-resurrect tmux-continuum tmux-fingers; do
  check "plugin $plugin" test -d "$HOME/.config/tmux/plugins/$plugin"
done
check "tmux-fingers program runs" "$HOME/.config/tmux/plugins/tmux-fingers/bin/tmux-fingers" version
tmux -L dotfiles-check new-session -d 2>/dev/null
expect "tmux loads the config (prefix is C-a)" "$(tmux -L dotfiles-check show -gv prefix 2>/dev/null)" "C-a"
fingers_bound() { tmux -L dotfiles-check list-keys -T prefix 2>/dev/null | grep -q 'tmux-fingers start'; }
for _ in $(seq 20); do fingers_bound && break; sleep 0.5; done # plugins load in the background
check "tmux-fingers is loaded (prefix + C-f)" fingers_bound
# (search the whole list: `list-keys -T prefix J` prints nothing on newer tmux)
expect "prefix + J still joins panes" "$(tmux -L dotfiles-check list-keys -T prefix 2>/dev/null | grep -cE 'prefix +J +.*join-pane')" 1
tmux -L dotfiles-check kill-server 2>/dev/null

echo "Neovim"
# (the sed drops a terminal color code that Snacks' lazygit setup prints even without a terminal)
expect "starts without errors" "$(nvim --headless +qa 2>&1 | sed 's/\x1b\][^\x07]*\x07//g')" ""
plugins=$(find "$HOME/.local/share/nvim/lazy" -mindepth 1 -maxdepth 1 -type d | wc -l)
check "plugins are installed ($plugins)" test "$plugins" -gt 40
for tool in lua-language-server basedpyright ruff clangd stylua tree-sitter; do
  check "Mason tool $tool" test -x "$HOME/.local/share/nvim/mason/bin/$tool"
done
parsers=$(nvim --headless "+lua io.write(table.concat(require('nvim-treesitter').get_installed(), ' '))" +qa 2>&1)
for parser in lua python cpp bash markdown; do
  check "treesitter parser $parser" grep -qw "$parser" <<<"$parsers"
done

# Language servers attach to real files (waits up to 90 s per file for them to start)
tmp=$(mktemp -d)
printf 'def add(a: int, b: int) -> int:\n    return a + b\n' >"$tmp/main.py"
printf 'int main() { return 0; }\n' >"$tmp/main.cpp"
printf 'local x = 1\nreturn x\n' >"$tmp/init.lua"
for case in "main.py basedpyright,ruff" "main.cpp clangd" "init.lua lua_ls"; do
  read -r file servers <<<"$case"
  check "language servers on $file: $servers" \
    env EXPECT="$servers" nvim --headless "$tmp/$file" -c "luafile $DOTFILES/tests/lsp_attached.lua"
done
rm -rf "$tmp"

echo
if [ "$failures" -eq 0 ]; then
  echo "All checks passed."
else
  echo "$failures check(s) failed."
  exit 1
fi
