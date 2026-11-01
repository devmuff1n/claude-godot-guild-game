class_name Art
extends RefCounted
## Процедурная графика: чиби-фигуры героев и врагов, иконки предметов, фон леса.

static var flash: float = 0.0
static var alpha: float = 1.0
## Дух зверя (враг с тегом phantom): фигура темнеет, светлые детали (глаза, клыки) горят красным
static var shade := false
const SHADE_BODY := Color(0.13, 0.09, 0.14)
const SHADE_GLOW := Color(1.0, 0.22, 0.12)

static func c(col: Color) -> Color:
	var r := col
	if shade:
		var lum := col.get_luminance()
		var glow := lum > 0.88 or (lum > 0.6 and col.s > 0.45)
		r = Color(SHADE_GLOW, col.a) if glow else col.lerp(Color(SHADE_BODY, col.a), 0.72)
	r = r.lerp(Color(1, 1, 1), flash)
	r.a *= alpha
	return r

static func ell(ci: CanvasItem, center: Vector2, rx: float, ry: float, col: Color, seg := 20) -> void:
	var pts := PackedVector2Array()
	for i in seg:
		var a := TAU * i / seg
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, c(col))

static func poly(ci: CanvasItem, pts: Array, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array(pts), c(col))

static func line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w := 3.0) -> void:
	ci.draw_line(a, b, c(col), w, true)

static func circ(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(p, r, c(col))

static func rect(ci: CanvasItem, r: Rect2, col: Color) -> void:
	ci.draw_rect(r, c(col))

# ================================================================ Фигуры
## st: {moving, swing (0..1), cast (bool), dead, flash, t}
static func draw_unit(ci: CanvasItem, pos: Vector2, look: String, facing: int, st: Dictionary, sc := 1.0) -> void:
	flash = float(st.get("flash", 0.0))
	alpha = 0.55 if st.get("dead", false) else float(st.get("alpha", 1.0))
	if look == "wolf_shade":
		look = "wolf"
		st = st.duplicate()
		st["shade"] = true
	shade = st.get("shade", false)
	var t: float = st.get("t", 0.0)
	var rot := 0.0
	var off := Vector2.ZERO
	var squash := 1.0
	if st.get("dead", false):
		if look in BEASTS:
			# Звери падают на бок: сплющиваем фигуру вместо поворота
			squash = 0.45
		else:
			rot = -PI * 0.5 * float(facing)
			off = Vector2(-facing * 10, -12)
	var lunge: float = sin(clamp(float(st.get("swing", 0.0)), 0.0, 1.0) * PI) * 8.0
	ci.draw_set_transform(pos + off + Vector2(lunge * facing, 0), rot, Vector2(float(facing) * sc, sc * squash))
	# Тень
	if not st.get("dead", false):
		var a0 := alpha
		alpha = 0.35
		ell(ci, Vector2(0, 0), shadow_w(look), 7, Color(0, 0, 0))
		alpha = a0
	if shade:
		_shade_smoke(ci, look, t)
	var walk := sin(t * 11.0) if st.get("moving", false) else 0.0
	var bob = abs(walk) * 2.0 if st.get("moving", false) else sin(t * 2.5) * 0.8
	var sw: float = float(st.get("swing", 0.0))
	var tier: int = clampi(int(st.get("tier", 1)), 1, 3)
	var casting: bool = st.get("cast", false)
	match look:
		"wolf", "wolf_alpha":
			_wolf(ci, look == "wolf_alpha", walk, t, sw, tier)
		"wolf_shade":
			_wolf(ci, false, walk, t, sw, 1)
		"obelisk":
			# сам обелиск — 3D-модель уровня; здесь только пульсирующее свечение у основания
			var k := 0.5 + 0.5 * sin(t * 3.0)
			ell(ci, Vector2(0, -4), 60, 14, Color(0.9, 0.2, 0.8, 0.18 + 0.15 * k))
		"boar":
			_boar(ci, walk, t, sw, tier)
		"spider", "spiderling":
			_spider(ci, walk, t, sw, tier, look == "spiderling", st.get("moving", false))
		"lynx":
			_lynx(ci, walk, t, sw, tier)
		"bear":
			_bear(ci, walk, t, sw, tier, casting)
		_:
			_humanoid(ci, look, walk, bob, sw, casting, t, tier)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	flash = 0.0
	alpha = 1.0
	shade = false

## Тёмная дымка над духом: клочья поднимаются со спины и тают
static func _shade_smoke(ci: CanvasItem, look: String, t: float) -> void:
	var w := shadow_w(look)
	var h := top_h(look) * 0.6
	var s0 := shade
	shade = false
	for k in 9:
		var ph := fmod(t * 0.55 + k * 0.37, 1.0)
		var wx := -w * 0.8 + k * w * 0.2 + sin(k * 2.3) * 7.0 - ph * 16.0
		var fade := (1.0 - ph) * minf(1.0, ph * 4.0)
		ell(ci, Vector2(wx, -h - ph * 50.0 + sin(t * 1.7 + k) * 3.0), 5.0 + ph * 11.0, 3.5 + ph * 7.0, Color(0.06, 0.03, 0.08, 0.38 * fade))
	shade = s0

const BEASTS := ["wolf", "wolf_alpha", "wolf_shade", "boar", "spider", "spiderling", "lynx", "bear"]

## Ширина тени и высота головы/верха фигуры (в пикселях до масштаба) для разных обликов.
static func shadow_w(look: String) -> float:
	match look:
		"wolf", "wolf_alpha", "wolf_shade", "boar": return 40.0
		"spider": return 46.0
		"spiderling": return 22.0
		"lynx": return 36.0
		"bear": return 56.0
	return 30.0

static func head_h(look: String) -> float:
	match look:
		"wolf", "wolf_shade": return 52.0
		"obelisk": return 200.0
		"wolf_alpha": return 66.0
		"boar": return 36.0
		"spider": return 36.0
		"spiderling": return 18.0
		"lynx": return 52.0
		"bear": return 78.0
	return 98.0

static func top_h(look: String) -> float:
	match look:
		"wolf", "wolf_shade": return 70.0
		"obelisk": return 230.0
		"wolf_alpha": return 91.0
		"boar": return 66.0
		"spider": return 70.0
		"spiderling": return 38.0
		"lynx": return 78.0
		"bear": return 108.0
	return 112.0

static func _legs(ci: CanvasItem, walk: float, pants: Color, boots: Color, hip_y := -36.0, spread := 7.0) -> void:
	var l1 := Vector2(-spread + walk * 7.0, 0)
	var l2 := Vector2(spread - walk * 7.0, 0)
	line(ci, Vector2(-4, hip_y), l1 + Vector2(0, -6), pants, 8)
	line(ci, Vector2(4, hip_y), l2 + Vector2(0, -6), pants, 8)
	ell(ci, l1 + Vector2(2, -3), 7, 4, boots)
	ell(ci, l2 + Vector2(2, -3), 7, 4, boots)

const LOOKS := {
	"aiden": {"skin": Color(1.0, 0.86, 0.74), "hair": Color(0.93, 0.88, 0.68), "body": Color(0.95, 0.93, 0.86), "trim": Color(0.16, 0.5, 0.55), "pants": Color(0.92, 0.9, 0.84), "boots": Color(0.45, 0.3, 0.18)},
	"marek": {"skin": Color(0.36, 0.24, 0.17), "hair": Color(0.08, 0.07, 0.07), "body": Color(0.26, 0.34, 0.56), "trim": Color(0.55, 0.14, 0.2), "pants": Color(0.22, 0.28, 0.46), "boots": Color(0.2, 0.24, 0.38)},
	"elira": {"skin": Color(1.0, 0.85, 0.74), "hair": Color(0.85, 0.42, 0.18), "body": Color(0.22, 0.45, 0.25), "trim": Color(0.45, 0.3, 0.16), "pants": Color(0.2, 0.16, 0.13), "boots": Color(0.42, 0.28, 0.16)},
	"neris": {"skin": Color(0.8, 0.6, 0.84), "hair": Color(0.3, 0.12, 0.36), "body": Color(0.42, 0.15, 0.45), "trim": Color(0.85, 0.66, 0.28), "pants": Color(0.15, 0.1, 0.16), "boots": Color(0.15, 0.1, 0.16)},
	"bandit": {"skin": Color(0.82, 0.62, 0.46), "hair": Color(0.3, 0.2, 0.12), "body": Color(0.42, 0.3, 0.2), "trim": Color(0.7, 0.18, 0.15), "pants": Color(0.25, 0.2, 0.16), "boots": Color(0.2, 0.15, 0.1)},
	"raider": {"skin": Color(0.78, 0.6, 0.45), "hair": Color(0.2, 0.15, 0.1), "body": Color(0.3, 0.22, 0.18), "trim": Color(0.62, 0.12, 0.12), "pants": Color(0.2, 0.17, 0.14), "boots": Color(0.18, 0.13, 0.1)},
	"archer": {"skin": Color(0.84, 0.66, 0.5), "hair": Color(0.25, 0.18, 0.1), "body": Color(0.35, 0.38, 0.22), "trim": Color(0.42, 0.3, 0.18), "pants": Color(0.24, 0.2, 0.15), "boots": Color(0.2, 0.15, 0.1)},
	"brute": {"skin": Color(0.8, 0.6, 0.45), "hair": Color(0.35, 0.22, 0.12), "body": Color(0.38, 0.28, 0.2), "trim": Color(0.25, 0.2, 0.18), "pants": Color(0.28, 0.22, 0.17), "boots": Color(0.18, 0.13, 0.1)},
	"healer": {"skin": Color(0.85, 0.7, 0.55), "hair": Color(0.5, 0.5, 0.45), "body": Color(0.3, 0.42, 0.28), "trim": Color(0.55, 0.45, 0.25), "pants": Color(0.25, 0.25, 0.2), "boots": Color(0.2, 0.16, 0.1)},
	"arsonist": {"skin": Color(0.78, 0.58, 0.44), "hair": Color(0.15, 0.1, 0.1), "body": Color(0.3, 0.18, 0.15), "trim": Color(0.55, 0.1, 0.12), "pants": Color(0.2, 0.15, 0.13), "boots": Color(0.15, 0.1, 0.08)},
	"farmer": {"skin": Color(0.9, 0.72, 0.56), "hair": Color(0.55, 0.4, 0.22), "body": Color(0.62, 0.55, 0.38), "trim": Color(0.82, 0.72, 0.38), "pants": Color(0.32, 0.3, 0.42), "boots": Color(0.3, 0.2, 0.12)},
	"druid": {"skin": Color(0.62, 0.55, 0.45), "hair": Color(0.2, 0.18, 0.12), "body": Color(0.16, 0.24, 0.14), "trim": Color(0.3, 0.2, 0.12), "pants": Color(0.12, 0.14, 0.1), "boots": Color(0.12, 0.1, 0.08)},
	"captain": {"skin": Color(0.88, 0.68, 0.52), "hair": Color(0.78, 0.28, 0.1), "body": Color(0.45, 0.12, 0.12), "trim": Color(0.8, 0.62, 0.25), "pants": Color(0.2, 0.15, 0.12), "boots": Color(0.15, 0.1, 0.08)},
}

static func _humanoid(ci: CanvasItem, look: String, walk: float, bob: float, sw: float, casting: bool, t: float, tier := 1) -> void:
	var L: Dictionary = LOOKS.get(look, LOOKS["bandit"]).duplicate()
	if tier >= 3:
		# Ветераны тракта: одежда темнее, дублёная
		L["body"] = L["body"].darkened(0.3)
		L["pants"] = L["pants"].darkened(0.25)
	var big := look in ["brute", "captain"]
	var w := 1.18 if big else 1.0
	_legs(ci, walk, L["pants"], L["boots"], -36.0, 7.0 * w)
	var y0 := -bob
	# Плащ сзади
	if look in ["elira", "raider", "arsonist", "healer", "archer", "druid"]:
		poly(ci, [Vector2(-12, -76 + y0), Vector2(6, -76 + y0), Vector2(-4, -26), Vector2(-24 - walk * 3, -24)], L["trim"] if look == "elira" else L["body"].darkened(0.25))
		if look == "elira":
			poly(ci, [Vector2(-12, -76 + y0), Vector2(6, -76 + y0), Vector2(-4, -30), Vector2(-26 - walk * 3, -30)], Color(0.2, 0.42, 0.24))
	if look == "neris":
		# Волосы за спиной
		ell(ci, Vector2(-8, -68 + y0), 16, 26, L["hair"])
	if look == "elira":
		# Коса
		for i in 5:
			circ(ci, Vector2(-14 - i * 2, -78 + y0 + i * 8), 5 - i * 0.4, L["hair"].darkened(0.1 * (i % 2)))
	# Туловище
	var tw := 15.0 * w
	var body := [Vector2(-tw, -72 + y0), Vector2(tw, -72 + y0), Vector2(tw + 3, -34), Vector2(-tw - 3, -34)]
	if look in ["aiden", "neris", "healer", "druid"]:
		body = [Vector2(-tw, -72 + y0), Vector2(tw, -72 + y0), Vector2(tw + 8, -14), Vector2(-tw - 8, -14)]
	poly(ci, body, L["body"])
	match look:
		"aiden":
			poly(ci, [Vector2(-4, -72 + y0), Vector2(4, -72 + y0), Vector2(5, -14), Vector2(-5, -14)], Color(0.85, 0.7, 0.32))
			rect(ci, Rect2(-tw - 1, -50 + y0, tw * 2 + 2, 6), L["trim"])
			circ(ci, Vector2(0, -62 + y0), 3.0, Color(0.95, 0.75, 0.3))
		"marek":
			poly(ci, [Vector2(-9, -50 + y0), Vector2(9, -50 + y0), Vector2(7, -20), Vector2(-7, -20)], L["trim"])
			rect(ci, Rect2(-tw - 2, -50 + y0, tw * 2 + 4, 5), Color(0.38, 0.25, 0.14))
			circ(ci, Vector2(-tw + 1, -70 + y0), 7, Color(0.3, 0.4, 0.62))
			circ(ci, Vector2(tw - 1, -70 + y0), 7, Color(0.3, 0.4, 0.62))
			circ(ci, Vector2(tw - 1, -70 + y0), 3, Color(0.85, 0.66, 0.3))
		"elira":
			rect(ci, Rect2(-tw, -48 + y0, tw * 2, 4), L["trim"])
		"neris":
			poly(ci, [Vector2(-tw, -72 + y0), Vector2(tw, -72 + y0), Vector2(tw - 4, -62 + y0), Vector2(-tw + 4, -62 + y0)], L["trim"])
			poly(ci, [Vector2(-3, -50 + y0), Vector2(3, -50 + y0), Vector2(7, -14), Vector2(-7, -14)], L["trim"])
		"bandit", "raider", "arsonist":
			rect(ci, Rect2(-tw, -46 + y0, tw * 2, 4), Color(0.2, 0.14, 0.1))
		"captain":
			poly(ci, [Vector2(-tw, -72 + y0), Vector2(tw, -72 + y0), Vector2(tw + 10, -24), Vector2(-tw - 10, -24)], L["body"])
			rect(ci, Rect2(-tw - 2, -48 + y0, tw * 2 + 4, 5), L["trim"])
		"brute":
			ell(ci, Vector2(0, -52 + y0), tw + 3, 18, L["body"].lightened(0.05))
	if look == "raider":
		# Второй клинок в задней руке
		_dagger(ci, Vector2(-tw + 6, -64 + y0), 1.0 - sw)
	# Задняя рука (оружие ближнего боя / посох)
	var ang := -0.4 - sw * 1.6
	var shoulder := Vector2(-tw + 4, -66 + y0)
	var hand_back := shoulder + Vector2(cos(ang + PI * 0.5) * -2.0, 0) + Vector2(10, 20)
	# Голова
	var hy := -88.0 + y0
	if big:
		hy -= 4
	var hr := 17.0
	# Шея и голова
	circ(ci, Vector2(1, hy), hr, L["skin"])
	# Уши
	if look in ["elira", "neris"]:
		poly(ci, [Vector2(-6, hy - 2), Vector2(-24, hy - 10), Vector2(-8, hy + 5)], L["skin"])
	# Волосы и головные уборы
	match look:
		"aiden":
			poly(ci, [Vector2(-17, hy + 2), Vector2(-14, hy - 14), Vector2(0, hy - 20), Vector2(14, hy - 14), Vector2(18, hy - 2), Vector2(10, hy - 8), Vector2(4, hy - 4), Vector2(-4, hy - 8)], L["hair"])
			ell(ci, Vector2(-10, hy - 2), 7, 12, L["hair"])
		"marek":
			ell(ci, Vector2(-2, hy - 10), 17, 9, L["hair"])
			ell(ci, Vector2(-12, hy - 2), 6, 9, L["hair"])
			poly(ci, [Vector2(0, hy + 9), Vector2(15, hy + 7), Vector2(13, hy + 15), Vector2(4, hy + 18)], L["hair"])
		"elira":
			poly(ci, [Vector2(-18, hy + 6), Vector2(-14, hy - 14), Vector2(2, hy - 21), Vector2(16, hy - 12), Vector2(18, hy - 2), Vector2(8, hy - 9), Vector2(-4, hy - 6)], L["hair"])
		"neris":
			poly(ci, [Vector2(-19, hy + 14), Vector2(-15, hy - 14), Vector2(2, hy - 20), Vector2(17, hy - 10), Vector2(18, hy + 4), Vector2(9, hy - 8), Vector2(-6, hy - 6)], L["hair"])
			# Рога
			poly(ci, [Vector2(-4, hy - 14), Vector2(-14, hy - 30), Vector2(-26, hy - 26), Vector2(-20, hy - 20), Vector2(-12, hy - 22), Vector2(-8, hy - 12)], Color(0.24, 0.18, 0.22))
			poly(ci, [Vector2(6, hy - 15), Vector2(10, hy - 32), Vector2(22, hy - 30), Vector2(16, hy - 24), Vector2(12, hy - 24), Vector2(12, hy - 13)], Color(0.28, 0.2, 0.25))
		"bandit":
			poly(ci, [Vector2(-18, hy - 2), Vector2(-12, hy - 16), Vector2(12, hy - 17), Vector2(18, hy - 4)], L["trim"])
			poly(ci, [Vector2(-16, hy - 6), Vector2(-28, hy - 2), Vector2(-26, hy + 6)], L["trim"])
			ell(ci, Vector2(4, hy + 12), 10, 6, L["hair"])
		"raider", "arsonist", "healer", "archer":
			var hood: Color = L["trim"] if look != "archer" else L["body"].darkened(0.1)
			if look == "healer":
				hood = L["body"]
			if look == "raider":
				hood = Color(0.16, 0.15, 0.15)
			poly(ci, [Vector2(-20, hy + 14), Vector2(-18, hy - 12), Vector2(0, hy - 23), Vector2(16, hy - 14), Vector2(20, hy - 2), Vector2(12, hy - 6), Vector2(-6, hy - 2), Vector2(-8, hy + 14)], hood)
			if look == "arsonist":
				rect(ci, Rect2(2, hy + 2, 16, 10), Color(0.18, 0.1, 0.1))
			elif look == "raider":
				# Платок на лицо
				poly(ci, [Vector2(-2, hy + 4), Vector2(19, hy + 3), Vector2(16, hy + 13), Vector2(2, hy + 16)], L["trim"])
		"brute":
			ell(ci, Vector2(6, hy + 10), 12, 9, L["hair"])
		"farmer":
			# Соломенная шляпа
			ell(ci, Vector2(0, hy - 10), 28, 6, L["trim"])
			ell(ci, Vector2(0, hy - 16), 14, 9, L["trim"])
			ell(ci, Vector2(6, hy + 12), 9, 5, L["hair"])
		"druid":
			# Капюшон из листьев и корона из рогов
			poly(ci, [Vector2(-20, hy + 16), Vector2(-18, hy - 12), Vector2(0, hy - 22), Vector2(16, hy - 14), Vector2(20, hy - 2), Vector2(12, hy - 6), Vector2(-6, hy - 2), Vector2(-8, hy + 16)], L["body"].darkened(0.2))
			for sx in [-1.0, 1.0]:
				line(ci, Vector2(2 + sx * 6, hy - 18), Vector2(2 + sx * 18, hy - 42), Color(0.78, 0.7, 0.56), 4.5)
				line(ci, Vector2(2 + sx * 13, hy - 31), Vector2(2 + sx * 26, hy - 36), Color(0.78, 0.7, 0.56), 3.5)
				line(ci, Vector2(2 + sx * 16, hy - 38), Vector2(2 + sx * 12, hy - 50), Color(0.78, 0.7, 0.56), 3.5)
		"captain":
			poly(ci, [Vector2(-19, hy + 8), Vector2(-16, hy - 14), Vector2(2, hy - 22), Vector2(17, hy - 12), Vector2(19, hy - 2), Vector2(8, hy - 9)], L["hair"])
			poly(ci, [Vector2(-6, hy + 6), Vector2(18, hy + 4), Vector2(12, hy + 22), Vector2(0, hy + 20)], L["hair"])
	# Глаз
	if look == "marek" or look == "captain" or look == "brute":
		circ(ci, Vector2(9, hy + 1), 3.6, Color(0.95, 0.93, 0.88))
	if look != "arsonist":
		circ(ci, Vector2(9, hy + 1), 2.6, Color(0.1, 0.08, 0.06))
		if look in ["aiden", "elira"]:
			circ(ci, Vector2(9, hy + 1), 1.6, Color(0.2, 0.6, 0.35))
		elif look == "neris":
			circ(ci, Vector2(9, hy + 1), 1.6, Color(0.95, 0.75, 0.2))
		elif look == "druid":
			circ(ci, Vector2(9, hy + 1), 6.0, Color(1.0, 0.15, 0.08, 0.3))
			circ(ci, Vector2(9, hy + 1), 2.4, Color(1.0, 0.25, 0.12))
	else:
		circ(ci, Vector2(10, hy), 2.2, Color(1, 0.6, 0.2))
	# Оружие и передняя рука
	var front_sh := Vector2(tw - 4, -66 + y0)
	match look:
		"marek":
			_sword(ci, front_sh, sw, 34.0)
			_shield(ci, Vector2(tw + 6, -50 + y0), Color(0.24, 0.32, 0.55), true)
		"aiden":
			_staff(ci, front_sh, sw, casting, Color(0.85, 0.68, 0.3), "sun", t)
		"neris":
			_staff(ci, front_sh, sw, casting, Color(0.3, 0.2, 0.28), "crystal", t)
		"healer":
			_staff(ci, front_sh, sw, casting, Color(0.45, 0.32, 0.18), "leaf", t)
		"druid":
			_staff(ci, front_sh, sw, casting, Color(0.3, 0.22, 0.14), "seed", t)
		"farmer":
			# Вилы
			line(ci, front_sh + Vector2(4, 30), front_sh + Vector2(10, -46), Color(0.5, 0.36, 0.2), 3.5)
			for dx in [-5.0, 0.0, 5.0]:
				line(ci, front_sh + Vector2(10 + dx, -46), front_sh + Vector2(10 + dx, -60), Color(0.6, 0.6, 0.62), 2.0)
			line(ci, front_sh + Vector2(4, -46), front_sh + Vector2(16, -46), Color(0.6, 0.6, 0.62), 2.0)
		"elira", "archer":
			_bow(ci, front_sh, sw, look == "elira")
		"bandit":
			_buckler(ci, Vector2(tw + 4, -46 + y0))
			_sword(ci, front_sh, sw, 18.0)
		"raider":
			_dagger(ci, front_sh, sw)
		"brute":
			_club(ci, front_sh, sw)
		"arsonist":
			_torch(ci, front_sh, sw, t)
		"captain":
			_sword(ci, front_sh, sw, 44.0)
	# Ступени: II — кожаный наплечник, III — железный
	if tier >= 2 and not look in ["aiden", "marek", "elira", "neris", "farmer", "druid"]:
		var pc := Color(0.66, 0.46, 0.24) if tier == 2 else Color(0.62, 0.64, 0.68)
		var pp := Vector2(-2, -62 + y0)
		poly(ci, [pp + Vector2(-13, 2) * w, pp + Vector2(-9, -8) * w, pp + Vector2(9, -8) * w, pp + Vector2(13, 2) * w, pp + Vector2(0, 6) * w], pc)
		line(ci, pp + Vector2(-12, 2) * w, pp + Vector2(12, 2) * w, pc.darkened(0.4), 2)
		if tier >= 3:
			circ(ci, pp + Vector2(-6, -2) * w, 1.8, Color(0.9, 0.9, 0.85))
			circ(ci, pp + Vector2(6, -2) * w, 1.8, Color(0.9, 0.9, 0.85))
	if casting:
		var glow := Color(1, 0.9, 0.5, 0.35 + 0.25 * sin(t * 10.0))
		ci.draw_arc(Vector2(0, -50), 40, 0, TAU, 32, c(glow), 2.0)

static func _arm(ci: CanvasItem, sh: Vector2, hand: Vector2, col: Color) -> void:
	line(ci, sh, hand, col, 7)

static func _sword(ci: CanvasItem, sh: Vector2, sw: float, blade: float) -> void:
	var a := lerp(-1.1, 0.5, sw)
	var hand := sh + Vector2(10, 18).rotated(a * 0.4)
	_arm(ci, sh, hand, Color(0.3, 0.25, 0.2))
	var dir := Vector2(cos(a - 0.6), sin(a - 0.6))
	var tip := hand + dir * blade
	line(ci, hand, tip, Color(0.85, 0.87, 0.9), 4.0)
	line(ci, hand - dir.orthogonal() * 6.0, hand + dir.orthogonal() * 6.0, Color(0.8, 0.62, 0.25), 3.0)
	if sw > 0.2 and sw < 0.9:
		ci.draw_arc(hand, blade, a - 1.6, a - 0.1, 12, c(Color(1, 0.95, 0.7, 0.45)), 3.0)

static func _dagger(ci: CanvasItem, sh: Vector2, sw: float) -> void:
	var a := lerp(-0.9, 0.7, sw)
	var hand := sh + Vector2(10, 18).rotated(a * 0.4)
	_arm(ci, sh, hand, Color(0.28, 0.22, 0.18))
	var dir := Vector2(cos(a - 0.3), sin(a - 0.3))
	poly(ci, [hand + dir.orthogonal() * 3.0, hand + dir * 20.0 + dir.orthogonal() * 1.0, hand + dir * 24.0, hand - dir.orthogonal() * 3.0], Color(0.78, 0.8, 0.84))
	line(ci, hand - dir.orthogonal() * 4.0, hand + dir.orthogonal() * 4.0, Color(0.3, 0.22, 0.15), 3.0)
	if sw > 0.2 and sw < 0.9:
		ci.draw_arc(hand, 22, a - 1.3, a, 10, c(Color(1, 0.9, 0.8, 0.4)), 2.0)

static func _buckler(ci: CanvasItem, p: Vector2) -> void:
	circ(ci, p, 11, Color(0.45, 0.3, 0.16))
	ci.draw_arc(p, 11, 0, TAU, 18, c(Color(0.3, 0.3, 0.32)), 2.5)
	line(ci, p + Vector2(-10, -2), p + Vector2(10, 2), Color(0.35, 0.22, 0.12), 2)
	circ(ci, p, 3.5, Color(0.6, 0.6, 0.62))

static func _shield(ci: CanvasItem, p: Vector2, col: Color, cross: bool) -> void:
	poly(ci, [p + Vector2(-9, -20), p + Vector2(12, -20), p + Vector2(12, 4), p + Vector2(1, 18), p + Vector2(-9, 4)], col)
	ci.draw_polyline(PackedVector2Array([p + Vector2(-9, -20), p + Vector2(12, -20), p + Vector2(12, 4), p + Vector2(1, 18), p + Vector2(-9, 4), p + Vector2(-9, -20)]), c(Color(0.85, 0.66, 0.3)), 2.0)
	if cross:
		line(ci, p + Vector2(1, -15), p + Vector2(1, 12), Color(0.9, 0.7, 0.3), 3)
		line(ci, p + Vector2(-5, -6), p + Vector2(8, -6), Color(0.9, 0.7, 0.3), 3)

static func _staff(ci: CanvasItem, sh: Vector2, sw: float, casting: bool, col: Color, top: String, t: float) -> void:
	var hand := sh + Vector2(12, 16) + Vector2(sw * 8.0, -sw * 10.0)
	_arm(ci, sh, hand, Color(0.3, 0.25, 0.2))
	var tip := hand + Vector2(4, -50)
	line(ci, hand + Vector2(-2, 30), tip, col, 4)
	match top:
		"sun":
			for i in 8:
				var a := TAU * i / 8.0 + t * 0.5
				line(ci, tip, tip + Vector2(cos(a), sin(a)) * 11.0, Color(0.95, 0.78, 0.3), 2.5)
			circ(ci, tip, 6, Color(1.0, 0.86, 0.4))
		"crystal":
			poly(ci, [tip + Vector2(0, -14), tip + Vector2(6, -2), tip + Vector2(0, 8), tip + Vector2(-6, -2)], Color(0.95, 0.3, 0.55))
			if casting:
				circ(ci, tip, 10, Color(0.8, 0.4, 1.0, 0.35))
		"leaf":
			ell(ci, tip + Vector2(4, -4), 6, 3, Color(0.4, 0.7, 0.3))
			ell(ci, tip + Vector2(-4, -2), 6, 3, Color(0.35, 0.6, 0.25))
		"seed":
			circ(ci, tip, 9.0 + sin(t * 4.0), Color(1.0, 0.15, 0.08, 0.25))
			circ(ci, tip, 4.5, Color(1.0, 0.25, 0.12))

static func _bow(ci: CanvasItem, sh: Vector2, sw: float, elf: bool) -> void:
	var hand := sh + Vector2(20, 6)
	_arm(ci, sh, hand, Color(0.3, 0.25, 0.2) if not elf else Color(1.0, 0.85, 0.74))
	var col := Color(0.55, 0.35, 0.15) if not elf else Color(0.7, 0.5, 0.2)
	ci.draw_arc(hand + Vector2(-8, 0), 26, -1.2, 1.2, 14, c(col), 3.5)
	var top := hand + Vector2(-8, 0) + Vector2(cos(-1.2), sin(-1.2)) * 26
	var bot := hand + Vector2(-8, 0) + Vector2(cos(1.2), sin(1.2)) * 26
	var pull := hand + Vector2(-8 - 12 * (1.0 - sw), 0)
	line(ci, top, pull, Color(0.9, 0.9, 0.85), 1.0)
	line(ci, bot, pull, Color(0.9, 0.9, 0.85), 1.0)
	if sw < 0.5:
		line(ci, pull, pull + Vector2(34, 0), Color(0.6, 0.45, 0.3), 2)

static func _club(ci: CanvasItem, sh: Vector2, sw: float) -> void:
	var a := lerp(-1.3, 0.6, sw)
	var hand := sh + Vector2(10, 18).rotated(a * 0.4)
	_arm(ci, sh, hand, Color(0.8, 0.6, 0.45))
	var dir := Vector2(cos(a - 0.6), sin(a - 0.6))
	line(ci, hand, hand + dir * 34.0, Color(0.42, 0.28, 0.14), 9)
	circ(ci, hand + dir * 34.0, 7, Color(0.38, 0.25, 0.12))

static func _torch(ci: CanvasItem, sh: Vector2, sw: float, t: float) -> void:
	var hand := sh + Vector2(14, 4) + Vector2(sw * 10.0, 0)
	_arm(ci, sh, hand, Color(0.3, 0.2, 0.15))
	var tip := hand + Vector2(6, -32)
	line(ci, hand + Vector2(-2, 8), tip, Color(0.4, 0.26, 0.14), 4)
	var f := 1.0 + 0.2 * sin(t * 18.0)
	poly(ci, [tip + Vector2(-7, 0), tip + Vector2(0, -20 * f), tip + Vector2(7, 0), tip + Vector2(0, 5)], Color(1.0, 0.5, 0.1))
	poly(ci, [tip + Vector2(-3, 0), tip + Vector2(0, -11 * f), tip + Vector2(3, 0)], Color(1.0, 0.9, 0.4))

## Окрас зверей по ступеням I/II/III
const FUR := {
	"wolf": [Color(0.5, 0.5, 0.52), Color(0.42, 0.33, 0.24), Color(0.84, 0.86, 0.9)],
	"wolf_alpha": [Color(0.36, 0.3, 0.28), Color(0.2, 0.18, 0.19), Color(0.62, 0.63, 0.68)],
	"boar": [Color(0.4, 0.29, 0.21), Color(0.27, 0.21, 0.18), Color(0.46, 0.43, 0.41)],
	"spider": [Color(0.34, 0.25, 0.16), Color(0.17, 0.22, 0.15), Color(0.2, 0.12, 0.24)],
	"lynx": [Color(0.8, 0.62, 0.4), Color(0.62, 0.57, 0.5), Color(0.3, 0.29, 0.32)],
	"bear": [Color(0.45, 0.3, 0.18), Color(0.32, 0.21, 0.13), Color(0.17, 0.14, 0.13)],
}
const ICE_EYE := Color(0.55, 0.92, 1.0)

static func _wolf(ci: CanvasItem, alpha_w: bool, walk: float, t: float, sw: float, tier := 1) -> void:
	var s := 1.3 if alpha_w else 1.0
	var fur: Color = FUR["wolf_alpha" if alpha_w else "wolf"][tier - 1]
	var belly := fur.lightened(0.3)
	var y := -30.0 * s
	# Лапы
	for i in 4:
		var bx := (-22.0 + i * 14.0) * s
		var ph := walk * (1 if i % 2 == 0 else -1)
		line(ci, Vector2(bx, y + 6), Vector2(bx + ph * 8.0, -2), fur.darkened(0.2), 6 * s)
	# Хвост
	poly(ci, [Vector2(-30 * s, y - 2), Vector2(-52 * s, y - 14 * s + walk * 4), Vector2(-48 * s, y + 2), Vector2(-30 * s, y + 6)], fur)
	ell(ci, Vector2(0, y), 32 * s, 15 * s, fur)
	ell(ci, Vector2(2 * s, y + 6 * s), 24 * s, 7 * s, belly)
	if alpha_w or tier >= 3:
		# Грива
		ell(ci, Vector2(18 * s, y - 6 * s), 16 * s, 14 * s, fur.darkened(0.15) if tier < 3 else fur.lightened(0.15))
		for k in 4:
			var mx := (6.0 + k * 6.0) * s
			poly(ci, [Vector2(mx - 4 * s, y - 14 * s), Vector2(mx - 2 * s, y - 24 * s), Vector2(mx + 3 * s, y - 15 * s)], fur.darkened(0.15) if tier < 3 else fur.lightened(0.15))
	# Голова
	var lunge := sw * 10.0
	var hp := Vector2(30 * s + lunge, y - 10 * s)
	circ(ci, hp, 12 * s, fur)
	poly(ci, [hp + Vector2(6, -6) * s, hp + Vector2(24, 0) * s, hp + Vector2(22, 7) * s, hp + Vector2(4, 8) * s], fur.lightened(0.1))
	poly(ci, [hp + Vector2(-6, -8) * s, hp + Vector2(-2, -22) * s, hp + Vector2(4, -9) * s], fur.darkened(0.1))
	poly(ci, [hp + Vector2(2, -9) * s, hp + Vector2(8, -21) * s, hp + Vector2(10, -6) * s], fur.darkened(0.1))
	circ(ci, hp + Vector2(23, 2) * s, 2.5 * s, Color(0.1, 0.08, 0.08))
	var eye := Color(1.0, 0.2, 0.15) if alpha_w else Color(0.95, 0.8, 0.2)
	if tier >= 3:
		eye = ICE_EYE if not alpha_w else Color(1.0, 0.35, 0.2)
	circ(ci, hp + Vector2(6, -3) * s, (3.0 if shade else 2.4) * s, eye)
	if tier == 2:
		# Шрам через морду
		line(ci, hp + Vector2(2, -9) * s, hp + Vector2(12, 5) * s, Color(0.75, 0.55, 0.5), 2.0)
	if sw > 0.1:
		poly(ci, [hp + Vector2(10, 6) * s, hp + Vector2(22, 8) * s, hp + Vector2(12, 12) * s], Color(0.7, 0.2, 0.2))

## Кабан: низкий, горбатый, щетина по хребту, клыки растут со ступенью.
static func _boar(ci: CanvasItem, walk: float, t: float, sw: float, tier: int) -> void:
	var fur: Color = FUR["boar"][tier - 1]
	var y := -26.0
	for i in 4:
		var bx := -20.0 + i * 13.0
		var ph := walk * (1 if i % 2 == 0 else -1)
		line(ci, Vector2(bx, y + 8), Vector2(bx + ph * 6.0, -3), fur.darkened(0.3), 8)
		ell(ci, Vector2(bx + ph * 6.0 + 1, -2), 4, 3, Color(0.12, 0.1, 0.09))
	line(ci, Vector2(-30, y - 4), Vector2(-38, y - 12 + walk * 2), fur.darkened(0.2), 3)
	ell(ci, Vector2(-4, y), 32, 18, fur)
	ell(ci, Vector2(12, y - 5), 20, 19, fur.darkened(0.08))
	ell(ci, Vector2(0, y + 9), 22, 6, fur.lightened(0.12))
	# Щетина по хребту
	var br := fur.darkened(0.35) if tier == 1 else Color(0.78, 0.72, 0.6)
	for k in 8:
		var x := -24.0 + k * 6.5
		var top: float = y - 15.0 - 7.0 * clamp(1.0 - abs(x - 12.0) / 34.0, 0.0, 1.0) - (2.0 if tier >= 2 else 0.0)
		poly(ci, [Vector2(x - 3, top + 5), Vector2(x + 1, top - 6 - 2.0 * (tier - 1)), Vector2(x + 4, top + 5)], br)
	# Голова клином
	var hp := Vector2(28 + sw * 12.0, y - 2)
	poly(ci, [hp + Vector2(-8, -15), hp + Vector2(10, -9), hp + Vector2(25, 3), hp + Vector2(23, 12), hp + Vector2(-4, 13)], fur.darkened(0.05) if tier < 3 else fur.lightened(0.2))
	ell(ci, hp + Vector2(25, 7), 3.5, 6, Color(0.5, 0.35, 0.32))
	poly(ci, [hp + Vector2(-4, -12), hp + Vector2(-9, -24), hp + Vector2(3, -13)], fur.darkened(0.25))
	circ(ci, hp + Vector2(7, -4), 2.2, Color(0.95, 0.3, 0.15) if tier >= 3 else Color(0.08, 0.06, 0.05))
	var tl := 5.0 + 4.0 * tier
	poly(ci, [hp + Vector2(15, 9), hp + Vector2(20, 9 - tl), hp + Vector2(23, 8 - tl * 0.7), hp + Vector2(19, 10)], Color(0.95, 0.92, 0.8))
	if tier >= 3:
		line(ci, Vector2(4, y - 10), Vector2(14, y + 4), Color(0.7, 0.55, 0.5), 2)
		line(ci, Vector2(10, y - 12), Vector2(20, y + 2), Color(0.7, 0.55, 0.5), 2)

## Паук: восемь лап, брюшко с узором ступени. Паучок — маленькая копия без узора.
static func _spider(ci: CanvasItem, walk: float, t: float, sw: float, tier: int, small: bool, moving: bool) -> void:
	var s := 0.6 if small else 1.25 + 0.08 * (tier - 1)
	var col: Color = Color(0.3, 0.24, 0.18) if small else FUR["spider"][tier - 1]
	var y := -24.0 * s
	var leg := col.darkened(0.35)
	for side in 2:
		for i in 4:
			var ph := sin(t * 16.0 + i * 1.7 + side * 3.1) if moving else sin(t * 2.0 + i) * 0.15
			var root := Vector2((2.0 + i * 3.0) * s, y + 2 * s)
			var foot := Vector2((-34.0 + i * 22.0 + side * 6.0 + ph * 5.0) * s, 0)
			var knee := Vector2((root.x + foot.x) * 0.5 + (-4.0 + i * 2.0) * s, y - (16.0 + abs(ph) * 3.0) * s)
			var lc := leg.darkened(0.3) if side == 0 else leg
			line(ci, root, knee, lc, 3.5 * s + 0.5)
			line(ci, knee, foot, lc, 2.5 * s + 0.5)
	# Брюшко
	var ab := Vector2(-16 * s, y - 6 * s)
	ell(ci, ab, 21 * s, 16 * s, col)
	if not small:
		match tier:
			1:
				for k in 3:
					circ(ci, ab + Vector2(-8 + k * 7, -6 + k * 2) * s, 2.6 * s, Color(0.85, 0.7, 0.3))
			2:
				for k in 3:
					ci.draw_arc(ab + Vector2(4, 2) * s, (5.0 + k * 5.0) * s, PI * 0.6, PI * 1.6, 8, c(Color(0.75, 0.82, 0.7, 0.8)), 1.2)
				line(ci, ab + Vector2(4, 2) * s, ab + Vector2(-16, -6) * s, Color(0.75, 0.82, 0.7, 0.8), 1.2)
				line(ci, ab + Vector2(4, 2) * s, ab + Vector2(-12, 10) * s, Color(0.75, 0.82, 0.7, 0.8), 1.2)
			3:
				poly(ci, [ab + Vector2(-6, -9) * s, ab + Vector2(4, -9) * s, ab + Vector2(-1, -1) * s], Color(0.9, 0.15, 0.12))
				poly(ci, [ab + Vector2(-6, 7) * s, ab + Vector2(4, 7) * s, ab + Vector2(-1, -1) * s], Color(0.9, 0.15, 0.12))
				# Паучата на спине
				circ(ci, ab + Vector2(-10, -12) * s, 3.0 * s, col.lightened(0.25))
				circ(ci, ab + Vector2(2, -14) * s, 2.6 * s, col.lightened(0.25))
	# Головогрудь
	var hp := Vector2(10 * s + sw * 8.0, y)
	ell(ci, hp, 11 * s, 9 * s, col.darkened(0.12))
	var ec := Color(0.95, 0.25, 0.2) if tier >= 3 else Color(0.6, 0.95, 0.4)
	for k in 4:
		circ(ci, hp + Vector2(6 + (k % 2) * 3, -4 + (k / 2) * 3) * s, (1.8 if k < 2 else 1.3) * s + 0.4, ec)
	poly(ci, [hp + Vector2(8, 5) * s, hp + Vector2(13, 6) * s, hp + Vector2(10, 12 + sw * 3) * s], Color(0.15, 0.1, 0.1))

## Рысь: поджарая, кисточки на ушах, короткий хвост, пятна. III — дымчатая, светящиеся глаза.
static func _lynx(ci: CanvasItem, walk: float, t: float, sw: float, tier: int) -> void:
	var fur: Color = FUR["lynx"][tier - 1]
	var y := -34.0
	for i in 4:
		var bx := -18.0 + i * 12.0 + (6.0 if i >= 2 else 0.0)
		var ph := walk * (1 if i % 2 == 0 else -1)
		line(ci, Vector2(bx, y + 6), Vector2(bx + ph * 9.0, -3), fur.darkened(0.15), 5)
		ell(ci, Vector2(bx + ph * 9.0 + 2, -2), 4.5, 3, fur.lightened(0.2))
	ell(ci, Vector2(-28, y - 7), 7, 4.5, fur)
	circ(ci, Vector2(-33, y - 9), 3.2, Color(0.1, 0.08, 0.08))
	ell(ci, Vector2(0, y), 28, 12, fur)
	ell(ci, Vector2(2, y + 5), 20, 5, fur.lightened(0.3))
	var spot := fur.darkened(0.4)
	for p in [Vector2(-16, -4), Vector2(-8, -7), Vector2(0, -3), Vector2(9, -6), Vector2(-12, 3), Vector2(4, 2), Vector2(14, 0)]:
		circ(ci, Vector2(p.x, y + p.y), 2.0, spot)
	var hp := Vector2(28 + sw * 14.0, y - 12)
	# Бакенбарды
	poly(ci, [hp + Vector2(-8, 4), hp + Vector2(-6, 16), hp + Vector2(2, 9), hp + Vector2(8, 16), hp + Vector2(10, 4)], fur.lightened(0.35))
	circ(ci, hp, 11, fur)
	ell(ci, hp + Vector2(10, 3), 6, 4.5, fur.lightened(0.3))
	circ(ci, hp + Vector2(15, 2), 1.8, Color(0.25, 0.12, 0.12))
	for ex in [-5.0, 3.0]:
		poly(ci, [hp + Vector2(ex - 4, -7), hp + Vector2(ex + 1, -22), hp + Vector2(ex + 5, -7)], fur.darkened(0.12))
		line(ci, hp + Vector2(ex + 1, -22), hp + Vector2(ex + 1, -29), Color(0.08, 0.06, 0.06), 2)
	var eye := Color(0.75, 0.9, 0.3) if tier < 3 else ICE_EYE
	ell(ci, hp + Vector2(6, -3), 2.6, 2.0, eye)
	circ(ci, hp + Vector2(6.6, -3), 1.0, Color(0.05, 0.05, 0.05))
	if tier >= 2 and sw > 0.1:
		var paw := Vector2(30 + sw * 16.0, y - 2)
		for k in 3:
			line(ci, paw + Vector2(0, k * 3 - 3), paw + Vector2(9, k * 3 - 6), Color(0.95, 0.95, 0.9), 1.5)
	if sw > 0.1:
		poly(ci, [hp + Vector2(6, 5), hp + Vector2(15, 6), hp + Vector2(8, 10)], Color(0.7, 0.2, 0.2))

## Медведь: огромный, горб на холке; на «Встать на дыбы» поднимается. III — чёрный с проседью.
static func _bear(ci: CanvasItem, walk: float, t: float, sw: float, tier: int, casting: bool) -> void:
	var fur: Color = FUR["bear"][tier - 1]
	var r := 1.0 if casting else 0.0
	var y := -42.0
	for i in 4:
		var bx := -26.0 + i * 15.0
		var ph := walk * (1 if i % 2 == 0 else -1)
		var lift := (24.0 * r) if i >= 2 else 0.0
		line(ci, Vector2(bx, y + 8 - lift), Vector2(bx + ph * 7.0 + lift * 0.6, -5 - lift), fur.darkened(0.2), 13)
		ell(ci, Vector2(bx + ph * 7.0 + lift * 0.6 + 2, -4 - lift), 8, 5, fur.darkened(0.3))
		if i >= 2:
			for k in 3:
				line(ci, Vector2(bx + ph * 7.0 + lift * 0.6 + 7, -6 - lift + k * 3 - 3), Vector2(bx + ph * 7.0 + lift * 0.6 + 13, -4 - lift + k * 3 - 2), Color(0.9, 0.88, 0.8), 1.5)
	ell(ci, Vector2(-2, y - 4 * r), 40, 25, fur)
	ell(ci, Vector2(12, y - 16 - 10 * r), 22, 16, fur)
	if tier >= 3:
		ell(ci, Vector2(10, y - 26 - 10 * r), 18, 5, fur.lightened(0.4))
	ell(ci, Vector2(0, y + 12), 28, 8, fur.lightened(0.1))
	var hp := Vector2(40 + sw * 10.0, y - 14 - 24 * r)
	circ(ci, hp + Vector2(-6, -14), 5.5, fur.darkened(0.1))
	circ(ci, hp + Vector2(5, -15), 5.5, fur.darkened(0.1))
	circ(ci, hp, 16, fur)
	ell(ci, hp + Vector2(14, 5), 10, 7, fur.lightened(0.25))
	circ(ci, hp + Vector2(23, 2), 3.5, Color(0.07, 0.05, 0.05))
	circ(ci, hp + Vector2(6, -4), 2.4, Color(1.0, 0.55, 0.15) if tier >= 3 else Color(0.08, 0.06, 0.05))
	if tier >= 2:
		line(ci, hp + Vector2(0, -12), hp + Vector2(12, 6), Color(0.75, 0.55, 0.5), 2.5)
		line(ci, hp + Vector2(5, -13), hp + Vector2(16, 3), Color(0.75, 0.55, 0.5), 2.5)
	if sw > 0.1 or casting:
		poly(ci, [hp + Vector2(10, 9), hp + Vector2(24, 9), hp + Vector2(14, 16)], Color(0.65, 0.18, 0.18))
		line(ci, hp + Vector2(14, 9), hp + Vector2(15, 12), Color(0.95, 0.95, 0.9), 1.5)

# ================================================================ Иконки предметов
## Рисованные иконки из assets/ui/icons/ (нарезаны tools/slice_icons.py). null — рисуем кодом, как раньше.
static var _icons := {}

static func icon_tex(name: String) -> Texture2D:
	if not _icons.has(name):
		var path := "res://assets/ui/icons/%s.png" % name
		_icons[name] = load(path) if ResourceLoader.exists(path) else null
	return _icons[name]

## Какая картинка и какой оттенок у предмета
static func item_icon(item: Dictionary) -> Array:
	var b := Items.base_of(item)
	var base: String = item.get("base", "")
	var at: String = b.get("atype", "")
	var tint := {"cloth": Color(1.12, 1.08, 1.0), "leather": Color.WHITE, "mail": Color(0.78, 0.84, 0.95), "plate": Color(0.7, 0.8, 1.05)}.get(at, Color.WHITE)
	match b.get("wtype", ""):
		"sword": return ["sword", Color.WHITE]
		"mace": return ["mace", Color.WHITE]
		"dagger": return ["dagger", Color.WHITE]
		"bow": return ["bow", Color.WHITE]
		"staff": return ["staff_amethyst" if base.contains("amethyst") else "staff_amber", Color.WHITE]
		"shield": return ["shield_iron" if base == "shield_iron" else "shield_wood", Color.WHITE]
	match b.get("slot", ""):
		"head": return ["hood", tint]
		"chest":
			if at == "mail" or at == "plate":
				return ["chainmail", Color.WHITE if at == "mail" else Color(0.8, 0.88, 1.08)]
			return ["tunic", Color.WHITE if at == "cloth" else Color(0.82, 0.62, 0.45)]
		"hands": return ["gloves", tint]
		"waist": return ["belt", tint]
		"feet": return ["boots", tint]
		"ring": return ["ring", Color.WHITE if base == "ring_copper" else Color(0.85, 0.9, 1.1)]
		"neck": return ["amulet", Color.WHITE if base == "amulet_bone" else Color(1.15, 0.95, 0.55)]
	return ["", Color.WHITE]

static func _draw_icon_tex(ci: CanvasItem, r: Rect2, tex: Texture2D, tint: Color) -> void:
	var side: float = min(r.size.x, r.size.y)
	var rr := Rect2(r.get_center() - Vector2(side, side) * 0.5, Vector2(side, side))
	ci.draw_texture_rect(tex, rr, false, tint)

static func draw_item_icon(ci: CanvasItem, r: Rect2, item: Dictionary) -> void:
	var ic := item_icon(item)
	var itex := icon_tex(ic[0]) if ic[0] != "" else null
	if itex != null:
		_draw_icon_tex(ci, r, itex, ic[1])
		return
	var b := Items.base_of(item)
	var cen := r.get_center()
	var k := r.size.x / 64.0
	var metal := Color(0.78, 0.8, 0.84)
	var gold := Color(0.85, 0.66, 0.3)
	var at: String = b.get("atype", "")
	var cloth := {"cloth": Color(0.85, 0.82, 0.72), "leather": Color(0.55, 0.36, 0.2), "mail": Color(0.6, 0.62, 0.66), "plate": Color(0.4, 0.48, 0.66), "jewel": gold}.get(at, metal)
	ci.draw_set_transform(cen, 0.0, Vector2(k, k))
	match b.get("wtype", ""):
		"sword":
			line(ci, Vector2(-16, 16), Vector2(16, -16), metal, 5)
			line(ci, Vector2(-20, 6), Vector2(-6, 20), gold, 4)
			line(ci, Vector2(-16, 16), Vector2(-22, 22), Color(0.4, 0.25, 0.15), 5)
		"mace":
			line(ci, Vector2(-16, 18), Vector2(8, -6), Color(0.45, 0.3, 0.18), 5)
			circ(ci, Vector2(10, -10), 10, metal)
		"dagger":
			line(ci, Vector2(-10, 12), Vector2(12, -12), metal, 4)
			line(ci, Vector2(-14, 6), Vector2(-4, 16), gold, 3)
		"bow":
			ci.draw_arc(Vector2(8, 0), 22, PI * 0.6, PI * 1.4, 14, c(Color(0.6, 0.4, 0.18)), 4)
			line(ci, Vector2(8, 0) + Vector2(cos(PI * 0.6), sin(PI * 0.6)) * 22, Vector2(8, 0) + Vector2(cos(PI * 1.4), sin(PI * 1.4)) * 22, Color(0.9, 0.9, 0.85), 1.2)
		"staff":
			line(ci, Vector2(-14, 22), Vector2(10, -14), Color(0.55, 0.38, 0.2), 4)
			var gem := Color(0.95, 0.35, 0.6) if item.get("base", "").contains("amethyst") else Color(1.0, 0.82, 0.35)
			circ(ci, Vector2(12, -17), 7, gem)
		"shield":
			_shield(ci, Vector2(-1, 0), Color(0.3, 0.38, 0.6) if item.get("base", "") == "shield_iron" else Color(0.55, 0.38, 0.2), true)
		_:
			match b.get("slot", ""):
				"head":
					poly(ci, [Vector2(-16, 8), Vector2(-14, -10), Vector2(0, -18), Vector2(14, -10), Vector2(16, 8)], cloth)
					rect(ci, Rect2(-17, 6, 34, 6), cloth.darkened(0.25))
				"chest":
					poly(ci, [Vector2(-18, -16), Vector2(-6, -18), Vector2(0, -12), Vector2(6, -18), Vector2(18, -16), Vector2(22, -2), Vector2(14, 0), Vector2(14, 20), Vector2(-14, 20), Vector2(-14, 0), Vector2(-22, -2)], cloth)
				"hands":
					ell(ci, Vector2(-7, 2), 8, 12, cloth)
					ell(ci, Vector2(9, 2), 8, 12, cloth.darkened(0.1))
				"waist":
					rect(ci, Rect2(-22, -5, 44, 10), cloth.darkened(0.1))
					ci.draw_rect(Rect2(-6, -7, 12, 14), c(gold), false, 2.5)
				"feet":
					poly(ci, [Vector2(-14, -18), Vector2(-4, -18), Vector2(-4, 10), Vector2(8, 12), Vector2(8, 18), Vector2(-14, 18)], cloth)
				"neck":
					ci.draw_arc(Vector2(0, -6), 14, 0.2, PI - 0.2, 16, c(gold), 2.0)
					poly(ci, [Vector2(0, 6), Vector2(6, 14), Vector2(0, 22), Vector2(-6, 14)], Color(0.3, 0.75, 0.6) if item.get("base", "") != "amulet_bone" else Color(0.9, 0.88, 0.8))
				"ring":
					ci.draw_arc(Vector2(0, 4), 11, 0, TAU, 20, c(gold if item.get("base", "") == "ring_copper" else Color(0.82, 0.84, 0.9)), 4.0)
					circ(ci, Vector2(0, -8), 5, Color(0.3, 0.55, 0.95) if item.get("base", "") != "ring_copper" else Color(0.9, 0.3, 0.3))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Иконка расходника/подарка
static func draw_cons_icon(ci: CanvasItem, r: Rect2, id: String) -> void:
	var ctex := icon_tex(id)
	if ctex != null:
		_draw_icon_tex(ci, r, ctex, Color.WHITE)
		return
	var cen := r.get_center()
	var k := r.size.x / 64.0
	ci.draw_set_transform(cen, 0.0, Vector2(k, k))
	match id:
		"potion_hp", "potion_mp":
			var col := Color(0.85, 0.2, 0.2) if id == "potion_hp" else Color(0.25, 0.45, 0.95)
			circ(ci, Vector2(0, 6), 14, col)
			rect(ci, Rect2(-5, -18, 10, 12), Color(0.8, 0.85, 0.9, 0.8))
			rect(ci, Rect2(-6, -22, 12, 5), Color(0.5, 0.32, 0.18))
			circ(ci, Vector2(-5, 2), 4, Color(1, 1, 1, 0.4))
		"kit":
			rect(ci, Rect2(-18, -8, 36, 22), Color(0.5, 0.33, 0.18))
			line(ci, Vector2(-10, -14), Vector2(10, 8), Color(0.75, 0.75, 0.8), 4)
			line(ci, Vector2(10, -14), Vector2(-10, 8), Color(0.6, 0.4, 0.2), 4)
		"apple":
			circ(ci, Vector2(-6, 4), 11, Color(0.75, 0.15, 0.12))
			circ(ci, Vector2(8, 6), 10, Color(0.55, 0.8, 0.25))
			line(ci, Vector2(-6, -7), Vector2(-4, -14), Color(0.4, 0.25, 0.1), 2)
		"berries":
			ell(ci, Vector2(0, 10), 18, 9, Color(0.6, 0.4, 0.2))
			for p in [Vector2(-8, 2), Vector2(0, -2), Vector2(8, 2), Vector2(-3, 6), Vector2(5, 6)]:
				circ(ci, p, 5, Color(0.85, 0.12, 0.2) if int(p.x) % 2 == 0 else Color(0.25, 0.2, 0.55))
		"wine":
			rect(ci, Rect2(-7, -6, 14, 26), Color(0.35, 0.05, 0.1))
			rect(ci, Rect2(-3, -20, 6, 14), Color(0.3, 0.05, 0.08))
			rect(ci, Rect2(-7, 2, 14, 8), Color(0.9, 0.85, 0.7))
		"bread":
			ell(ci, Vector2(0, 4), 20, 11, Color(0.8, 0.55, 0.25))
			line(ci, Vector2(-8, -2), Vector2(-4, 6), Color(0.6, 0.38, 0.15), 2)
			line(ci, Vector2(2, -4), Vector2(6, 4), Color(0.6, 0.38, 0.15), 2)
		"tea":
			rect(ci, Rect2(-12, -6, 22, 22), Color(0.85, 0.82, 0.75))
			ci.draw_arc(Vector2(12, 4), 6, -1.5, 1.5, 8, c(Color(0.85, 0.82, 0.75)), 3)
			ell(ci, Vector2(-1, -6), 11, 3, Color(0.5, 0.65, 0.3))
		"book":
			rect(ci, Rect2(-16, -16, 30, 34), Color(0.45, 0.18, 0.15))
			rect(ci, Rect2(-12, -12, 22, 26), Color(0.55, 0.22, 0.18))
			line(ci, Vector2(-8, -4), Vector2(6, -4), Color(0.85, 0.66, 0.3), 2)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
