extends SceneTree
# LOCAL-ONLY probe: feed the invaluable behavior gestures at its own published
# hint-target positions and report state after each step.

const BehaviorScript := preload("res://scripts/rooms/behaviors/invaluable.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manifest: Dictionary = {}
	var file := FileAccess.open("res://data/releases/invaluable/manifest.json", FileAccess.READ)
	if file == null:
		for candidate in ["res://data/releases/invaluable/room.json", "res://data/rooms/invaluable.json"]:
			if FileAccess.file_exists(candidate):
				file = FileAccess.open(candidate, FileAccess.READ)
				break
	if file == null:
		print("[probe-invaluable] NO MANIFEST; listing:")
		_list("res://data/releases")
		return
	manifest = JSON.parse_string(file.get_as_text())
	var behavior = BehaviorScript.new()
	behavior.configure(manifest)
	print("[probe-invaluable] configured. hint=", behavior.interaction_hint())
	for round_i in range(6):
		var targets: Array[Dictionary] = behavior.hint_targets()
		var kinds := []
		for t in targets:
			kinds.append(str(t.get("kind")))
		print("[probe-invaluable] round=", round_i, " targets=", targets.size(), " kinds=", kinds,
			" first=", targets[0].get("point") if targets.size() > 0 else "none")
		if targets.is_empty():
			break
		var target: Dictionary = targets[0]
		var point: Vector2 = target.get("point")
		var kind := str(target.get("kind"))
		# Simulate exactly what the router emits for the driver's gestures.
		if kind == "tap":
			var tap := {"kind": "tap", "point": point, "start": point, "delta": Vector2.ZERO,
				"duration_ms": 60, "distance": 0.001, "velocity": 0.0, "pointer_count": 1}
			var events: Array = behavior.on_gesture("tap", tap, 0.0)
			print("[probe-invaluable]   tap->", events.size(), " events; cracked=",
				behavior.state.get("cracked"), " hint=", behavior.interaction_hint())
		else:
			var start := point
			var finish := point + Vector2(0.0, -0.36)
			var swipe := {"kind": "swipe", "point": finish, "start": start, "delta": finish - start,
				"duration_ms": 420, "distance": 0.36, "velocity": 0.85, "pointer_count": 1}
			var events: Array = behavior.on_gesture("swipe", swipe, 0.0)
			print("[probe-invaluable]   swipe->", events.size(), " events; cracked=",
				behavior.state.get("cracked"), " shattered=", behavior.state.get("shattered"),
				" hint=", behavior.interaction_hint())
	print("[probe-invaluable] progress=", behavior.mechanic_progress())
	quit(0)


func _list(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		print("  ", path, "/", name)
		name = dir.get_next()
