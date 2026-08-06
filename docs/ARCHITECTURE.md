# Architecture

## Product boundary

Synestezja is a standalone Godot application. It does not embed Virya Signal, n8n or the Virya Astro site. Public ecosystem integration is limited to a small CrowdRelay reward API after album completion.

## Runtime layers

- `main.gd` owns the eleven-room route, UI, persistence, transitions and reward orchestration.
- `paint_room.gd` owns gesture input, reveal cells, painting, room-specific scenes, special interactions and split-door animation.
- `audio_director.gd` owns the bounded procedural bed and transition into a local completion excerpt.
- `haptics.gd` owns rate limits and differentiated vibration patterns.
- `progress_store.gd` atomically stores versioned local state in `user://`.
- `reward_client.gd` serialises optional CrowdRelay requests without blocking gameplay.
- release manifests contain content and safe ranges, never executable code.

## Reveal model

The room uses a fixed reveal grid. Painting marks cells as uncovered. Uncovered cells show the proper scene; untouched cells retain Visual Snow, muted negative colour or a room-specific distortion. `completion_coverage` defines the practical amount of physical painting required. Progress is normalised against that threshold.

At `cinematic_reveal_at = 0.99`:

1. interaction freezes;
2. remaining traces resolve;
3. the local mask disappears;
4. the completion excerpt fades in;
5. haptics play the reveal pattern;
6. the split door animates open;
7. the next-room transition becomes available.

This deliberately removes the frustrating final-pixel hunt.

## Persistence

`progress_store.gd` stores:

- paint segments and occupied cells per room;
- discovered traces and special-interaction state;
- completed room IDs and current route index;
- sensory preferences;
- real elapsed time per completed room;
- server run token and server acknowledgement index;
- reward status, but never shipping details.

Writes use a temporary file, a short-lived backup and an atomic rename. Schema-v2 and legacy single-room saves are migrated when present; an interrupted commit can recover from the backup on the next start.

## Reward boundary

Gameplay is authoritative only for presentation; CrowdRelay is authoritative for the physical reward.

The server:

- creates an installation-bound run token;
- accepts rooms only in configured order;
- enforces server-side minimum wall time;
- limits one claim per run and one non-cancelled claim per campaign/e-mail;
- reserves from a campaign-wide stock limit;
- confirms e-mail ownership before collecting shipping data;
- stores shipping in a dedicated table;
- emits no address or phone in outbox payloads;
- records optional marketing consent separately.

If the network is unavailable, the application keeps playing and resynchronises completed rooms in order when a run becomes available. Once all rooms are acknowledged, it also submits the final album completion. Transient calls use bounded exponential backoff and an expired run is recreated without clearing local progress.

## Deployment boundary

The Web build is static and single-threaded. `synesthesia.virya.music` may be deployed independently of `virya.music`; this prevents Godot assets, caching and security headers from affecting the Astro site.


## Performance model

The renderer keeps interaction at 60 Hz but lowers idle redraw frequency. Untouched VSS cells are merged into horizontal strips, paint history is bounded, progress events are emitted once per gesture batch, and procedural audio catch-up is capped per frame. Resize events rebuild room hit geometry without resetting interaction state.

The Web build is post-processed into a small PWA. Navigation and runtime assets are network-first; media uses stale-while-revalidate; reward routes and private responses are never cached.
