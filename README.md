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
- **Update tools:** `mise upgrade` updates everything set to `latest` (and Node within 24.x).
  Neovim is pinned on purpose: `mise upgrade --bump neovim` updates it and writes the new version
  into `mise/config.toml`. Commit that.
- **Add a system package:** add it to the package lists at the top of `install.sh`.
- **Secrets and settings for one machine** (tokens, CUDA paths, ...): put them in `~/.bashrc.local`.
  `install.sh` creates it, `~/.bashrc` loads it, and it's never committed. **This repo is public.**

## Testing

**Does my install work?** Run `tests/check.sh` (about 20 seconds). It checks the links, tools,
font, tmux plugins, Neovim plugins and that language servers attach, and then that the features
work:

- the Neovim config's own tests (`~/.config/nvim/tests/run.sh`, see that repo's README)
- `tests/tmux_nvim.sh`: a hidden tmux with your `tmux.conf` and Neovim inside it. It presses
  tmux's keys (new window, splits, pane swapping, tmux-fingers, ...), moves between Neovim splits and
  tmux panes with Ctrl-h/l, and checks what Neovim draws on the screen.

Everything runs in throwaway files and a separate tmux server: your sessions, saved tmux sessions,
repos and clipboard aren't touched. A failing screen check prints what was on the screen.

`tests/run.sh` runs `install.sh` twice in fresh Ubuntu 24.04 and Fedora containers (Docker), then
runs `tests/check.sh` there. Your machine isn't touched. It takes a while, because everything is
downloaded and built from scratch.

```bash
tests/check.sh        # check this machine
tests/tmux_nvim.sh    # only the tmux + Neovim part
tests/run.sh          # fresh installs: Ubuntu and Fedora
tests/run.sh fedora   # one distro
```

Logs end up in `tests/logs/`.

## Not installed

- `tmuxinator` (the `mux` alias): install it with your package manager if you want it.
