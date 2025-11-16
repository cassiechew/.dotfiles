#!/usr/bin/env bash

# Temporary for now

PROC=$(ps -o comm= -p "$1" | tr '[:upper:]' '[:lower:]')

case "$PROC" in
  nvim|vim)
    echo "" ;;          # Neovim icon
  zsh|bash|fish)
    echo "" ;;          # Terminal icon
  node)
    echo "" ;;          # Node.js
  npm|pnpm|yarn)
    echo "" ;;          # Treat all JS toolchains same
  docker|dockerd)
    echo "" ;;          # Docker
  python|python3)
    echo "" ;;          # Python
  git)
    echo "󰊢" ;;          # Git
  lazygit)
    echo "󰊢" ;;          # Git
  ssh)
    echo "󰣀" ;;          # SSH
  *)
    echo "" ;;          # Default: terminal
esac

