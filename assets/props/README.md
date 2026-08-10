# VIRYA Signal room props

Runtime slots are declared in `data/room_asset_slots.json`.

Rules:
- assets are authored as isolated transparent props/decals, not flattened fake screenshots;
- use the approved Signal language: charcoal, 1px technical lines, selective red/cyan/purple/dirty-white, waveform/ring geometry, controlled grain;
- literal portraits are forbidden for v1; band members are represented as abstract silhouettes/personas;
- props must support animation by transform/mask/shader so the Web build does not need full-frame video for every reaction;
- keep each room under the declared runtime budget and atlas related tiny FX where possible.
