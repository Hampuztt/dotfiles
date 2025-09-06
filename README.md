# Dotfiles Setup 

This repository bootstraps a development environment on Linux using [Ansible](https://docs.ansible.com/) and [uv](https://github.com/astral-sh/uv).

## Requirements
- Debian based distro
- `sudo` privileges  
- Internet 

## Quick start
Run the following script to install everything.


```bash
git clone https://github.com/hampuztt/dotfiles.git
cd dotfiles
chmod +x run.sh
./run.sh
```


## Modification
If you do not want to install everything (such as ros2), modify the book.yml file



## Default installation
The playbook with by default install the following

- `fzf`  
- `homebrew`  
- `tmux`  
- `neovim` (installed via Homebrew)  
- `nerdfonts` (for Neovim and terminal usage)  
