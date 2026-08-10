# Synesthesia 2.0.0 — release notes

## Visual reboot

- Rebuilt or replaced all 11 runtime room scene/background/subject/foreground stacks.
- Locked the application to the accepted VIRYA Signal moodboard: charcoal surfaces, hairline borders, red/cyan/purple/dirty-white accents, waveform and concentric-ring language.
- Added high-resolution-derived menu, corridor and finale world art.
- Replaced the old visible eye/comic material with a Signal glyph/portal treatment while retaining compatible resource paths.
- Rebuilt native/PWA application icons around the Signal waveform/ring mark.
- Rebuilt the browser/native boot poster and loop around the V2 portal artwork.
- Reduced legacy cinematic clips to secondary low-amplitude motion texture so V2 room art remains the visual source of truth.

## Gameplay

- Eleven rooms use mechanic-first completion with paint/reveal retained as assist.
- Semantic pointer capture prevents painting while manipulating puzzle objects.
- Hidden echoes are optional discoveries rather than automatic completion rewards.
- Seed of Doubt no longer has a hidden timed finishing swipe and cannot dead-end after successful growth.
- Technophobia is the reference vertical slice: cable pulls, power breaker, tuner lock, monitor/noise response, SFX and haptics.
- Remaining rooms follow the same notice → manipulate → response → changed-world → echo/payoff contract.

## UI / UX

- Menu is a left navigation rail over full V2 world art.
- Korytarz uses V2 background art and per-room scene thumbnails.
- Finale uses the V2 Signal constellation and band roster.
- Settings and confirmation surfaces inherit the same product tokens.
- Finale email input is focus/virtual-keyboard/scroll safe on touch devices.
- Technical radius system reduced to 2–4 px and broad comic/button treatments removed from active product surfaces.

## Band identity

- GŁOS — Yanusin
- GITARA — Mr R
- BAS — Lubek
- PERA — Koobosky

Avatar components remain intentionally abstract. Final Viryatkowo portrait assets can replace avatar interiors later without changing layouts or interaction contracts.

## Validation

The source-contract suite, V2 art contract, gameplay contracts, performance budget, memory budget, audio mix budget and asset report pass in the build environment. The canonical wrapper cannot fetch bundled font sources in the current sandbox because DNS access to the pinned upstream font files is unavailable; the offline font supply-chain contract itself passes. A real Godot runtime/import smoke still requires a machine with Godot 4.7.1 installed.
