class_name Bar
extends Control
## Полоса значения (ОЗ/МП/ATB/прочность) с текстом и сегментами.

@export var value: float = 1.0
@export var max_value: float = 1.0
@export var color: Color = Color.RED
@export var back: Color = Color(0.05, 0.04, 0.03, 0.9)
@export var segments: int = 1
@export var text: String = ""
@export var text_size: int = 13
var ghost: float = -1.0  # отложенная полоса урона

func _init(col: Color = Color.RED, h: float = 12.0, segs: int = 1) -> void:
	color = col
	segments = segs
	# Размер из сцены задаётся раньше скрипта — не перезаписываем его
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(40, h)
	mouse_filter = Control.MOUSE_FILTER_PASS

func set_val(v: float, m: float, t: String = "") -> void:
	value = v
	max_value = max(m, 0.0001)
	text = t
	queue_redraw()

func _process(delta: float) -> void:
	var r: float = clamp(value / max_value, 0.0, 1.0)
	if ghost < 0.0:
		ghost = r
	if ghost > r:
		ghost = max(r, ghost - delta * 0.6)
		queue_redraw()
	elif ghost < r:
		ghost = r

static var _sb := StyleBoxFlat.new()

## Скруглённый прямоугольник (заливка или рамка)
func _rr(r: Rect2, col: Color, rad: float, fill := true, bw := 1) -> void:
	if r.size.x <= 0.5 or r.size.y <= 0.5:
		return
	_sb.bg_color = col if fill else Color(0, 0, 0, 0)
	_sb.draw_center = fill
	_sb.set_border_width_all(0 if fill else bw)
	_sb.border_color = col
	_sb.set_corner_radius_all(int(min(rad, r.size.y * 0.5, r.size.x * 0.5)))
	_sb.anti_aliasing = true
	draw_style_box(_sb, r)

func _fill(r: Rect2, col: Color, rad: float) -> void:
	# объём: светлая верхняя половина, тёмный низ, блик
	_rr(r, col.darkened(0.25), rad)
	_rr(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.55)), col, rad)
	_rr(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, max(1.0, r.size.y * 0.22))), Color(1, 1, 1, 0.22), rad)

func _draw() -> void:
	var sz := size
	var rad := sz.y * 0.5 if sz.y <= 10 else 4.0
	var outer := Rect2(Vector2.ZERO, sz)
	var r: float = clamp(value / max_value, 0.0, 1.0)
	if segments <= 1:
		_rr(outer, Color(back, max(back.a, 0.85)), rad)
		_rr(Rect2(Vector2(0, 0), Vector2(sz.x, sz.y * 0.4)), Color(0, 0, 0, 0.35), rad)
		var inner := outer.grow(-1)
		if ghost > r:
			_rr(Rect2(inner.position + Vector2(inner.size.x * r, 0), Vector2(inner.size.x * (ghost - r), inner.size.y)), Color(1, 0.9, 0.7, 0.5), rad)
		_fill(Rect2(inner.position, Vector2(inner.size.x * r, inner.size.y)), color, rad)
		_rr(outer, Color(0, 0, 0, 0.85), rad, false)
	else:
		var gap := 4.0
		var w := (sz.x - gap * (segments - 1)) / segments
		var per := max_value / segments
		for i in segments:
			var seg := Rect2(Vector2(i * (w + gap), 0), Vector2(w, sz.y))
			_rr(seg, Color(0.03, 0.025, 0.02, 0.95), rad)
			var fill: float = clamp((value - per * i) / per, 0.0, 1.0)
			var inner2 := seg.grow(-1)
			if fill >= 1.0:
				_fill(inner2, color, rad)
			elif fill > 0.0:
				_rr(Rect2(inner2.position, Vector2(inner2.size.x * fill, inner2.size.y)), color.darkened(0.45), rad)
			_rr(seg, Color(0, 0, 0, 0.85) if fill < 1.0 else color.darkened(0.55), rad, false)
	if text != "":
		var f := UIK.fb()
		var ts := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size)
		var pos := Vector2((sz.x - ts.x) * 0.5, (sz.y + ts.y * 0.62) * 0.5)
		draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, 3, Color(0, 0, 0, 0.85))
		draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color(1, 1, 1))
