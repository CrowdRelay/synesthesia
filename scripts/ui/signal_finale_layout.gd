extends RefCounted

const UiMetrics := preload("res://scripts/ui/ui_metrics.gd")

const MOBILE_BASE_MARGIN_PX: float = 12.0
const MOBILE_SCROLL_DEADZONE_PX: int = 4

static func _available_size(app: Control) -> Vector2:
    var available: Vector2 = app.size
    if available.x <= 1.0 or available.y <= 1.0:
        available = app.get_viewport_rect().size
    return Vector2(maxf(1.0, available.x), maxf(1.0, available.y))

static func _local_safe_insets(app: Control, available: Vector2) -> Vector4:
    var viewport: Vector2 = app.get_viewport_rect().size
    var safe: Vector4 = UiMetrics.safe_insets(viewport)
    var rect: Rect2 = app.get_global_rect()
    var root_left: float = rect.position.x
    var root_top: float = rect.position.y
    var root_right: float = rect.position.x + available.x
    var root_bottom: float = rect.position.y + available.y
    var safe_right_edge: float = viewport.x - safe.z
    var safe_bottom_edge: float = viewport.y - safe.w
    return Vector4(
        maxf(0.0, safe.x - root_left),
        maxf(0.0, safe.y - root_top),
        maxf(0.0, root_right - safe_right_edge),
        maxf(0.0, root_bottom - safe_bottom_edge)
    )

static func _panel_rect(app: Control) -> Rect2:
    var available: Vector2 = _available_size(app)
    app._ui_scale = UiMetrics.scale_for_viewport(available)
    var safe: Vector4 = _local_safe_insets(app, available)
    var base_margin: float = clampf(
        minf(available.x, available.y) * 0.025,
        MOBILE_BASE_MARGIN_PX,
        28.0 * app._ui_scale
    )
    # A centred card must read as centred. Taking the left and right insets
    # independently let the panel inherit any horizontal safe-area asymmetry
    # verbatim: left_gap - right_gap works out to exactly safe.x - safe.z, so a
    # cutout or gesture inset on one edge visibly shoves the whole finale
    # sideways. Safe areas raise the floor for both edges instead of skewing
    # one. Top and bottom stay independent, where a status bar and a gesture
    # bar are genuinely different sizes and matching them would waste height.
    var horizontal: float = maxf(base_margin, maxf(safe.x, safe.z))
    var left: float = horizontal
    var top: float = maxf(base_margin, safe.y)
    var right: float = horizontal
    var bottom: float = maxf(base_margin, safe.w)
    var usable_width: float = maxf(1.0, available.x - left - right)
    var usable_height: float = maxf(1.0, available.y - top - bottom)
    var width: float = minf(1120.0 * app._ui_scale, usable_width)
    var height: float = minf(820.0 * app._ui_scale, usable_height)
    var x: float = left + maxf(0.0, (usable_width - width) * 0.5)
    var y: float = top + maxf(0.0, (usable_height - height) * 0.5)
    return Rect2(Vector2(x, y), Vector2(width, height))

static func prepare_scroll_content(root: Node) -> void:
    if root is Control:
        var control := root as Control
        control.mouse_force_pass_scroll_events = true
        if control is BaseButton:
            control.mouse_filter = Control.MOUSE_FILTER_PASS
            control.custom_minimum_size.x = 0.0
            if control is Button:
                var button := control as Button
                button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
                button.clip_text = true
        elif control is LineEdit:
            control.mouse_filter = Control.MOUSE_FILTER_PASS
            control.custom_minimum_size.x = 0.0
        elif control is BoxContainer:
            control.custom_minimum_size.x = 0.0
    for child in root.get_children():
        prepare_scroll_content(child)


static func layout_panel(app: Control) -> void:
    if app._panel == null:
        return
    var rect: Rect2 = _panel_rect(app)
    app._panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
    app._panel.offset_left = rect.position.x
    app._panel.offset_top = rect.position.y
    app._panel.offset_right = rect.position.x + rect.size.x
    app._panel.offset_bottom = rect.position.y + rect.size.y

static func layout_columns(app: Control) -> void:
    if app._layout == null:
        return
    var available: Vector2 = _available_size(app)
    app._ui_scale = UiMetrics.scale_for_viewport(available)
    app._layout.vertical = true
    app._layout.custom_minimum_size.x = 0.0

    if app._visual != null and app._form != null:
        app._layout.move_child(app._form, 0)
        app._layout.move_child(app._visual, 1)
        app._visual.custom_minimum_size.x = 0.0
        app._form.custom_minimum_size.x = 0.0
        app._visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        app._form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        app.call_deferred("_scroll_to_start")

    if app._body != null:
        app._body.custom_minimum_size.x = 0.0
        app._body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    if app._motif != null:
        app._motif.custom_minimum_size.x = 0.0

    prepare_scroll_content(app._layout)

static func apply_ui_scale(app: Control) -> void:
    if app._panel == null:
        return
    UiMetrics.apply_tree(app._panel, app._ui_scale)
    if app._layout != null:
        prepare_scroll_content(app._layout)
