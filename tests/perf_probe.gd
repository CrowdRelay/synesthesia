extends SceneTree
# LOCAL-ONLY performance probe (untracked, not part of the contract suite).
# Measures: engine boot, main scene script+scene instantiation, time to an
# interactive main menu, and steady-state frame cost while the menu idles.

var t0_ms: int = 0
var stage: int = 0
var frames_after_menu: int = 0
var frame_costs: Array = []
var main_node: Node = null


func _initialize() -> void:
	t0_ms = Time.get_ticks_msec()
	print("[perf-probe] engine_ready_ms=", t0_ms)
	var packed: PackedScene = load("res://scenes/main.tscn")
	var load_done := Time.get_ticks_msec()
	print("[perf-probe] main_scene_load_ms=", load_done - t0_ms)
	main_node = packed.instantiate()
	root.add_child(main_node)
	stage = 1


func _process(_delta: float) -> bool:
	if stage == 0:
		return false
	var now := Time.get_ticks_msec()
	if stage == 1:
		# Wait until the experience intro panel exists => menu interactive.
		if main_node.get("experience_intro_panel") != null or now - t0_ms > 60000:
			var intro_ms := now - t0_ms
			print("[perf-probe] menu_interactive_ms=", intro_ms)
			print("[perf-probe] intro_panel_present=", main_node.get("experience_intro_panel") != null)
			stage = 2
	elif stage == 2:
		frames_after_menu += 1
		frame_costs.append(_delta * 1000.0)
		if frames_after_menu >= 300:
			frame_costs.sort()
			var p50: float = frame_costs[int(frame_costs.size() * 0.5)]
			var p95: float = frame_costs[int(frame_costs.size() * 0.95) - 1]
			var mx: float = frame_costs[frame_costs.size() - 1]
			print("[perf-probe] idle_frames=", frames_after_menu, " p50_ms=%.2f" % p50,
				" p95_ms=%.2f" % p95, " max_ms=%.2f" % mx)
			print("[perf-probe] DONE")
			stage = 3
			return true
	return false
