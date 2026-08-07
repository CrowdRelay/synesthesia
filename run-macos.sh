#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
RESET=0
RESET_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --reset) RESET=1 ;;
    --reset-only) RESET=1; RESET_ONLY=1 ;;
    *) echo "Unknown option: $arg" >&2; echo "Usage: ./run-macos.sh [--reset|--reset-only]" >&2; exit 2 ;;
  esac
done

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

GODOT_VERSION="$($GODOT --version 2>/dev/null | head -n 1 || true)"
case "$GODOT_VERSION" in
  4.7.1*) ;;
  *) echo "Godot 4.7.1 is required; got ${GODOT_VERSION:-unknown}" >&2; exit 3 ;;
esac

required_audio=(
  pink-noise-asmr-loop.ogg
  balloon-pop.mp3
  wave-of-uncertainty-room-outro.mp3
  party-time-room-outro.mp3
  unmasked-room-outro.mp3
  the-calling-room-outro.mp3
  seed-of-doubt-room-outro.mp3
  hybrid-room-outro.mp3
  technophobia-room-outro.mp3
  invaluable-room-outro.mp3
  from-the-ashes-room-outro.mp3
  waves-room-outro.mp3
  rise-room-outro.mp3
)
for name in "${required_audio[@]}"; do
  [[ -s "$ROOT/assets/audio/$name" ]] || { echo "Missing audio asset: assets/audio/$name" >&2; exit 4; }
done
required_sensory_audio=(
  ambience/uncertainty.wav ambience/party.wav ambience/unmasked.wav ambience/calling.wav
  ambience/seed.wav ambience/hybrid.wav ambience/technophobia.wav ambience/invaluable.wav
  ambience/ashes.wav ambience/waves.wav ambience/rise.wav
  sfx/glass-clink.wav sfx/wood-creak.wav sfx/gunshot.wav sfx/mirror-shatter.wav
  sfx/wing-whoosh.wav sfx/electric-bzz.wav sfx/mask-whisper.wav sfx/wave-slap.wav
  sfx/light-rise.wav sfx/presence-wind.wav sfx/door-close.wav sfx/door-open.wav sfx/teleport-suck.wav
)
for name in "${required_sensory_audio[@]}"; do
  [[ -s "$ROOT/assets/audio/$name" ]] || { echo "Missing sensory audio asset: assets/audio/$name" >&2; exit 4; }
done
[[ -s "$ROOT/assets/finale/echoes-finale.webp" ]] || { echo "Missing finale artwork: assets/finale/echoes-finale.webp" >&2; exit 4; }
required_video=(uncertainty party unmasked calling seed hybrid technophobia invaluable ashes waves rise finale)
for name in "${required_video[@]}"; do
  [[ -s "$ROOT/assets/video/$name.ogv" ]] || { echo "Missing cinematic video: assets/video/$name.ogv" >&2; exit 4; }
done

# A source checkout needs Godot's imported cache for MP3/OGG/WebP resources.
# v0.11.0 used to delete .godot after validation, which made real assets look missing at runtime.
# The old settings-gear.svg triggered a Godot 4.7.1 macOS headless importer crash.
# It is procedural now; purge only that legacy imported cache before the editor scan.
if [[ -d "$ROOT/.godot/imported" ]]; then
  find "$ROOT/.godot/imported" -maxdepth 1 -type f -name 'settings-gear.svg-*' -delete 2>/dev/null || true
fi
IMPORT_LOG="$(mktemp "${TMPDIR:-/tmp}/synesthesia-import.XXXXXX.log")"
trap 'rm -f "$IMPORT_LOG"' EXIT
set +e
"$GODOT" --headless --editor --path "$ROOT" --quit >"$IMPORT_LOG" 2>&1
IMPORT_STATUS=$?
set -e
if (( IMPORT_STATUS != 0 )) || grep -Eiq '(SCRIPT ERROR:|Parse Error:|Parser Error:|Compile Error:|Failed to load script|Failed loading resource|Shader error:)' "$IMPORT_LOG"; then
  cat "$IMPORT_LOG" >&2
  echo "Synestezja import failed; game was not started." >&2
  exit 5
fi

if (( RESET == 1 )); then
  "$GODOT" --headless --path "$ROOT" --script res://tools/reset_local_progress.gd
  if (( RESET_ONLY == 1 )); then
    exit 0
  fi
fi

rm -f "$IMPORT_LOG"
trap - EXIT
SYNESTHESIA_LOCAL_DEBUG=1 exec "$GODOT" --path "$ROOT"
