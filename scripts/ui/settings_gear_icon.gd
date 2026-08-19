extends Control

const GEAR_COLOR := Color("eef4f1")
const GEAR_DIM := Color("98a5a0")

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    queue_redraw()

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED or what == NOTIFICATION_THEME_CHANGED:
        queue_redraw()

func _draw() -> void:
    var center: Vector2 = size * 0.5
    var scale_factor: float = minf(size.x, size.y) / 30.0
    var hub_radius: float = 2.6 * scale_factor
    var ring_radius: float = 6.1 * scale_factor
    var tooth_inner: float = 7.2 * scale_factor
    var tooth_outer: float = 10.0 * scale_factor
    var stroke: float = maxf(1.35, 1.65 * scale_factor)

    draw_arc(center, ring_radius, 0.0, TAU, 32, GEAR_COLOR, stroke, true)
    draw_arc(center, hub_radius, 0.0, TAU, 24, GEAR_COLOR, stroke, true)
    for index in range(8):
        var angle: float = TAU * float(index) / 8.0 - PI * 0.5
        var direction := Vector2(cos(angle), sin(angle))
        draw_line(
            center + direction * tooth_inner,
            center + direction * tooth_outer,
            GEAR_COLOR if index % 2 == 0 else GEAR_DIM,
            stroke + 0.35,
            true
        )
