#!/usr/bin/env bash
set -Eeuo pipefail

platform="${1:-$(uname -s)}"
case "$platform" in
  Darwin)
    printf '%s\n' "$HOME/Library/Application Support/Godot"
    ;;
  *)
    printf '%s\n' "$HOME/.local/share/godot"
    ;;
esac
