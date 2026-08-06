#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_GODOT="/Applications/Godot.app/Contents/MacOS/Godot"

if [[ -x "${GODOT_BIN:-}" ]]; then
  GODOT="${GODOT_BIN}"
elif [[ -x "$DEFAULT_GODOT" ]]; then
  GODOT="$DEFAULT_GODOT"
elif command -v godot >/dev/null 2>&1; then
  GODOT="$(command -v godot)"
else
  echo "Godot 4.7.1 is not installed. Run: brew install --cask godot" >&2
  exit 1
fi

exec "$GODOT" --path "$ROOT"
