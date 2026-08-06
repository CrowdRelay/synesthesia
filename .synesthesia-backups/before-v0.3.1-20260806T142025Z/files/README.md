# VIRYA: Synestezja

An interactive sensory album and exploratory game built with Godot 4.7.1.

Synestezja turns VIRYA releases into small playable spaces. Each song or release can become a room that the player enters, paints, listens to, and gradually uncovers through touch, image, sound, and restrained haptic feedback.

The project is designed as a calm alternative to attention-driven social media promotion. Music is discovered through interaction rather than interrupted by banners, timers, streaks, or forced calls to action.

## Current prototype

The first vertical slice includes:

- mouse and touch painting;
- brush behaviour reacting to gesture speed;
- hidden narrative traces and collectibles;
- layered procedural audio;
- subtle visual-noise treatment;
- optional restrained haptics;
- calm and full sensory modes;
- an immediate **Calm the room** action;
- data-driven release manifests for future singles and albums.

The prototype is offline-first and currently contains no accounts, analytics, advertisements, backend dependency, or coercive engagement mechanics.

## Design principles

- Experience before promotion.
- Calm by default.
- Every sensory effect remains optional and adjustable.
- No sudden volume jumps or aggressive flashing.
- No streaks, leaderboards, artificial scarcity, or forced sharing.
- New releases should add a meaningful room, interaction, or sensory texture—not only another menu item.

## Technology

- Godot 4.7.1
- GDScript
- JSON release manifests
- Android first
- Linux and Web builds for development and review

The Godot project lives directly at the repository root. There is intentionally no nested application directory.

## Run locally

Open `project.godot` in Godot 4.7.1 and run the main scene.

From the command line:

```bash
godot --path .
```

## Validate

```bash
./validate.sh
```

CI additionally rejects any `ERROR:` or `SCRIPT ERROR:` emitted by Godot, even when the engine exits with status code zero.

## Build

GitHub Actions provides:

- **CI** on pushes and pull requests;
- **Build** for Linux, Web, and Android debug APK artifacts.

Run a build through:

```text
Actions → Build → Run workflow → all
```

Pushing a tag matching `v*` builds all platforms and creates a GitHub Release.

```bash
git tag v0.2.1
git push origin v0.2.1
```

## Add another release pack

```bash
python3 tools/new_release_pack.py brak-sygnalu \
  --title "VIRYA: Brak sygnału" \
  --room "Transmission Room" \
  --activate
```

See `docs/RELEASE_PACK_SCHEMA.md` for the content contract and `docs/BUILDING.md` for platform build details.

## Status

Early experimental prototype. The first goal is to validate whether painting, audio layers, and restrained haptics feel enjoyable on a physical Android device before expanding the world.

## License

Source code is available under the repository license. VIRYA names, logos, music, recordings, stems, lyrics, and artwork remain the property of their respective rights holders.
