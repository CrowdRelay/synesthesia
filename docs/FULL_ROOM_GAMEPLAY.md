# Full Room Gameplay

This document defines the production contract for the eleven interactive rooms. Runtime behavior is authoritative in `scripts/rooms/behaviors/`; asset slots and budgets are authoritative in `data/room_asset_slots.json`.

## Shared room loop

Each room is a discoverable micro-interaction rather than a paint-to-unlock gate:

1. Open on authored scene art with a diegetic interaction hint.
2. Capture pointer input only over semantic targets reported by the behavior.
3. Drive progress through the room-specific mechanic; brushing is assistance only.
4. Overlap the hero reveal with the living post-reveal loop.
5. Leave the completed room explorable without automatically awarding optional echoes.

Every behavior provides `interaction_hint()`, `hint_targets()`, `captures_pointer_at()`, and `mechanic_progress()`. Hints adapt while the player is idle and do not obscure active interaction.

## Visual and asset contract

- Style: `virya-signal-v2-moodboard-locked`.
- Minimum master size: 1080 x 1920.
- Runtime art uses separated scene, background, subject, foreground, and prop/FX layers.
- Transparent props originate from lossless masters and ship as WebP or PNG.
- Each room has a 900 KiB runtime prop/FX budget; related small effects should be atlased.
- Faces remain abstract silhouettes; literal portrait treatment is excluded.
- Motion uses transforms, masks, particles, and localized shaders. Legacy cinematics may add only low-amplitude texture.

## Room mechanics and slots

| Room | Core interaction | Required prop/FX slots |
| --- | --- | --- |
| Wave of Uncertainty | Calm the moving wave and restore its horizon | foam foreground, water streaks, horizon signal, spray particles |
| Party Time | Discover and pop the trembling balloon shells | balloon atlas, confetti atlas, disco glints, party stains |
| Unmasked | Remove the masks and expose the presence beneath | mask atlas, mask cracks, mask straps, ceremony dust |
| The Calling | Hold the table pulse, pour, and complete the toast | wine bottle, wine glass, candle glow, table stains, glass condensation |
| Seed of Doubt | Find and hold the seed, then grow it to its crown | seed, root tendrils, soil cracks, leaf dust, organic stains |
| Hybrid | Establish aim and resolve the opposing silhouettes | dust atlas, impact decals, metal scratches, duel silhouette |
| Technophobia | Pull plugs, hold the breaker, and tune the signal | cable atlas, plug atlas, socket atlas, screen cracks, CRT noise masks, spark atlas, burnt-electronics stains |
| Invaluable | Crack and shatter the mirror set | mirror cracks, glass shards, fingerprint stains, reflection slices |
| From the Ashes | Gather the ash current and awaken the phoenix | ash atlas, ember atlas, wing traces, burn marks, smoke wisps |
| Waves | Discover the presence and synchronize the shared rhythm | curtain layer, lamp glow, window rain, breath fog, bedroom dust |
| Rise | Open the vertical light and complete the final gesture | light rays, dust motes, halo rings, atrium glass, final signal traces |

## Completion and accessibility

Progress remains legible through visual and audio response, with semantic haptics where available. Every mechanic has a reachable mouse and touch completion path. Seed of Doubt accepts tap, hold, or press input and cannot strand the player behind a hidden crown threshold.

After completing the required mechanic, the player may continue searching for echoes or leave for Album Mode. Living accents and localized material effects remain active so the completed scene never freezes into a still image.
