# Building VIRYA: Synestezja

## Engine

Use Godot **4.7.1 stable** with GL Compatibility.

## macOS

```bash
brew install --cask godot
./run-macos.sh
```

## Full validation

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot ./validate.sh
```

Validation includes Python syntax, room/schema/resource contracts, mobile renderer and audio budgets, visual layer snapshots, release-generator regression, asset reporting, clean Godot import and runtime validation of all rooms.

## Visual captures

```bash
godot --path . --script res://tests/capture_rooms.gd
```

The captures land in Godot's `user://synesthesia-room-captures` directory. They are review artifacts, not committed build output.

## Web

```bash
./scripts/build-web-preview.sh
python3 -m http.server 8080 --directory build/web
```

The script downloads and verifies the pinned editor/templates only when a local Godot installation is unavailable, runs all gates, exports Web, injects the PWA shell and writes `asset-report.txt`.

## Android debug

With JDK 17, Android SDK and Godot templates installed:

```bash
mkdir -p build/android
godot --headless --path . --export-debug "Android Debug" build/android/synesthesia-debug.apk
```

The current preset targets arm64 and requests only internet and vibration. A production AAB requires a private release keystore.

## Quality profiles

- Battery: 180×320 reveal mask, 20 particles, low shader detail.
- Balanced: 270×480, 42 particles.
- High: 360×640, 72 particles.

All profiles retain the 540×960 logical viewport. Use the built-in diagnostics overlay only in debug/profiling sessions.

## CI

- `CI`: verified editor, import and runtime validation.
- `Build`: Linux, Web and Android artifacts.
- `Web preview`: verified PWA artifact and optional Netlify deployment.

Hosting credentials and DNS are deliberately not required for local builds.
