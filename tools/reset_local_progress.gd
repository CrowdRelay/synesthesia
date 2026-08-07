extends SceneTree

const ProgressStoreScript := preload("res://scripts/progress_store.gd")

func _initialize() -> void:
    if ProgressStoreScript.reset_local_journey():
        print("SYNESTHESIA_LOCAL_RESET=PASS gameplay=cleared preferences=preserved server_state=preserved")
        quit(0)
    else:
        push_error("Could not reset local Synestezja journey")
        quit(1)
