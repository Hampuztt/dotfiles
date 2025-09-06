#!/bin/bash
set -e
sudo apt update
sudo apt install -y curl git

# Install uv
if ! command -v uv &> /dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # Add uv to PATH for current shell
    . "$HOME/.bashrc"
fi

# Run Ansible playbook
uvx ansible-playbook book.yml -i localhost, -c local -k --ask-become-pass
