# Dotfiles

Sets up a Linux machine (Ubuntu/Debian, Fedora or Arch): bash, tmux, Alacritty, a Nerd Font,
command-line tools, and my Neovim config (its own repo: [Hampuztt/neovim](https://github.com/Hampuztt/neovim)).

## Install

```bash
git clone https://github.com/Hampuztt/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

Run it as your normal user; it asks for sudo for system packages. It's safe to run again:
each step skips what's already done.

## What `install.sh` does

1. **System packages** with apt, dnf or pacman: compilers, curl, git, Python venv support, tmux,
   xclip / wl-clipboard, and the libraries Alacritty is built against.
2. **Links your config files into your home folder** (see below). An existing file is kept as
   `<name>.backup-<date>`.
3. **[mise](https://mise.jdx.dev) and the tools in `mise/config.toml`**: Neovim, Node,
   ripgrep, fd, fzf, lazygit, lazydocker, btm, gdu, uv and Alacritty (compiled, takes a few minutes).
4. **JetBrainsMono Nerd Font** into `~/.local/share/fonts`.
5. **Alacritty app launcher**, and on Debian/Ubuntu Alacritty as the default terminal.
6. **tmux plugins** (tpm and the plugins listed in `tmux.conf`).
7. **Neovim config** cloned into `~/.config/nvim` (if it isn't there yet), plus its plugins and
   language servers.

## Where things are

One folder per program:

| In this repo               | Linked to                            |
| -------------------------- | ------------------------------------ |
| `bash/bashrc`              | `~/.bashrc`                          |
| `tmux/tmux.conf`           | `~/.config/tmux/tmux.conf`           |
| `alacritty/alacritty.toml` | `~/.config/alacritty/alacritty.toml` |
| `mise/config.toml`         | `~/.config/mise/config.toml`         |
| `install.sh`               | (the installer)                      |

They're links, so editing `~/.bashrc` (or any of them) edits the file in the repo. Commit when
you're happy.

## Common changes

- **Add a config file:** put it in a folder for its program (e.g. `git/gitconfig`), add a line to
  `LINKS` at the top of `install.sh`, then run `./install.sh`.
- **Add a tool:** find its name with `mise registry <name>`, add a line to `mise/config.toml`,
  then run `mise install`.
- **Update tools:** `mise upgrade --bump` installs the newest versions and writes them into
  `config.toml`. Commit that.
- **Add a system package:** add it to the package lists at the top of `install.sh`.
- **Secrets and settings for one machine** (tokens, CUDA paths, ...): put them in `~/.bashrc.local`.
  `install.sh` creates it, `~/.bashrc` loads it, and it's never committed. **This repo is public.**

## Not installed

- `tmuxinator` (the `mux` alias): install it with your package manager if you want it.
