extends SceneTree

const ROOTS: Array[String] = ["res://scripts", "res://tests"]

var _failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var paths: Array[String] = []
    for root in ROOTS:
        _collect_gdscript_paths(root, paths)
    paths.sort()

    for path in paths:
        if path == "res://tests/gdscript_parse_smoke.gd":
            continue
        var script_resource: Resource = ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
        if script_resource == null:
            _failures.append(path)

    if not _failures.is_empty():
        for path in _failures:
            push_error("GDScript parse/load failed: %s" % path)
        print("SYNESTHESIA_GDSCRIPT_PARSE=FAIL count=%d" % _failures.size())
        quit(1)
        return

    print("SYNESTHESIA_GDSCRIPT_PARSE=PASS scripts=%d" % paths.size())
    quit(0)

func _collect_gdscript_paths(root: String, output: Array[String]) -> void:
    var directory: DirAccess = DirAccess.open(root)
    if directory == null:
        _failures.append(root)
        return

    directory.list_dir_begin()
    while true:
        var entry: String = directory.get_next()
        if entry.is_empty():
            break
        if entry == "." or entry == "..":
            continue
        var path: String = root.path_join(entry)
        if directory.current_is_dir():
            _collect_gdscript_paths(path, output)
        elif entry.ends_with(".gd"):
            output.append(path)
    directory.list_dir_end()
