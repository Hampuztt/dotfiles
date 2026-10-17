#!/usr/bin/env bash
# Sets up a Linux machine (Ubuntu/Debian, Fedora or Arch) with these dotfiles:
#   1. system packages            4. JetBrainsMono Nerd Font      7. Neovim config + plugins
#   2. links your configs into ~  5. Alacritty launcher
#   3. mise and its tools         6. tmux plugins
# Safe to run again: every step skips what's already done. Run it as yourself (it asks for sudo).
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NVIM_CONFIG_REPO="https://github.com/Hampuztt/neovim.git"
NERD_FONT="JetBrainsMono" # any font name from https://github.com/ryanoasis/nerd-fonts/releases

# Config files: "file in this repo" and "where it goes in your home folder".
# Add a line here when you add a config file to the repo.
LINKS=(
  "bash/bashrc              .bashrc"
  "tmux/tmux.conf           .config/tmux/tmux.conf"
  "alacritty/alacritty.toml .config/alacritty/alacritty.toml"
  "mise/config.toml         .config/mise/config.toml"
)

# System packages: compilers (treesitter parsers, Alacritty), what Mason needs (curl, unzip,
# Python venvs), clipboard tools, tmux, and the libraries Alacritty is built against.
# Everything else (Neovim, Node, ripgrep, ...) comes from mise: mise/config.toml
APT_PACKAGES=(
  build-essential cmake pkg-config curl git unzip xz-utils fontconfig
  python3 python3-venv python3-pip tmux xclip wl-clipboard
  libfreetype6-dev libfontconfig1-dev libxcb-xfixes0-dev libxkbcommon-dev
)
DNF_PACKAGES=(
  gcc gcc-c++ make cmake pkgconf-pkg-config curl git unzip xz fontconfig
  python3 python3-pip tmux xclip wl-clipboard
  freetype-devel fontconfig-devel libxcb-devel libxkbcommon-devel
)
PACMAN_PACKAGES=(
  base-devel cmake pkgconf curl git unzip xz fontconfig
  python python-pip tmux xclip wl-clipboard
  freetype2 libxcb libxkbcommon
)

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }

install_system_packages() {
  step "System packages"
  # shellcheck disable=SC1091
  . /etc/os-release
  case " $ID ${ID_LIKE:-} " in
    *" debian "* | *" ubuntu "*) sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${APT_PACKAGES[@]}" ;;
    *" fedora "* | *" rhel "*) sudo dnf install -y "${DNF_PACKAGES[@]}" ;;
    *" arch "*) sudo pacman -Syu --needed --noconfirm "${PACMAN_PACKAGES[@]}" ;;
    *)
      echo "Don't know how to install packages on '$ID'. Install the equivalent of:" >&2
      echo "  ${APT_PACKAGES[*]}" >&2
      exit 1
      ;;
  esac
}

# Links each file in LINKS into your home folder. An existing file there is kept as a backup.
link_configs() {
  step "Linking configs into ~"
  local backup_suffix link src dest
  backup_suffix=".backup-$(date +%Y%m%d-%H%M%S)"
  for link in "${LINKS[@]}"; do
    read -r src dest <<<"$link"
    src="$DOTFILES/$src"
    dest="$HOME/$dest"
    [ "$(readlink "$dest" 2>/dev/null)" = "$src" ] && continue # already linked
    mkdir -p "$(dirname "$dest")"
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      mv "$dest" "$dest$backup_suffix"
      info "kept your old ${dest/#"$HOME"/\~} as ${dest/#"$HOME"/\~}$backup_suffix"
    fi
    ln -s "$src" "$dest"
    info "linked ${dest/#"$HOME"/\~}"
  done

  if [ ! -e "$HOME/.bashrc.local" ]; then
    echo "# Settings for this machine only, and secrets. Loaded by ~/.bashrc, never committed." >"$HOME/.bashrc.local"
    chmod 600 "$HOME/.bashrc.local"
    info "created ~/.bashrc.local"
  fi
}

install_mise_tools() {
  step "mise and its tools (Alacritty is compiled, which takes a few minutes the first time)"
  export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
  command -v mise >/dev/null || curl -fsSL https://mise.run | sh
  mise install rust # needed to build Alacritty
  mise install
  mise reshim
}

install_font() {
  step "$NERD_FONT Nerd Font"
  if fc-list | grep -qi "$NERD_FONT Nerd Font"; then
    info "already installed"
    return
  fi
  local dir="$HOME/.local/share/fonts/${NERD_FONT}NerdFont"
  mkdir -p "$dir"
  curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$NERD_FONT.tar.xz" | tar -xJ -C "$dir"
  fc-cache -f
}

# mise doesn't add Alacritty to your app menu, so add a launcher (and make it the default terminal).
setup_alacritty() {
  step "Alacritty launcher"
  local alacritty="$HOME/.local/share/mise/shims/alacritty"
  local apps="$HOME/.local/share/applications"
  local icons="$HOME/.local/share/icons/hicolor/scalable/apps"
  mkdir -p "$apps" "$icons"
  [ -f "$icons/Alacritty.svg" ] ||
    curl -fsSL -o "$icons/Alacritty.svg" https://raw.githubusercontent.com/alacritty/alacritty/master/extra/logo/alacritty-term.svg
  cat >"$apps/Alacritty.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Alacritty
GenericName=Terminal
Comment=A fast, cross-platform, OpenGL terminal emulator
Exec=$alacritty
Icon=Alacritty
Terminal=false
Categories=System;TerminalEmulator;
StartupWMClass=Alacritty
EOF
  info "added ~/.local/share/applications/Alacritty.desktop"

  # Debian/Ubuntu: the terminal that x-terminal-emulator (and "Open in Terminal") starts
  if [ -e /etc/alternatives/x-terminal-emulator ]; then
    sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator "$alacritty" 50
    sudo update-alternatives --set x-terminal-emulator "$alacritty"
  fi
}

install_tmux_plugins() {
  step "tmux plugins"
  local tpm="$HOME/.config/tmux/plugins/tpm"
  [ -d "$tpm" ] || git clone --depth 1 https://github.com/tmux-plugins/tpm "$tpm"
  "$tpm/bin/install_plugins"

  # tmux-fingers also needs its program; without it, tmux asks you to install it on first start
  local fingers="$HOME/.config/tmux/plugins/tmux-fingers"
  if [ -d "$fingers" ] && [ ! -x "$fingers/bin/tmux-fingers" ]; then
    bash "$fingers/install-wizard.sh" download-binary </dev/null ||
      info "couldn't download the tmux-fingers program; tmux will offer to install it"
  fi
}

setup_neovim() {
  step "Neovim config and plugins"
  if [ -e "$HOME/.config/nvim" ]; then
    info "your Neovim config (~/.config/nvim) already exists, leaving it as it is"
  else
    git clone "$NVIM_CONFIG_REPO" "$HOME/.config/nvim"
  fi
  nvim --headless "+Lazy! sync" +qa
  # (time limit: if Mason ever gets stuck, this script still finishes)
  timeout 30m nvim --headless "+MasonToolsInstallSync" +qa ||
    info "Mason tools didn't finish within 30 minutes; open Neovim and check :Mason"
  # Build the treesitter parsers now instead of in the background on your first start
  # (only with the nvim-treesitter version that has `install`, i.e. AstroNvim v6)
  nvim --headless "+lua local ok, ts = pcall(require, 'nvim-treesitter') if ok and ts.install then ts.install(require('astrocore').config.treesitter.ensure_installed):wait(600000) end" +qa
}

main() {
  if [ "$(id -u)" = 0 ]; then
    echo "Run this as your normal user, not with sudo (it asks for sudo when needed)." >&2
    exit 1
  fi
  install_system_packages
  link_configs
  install_mise_tools
  install_font
  setup_alacritty
  install_tmux_plugins
  setup_neovim
  step "Done. Open a new terminal (or run: source ~/.bashrc)"
}

main "$@"
