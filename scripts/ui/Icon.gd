@tool
class_name UiIcon
extends Control
## Векторная иконка интерфейса (scenes/ui/Icon.tscn). Вид задаётся в сцене полем kind.
## Расходники (зелья, подарки) рисуются теми же картинками, что и в кладовой (Art.draw_cons_icon).

@export_enum("coin", "trust", "chapter", "purse", "backpack", "burnout", "xp", "job", "lock", "check", "cross",
	"sword", "shield", "flag", "menu", "pause", "play", "heart", "friend", "skull", "hourglass", "camp", "event",
	"route", "storage", "perk", "save", "home", "board", "shop", "party", "arena", "gift", "dot", "diamond", "material", "badge", "cons", "dawn", "sun", "dusk", "moon")
var kind: String = "coin":
	set(v):
		kind = v
		queue_redraw()
## Для kind = "cons": id расходника или подарка (potion_hp, kit, apple…)
@export var cons_id: String = "":
	set(v):
		cons_id = v
		queue_redraw()
@export var tint: Color = Color(1, 1, 1, 1):
	set(v):
		tint = v
		queue_redraw()

const C_GOLD := Color(0.86, 0.68, 0.3)
const C_GOLD_D := Color(0.55, 0.4, 0.17)
const C_INK := Color(0.93, 0.89, 0.8)
const C_DARK := Color(0.1, 0.07, 0.04)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(20, 20)

func _draw() -> void:
	var s: float = min(size.x, size.y)
	var off := (size - Vector2(s, s)) * 0.5
	if kind == "cons":
		if cons_id != "":
			Art.draw_cons_icon(self, Rect2(off, Vector2(s, s)), cons_id)
		return
	if kind in ["purse", "material", "gift"] and Art.icon_tex(kind) != null:
		Art.draw_cons_icon(self, Rect2(off, Vector2(s, s)), kind)
		return
	# Рисуем в координатах 0..24
	draw_set_transform(off, 0.0, Vector2(s / 24.0, s / 24.0))
	_paint()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _c(c: Color) -> Color:
	return Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a * tint.a)

func _poly(pts: Array, c: Color) -> void:
	draw_colored_polygon(PackedVector2Array(pts), _c(c))

func _line(a: Vector2, b: Vector2, c: Color, w := 2.0) -> void:
	draw_line(a, b, _c(c), w, true)

func _circ(p: Vector2, r: float, c: Color) -> void:
	draw_circle(p, r, _c(c))

func _ring(p: Vector2, r: float, c: Color, w := 2.0) -> void:
	draw_arc(p, r, 0, TAU, 28, _c(c), w, true)

func _rect(r: Rect2, c: Color, fill := true, w := 2.0) -> void:
	draw_rect(r, _c(c), fill, w if not fill else -1.0)

func _paint() -> void:
	match kind:
		"coin":
			_circ(Vector2(12, 12), 10, C_GOLD_D)
			_circ(Vector2(12, 11.2), 9.2, C_GOLD)
			_ring(Vector2(12, 11.2), 6.4, C_GOLD_D, 1.5)
			_line(Vector2(12, 7.5), Vector2(12, 15), C_GOLD_D, 2.0)
			_circ(Vector2(8.5, 7.5), 1.6, Color(1, 0.95, 0.75, 0.8))
		"trust":
			# Домик деревни с сердцем
			_poly([Vector2(3, 11), Vector2(12, 3), Vector2(21, 11)], Color(0.72, 0.36, 0.24))
			_rect(Rect2(5, 11, 14, 10), Color(0.82, 0.7, 0.5))
			_circ(Vector2(10.2, 14.6), 2.2, Color(0.85, 0.25, 0.25))
			_circ(Vector2(13.8, 14.6), 2.2, Color(0.85, 0.25, 0.25))
			_poly([Vector2(8.1, 15.4), Vector2(15.9, 15.4), Vector2(12, 19.5)], Color(0.85, 0.25, 0.25))
		"chapter":
			_poly([Vector2(2, 6), Vector2(11.5, 7.5), Vector2(11.5, 21), Vector2(2, 19)], Color(0.86, 0.8, 0.64))
			_poly([Vector2(12.5, 7.5), Vector2(22, 6), Vector2(22, 19), Vector2(12.5, 21)], Color(0.78, 0.72, 0.56))
			for i in 3:
				_line(Vector2(4, 10 + i * 3), Vector2(9.5, 10.8 + i * 3), Color(0.5, 0.42, 0.3), 1.0)
				_line(Vector2(14.5, 10.8 + i * 3), Vector2(20, 10 + i * 3), Color(0.5, 0.42, 0.3), 1.0)
			_line(Vector2(12, 5), Vector2(12, 21.5), Color(0.72, 0.2, 0.18), 1.6)
		"purse":
			_poly([Vector2(5, 12), Vector2(8, 7), Vector2(16, 7), Vector2(19, 12), Vector2(20, 18), Vector2(16, 22), Vector2(8, 22), Vector2(4, 18)], Color(0.55, 0.36, 0.2))
			_poly([Vector2(8, 7), Vector2(9, 3), Vector2(12, 5), Vector2(15, 3), Vector2(16, 7)], Color(0.45, 0.29, 0.16))
			_line(Vector2(7.5, 7.5), Vector2(16.5, 7.5), C_GOLD, 1.6)
			_circ(Vector2(12, 15), 3.2, C_GOLD)
		"backpack":
			_rect(Rect2(5, 7, 14, 15), Color(0.5, 0.36, 0.22))
			_rect(Rect2(7, 4, 10, 4), Color(0.42, 0.3, 0.18))
			_rect(Rect2(7, 13, 10, 6), Color(0.6, 0.45, 0.28))
			_line(Vector2(5, 12), Vector2(19, 12), Color(0.32, 0.22, 0.13), 1.5)
			_circ(Vector2(12, 16), 1.2, C_GOLD)
		"burnout":
			_poly([Vector2(12, 2), Vector2(18, 11), Vector2(19, 16), Vector2(16, 21), Vector2(8, 21), Vector2(5, 16), Vector2(6, 11), Vector2(9, 13)], Color(0.92, 0.42, 0.16))
			_poly([Vector2(12, 9), Vector2(15.5, 15), Vector2(14.5, 20), Vector2(9.5, 20), Vector2(8.5, 16)], Color(1, 0.78, 0.3))
		"xp", "perk":
			var pts := []
			for i in 10:
				var r := 10.0 if i % 2 == 0 else 4.4
				var a := -PI / 2 + i * PI / 5
				pts.append(Vector2(12, 12.5) + Vector2(cos(a), sin(a)) * r)
			_poly(pts, C_GOLD if kind == "xp" else Color(0.55, 0.75, 1.0))
		"job":
			_rect(Rect2(4, 4, 16, 17), Color(0.85, 0.78, 0.6))
			_rect(Rect2(4, 4, 16, 3), Color(0.6, 0.45, 0.25))
			for i in 3:
				_line(Vector2(7, 10 + i * 3.5), Vector2(17, 10 + i * 3.5), Color(0.45, 0.38, 0.28), 1.2)
		"lock":
			_ring(Vector2(12, 9), 4.5, Color(0.7, 0.66, 0.58), 2.4)
			_rect(Rect2(5, 10, 14, 11), Color(0.7, 0.66, 0.58))
			_circ(Vector2(12, 15), 1.8, C_DARK)
		"check":
			_line(Vector2(4, 12.5), Vector2(10, 18.5), Color(0.5, 0.85, 0.45), 3.2)
			_line(Vector2(10, 18.5), Vector2(20.5, 5.5), Color(0.5, 0.85, 0.45), 3.2)
		"cross":
			_line(Vector2(5, 5), Vector2(19, 19), Color(0.9, 0.38, 0.33), 3.2)
			_line(Vector2(19, 5), Vector2(5, 19), Color(0.9, 0.38, 0.33), 3.2)
		"sword":
			_line(Vector2(5, 19), Vector2(18, 6), Color(0.85, 0.87, 0.9), 3.0)
			_poly([Vector2(17, 4), Vector2(21, 3), Vector2(20, 7)], Color(0.85, 0.87, 0.9))
			_line(Vector2(4, 14), Vector2(10, 20), C_GOLD, 2.6)
			_line(Vector2(3, 21), Vector2(6, 18), Color(0.45, 0.3, 0.16), 3.0)
		"shield":
			_poly([Vector2(4, 4), Vector2(20, 4), Vector2(20, 12), Vector2(12, 21), Vector2(4, 12)], Color(0.26, 0.36, 0.62))
			_line(Vector2(12, 6.5), Vector2(12, 17), C_GOLD, 2.2)
			_line(Vector2(7.5, 10), Vector2(16.5, 10), C_GOLD, 2.2)
		"flag":
			_line(Vector2(5, 3), Vector2(5, 22), Color(0.6, 0.45, 0.28), 2.2)
			_poly([Vector2(6, 4), Vector2(19, 6.5), Vector2(15, 10), Vector2(19, 13.5), Vector2(6, 13)], Color(0.86, 0.82, 0.72))
		"menu":
			for i in 3:
				_rect(Rect2(4, 5.5 + i * 5.5, 16, 2.6), C_INK)
		"sun":
			for i in 8:
				var a := TAU * i / 8.0
				_line(Vector2(12, 12) + Vector2(cos(a), sin(a)) * 7.5, Vector2(12, 12) + Vector2(cos(a), sin(a)) * 10.5, Color(1.0, 0.8, 0.35), 1.8)
			_circ(Vector2(12, 12), 5.5, Color(1.0, 0.84, 0.4))
		"dawn", "dusk":
			var sc := Color(1.0, 0.72, 0.45) if kind == "dawn" else Color(0.95, 0.45, 0.25)
			for i in 5:
				var a := PI + PI * (i + 0.5) / 5.0
				_line(Vector2(12, 16) + Vector2(cos(a), sin(a)) * 8.5, Vector2(12, 16) + Vector2(cos(a), sin(a)) * 11.0, sc, 1.6)
			var arc := [Vector2(5.5, 16)]
			for i in 13:
				var a2 := PI + PI * i / 12.0
				arc.append(Vector2(12, 16) + Vector2(cos(a2), sin(a2)) * 6.5)
			_poly(arc, sc)
			_line(Vector2(2, 17.5), Vector2(22, 17.5), C_INK, 1.6)
			_line(Vector2(6, 20.5), Vector2(18, 20.5), Color(C_INK, 0.6), 1.4)
		"moon":
			_poly([Vector2(19.5, 14.7), Vector2(18.6, 16.6), Vector2(17.1, 18.1), Vector2(15.4, 19.3), Vector2(13.4, 19.9),
				Vector2(11.3, 20.0), Vector2(9.3, 19.5), Vector2(7.4, 18.6), Vector2(5.9, 17.1), Vector2(4.7, 15.4),
				Vector2(4.1, 13.4), Vector2(4.0, 11.3), Vector2(4.5, 9.3), Vector2(5.4, 7.4), Vector2(6.9, 5.9),
				Vector2(8.6, 4.7), Vector2(10.4, 4.2), Vector2(9.5, 5.4), Vector2(8.9, 6.7), Vector2(8.6, 8.1),
				Vector2(8.5, 9.6), Vector2(8.8, 11.0), Vector2(9.4, 12.4), Vector2(10.2, 13.6), Vector2(11.3, 14.6),
				Vector2(12.5, 15.3), Vector2(13.9, 15.8), Vector2(15.4, 16.0), Vector2(16.8, 15.9), Vector2(18.2, 15.4)],
				Color(0.85, 0.88, 1.0))
			_circ(Vector2(19, 18), 1.0, Color(0.85, 0.88, 1.0))
			_circ(Vector2(5, 5), 0.9, Color(0.85, 0.88, 1.0))
		"pause":
			_rect(Rect2(6, 5, 4, 14), C_INK)
			_rect(Rect2(14, 5, 4, 14), C_INK)
		"play":
			_poly([Vector2(7, 4.5), Vector2(19, 12), Vector2(7, 19.5)], C_INK)
		"heart":
			_circ(Vector2(8.5, 9.5), 4.6, Color(0.9, 0.42, 0.55))
			_circ(Vector2(15.5, 9.5), 4.6, Color(0.9, 0.42, 0.55))
			_poly([Vector2(4.1, 11), Vector2(19.9, 11), Vector2(12, 20.5)], Color(0.9, 0.42, 0.55))
		"friend":
			_circ(Vector2(8.5, 8), 3.2, Color(0.55, 0.8, 0.5))
			_circ(Vector2(15.5, 8), 3.2, Color(0.55, 0.8, 0.5))
			_poly([Vector2(3, 20), Vector2(4.5, 13), Vector2(12, 12), Vector2(19.5, 13), Vector2(21, 20)], Color(0.55, 0.8, 0.5))
		"skull":
			_circ(Vector2(12, 10), 7.5, C_INK)
			_rect(Rect2(8, 14, 8, 6), C_INK)
			_circ(Vector2(9.2, 10), 2.0, C_DARK)
			_circ(Vector2(14.8, 10), 2.0, C_DARK)
		"hourglass":
			_poly([Vector2(6, 3), Vector2(18, 3), Vector2(12, 12)], C_INK)
			_poly([Vector2(12, 12), Vector2(18, 21), Vector2(6, 21)], C_GOLD)
		"camp":
			_poly([Vector2(3, 20), Vector2(12, 4), Vector2(21, 20)], Color(0.78, 0.62, 0.4))
			_poly([Vector2(10, 20), Vector2(12, 13), Vector2(14, 20)], C_DARK)
		"event":
			_ring(Vector2(12, 12), 9, C_GOLD, 2.0)
			_line(Vector2(9, 9), Vector2(12, 7), C_GOLD, 2.0)
			_line(Vector2(12, 7), Vector2(15, 9.5), C_GOLD, 2.0)
			_line(Vector2(15, 9.5), Vector2(12, 13.5), C_GOLD, 2.0)
			_circ(Vector2(12, 17), 1.4, C_GOLD)
		"route":
			for i in 3:
				_circ(Vector2(4 + i * 8, 12 + (i % 2) * -4), 2.4, C_GOLD)
			_line(Vector2(4, 12), Vector2(12, 8), C_GOLD_D, 1.4)
			_line(Vector2(12, 8), Vector2(20, 12), C_GOLD_D, 1.4)
		"storage":
			_rect(Rect2(3, 8, 18, 13), Color(0.5, 0.33, 0.18))
			_rect(Rect2(3, 5, 18, 5), Color(0.42, 0.27, 0.14))
			_rect(Rect2(10, 9, 4, 4), C_GOLD)
		"save":
			_poly([Vector2(6, 3), Vector2(18, 3), Vector2(18, 21), Vector2(12, 17), Vector2(6, 21)], Color(0.72, 0.22, 0.2))
		"home":
			_poly([Vector2(2, 12), Vector2(12, 3), Vector2(22, 12)], Color(0.7, 0.35, 0.24))
			_rect(Rect2(5, 12, 14, 9), Color(0.78, 0.66, 0.46))
			_rect(Rect2(10, 15, 4, 6), Color(0.35, 0.22, 0.12))
		"board":
			_rect(Rect2(3, 4, 18, 14), Color(0.5, 0.34, 0.19))
			_rect(Rect2(5, 6, 6, 5), Color(0.9, 0.85, 0.7))
			_rect(Rect2(13, 7, 6, 7), Color(0.88, 0.82, 0.66))
			_line(Vector2(6, 18), Vector2(5, 22), Color(0.4, 0.27, 0.15), 2)
			_line(Vector2(18, 18), Vector2(19, 22), Color(0.4, 0.27, 0.15), 2)
		"shop":
			_rect(Rect2(4, 10, 16, 11), Color(0.62, 0.45, 0.27))
			for i in 4:
				_poly([Vector2(3 + i * 4.5, 6), Vector2(7.5 + i * 4.5, 6), Vector2(7.5 + i * 4.5, 10), Vector2(3 + i * 4.5, 10)], Color(0.8, 0.25, 0.22) if i % 2 == 0 else Color(0.9, 0.85, 0.72))
			_rect(Rect2(9, 14, 6, 7), Color(0.35, 0.22, 0.12))
		"party":
			_circ(Vector2(7, 8), 3, C_INK)
			_circ(Vector2(17, 8), 3, C_INK)
			_circ(Vector2(12, 7), 3.6, C_GOLD)
			_poly([Vector2(6, 21), Vector2(7.5, 13), Vector2(16.5, 13), Vector2(18, 21)], C_GOLD)
		"arena":
			_line(Vector2(4, 4), Vector2(20, 20), Color(0.85, 0.87, 0.9), 2.6)
			_line(Vector2(20, 4), Vector2(4, 20), Color(0.85, 0.87, 0.9), 2.6)
			_line(Vector2(3, 15), Vector2(9, 21), C_GOLD, 2.4)
			_line(Vector2(21, 15), Vector2(15, 21), C_GOLD, 2.4)
		"badge":
			_circ(Vector2(12, 12), 9, Color(0.1, 0.07, 0.04))
			_circ(Vector2(12, 12), 7, Color(0.95, 0.42, 0.25))
			_circ(Vector2(10, 10), 2.4, Color(1, 0.85, 0.7, 0.8))
		"dot":
			_ring(Vector2(12, 12), 6.5, C_INK, 2.2)
		"diamond":
			_poly([Vector2(12, 4), Vector2(20, 12), Vector2(12, 20), Vector2(4, 12)], C_GOLD)
		"material":
			_rect(Rect2(3, 13, 18, 5), Color(0.55, 0.38, 0.2))
			_rect(Rect2(5, 7, 18, 5), Color(0.62, 0.44, 0.24))
			_line(Vector2(6, 15.5), Vector2(19, 15.5), Color(0.35, 0.23, 0.12), 1.0)
		"gift":
			_rect(Rect2(4, 10, 16, 11), Color(0.75, 0.3, 0.35))
			_rect(Rect2(3, 7, 18, 4), Color(0.85, 0.36, 0.4))
			_rect(Rect2(10.5, 7, 3, 14), C_GOLD)
			_circ(Vector2(9, 5.5), 2.6, C_GOLD)
			_circ(Vector2(15, 5.5), 2.6, C_GOLD)
