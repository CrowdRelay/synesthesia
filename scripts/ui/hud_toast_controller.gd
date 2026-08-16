extends Node

const HOLD_SECONDS: float = 1.55
const HOVER_ALPHA: float = 0.18

var app: Control
var _timer: Timer
var _tween: Tween
var _base_alpha: float = 0.0
var _hover_alpha: float = 1.0
var _last_text: String = ""

func bind(owner: Control) -> void:
    app = owner

func _ready() -> void:
    _timer = Timer.new()
    _timer.one_shot = true
    _timer.wait_time = HOLD_SECONDS
    _timer.timeout.connect(hide)
    add_child(_timer)
    set_process(false)

func show(text_value: String) -> void:
    var normalized := text_value.strip_edges()
    if normalized.is_empty() or app == null or not app.visible or app.toast_panel == null or app.toast_label == null:
        return
    if app.toast_panel.visible and normalized == _last_text:
        return
    _last_text = normalized
    _timer.stop()
    _kill_tween()
    app.toast_label.text = normalized
    app.toast_label.queue_redraw()
    app.toast_panel.visible = true
    _base_alpha = 0.0
    _hover_alpha = 1.0
    _apply_alpha()
    set_process(true)
    _tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    _tween.tween_method(_set_base_alpha, 0.0, 1.0, 0.12)
    _timer.start()

func hide() -> void:
    if app == null or app.toast_panel == null or not app.toast_panel.visible:
        return
    _kill_tween()
    _tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    _tween.tween_method(_set_base_alpha, _base_alpha, 0.0, 0.16)
    _tween.finished.connect(_finish_hide)

func clear() -> void:
    if _timer != null:
        _timer.stop()
    _kill_tween()
    _base_alpha = 0.0
    _hover_alpha = 1.0
    _last_text = ""
    set_process(false)
    if app != null and app.toast_panel != null:
        app.toast_panel.visible = false
        _apply_alpha()

func _finish_hide() -> void:
    if app != null and app.toast_panel != null:
        app.toast_panel.visible = false
    _base_alpha = 0.0
    _hover_alpha = 1.0
    _last_text = ""
    _apply_alpha()
    set_process(false)

func _kill_tween() -> void:
    if _tween != null and _tween.is_valid():
        _tween.kill()
    _tween = null

func _set_base_alpha(value: float) -> void:
    _base_alpha = clampf(value, 0.0, 1.0)
    _apply_alpha()

func _apply_alpha() -> void:
    if app != null and app.toast_panel != null:
        app.toast_panel.modulate.a = _base_alpha * _hover_alpha

func _process(delta: float) -> void:
    if app == null or app.toast_panel == null or not app.toast_panel.visible:
        set_process(false)
        return
    # Hover is observed manually so the overlay can remain recursively input
    # disabled: gameplay underneath still receives every click/touch.
    var panel: Control = app.toast_panel as Control
    if panel == null:
        set_process(false)
        return
    var mouse_position: Vector2 = app.get_viewport().get_mouse_position()
    var hovered: bool = panel.get_global_rect().has_point(mouse_position)
    var target: float = HOVER_ALPHA if hovered else 1.0
    _hover_alpha = move_toward(_hover_alpha, target, delta * 7.5)
    _apply_alpha()
