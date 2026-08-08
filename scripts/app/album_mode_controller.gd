extends Node

signal room_requested(index: int)
signal finale_requested
signal menu_requested
signal corridor_requested

const AlbumArchiveCardScript := preload("res://scripts/ui/album_archive_card.gd")
const UIFactory := preload("res://scripts/ui/ui_factory.gd")
const ReleaseReader := preload("res://scripts/app/release_reader.gd")

var _ui_root: Control
var _room_layer: Control
var _hud: Control
var _transition
var _releases: Array = []
var _archive_panel
var _return_button: Button
var _capture_button: Button
var _current_index: int = 0
var _listening: bool = false

func configure(ui_root: Control, room_layer: Control, hud: Control, transition, releases: Array) -> void:
    _ui_root = ui_root
    _room_layer = room_layer
    _hud = hud
    _transition = transition
    _releases = releases.duplicate(true)

func show_archive(album_state: Dictionary, current_index: int, finale_background = null) -> void:
    _listening = false
    hide_return()
    if _room_layer != null:
        _room_layer.visible = false
    if _hud != null:
        _hud.visible = false
    if finale_background != null and is_instance_valid(finale_background):
        finale_background.visible = true
    if _archive_panel != null and is_instance_valid(_archive_panel):
        return
    _archive_panel = AlbumArchiveCardScript.new()
    _archive_panel.name = "AlbumArchiveCard"
    _ui_root.attach(_archive_panel, 45)
    var archive_value: Variant = album_state.get("echo_archive", {})
    var archive: Dictionary = archive_value if archive_value is Dictionary else {}
    var completed_value: Variant = album_state.get("completed_room_ids", [])
    var completed: Array = completed_value if completed_value is Array else []
    _archive_panel.configure(_releases, completed, archive, _accent_for_index(current_index))
    _archive_panel.room_requested.connect(func(index: int) -> void: room_requested.emit(index))
    _archive_panel.finale_requested.connect(_emit_finale)
    _archive_panel.close_requested.connect(_emit_menu)

func enter_room(index: int, finale_background, load_room: Callable) -> void:
    _listening = true
    _current_index = index
    if _transition != null:
        _transition.set_next_accent(_accent_for_index(index))
        await _transition.travel_out()
    _dispose_archive()
    if finale_background != null and is_instance_valid(finale_background):
        finale_background.visible = false
    if _room_layer != null:
        _room_layer.visible = true
    load_room.call(index, false)
    await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().process_frame
    if _hud != null:
        _hud.visible = false
    show_return()
    if _transition != null:
        await _transition.travel_in()

func is_listening() -> bool:
    return _listening

func has_archive() -> bool:
    return _archive_panel != null and is_instance_valid(_archive_panel)

func show_return() -> void:
    if _return_button != null and is_instance_valid(_return_button):
        _return_button.visible = true
        return
    _return_button = UIFactory.button("KORYTARZ", true)
    _return_button.name = "AlbumModeCorridorButton"
    _return_button.custom_minimum_size = Vector2(132.0, 48.0)
    _return_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    _return_button.offset_left = -152.0
    _return_button.offset_right = -16.0
    _return_button.offset_top = -68.0
    _return_button.offset_bottom = -16.0
    _return_button.pressed.connect(func() -> void: corridor_requested.emit())
    _ui_root.attach(_return_button, 35)
    if OS.has_feature("web"):
        _capture_button = UIFactory.button("ZAPISZ KADR", true)
        _capture_button.name = "AlbumModeCaptureButton"
        _capture_button.custom_minimum_size = Vector2(154.0, 48.0)
        _capture_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
        _capture_button.offset_left = -318.0
        _capture_button.offset_right = -160.0
        _capture_button.offset_top = -68.0
        _capture_button.offset_bottom = -16.0
        _capture_button.pressed.connect(_download_share_frame)
        _ui_root.attach(_capture_button, 35)

func hide_return() -> void:
    if _return_button != null and is_instance_valid(_return_button):
        _return_button.queue_free()
    if _capture_button != null and is_instance_valid(_capture_button):
        _capture_button.queue_free()
    _return_button = null
    _capture_button = null

func _download_share_frame() -> void:
    if not OS.has_feature("web"):
        return
    var room_name: String = "SYNESTHESIA"
    if _current_index >= 0 and _current_index < _releases.size():
        var entry_value: Variant = _releases[_current_index]
        if entry_value is Dictionary:
            room_name = str(entry_value.get("id", room_name)).replace("-", " ").to_upper()
    var script: String = """
(() => {
  const source = document.querySelector('canvas');
  if (!source) return;
  const out = document.createElement('canvas');
  out.width = source.width; out.height = source.height;
  const ctx = out.getContext('2d');
  ctx.drawImage(source, 0, 0);
  const barH = Math.max(120, Math.floor(out.height * 0.14));
  ctx.fillStyle = 'rgba(3,5,10,0.88)';
  ctx.fillRect(0, out.height - barH, out.width, barH);
  ctx.fillStyle = '#71dcff';
  ctx.font = `900 ${Math.max(22, Math.floor(out.width * 0.028))}px Impact, sans-serif`;
  ctx.fillText('VIRYA · SYNESTHESIA', Math.floor(out.width * 0.05), out.height - Math.floor(barH * 0.58));
  ctx.fillStyle = '#f4ead7';
  ctx.font = `900 ${Math.max(18, Math.floor(out.width * 0.021))}px Impact, sans-serif`;
  ctx.fillText(%s, Math.floor(out.width * 0.05), out.height - Math.floor(barH * 0.30));
  ctx.textAlign = 'right';
  ctx.fillText('I FOUND THE SIGNAL', Math.floor(out.width * 0.95), out.height - Math.floor(barH * 0.30));
  const a = document.createElement('a');
  a.download = 'virya-synesthesia-%s.png';
  a.href = out.toDataURL('image/png');
  a.click();
})();
""" % [JSON.stringify(room_name), room_name.to_lower().replace(" ", "-")]
    JavaScriptBridge.eval(script, true)

func close_archive() -> void:
    _dispose_archive()
    _listening = false

func _dispose_archive() -> void:
    if _archive_panel != null and is_instance_valid(_archive_panel):
        _archive_panel.queue_free()
    _archive_panel = null

func _emit_finale() -> void:
    close_archive()
    finale_requested.emit()

func _emit_menu() -> void:
    close_archive()
    menu_requested.emit()

func _accent_for_index(index: int) -> Color:
    if index < 0 or index >= _releases.size():
        return Color("72afff")
    return ReleaseReader.accent_for_entry(_releases[index], Color("72afff"))
