@tool
class_name PipBar
extends Control
## Шкала из делений (заряды и т. п.): count делений, value заполнено.

@export var count: int = 10:
	set(v):
		count = max(1, v)
		queue_redraw()
@export var value: int = 0:
	set(v):
		value = v
		queue_redraw()
@export var color: Color = Color(0.92, 0.45, 0.18):
	set(v):
		color = v
		queue_redraw()
@export var empty_color: Color = Color(0.2, 0.17, 0.13):
	set(v):
		empty_color = v
		queue_redraw()
@export var gap: float = 2.0

static var _sb := StyleBoxFlat.new()

func _draw() -> void:
	var w := (size.x - gap * (count - 1)) / count
	_sb.anti_aliasing = true
	_sb.set_corner_radius_all(int(min(2.0, size.y * 0.5)))
	for i in count:
		var r := Rect2(Vector2(i * (w + gap), 0), Vector2(w, size.y))
		var on := i < value
		_sb.bg_color = color if on else empty_color
		_sb.set_border_width_all(1)
		_sb.border_color = color.darkened(0.5) if on else Color(0, 0, 0, 0.6)
		draw_style_box(_sb, r)
		if on:
			draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, r.size.y * 0.35)), Color(1, 1, 1, 0.22))
