#!/usr/bin/env bash
# Tests install.sh on fresh machines (Docker containers), then checks the result with check.sh.
#
#   tests/run.sh                 test Ubuntu and Fedora (one after the other)
#   tests/run.sh fedora          test one distro
#   tests/run.sh --github-nvim   clone the Neovim config from GitHub (what a new machine gets)
#                                instead of copying your local ~/.config/nvim into the container
#
# Each run starts from a clean image, so it takes a while (Alacritty and Mason tools are built
# and downloaded from scratch). Logs go to tests/logs/<distro>.log. Your machine isn't touched:
# the repo is mounted read-only into the container.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
REPO="$PWD"
mkdir -p tests/logs

declare -A IMAGES=([ubuntu]=ubuntu:24.04 [fedora]=fedora:latest)
nvim_config=local
distros=()
for arg in "$@"; do
  case "$arg" in
    --github-nvim) nvim_config=github ;;
    *) distros+=("$arg") ;;
  esac
done
[ ${#distros[@]} -gt 0 ] || distros=(ubuntu fedora)

# Your local Neovim config (with uncommitted changes) is mounted read-only and copied in,
# so install.sh finds it already in place. With --github-nvim, install.sh clones it instead.
nvim_mount=()
[ "$nvim_config" = local ] && nvim_mount=(-v "$HOME/.config/nvim:/nvim-local:ro")

results=()
for distro in "${distros[@]}"; do
  image="${IMAGES[$distro]:?unknown distro: $distro (choose: ${!IMAGES[*]})}"
  log="tests/logs/$distro.log"
  echo "==> $distro ($image), Neovim config: $nvim_config, log: $log"
  if [ -n "$(docker ps -q --filter "name=^dotfiles-test-$distro\$")" ]; then
    echo "    a $distro test is already running; wait for it, or stop it: docker kill dotfiles-test-$distro"
    results+=("NOT RUN $distro (a test was already running)")
    continue
  fi
  docker build -q -t "dotfiles-test-$distro" --build-arg BASE="$image" tests >/dev/null

  # Install twice (the second run must succeed and change nothing), then check everything.
  if docker run --rm --init --name "dotfiles-test-$distro" -v "$REPO:/home/tester/dotfiles:ro" \
    "${nvim_mount[@]}" "dotfiles-test-$distro" bash -c '
      set -e
      if [ -d /nvim-local ]; then mkdir -p ~/.config && cp -a /nvim-local ~/.config/nvim; fi
      echo "### first install";  time ~/dotfiles/install.sh
      echo "### second install"; time ~/dotfiles/install.sh
      echo "### checks";         ~/dotfiles/tests/check.sh
    ' >"$log" 2>&1; then
    results+=("PASS $distro")
  else
    results+=("FAIL $distro (see $log)")
  fi
  sed -n '/### checks/,$p' "$log"
done

echo
printf '%s\n' "${results[@]}"
for result in "${results[@]}"; do [[ "$result" == PASS* ]] || exit 1; done
