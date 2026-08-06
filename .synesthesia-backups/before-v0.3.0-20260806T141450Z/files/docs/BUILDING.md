# Building VIRYA: Synestezja

## Supported prototype targets

The repository currently defines export presets for:

- Linux x86_64;
- Web;
- Android arm64 debug APK.

The Android artifact is a development build for direct device testing. It is not a Play Store release and does not use a production signing key.

## Local validation

From the Godot project directory:

```bash
./validate.sh
```

To use a Godot executable outside `PATH`:

```bash
GODOT_BIN=/absolute/path/to/godot ./validate.sh
```

Validation performs static manifest and safety checks, then loads the project and main scene headlessly when Godot is available.

## Local editor run

1. Install Godot 4.7.1.
2. Import `project.godot`.
3. Press F6 or F5.

The prototype uses GL Compatibility and a portrait viewport.

## Local command-line exports

Install the official Godot 4.7.1 export templates first, then run:

```bash
mkdir -p build/linux build/web build/android

godot --headless --path . --export-release Linux build/linux/synesthesia.x86_64
godot --headless --path . --export-release Web build/web/index.html
godot --headless --path . --export-debug "Android Debug" build/android/synesthesia-debug.apk
```

Android export also requires a configured Android SDK, JDK 17, and a debug keystore. The preset enables only arm64 and the VIBRATE permission.

## GitHub Actions

The repository root must be the outer `synesthesia/` directory so that GitHub can discover `.github/workflows/`.

### CI

`CI` runs automatically on every push and pull request. It validates the data model and runs Godot 4.7.1 headlessly using an editor archive whose SHA-256 checksum is pinned in the workflow.

### Manual builds

Open **Actions → Build → Run workflow** and select one target:

- `desktop-web`;
- `android`;
- `all`.

Artifacts are stored with the workflow run for 14 days.

### Tagged releases

Create and push a semantic version tag:

```bash
git tag v0.2.0
git push origin v0.2.0
```

The build workflow exports every target and creates or updates a GitHub Release containing the generated archives.

## Creating the GitHub repository

From inside the outer `synesthesia/` directory:

```bash
git init
git add .
git commit -m "feat: start VIRYA Synesthesia"
```

With GitHub CLI authenticated:

```bash
gh repo create synesthesia --private --source=. --remote=origin --push
```

A public repository is also possible, but do not include private music stems, signing keys, unreleased artwork, or production credentials.

## Production Android signing

The workflow intentionally builds a debug APK. Before store distribution:

1. create a private release keystore outside the repository;
2. store it as an encrypted GitHub Actions secret;
3. materialize it only during a protected release job;
4. use environment protection and required reviewers;
5. build an AAB with a separate production preset;
6. never reuse the debug signing configuration.
