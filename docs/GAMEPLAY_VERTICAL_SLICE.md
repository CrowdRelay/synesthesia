# Gameplay Vertical Slice — Technophobia

## Experience goal
Synesthesia should feel like a music-discovery adventure, not a completion bar. The player notices a cause, manipulates it, sees/hears the consequence, and discovers a trace of the album world.

## Live loop in Technophobia
1. **Discover the plugs** — three live cables feed the noisy screen wall.
2. **Pull a cable** — press a glowing plug, drag it far enough from the socket, release.
3. **Immediate payoff** — cable hangs loose, spark/glitch FX fires, haptic + tactile SFX plays, a screen pair goes quiet and the noise/music mix advances.
4. **Cut main power** — after enough sources are disconnected, hold the breaker.
5. **Tune the signal** — drag the circular tuner until the signal locks.
6. **Explore** — three existing echoes remain discoverable and painting is still an accessibility/reveal assist.

## Interaction rules
- Semantic props capture the pointer; the reveal brush never paints underneath a cable pull, breaker hold or tuner drag.
- Painting cannot complete Technophobia.
- Progress is causal: cable state -> breaker -> tuner -> signal lock.
- Every successful semantic interaction has visual + audio + haptic feedback.
- HUD instructions update from the room's current state.

## Pattern for the remaining rooms
Use the same structure: 3–6 discoverable interactions, one small dependency chain, a visible before/after state, and a music/noise consequence. Keep puzzles readable on mobile and avoid inventory/menu puzzle abstractions.
