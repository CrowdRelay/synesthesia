# Building VIRYA: Synestezja

## Required engine

Use Godot **4.7.1 stable**. The project uses GL Compatibility and a portrait viewport.

## macOS

```bash
brew install --cask godot
./run-macos.sh
```

Validate with the same installed binary:

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot ./validate.sh
```

## Static and runtime validation

```bash
./validate.sh
```

Static validation checks all eleven manifests, their exact order, excerpts, sensory bounds, renderers, permissions, Web deployment files, reward contracts and explicit mobile performance budgets. Runtime validation asks Godot to load every script, every manifest, every excerpt and the main scene. The shell gate also rejects engine error text even when Godot exits with code zero.

## Web preview

```bash
./scripts/build-web-preview.sh
python3 -m http.server 8080 --directory build/web
```

The build script:

1. finds a local Godot binary or downloads the pinned 4.7.1 Linux editor;
2. verifies the editor archive SHA-256;
3. installs matching export templates when necessary;
4. runs static and runtime import gates;
5. exports the single-threaded Web preset;
6. copies the static reward page and Netlify headers;
7. injects the PWA manifest and service-worker registration;
8. writes `asset-report.txt` for deploy inspection.

Output: `build/web/`.

## Android debug APK

Install Android SDK, JDK 17 and official Godot export templates, then run:

```bash
mkdir -p build/android
godot --headless --path . --export-debug "Android Debug" build/android/synesthesia-debug.apk
```

The development preset targets arm64 and declares `INTERNET` and `VIBRATE`. Production distribution still requires a private release keystore and a separate AAB preset.

## GitHub Actions

- `CI`: static checks, verified Godot editor, clean import and runtime validation.
- `Build`: Linux, Web and Android artifacts.
- `Web preview`: `build/web` artifact and optional Netlify deployment.

Set these repository secrets only for automated Netlify deployment:

- `NETLIFY_AUTH_TOKEN`
- `NETLIFY_SITE_ID`

No CrowdRelay secret is needed in the client. The API is public, while run operations use a per-run bearer token.

## Domain

Create a separate Netlify site from this repository, use `build/web` as the publish directory, then attach `synesthesia.virya.music`. Add `https://synesthesia.virya.music` to CrowdRelay's allowed CORS origins before enabling real reward claims.


## Performance budget

```bash
python3 tools/perf_budget.py
```

The budget prevents accidental regressions in retained paint segments, idle redraw frequency, reduced-motion frequency and VSS strip merging.
