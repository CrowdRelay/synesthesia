# VIRYA: Synestezja

A playable sensory edition of VIRYA's **Echoes Of The Modern Mind**, built with Godot 4.7.1.

The album becomes eleven rooms. The player paints through Visual Snow, muted negative colour and room-specific distortions. Every gesture repairs or reveals part of the scene; at **99%** the remaining filter releases at once, the song excerpt enters and the next door opens.

## Album route

1. **Wave of Uncertainty** — a calm tidal chamber.
2. **Party Time** — balloons, popping, colour and confetti.
3. **Unmasked** — a Venetian dressing room where masks leave the walls.
4. **The Calling** — an elegant monochrome dinner with a red-wine toast.
5. **Seed of Doubt** — a seed growing into a full tree.
6. **Hybrid** — a Western street duel against inherited authority.
7. **Technophobia** — screens, cables, ZZZ scan jitter and glitches repaired by paint.
8. **Invaluable** — a mirror gallery whose panes can be cracked.
9. **From the Ashes** — falling ash and a phoenix forming from embers.
10. **Waves** — an intimate bedroom in warm half-light.
11. **Rise** — a bright atrium and the album finale.

Each room has its own palette, architecture, interaction, haptic profile and gently faded local music excerpt.

## v0.7 performance and polish

- adaptive rendering: full responsiveness while painting, lower idle redraw rates and a 10 Hz reduced-motion path;
- horizontally merged VSS mask strips and a bounded retained-stroke budget;
- batched progress events and protected repeatable interactions;
- responsive touch geometry after phone rotation or browser resize;
- compact mobile controls, album progress, palette preview and scrollable modals;
- atomic progress saves with backup recovery and schema migration;
- offline-safe reward synchronisation with bounded retries and expired-run recovery;
- installable Web preview with a versioned service worker and cache-safe deploy headers;
- bounded procedural audio work, Master hard limiter and room-safe delayed haptics.

## Interaction and accessibility

- touch and mouse painting;
- restrained haptics for painting, discoveries, balloons, mirrors, duel, reveal and doors;
- calm and full sensory modes;
- independent haptics toggle;
- immediate **Uspokój** control reducing motion, Visual Snow, sound intensity and vibration;
- no strobe, jumpscares, analytics, ads or forced sharing;
- local progress for every room and the complete album route.

Gameplay remains usable offline. Network access is used only for the optional completion reward.

## Completion reward

After all eleven rooms, the player may claim one physical VIRYA album. The client sends the verified run, e-mail, optional Signal consent and city. Shipping details are collected later through a separate no-store page and remain outside Signal and webhook payloads.

When connectivity returns, locally completed rooms are submitted in order and the album completion is finalised automatically. An expired run is replaced without deleting local gameplay progress.

## Run on macOS

```bash
./run-macos.sh
```

The script uses `/Applications/Godot.app/Contents/MacOS/Godot`, `GODOT_BIN`, or a `godot` executable on `PATH`.

## Validate

```bash
./validate.sh
```

The gate checks content contracts, explicit mobile performance budgets and the real Godot import/runtime. It fails on the process exit code and fatal diagnostics in the engine log.

## Web preview

```bash
./scripts/build-web-preview.sh
python3 -m http.server 8080 --directory build/web
```

The generated PWA is prepared for `https://synesthesia.virya.music`. The reward page is available at `/reward/`. The service worker uses network-first navigation/runtime assets and stale-while-revalidate for media, preventing stale deploys while keeping repeat visits fast.

GitHub workflow `Web preview` builds the same directory and deploys it only when `NETLIFY_AUTH_TOKEN` and `NETLIFY_SITE_ID` are configured.

## Build artifacts

The `Build` workflow produces Linux x86_64, single-threaded Web and Android arm64 debug artifacts. Tagged `v*` commits publish them as a GitHub Release.

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

## v0.8 visual language

Every room now uses a thematic comic brush and a room-owned art-direction profile. The hidden image sits beneath animated CRT/cosmic static; the gesture behaves like a compact Photoshop-style textured stamp rather than a circular cursor. At 99% the static drops, the complete panel resolves and the doors open.
