from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
guide = (ROOT / "scripts/app/interaction_guide.gd").read_text()
hint = (ROOT / "scripts/render/interaction_hint_layer.gd").read_text()
hud = (ROOT / "scripts/ui/hud_layout_flow.gd").read_text()
app_hud = (ROOT / "scripts/ui/app_hud.gd").read_text()
shader = (ROOT / "shaders/room_composite.gdshader").read_text()
setup = (ROOT / "scripts/render/room_visual_setup.gd").read_text()

assert "FIRST_IDLE_SECONDS := 2.8" in guide
assert "visual_hint_changed.emit(0.62)" in guide
assert "portrait_gain" in hint and "1.28" in hint
assert 'add_theme_font_size_override("font_size", 15)' in hud
assert "108.0 * app._ui_scale" in hud
assert 'replace(" · ", "\\n")' in app_hud
assert "uniform float display_clarity" in shader
assert "mix(1.0, 0.72, display_clarity)" in shader
assert 'set_shader_parameter("display_clarity"' in setup
assert "texture(" not in shader[shader.index("uniform float display_clarity"):shader.index("void fragment")]

print("SYNESTHESIA_MOBILE_CLARITY=PASS cue<=2.8s hint=large safe-area=true renderer=single-pass")
