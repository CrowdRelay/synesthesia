# VIRYA: Synestezja

A playable sensory edition of VIRYA's **Echoes Of The Modern Mind**, built with Godot 4.7.1.

The album becomes eleven rooms. The player paints through Visual Snow, muted negative colour and room-specific distortions. Every gesture repairs or reveals part of the scene; at **99%** the remaining filter releases at once, the song excerpt enters, and the next door opens.

## Album route

1. **Wave of Uncertainty** — a calm tidal chamber.
2. **Party Time** — balloons, popping, colour and confetti.
3. **Unmasked** — a Venetian dressing room where masks leave the walls.
4. **The Calling** — an elegant monochrome dinner with a red-wine toast.
5. **Seed of Doubt** — a seed growing into a full tree.
6. **Hybrid** — a Western street duel against an inherited authority figure.
7. **Technophobia** — screens, cables, ZZZ scan jitter and glitches repaired by paint.
8. **Invaluable** — a mirror gallery whose panes can be cracked.
9. **From the Ashes** — falling ash and a phoenix forming from embers.
10. **Waves** — an intimate bedroom in warm half-light.
11. **Rise** — a bright atrium and the album finale.

Each room has its own palette, architecture, interaction, haptic profile and gently faded local music excerpt.

## Interaction and accessibility

- touch and mouse painting;
- local reveal mask instead of a global progress bar trick;
- restrained haptics for painting, discoveries, balloons, mirrors, duel, reveal and doors;
- calm and full sensory modes;
- independent haptics toggle;
- immediate **Uspokój** control disabling music intensity, Visual Snow and vibration;
- no strobe, jumpscares, artificial streaks, analytics, ads or forced sharing;
- local, versioned progress for every room and the complete album route.

Gameplay remains usable offline. Network access is used only for the optional completion reward.

## Completion reward

After all eleven rooms, the player may claim one physical VIRYA album. The client only submits the verified run, e-mail, optional Signal consent and city. Shipping details are collected later through a separate no-store page and remain outside Signal and webhook payloads.

The matching CrowdRelay overlay is distributed separately. Until that backend is deployed, completion remains saved locally and the game reports the reward service as unavailable without losing progress.

## Run on macOS

```bash
./run-macos.sh
```

The script uses `/Applications/Godot.app/Contents/MacOS/Godot`, `GODOT_BIN`, or a `godot` executable on `PATH`.

## Validate

```bash
./validate.sh
```

The runtime gate fails on Godot's exit code **and** on `SCRIPT ERROR:`, `Parse Error:` or `ERROR:` in the engine log.

## Web preview

```bash
./scripts/build-web-preview.sh
python3 -m http.server 8080 --directory build/web
```

The generated static site is prepared for `https://synesthesia.virya.music`. The Web preset is single-threaded to avoid a SharedArrayBuffer dependency. The reward page is available at `/reward/`.

GitHub workflow `Web preview` builds the exact same directory and deploys it only when `NETLIFY_AUTH_TOKEN` and `NETLIFY_SITE_ID` are configured.

## Build artifacts

The `Build` workflow produces:

- Linux x86_64 archive;
- single-threaded Web export;
- Android arm64 debug APK with `INTERNET` and `VIBRATE` permissions.

Run it through **Actions → Build → Run workflow → all**. Tagged `v*` commits publish the artifacts as a GitHub Release.

## Repository structure

The Godot project is the repository root. Do not restore a nested application folder.

```text
synesthesia/
├── project.godot
├── scenes/
├── scripts/
├── shaders/
├── assets/audio/
├── data/release_index.json
├── data/releases/<room>/manifest.json
├── web/reward/
└── .github/workflows/
```

## Rights

Project source follows the repository licence. VIRYA names, logos, recordings, excerpts, lyrics and artwork remain the property of their respective rights holders and are not relicensed by the source-code licence.
