#!/bin/bash
set -e

# Install uv
if ! command -v uv &> /dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # Add uv to PATH for current shell
    . "$HOME/.local/bin/env"
fi

# Run Ansible playbook
uvx --from ansible ansible-playbook book.yml -i localhost, -c local -k --ask-become-pass
