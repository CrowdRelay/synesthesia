extends Node

## Fetches and mounts the room-outro audio pack on Web.
##
## The eleven outro excerpts are 5.3 MB of the album's music. Shipping them in
## the main pack meant the browser had to finish downloading every one of them
## before Godot could start and the menu could appear, even though the menu
## needs at most one of them and rooms need theirs only on completion.
##
## They now ship as a separate pack. Mounting it puts the same `res://` paths
## back on the loader, so menu_soundscape, audio_director and asset_preloader
## keep working unchanged and need no knowledge of where the bytes came from.
## Until it is mounted every consumer already guards with
## `ResourceLoader.exists()`, so the album is quiet rather than broken.

signal mounted

const PACK_URL: String = "room-audio.pck"
const PACK_USER_PATH: String = "user://room-audio.pck"
const REQUEST_TIMEOUT_SECONDS: float = 120.0

var _http: HTTPRequest
var _is_mounted: bool = false

func _ready() -> void:
	# Native builds keep the audio in their own pack: there is no download to
	# defer, and a second copy on disk would be waste, not a saving.
	if not OS.has_feature("web"):
		_is_mounted = true
		return
	# A previous visit already paid for the bytes. IndexedDB keeps `user://`
	# across sessions, so a warm start mounts without touching the network.
	if FileAccess.file_exists(PACK_USER_PATH) and _mount():
		return
	# The download must not be a hostage of the tree's pause state: rooms and
	# menus pause it, and a paused HTTPRequest never polls, so the request
	# starts and then silently never completes.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_http = HTTPRequest.new()
	_http.process_mode = Node.PROCESS_MODE_ALWAYS
	_http.name = "RoomAudioPackRequest"
	_http.timeout = REQUEST_TIMEOUT_SECONDS
	_http.request_completed.connect(_on_request_completed)
	add_child(_http)
	var url: String = _resolve_pack_url()
	if url.is_empty():
		push_warning("Room audio pack URL could not be resolved")
		return
	var error: Error = _http.request(url)
	if error != OK:
		push_warning("Room audio pack request could not start: %d" % error)

func is_mounted() -> bool:
	return _is_mounted

func _resolve_pack_url() -> String:
	# HTTPRequest needs an absolute URL; a bare filename fails with an invalid
	# scheme. Resolve it against the document so the pack is found wherever the
	# build is deployed, rather than assuming it sits at the origin root.
	var resolved: Variant = JavaScriptBridge.eval(
		"new URL('%s', window.location.href).href" % PACK_URL, true
	)
	if resolved is String and not str(resolved).is_empty():
		return str(resolved)
	return ""

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200 or body.is_empty():
		# Degrade to a quiet album rather than blocking or retrying forever;
		# the next visit tries again from a clean state.
		push_warning("Room audio pack unavailable: result=%d status=%d" % [result, response_code])
		return
	var file: FileAccess = FileAccess.open(PACK_USER_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Room audio pack could not be written to user://")
		return
	file.store_buffer(body)
	file.close()
	if not _mount():
		# A truncated or corrupt copy must not persist and poison warm starts.
		DirAccess.remove_absolute(PACK_USER_PATH)

func _mount() -> bool:
	if _is_mounted:
		return true
	# `replace_files = false`: this pack only ever adds the excerpts. It must
	# never be able to shadow anything the main pack already owns.
	if not ProjectSettings.load_resource_pack(PACK_USER_PATH, false):
		return false
	_is_mounted = true
	mounted.emit()
	return true
