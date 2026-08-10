extends Control

var _alpha: float = 0.16
var _marks: PackedVector3Array = PackedVector3Array()

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(false)

func configure(alpha: float) -> void:
    _alpha = clampf(alpha, 0.0, 0.42)
    _marks.clear()
    for index in range(84):
        var x := _hash01(index, 17)
        var y := _hash01(index, 31)
        var length := lerpf(0.0015, 0.009, _hash01(index, 47))
        _marks.append(Vector3(x, y, length))
    queue_redraw()

func _draw() -> void:
    if size.x <= 1.0 or size.y <= 1.0 or _alpha <= 0.001:
        return
    for index in range(_marks.size()):
        var mark := _marks[index]
        var p := Vector2(mark.x * size.x, mark.y * size.y)
        var length := maxf(1.0, mark.z * size.x)
        var a := _alpha * (0.10 + 0.16 * _hash01(index, 71))
        if index % 5 == 0:
            draw_line(p, p + Vector2(length, 0.0), Color(0.76, 0.84, 0.90, a), 1.0)
        else:
            draw_circle(p, 0.55, Color(0.80, 0.84, 0.88, a * 0.72))

func _hash01(a: int, b: int) -> float:
    var value := sin(float(a * 127 + b * 311) * 0.0179) * 43758.5453
    return value - floor(value)
