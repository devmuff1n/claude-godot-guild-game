class_name RouteBar
extends Control
## Полоса маршрута похода: пункты, пройденные и текущий.

var nodes: Array = []
var current := 0
var progress := 0.0  # 0..1 движение к текущему пункту
var times: Array = []  # время суток каждого пункта (DayTime.route_times)

const TIME_COLORS := {"morning": Color(1.0, 0.72, 0.45), "day": Color(1.0, 0.86, 0.4),
	"evening": Color(0.95, 0.45, 0.25), "night": Color(0.78, 0.84, 1.0)}

func _init() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(700, 64)
	mouse_filter = Control.MOUSE_FILTER_PASS

func set_route(n: Array, cur: int, prog: float, t: Array = []) -> void:
	nodes = n
	current = cur
	progress = prog
	times = t
	var tip := []
	for i in nodes.size():
		var nd: Dictionary = nodes[i]
		var when := (" · " + str(DayTime.NAMES[times[i]]).to_lower()) if i < times.size() else ""
		tip.append("%s %s — %s%s" % ["✓" if nd.get("done", false) else ("▶" if i == current else "·"), nd["name"], type_name(nd), when])
	tooltip_text = "Маршрут:\n" + "\n".join(tip)
	queue_redraw()

static func type_name(nd: Dictionary) -> String:
	match nd["type"]:
		"battle": return "бой" + (" с главарём" if nd.get("boss", false) else "") + (", возможна засада" if nd.get("ambush", []).size() > 0 else "")
		"event": return "дорожная ситуация"
		"camp": return "привал"
		"shop": return "придорожная торговля"
		"outpost": return "оборона"
		"talk": return "переговоры"
	return ""

func _draw() -> void:
	var n := nodes.size() + 2
	if n < 2:
		return
	var pad := 44.0
	var w := size.x - pad * 2.0
	var step := w / float(n - 1)
	var y := 22.0
	for i in n - 1:
		var x0 := pad + i * step
		var x1 := pad + (i + 1) * step
		var done := i < current + 1
		var xx := x0 + 14
		while xx < x1 - 14:
			draw_line(Vector2(xx, y), Vector2(min(xx + 6, x1 - 14), y), UIK.GOLD if done else Color(0.4, 0.35, 0.28), 2)
			xx += 11
	for i in n:
		var x := pad + i * step
		var label := ""
		var kind := ""
		var state := 0  # 0 впереди, 1 пройдено, 2 текущий
		if i == 0:
			label = "Старт"
			kind = "start"
			state = 1
		elif i == n - 1:
			label = "К цели"
			kind = "goal"
			state = 2 if current >= nodes.size() else 0
		else:
			var nd: Dictionary = nodes[i - 1]
			label = nd["name"]
			kind = nd["type"] + ("_boss" if nd.get("boss", false) else "")
			state = 1 if nd.get("done", false) else (2 if i - 1 == current else 0)
		var col := Color(0.4, 0.35, 0.28)
		if state == 1:
			col = UIK.GOLD_DIM
		elif state == 2:
			col = UIK.GOLD
		draw_circle(Vector2(x, y), 16 if state == 2 else 13, Color(0.08, 0.06, 0.05))
		draw_arc(Vector2(x, y), 16 if state == 2 else 13, 0, TAU, 24, col, 2.5 if state == 2 else 1.5)
		_glyph(Vector2(x, y), kind, col if state != 0 else Color(0.55, 0.5, 0.42))
		if i > 0 and i < n - 1 and i - 1 < times.size():
			_time_mark(Vector2(x + 12, y - 11), str(times[i - 1]), state == 0)
		var fs := 13
		draw_string(UIK.f(), Vector2(x - 50, y + 34), label, HORIZONTAL_ALIGNMENT_CENTER, 100, fs, UIK.INK if state == 2 else UIK.MUTED)

## Метка времени суток у пункта: утро, день, вечер — диск своего цвета, ночь — серп.
func _time_mark(p: Vector2, t: String, dim: bool) -> void:
	var c: Color = TIME_COLORS.get(t, Color.WHITE)
	if dim:
		c = c.darkened(0.35)
	draw_circle(p, 6.5, Color(0.08, 0.06, 0.05))
	draw_circle(p, 4.5, c)
	if t == "night":
		draw_circle(p + Vector2(2.2, -1.6), 3.8, Color(0.08, 0.06, 0.05))
	elif t == "morning" or t == "evening":
		draw_rect(Rect2(p + Vector2(-5, 1.0), Vector2(10, 4)), Color(0.08, 0.06, 0.05))

func _glyph(p: Vector2, kind: String, col: Color) -> void:
	match kind:
		"battle", "battle_boss", "outpost":
			draw_line(p + Vector2(-6, -6), p + Vector2(6, 6), col, 2.5)
			draw_line(p + Vector2(6, -6), p + Vector2(-6, 6), col, 2.5)
			if kind == "battle_boss":
				draw_circle(p + Vector2(0, -9), 3, Color(0.9, 0.3, 0.25))
		"event":
			draw_string(UIK.fb(), p + Vector2(-5, 6), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, col)
		"camp":
			draw_colored_polygon(PackedVector2Array([p + Vector2(-8, 6), p + Vector2(0, -8), p + Vector2(8, 6)]), col)
		"shop":
			draw_circle(p, 6, col)
			draw_circle(p, 3, Color(0.08, 0.06, 0.05))
		"talk":
			draw_rect(Rect2(p + Vector2(-7, -6), Vector2(14, 9)), col)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-4, 3), p + Vector2(1, 3), p + Vector2(-5, 8)]), col)
		"start":
			draw_circle(p, 4, col)
		"goal":
			draw_rect(Rect2(p + Vector2(-6, -6), Vector2(12, 12)), col, false, 2)
