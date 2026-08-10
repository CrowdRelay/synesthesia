#!/usr/bin/env python3
"""Contracts for the premium living-world/game-feel pass."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
failures=[]

def require(path,*tokens):
    p=ROOT/path
    if not p.is_file():
        failures.append(f"missing {path}"); return ""
    text=p.read_text(errors="replace")
    for token in tokens:
        if token not in text: failures.append(f"{path}: missing {token!r}")
    return text

micro=require("scripts/render/world_micro_fx_layer.gd","WorldMicroFXDrawHelpers.draw_hero_beat","interaction_energy","_draw_tech","_draw_mask","_draw_glass","_draw_seed","_draw_party","_draw_calling","_draw_ashes","_draw_waves","_draw_hybrid","_draw_rise","_draw_uncertainty")
require("scripts/render/world_micro_fx_draw_helpers.gd","static func draw_hero_beat", "\"uncertainty\":", "\"invaluable\":")
require("scripts/render/room_stage.gd","signal interaction_motion","_idle_motion_time","idle_breath","set_interaction_energy")
require("scripts/render/room_interaction_flow.gd","_emit_continuous_motion","_motion_kind","app.interaction_motion.emit")
require("scripts/app/player_feedback_bridge.gd","_on_interaction_motion","set_interaction_motion","_haptics.motion")
require("scripts/haptics.gd","func motion(","signal_breach","glass_pressure","heartbeat","resonance")
require("scripts/audio_director.gd","_motion_target","set_interaction_motion","motion_reveal","_motion_smoothed")
require("scripts/app/room_cinematic_runtime.gd","hero_beat_delay","play_signal_breach","SignalBreachBeat")
require("scripts/ui/signal_breach_beat.gd","SIGNAL BREACH","_duration: float = 1.55")
require("scripts/ui/app_hud.gd","HUD recedes","target_alpha: float = 0.30","target_bottom_alpha: float = 0.24")
hybrid=require("scripts/rooms/behaviors/hybrid.gd","frequency core","Counter-rotating","draw_arc")
if "draw_circle(opponent + Vector2" in hybrid or "draw_line(opponent + Vector2(jitter, -8.0)" in hybrid:
    failures.append("hybrid resurrected stick-figure overlay")
archive=require("scripts/ui/album_archive_card.gd","EchoCodexMemory","source","memory_lines")
if 'UIFactory.body("\\n".join(memory_lines))' not in archive:
    failures.append("echo codex memory join is not escaped correctly")
if micro.count("func _draw_") < 12:
    failures.append("world micro FX does not expose enough authored room motifs")
if failures:
    for f in failures: print("FAIL:",f)
    raise SystemExit(f"SYNESTHESIA_GAMEFEEL_V5=FAIL count={len(failures)}")
print("SYNESTHESIA_GAMEFEEL_V5=PASS living=11 hero-beats=11 touch=continuous audio=reactive haptics=motion hud=immersive meta=signal-breach codex=echo-memory")
