# Synesthesia V2 — Production Direction

V2 is the production implementation of the accepted VIRYA Signal moodboard. The board is a visual acceptance test, not loose inspiration.

## Locked visual system

- near-black / charcoal world surfaces;
- thin 1 px technical hairlines and small 2–4 px radii;
- VIRYA red, Signal cyan, bass purple and dirty white used selectively;
- waveform, concentric signal rings and vertical signal beam as recurring motifs;
- photoreal / cinematic room art first, UI second;
- no board-game frames, broad comic textures, generic RPG cards or glossy mobile-game hotspots;
- faces remain abstract/silhouetted until the band portrait pass is ready.

## Runtime V2 art

All eleven rooms ship with new or substantially rebuilt `scene`, `background`, `subject` and `foreground` layers. High-quality generated masters are flattened into the existing bounded 2.5D runtime geometry so Web/mobile memory stays predictable.

The room pipeline uses:

1. authored room still as the hero image;
2. low-frequency dark background for parallax;
3. transparent signal/subject light layer;
4. transparent foreground material/particle layer;
5. shader signal-loss → clean-music reveal;
6. room-specific behavior rendering and microinteraction FX.

## Interaction promise

Every room follows:

**notice → manipulate → immediate audiovisual response → changed world state → optional echo → payoff**

The paint/reveal system remains as an accessibility assist. It is no longer the primary game.

## Motion

Old source cinematics are retained only as low-amplitude motion texture so they cannot visually replace V2 art. The hero motion comes from parallax, procedural room behavior, physical interaction state, signal FX and the new V2 portal boot loop.

## Brand surfaces

- Boot + menu: `assets/v2/branding/menu-world.webp`
- Album corridor: `assets/v2/branding/corridor-world.webp`
- Finale: `assets/v2/branding/finale-world.webp`
- App icons: Signal waveform/ring system
- Avatars: Yanusin / Mr R / Lubek / Koobosky

## Future portrait pass

The avatar component is intentionally stable. When final Viryatkowo photos exist, replace only avatar interiors and selected room subject layers. Ring geometry, waveform treatment, colors, roles and layout remain unchanged.
