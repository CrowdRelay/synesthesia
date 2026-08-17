extends RefCounted

const UiMetrics := preload("res://scripts/ui/ui_metrics.gd")

static func layout_panel(app: Control) -> void:
    if app._panel == null:
        return
    var viewport := app.get_viewport_rect().size
    app._ui_scale = UiMetrics.scale_for_viewport(viewport)
    var margin := UiMetrics.safe_margin(viewport, clampf(minf(viewport.x, viewport.y) * 0.035, 14.0 * app._ui_scale, 46.0 * app._ui_scale))
    var width := minf(1120.0 * app._ui_scale, maxf(320.0 * app._ui_scale, viewport.x - margin * 2.0))
    var height := minf(820.0 * app._ui_scale, maxf(500.0 * app._ui_scale, viewport.y - margin * 2.0))
    app._panel.set_anchors_preset(Control.PRESET_CENTER)
    app._panel.offset_left = -width * 0.5
    app._panel.offset_right = width * 0.5
    app._panel.offset_top = -height * 0.5
    app._panel.offset_bottom = height * 0.5

static func layout_columns(app: Control) -> void:
    if app._layout == null:
        return
    var viewport := app.get_viewport_rect().size
    app._ui_scale = UiMetrics.scale_for_viewport(viewport)
    # One finale layout everywhere: the single-column portrait treatment reads
    # better than the two-column desktop split, so web matches mobile 1:1 rather
    # than switching presentation on viewport width.
    var portrait_layout: bool = true
    app._layout.vertical = portrait_layout
    # The actionable result/form is always first, including desktop replay.
    # Decorative art must never push the e-mail/Signal actions outside the first
    # viewport or leave keyboard focus at the visual column after reconstruction.
    if app._visual != null and app._form != null:
        app._layout.move_child(app._form, 0)
        app._layout.move_child(app._visual, 1)
        app.call_deferred("_scroll_to_start")
    var margin := UiMetrics.safe_margin(viewport, clampf(minf(viewport.x, viewport.y) * 0.035, 14.0 * app._ui_scale, 46.0 * app._ui_scale))
    var panel_width := minf(1120.0 * app._ui_scale, maxf(320.0 * app._ui_scale, viewport.x - margin * 2.0))
    # Never force a minimum width on the column: the scroll container has
    # horizontal scrolling disabled, so any content wider than the panel is
    # simply clipped off the right edge instead of wrapping. Let the layout take
    # the width the panel actually offers.
    app._layout.custom_minimum_size.x = 0.0
    if app._visual != null:
        app._visual.custom_minimum_size.x = 0.0 if portrait_layout else 380.0 * app._ui_scale
        app._visual.size_flags_stretch_ratio = 1.25
    if app._form != null:
        app._form.custom_minimum_size.x = 0.0 if portrait_layout else 340.0 * app._ui_scale
    if app._body != null:
        app._body.custom_minimum_size.x = 0.0 if portrait_layout else 360.0 * app._ui_scale
    if app._motif != null:
        app._motif.custom_minimum_size = Vector2(0.0, 190.0 * app._ui_scale) if portrait_layout else Vector2(260.0, 330.0) * app._ui_scale

static func apply_ui_scale(app: Control) -> void:
    if app._panel != null:
        UiMetrics.apply_tree(app._panel, app._ui_scale)
