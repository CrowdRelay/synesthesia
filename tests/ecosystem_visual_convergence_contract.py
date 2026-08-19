#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
read = lambda rel: (ROOT / rel).read_text()
failures = []

tokens = read("scripts/ui/virya_design_tokens.gd")
expected = {
    'VOID': '070908', 'BG_RAISED': '0B100F', 'SURFACE': '101715',
    'SURFACE_RAISED': '16201D', 'TEXT': 'EEF4F1', 'TEXT_MUTED': '98A5A0',
    'HAIRLINE': '27322F', 'SIGNAL': '84B4AC', 'SIGNAL_HOT': '93C6C0',
    'SIGNAL_DEEP': '26655D', 'WARNING': 'F3C51A', 'DANGER': 'E73535',
    'SUCCESS': '70DB91',
}
for name, value in expected.items():
    if f'const {name}: Color = Color("{value}")' not in tokens:
        failures.append(f'canonical token drift: {name}={value}')

intro = read("scripts/ui/experience_intro_card.gd")
settings = read("scripts/ui/settings_card.gd")
hud = read("scripts/ui/hud_layout_flow.gd")
finale = read("scripts/ui/signal_finale_card.gd")
ui_factory = read("scripts/ui/ui_factory.gd")

for token in (
    'VIRYA // ODDZIAŁ SYNESTHESIA', 'WEJŚCIE // SESJA',
    'KARTA SESJI // SYGNAŁ // USTAWIENIA', 'ViryaDesign.SIGNAL_HOT',
):
    if token not in intro:
        failures.append(f'intro clinical chrome missing: {token}')
for token in ('VIRYA // ODDZIAŁ SYNESTHESIA', 'Parametry sesji', 'BODŹCE WZROKOWE', 'KARTA POSTĘPU'):
    if token not in settings:
        failures.append(f'settings clinical chrome missing: {token}')
for token in ('ViryaDesign.SIGNAL_HOT', 'ViryaDesign.TEXT_MUTED', 'ViryaDesign.SIGNAL_DEEP'):
    if token not in hud:
        failures.append(f'HUD product-token adoption missing: {token}')
for token in ('VIRYA // WYPIS Z ODDZIAŁU // FINAŁ', 'WYPIS // SYGNAŁ DOTARŁ // 5 PŁYT', 'ViryaDesign.SIGNAL'):
    if token not in finale:
        failures.append(f'finale clinical chrome missing: {token}')
if 'Color("71dcff")' in intro or 'Color("71dcff")' in finale or 'Color("43d6df")' in settings:
    failures.append('legacy cyan survives in fixed product chrome')
if 'var action_text := Color("07100e") if primary else ViryaDesign.TEXT' not in ui_factory:
    failures.append('primary mint action must use dark readable text like VIRYA/Signal')
if 'style.bg_color = primary_color' not in tokens:
    failures.append('primary product action is not a flat filled accent')
if (ROOT / 'scripts/app/finale_panel_builder.gd').exists():
    failures.append('dead duplicate finale panel builder must stay removed')
if (ROOT / 'scripts/app/finale_panel_builder.gd.uid').exists():
    failures.append('dead duplicate finale panel builder UID must stay removed')

# Sensory room art remains free to keep cyan/red/purple identities.
room_art = read("scripts/rooms/behaviors/technophobia.gd")
if 'Color("71dcff")' not in room_art or 'Color("ff5f7c")' not in room_art:
    failures.append('room art was incorrectly flattened into product chrome palette')

if failures:
    for failure in failures:
        print(f"FAIL: {failure}")
    raise SystemExit(f"SYNESTHESIA_ECOSYSTEM_VISUAL=FAIL count={len(failures)}")
print("SYNESTHESIA_ECOSYSTEM_VISUAL=PASS chrome=virya-v2-clinical-mint ward=psychiatric room-art=sensory-independent")
