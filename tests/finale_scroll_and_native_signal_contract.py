#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
layout = (ROOT / 'scripts/ui/signal_finale_layout.gd').read_text()
card = (ROOT / 'scripts/ui/signal_finale_card.gd').read_text()
fallback = (ROOT / 'scripts/ui/signal_finale_fallback_card.gd').read_text()
cta = (ROOT / 'scripts/ui/signal_cta_state.gd').read_text()

# Android soft-keyboard changes viewport size. A resize must preserve the user's
# scroll position and only re-ensure the focused field instead of jumping home.
assert 'app.call_deferred("_scroll_to_start")' not in layout
assert card.count('call_deferred("_scroll_to_start")') == 1, 'full finale may reset scroll only during initial configure'
assert fallback.count('call_deferred("_scroll_to_start")') == 1, 'fallback finale may reset scroll only during initial configure'
for source in (card, fallback):
    resize = source.split('func _notification(what: int)', 1)[1]
    assert 'if _email != null and _email.has_focus()' in resize
    assert 'call_deferred("_ensure_email_visible_after_layout")' in resize
    assert 'await get_tree().process_frame' in source

# A ScrollContainer clamps a child that expands along the scroll axis, which
# silently disables scrolling while still drawing the scrollbar.
for name, source in (('finale', card), ('fallback', fallback)):
    stack = source.split('_scroll.add_child(_layout)', 1)[0].rsplit('_panel.add_child(_scroll)', 1)[1]
    assert 'size_flags_vertical = Control.SIZE_EXPAND_FILL' not in stack, (
        f'{name} scroll content must not expand along the scroll axis'
    )

# Installed Signal is the primary Android transport. HTTPS remains a fallback
# if the custom scheme cannot be opened, so web and older installs stay usable.
assert 'virya-signal://my-signal?source=%s' in cta
open_signal = card.split('func _open_signal() -> void:', 1)[1].split('\nfunc ', 1)[0]
assert 'OS.has_feature("android")' in open_signal
assert 'SignalCtaState.signal_app_url(handoff)' in open_signal
assert 'native_result == OK' in open_signal
assert 'SignalCtaState.my_signal_url(handoff)' in open_signal
assert open_signal.index('signal_app_url') < open_signal.index('my_signal_url')

print('SYNESTHESIA_FINALE_HANDOFF=PASS scroll=keyboard-stable android=native-first https=fallback')
