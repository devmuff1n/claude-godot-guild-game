class_name BattleView
extends Control
## Поле боя и дороги: лес сбоку, отряд, враги, объекты, снаряды, всплывающие числа.

signal unit_clicked(uid: int, button: int)
signal object_clicked(obj: String)
signal ground_clicked(x: float)

const GROUND := 600.0
const SC := 1.38
const W := 1600.0

var sim: BattleSim = null
var night := false
var tint := Color(1, 1, 1, 0)  # слой времени суток поверх поля (DayTime.PRESETS → tint); если пусто — ночной слой по night
var outpost := false
var bg_3d := false           # фон, дорога и частокол рисуются 3D-уровнем под этим слоем
var scroll := 0.0
var walking := false
var walk_units: Array = []   # [{look, x}] для режима ходьбы
var corpses: Array = []      # павшие враги остаются на дороге и уезжают назад вместе с ней
var walk_wagon := false
var selected_hero := ""
var target_mode := ""        # "", "enemy", "ally", "ground"
var target_radius := 0.0     # радиус области в режиме "ground"
var target_ab := ""          # умение, для которого выбирается область (цвет превью)
var hover_uid := -1
var hover_pos := Vector2(-1000, -1000)
var time := 0.0
var shake := 0.0
var warn_left := 0.0

var floats: Array = []
var projs: Array = []
var fx: Array = []
var vis := {}   # uid -> {swing, dx, dead_t}
var trees_far: Array = []
var trees_mid: Array = []
var bushes: Array = []
var stones: Array = []
var stars: Array = []

## Герои, которых вместо рисованной фигурки показывает 3D-модель (Hero3DSprite).
const MODEL_LOOKS := {
	"neris": "res://scenes/characters/Neris3D.tscn",
	"elira": "res://scenes/characters/Elira3D.tscn",
}
## Чем 3D-модель отвечает на обычную атаку: Нэрис бьёт магией из посоха, остальные — своим «attack» (Элира — быстрый выстрел).
const MODEL_ATTACK := {"neris": "cast_release"}
const ROAD_SPEED_MPS := 1.7  # отряд на дороге идёт со скоростью прокрутки (260 px/с)
## Выключено (26.10.2026): 3D-модели пока выглядят хуже рисованных фигурок. Модели и сцены остаются в проекте, true вернёт их.
var use_3d_models := false
var models := {}             # ключ юнита -> Hero3DSprite

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var r := RandomNumberGenerator.new()
	r.seed = 777
	for i in 26:
		trees_far.append({"x": r.randf_range(0, 1800), "h": r.randf_range(180, 300), "w": r.randf_range(40, 70), "c": r.randf_range(0.0, 1.0)})
	for i in 11:
		trees_mid.append({"x": i * 165.0 + r.randf_range(-40, 40), "w": r.randf_range(30, 58), "c": r.randf_range(0.0, 1.0), "blobs": []})
		for j in 6:
			trees_mid[i]["blobs"].append(Vector3(r.randf_range(-80, 80), r.randf_range(-40, 60), r.randf_range(40, 75)))
	for i in 30:
		bushes.append({"x": r.randf_range(0, 1800), "y": r.randf_range(0, 1), "r": r.randf_range(20, 46), "c": r.randf_range(0, 1)})
	for i in 24:
		stones.append(Vector3(r.randf_range(0, 1800), r.randf_range(548, 650), r.randf_range(3, 8)))
	for i in 60:
		stars.append(Vector3(r.randf_range(0, 1600), r.randf_range(0, 260), r.randf_range(0.5, 1.8)))

func _process(delta: float) -> void:
	time += delta
	shake = max(0.0, shake - delta)
	warn_left = max(0.0, warn_left - delta)
	for f in floats:
		f["t"] += delta
	floats = floats.filter(func(f): return f["t"] < 1.2)
	for p in projs:
		p["t"] += delta
	projs = projs.filter(func(p): return p["t"] < p["dur"])
	for e in fx:
		e["t"] += delta
	fx = fx.filter(func(e): return e["t"] < e["dur"])
	for k in vis.keys():
		var v: Dictionary = vis[k]
		v["swing"] = max(0.0, v["swing"] - delta * 3.5)
	for k in models.keys():
		var m: Hero3DSprite = models[k]
		m.render_target_update_mode = SubViewport.UPDATE_ALWAYS if m.used else SubViewport.UPDATE_DISABLED
		m.unused_t = 0.0 if m.used else m.unused_t + delta
		m.used = false
		if m.unused_t > 3.0:
			m.queue_free()
			models.erase(k)
	queue_redraw()

## Забрать визуальные события из симуляции
func consume_events(evs: Array) -> void:
	for e in evs:
		match e["type"]:
			"float":
				var u = sim.unit(int(e["uid"])) if sim != null else null
				if u != null:
					var n := 0
					for f in floats:
						if f.get("uid", -1) == e["uid"] and f["t"] < 0.3:
							n += 1
					floats.append({"uid": e["uid"], "pos": Vector2(u["x"], GROUND - 175 - n * 18), "text": e["text"], "color": e["color"], "big": e.get("big", false), "t": 0.0})
			"float_obj":
				var o = sim.s["objects"].get(e["obj"]) if sim != null else null
				if o != null:
					floats.append({"pos": Vector2(o["x"], GROUND - 170), "text": e["text"], "color": e["color"], "big": false, "t": 0.0})
			"swing":
				_v(int(e["uid"]))["swing"] = 1.0
				_model_event(int(e["uid"]), "attack")
			"proj":
				var a = sim.unit(int(e["from"]))
				var b = sim.unit(int(e["to"]))
				if a != null and b != null:
					projs.append({"a": Vector2(a["x"], GROUND - 60), "b": Vector2(b["x"], GROUND - 55), "kind": e["kind"], "t": 0.0, "dur": 0.28})
			"area_fx":
				fx.append({"pos": Vector2(float(e["x"]), GROUND), "kind": e["ab"], "t": 0.0, "dur": 0.7, "area": float(e["r"])})
			"cast_fx":
				var u2 = sim.unit(int(e["uid"]))
				if u2 != null:
					fx.append({"pos": Vector2(u2["x"], GROUND - 55), "kind": e["ab"], "t": 0.0, "dur": 0.6})
					_model_event(int(e["uid"]), "cast_release")
			"shake":
				shake = 0.25
			"warn_left":
				warn_left = 2.2

func _model_event(uid: int, kind: String) -> void:
	if sim == null:
		return
	var u = sim.unit(uid)
	if u == null or not models.has("u%d" % uid):
		return
	models["u%d" % uid].one_shot(MODEL_ATTACK.get(u["look"], "attack") if kind == "attack" else kind)


## Нарисовать юнита 3D-моделью, если для его облика она есть. false — рисовать как раньше.
func _draw_model(key: String, look: String, pos: Vector2, facing: int, st: Dictionary) -> bool:
	if not use_3d_models or not MODEL_LOOKS.has(look):
		return false
	var m: Hero3DSprite = models.get(key)
	if m == null:
		var scene := load(MODEL_LOOKS[look]) as PackedScene
		if scene == null:
			return false
		m = Hero3DSprite.new(scene)
		m.name = "Model_" + key
		add_child(m)
		models[key] = m
	m.drive(st, facing)
	if not st.get("dead", false):
		_ell(pos, 30 * SC, 7 * SC, Color(0, 0, 0, 0.35))
	draw_texture(m.get_texture(), pos - m.anchor(), Color(1, 1, 1, 0.8 if st.get("dead", false) else 1.0))
	return true


func _v(uid: int) -> Dictionary:
	if not vis.has(uid):
		vis[uid] = {"swing": 0.0}
	return vis[uid]

# ================================================================ Отрисовка
func _draw() -> void:
	var sh := Vector2.ZERO
	if shake > 0.0:
		sh = Vector2(randf_range(-4, 4), randf_range(-3, 3)) * (shake / 0.25)
	draw_set_transform(sh, 0.0, Vector2.ONE)
	if not bg_3d:
		_draw_bg()
		if outpost:
			_draw_palisade()
	_draw_objects()
	if sim != null:
		_draw_areas()
		_draw_units()
		if sim.s.get("night", false):
			_draw_darkness()
	else:
		_draw_walkers()
	_draw_projs()
	_draw_fx()
	_draw_floats()
	if tint.a > 0.0:
		draw_rect(Rect2(-20, -20, W + 40, 940), tint)
	elif night:
		draw_rect(Rect2(0, 0, W, 900), Color(0.03, 0.05, 0.16, 0.12 if bg_3d else 0.28))
	if warn_left > 0.0:
		var a := 0.25 + 0.25 * sin(time * 12.0)
		var pts := PackedVector2Array([Vector2(0, 300), Vector2(140, 300), Vector2(60, 700), Vector2(0, 700)])
		draw_colored_polygon(pts, Color(1, 0.2, 0.1, a * 0.5))
		draw_string(UIK.fb(), Vector2(14, 290), "⚠ Засада!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.6, 0.4, 0.6 + a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Ночь: всё дальше NIGHT_SIGHT от героев тонет во тьме; у скрытых врагов видны только глаза.
func _draw_darkness() -> void:
	var lit := []
	var reach := BattleSim.NIGHT_SIGHT + BattleSim.BODY
	for h in sim.alive_of("hero"):
		lit.append([float(h["x"]) - reach, float(h["x"]) + reach])
	lit.sort_custom(func(a, b): return a[0] < b[0])
	var spans := []
	for l in lit:
		if not spans.is_empty() and l[0] <= spans[-1][1]:
			spans[-1][1] = max(spans[-1][1], l[1])
		else:
			spans.append([l[0], l[1]])
	var dark := Color(0.01, 0.02, 0.07, 0.62)
	var edge := 70.0
	var x := -200.0
	for sp in spans:
		if sp[0] > x:
			draw_rect(Rect2(x, 0, sp[0] - x, 900), dark)
		# мягкий край света
		for i in 6:
			var a := dark.a * (1.0 - (i + 1) / 7.0)
			draw_rect(Rect2(sp[0] + i * edge / 6.0, 0, edge / 6.0, 900), Color(dark, a))
			draw_rect(Rect2(sp[1] - (i + 1) * edge / 6.0, 0, edge / 6.0, 900), Color(dark, a))
		x = max(x, sp[1])
	if x < W + 200:
		draw_rect(Rect2(x, 0, W + 200 - x, 900), dark)
	for u in sim.alive_of("enemy"):
		if sim.in_dark(u):
			var v := _v(u["uid"])
			var head := Vector2(u["x"], GROUND + float(v.get("py", 0.0)) - (52.0 if u["look"].begins_with("wolf") else 98.0) * SC)
			var f := -6.0 if int(u["facing"]) < 0 else 6.0
			var glow := Color(1, 0.75, 0.3, 0.75 + 0.2 * sin(time * 3.0 + u["uid"]))
			draw_circle(head + Vector2(f - 4, 0), 2.6, glow)
			draw_circle(head + Vector2(f + 4, 0), 2.6, glow)

func _wrap(x: float, period: float) -> float:
	return fposmod(x, period) - 100.0

func _draw_bg() -> void:
	var day_top := Color(0.36, 0.5, 0.42) if not night else Color(0.05, 0.07, 0.16)
	var day_bot := Color(0.2, 0.3, 0.2) if not night else Color(0.06, 0.1, 0.12)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, 560), Vector2(0, 560)]),
		PackedColorArray([day_top, day_top, day_bot, day_bot]))
	if night:
		for s in stars:
			draw_circle(Vector2(s.x, s.y), s.z, Color(1, 1, 0.9, 0.5 + 0.4 * sin(time * 2.0 + s.x)))
		draw_circle(Vector2(1320, 90), 34, Color(0.95, 0.95, 0.85, 0.9))
		draw_circle(Vector2(1332, 82), 30, Color(0.07, 0.09, 0.18, 0.95))
	# Дальний ельник
	for t in trees_far:
		var x := _wrap(t["x"] - scroll * 0.25, 1800.0)
		var base_y := 470.0
		var col := Color(0.12, 0.22, 0.15).lerp(Color(0.16, 0.28, 0.18), t["c"])
		if night:
			col = col.darkened(0.55)
		for k in 4:
			var yy: float = base_y - t["h"] * (k / 4.0)
			var ww: float = t["w"] * (1.0 - k * 0.2)
			draw_colored_polygon(PackedVector2Array([Vector2(x - ww, yy), Vector2(x + ww, yy), Vector2(x, yy - t["h"] * 0.42)]), col)
	# Лучи света
	if not night:
		for i in 4:
			var lx := _wrap(300.0 + i * 450.0 - scroll * 0.4, 1800.0)
			draw_colored_polygon(PackedVector2Array([Vector2(lx, 0), Vector2(lx + 70, 0), Vector2(lx - 120, 560), Vector2(lx - 260, 560)]), Color(1, 0.95, 0.7, 0.05))
	# Средние деревья
	for t in trees_mid:
		var x := _wrap(t["x"] - scroll * 0.55, 1815.0)
		var trunk := Color(0.24, 0.17, 0.11).lerp(Color(0.32, 0.22, 0.14), t["c"])
		if night:
			trunk = trunk.darkened(0.5)
		draw_rect(Rect2(x - t["w"] * 0.5, 60, t["w"], 470), trunk)
		draw_rect(Rect2(x - t["w"] * 0.5, 60, t["w"] * 0.25, 470), trunk.darkened(0.25))
		for b in t["blobs"]:
			var cc := Color(0.1, 0.22, 0.1).lerp(Color(0.18, 0.34, 0.14), fmod(b.x * 0.013 + 5.0, 1.0))
			if night:
				cc = cc.darkened(0.55)
			draw_circle(Vector2(x + b.x, 40 + b.y), b.z, cc)
	# Подлесок
	for b in bushes:
		var x := _wrap(b["x"] - scroll * 0.75, 1800.0)
		var cc2 := Color(0.14, 0.3, 0.13).lerp(Color(0.22, 0.4, 0.16), b["c"])
		if night:
			cc2 = cc2.darkened(0.5)
		draw_circle(Vector2(x, 520 - b["y"] * 30), b["r"], cc2)
	# Дорога
	var road := Color(0.5, 0.38, 0.24) if not night else Color(0.25, 0.22, 0.2)
	draw_polygon(PackedVector2Array([Vector2(0, 535), Vector2(W, 530), Vector2(W, 680), Vector2(0, 690)]),
		PackedColorArray([road.darkened(0.15), road.darkened(0.15), road, road]))
	for i in 9:
		var px := _wrap(i * 210.0 - scroll, 1890.0)
		draw_colored_polygon(PackedVector2Array([Vector2(px, 600), Vector2(px + 90, 596), Vector2(px + 120, 612), Vector2(px + 10, 616)]), Color(road.lightened(0.12), 0.6))
	for s in stones:
		var x2 := _wrap(s.x - scroll, 1800.0)
		draw_circle(Vector2(x2, s.y), s.z, Color(0.6, 0.58, 0.52) if not night else Color(0.35, 0.35, 0.36))
	# Передний план
	var fg := Color(0.07, 0.15, 0.07) if not night else Color(0.03, 0.06, 0.06)
	for i in 14:
		var fx2 := _wrap(i * 135.0 - scroll * 1.3, 1890.0)
		draw_circle(Vector2(fx2, 740 + (i % 3) * 14), 60 + (i % 4) * 12, fg)
	draw_rect(Rect2(0, 760, W, 140), fg)

func _draw_palisade() -> void:
	var gx := BattleSim.GATE_X
	for i in 12:
		var x := gx - 20 - i * 26.0
		if x < -30:
			break
		draw_colored_polygon(PackedVector2Array([Vector2(x - 12, 600), Vector2(x - 12, 300), Vector2(x, 270), Vector2(x + 12, 300), Vector2(x + 12, 600)]), Color(0.38, 0.26, 0.15) if i % 2 == 0 else Color(0.33, 0.22, 0.13))
	draw_rect(Rect2(-10, 360, gx - 30, 12), Color(0.25, 0.17, 0.1))
	draw_rect(Rect2(-10, 520, gx - 30, 12), Color(0.25, 0.17, 0.1))
	# Знамя
	draw_colored_polygon(PackedVector2Array([Vector2(60, 330), Vector2(110, 330), Vector2(110, 430), Vector2(85, 410), Vector2(60, 430)]), Color(0.2, 0.28, 0.5))
	draw_line(Vector2(85, 345), Vector2(85, 400), Color(0.85, 0.66, 0.3), 4)
	draw_line(Vector2(72, 360), Vector2(98, 360), Color(0.85, 0.66, 0.3), 4)

func _draw_objects() -> void:
	var objs := {}
	if sim != null:
		objs = sim.s["objects"]
	elif walk_wagon:
		objs = {"wagon": {"x": BattleSim.WAGON_X, "hp": 1, "max": 1, "burning": 0.0}}
	for k in objs.keys():
		var o: Dictionary = objs[k]
		var x: float = o["x"]
		match k:
			"wagon":
				_draw_wagon(x, o["hp"] <= 0.0)
			"gate":
				if not bg_3d:
					_draw_gate(x, o)
			"chest":
				_draw_chest(x, o)
		if o["burning"] > 0.0 and o["hp"] > 0.0:
			for i in 7:
				var fxx := x - 40 + i * 13 + sin(time * 9.0 + i) * 4
				var fh = 30 + 22 * abs(sin(time * 7.0 + i * 1.7))
				draw_colored_polygon(PackedVector2Array([Vector2(fxx - 9, GROUND - 60), Vector2(fxx, GROUND - 60 - fh), Vector2(fxx + 9, GROUND - 60)]), Color(1, 0.45 + 0.2 * sin(i), 0.1, 0.85))
		if sim != null:
			var pct: float = o["hp"] / o["max"]
			var bw := 120.0
			var by := GROUND - 200 if k != "chest" else GROUND - 120
			draw_rect(Rect2(x - bw * 0.5 - 2, by - 2, bw + 4, 12), Color(0, 0, 0, 0.75))
			var col := Color(0.4, 0.85, 0.35) if k == "wagon" else Color(0.95, 0.7, 0.25)
			draw_rect(Rect2(x - bw * 0.5, by, bw * pct, 8), col)

func _draw_wagon(x: float, broken: bool) -> void:
	var y := GROUND
	var wood := Color(0.42, 0.28, 0.16)
	var t := time if walking else 0.0
	# Лошадь
	var hx := x + 120
	var horse := Color(0.48, 0.3, 0.17)
	var leg := sin(t * 10.0) * 6.0
	for i in 4:
		draw_line(Vector2(hx - 26 + i * 16, y - 50), Vector2(hx - 26 + i * 16 + (leg if i % 2 == 0 else -leg), y - 4), horse.darkened(0.2), 7)
	_ell(Vector2(hx, y - 62), 40, 20, horse)
	draw_colored_polygon(PackedVector2Array([Vector2(hx + 28, y - 70), Vector2(hx + 46, y - 112), Vector2(hx + 66, y - 106), Vector2(hx + 58, y - 92), Vector2(hx + 40, y - 60)]), horse)
	draw_colored_polygon(PackedVector2Array([Vector2(hx + 30, y - 76), Vector2(hx + 40, y - 112), Vector2(hx + 36, y - 74)]), Color(0.2, 0.12, 0.07))
	draw_line(Vector2(hx - 30, y - 70), Vector2(x + 70, y - 70), Color(0.3, 0.2, 0.12), 3)
	# Повозка
	draw_rect(Rect2(x - 80, y - 90, 160, 44), wood)
	for i in 5:
		draw_line(Vector2(x - 80, y - 90 + i * 11), Vector2(x + 80, y - 90 + i * 11), wood.darkened(0.25), 1)
	if not broken:
		draw_colored_polygon(PackedVector2Array([Vector2(x - 78, y - 90), Vector2(x - 70, y - 150), Vector2(x - 30, y - 172), Vector2(x + 30, y - 172), Vector2(x + 70, y - 150), Vector2(x + 78, y - 90)]), Color(0.86, 0.8, 0.64))
		for i in 4:
			draw_line(Vector2(x - 50 + i * 33, y - 168), Vector2(x - 56 + i * 37, y - 92), Color(0.7, 0.63, 0.48), 2)
	for wx in [x - 50, x + 50]:
		var rot := -scroll * 0.02
		draw_circle(Vector2(wx, y - 30), 26, Color(0.3, 0.2, 0.12))
		draw_circle(Vector2(wx, y - 30), 21, Color(0.5, 0.36, 0.2))
		for i in 6:
			var a := rot + TAU * i / 6.0
			draw_line(Vector2(wx, y - 30), Vector2(wx, y - 30) + Vector2(cos(a), sin(a)) * 20, Color(0.3, 0.2, 0.12), 3)
		draw_circle(Vector2(wx, y - 30), 5, Color(0.25, 0.18, 0.1))
	# Возчик
	Art.draw_unit(self, Vector2(x + 62, y - 88), "bandit", 1, {"t": time}, 0.62)

func _draw_gate(x: float, o: Dictionary) -> void:
	var y := GROUND
	var pct: float = o["hp"] / o["max"]
	var wood := Color(0.42, 0.29, 0.16).lerp(Color(0.2, 0.13, 0.08), 1.0 - pct)
	draw_rect(Rect2(x - 34, y - 300, 68, 300), wood)
	for i in 5:
		draw_line(Vector2(x - 34 + i * 17, y - 300), Vector2(x - 34 + i * 17, y), wood.darkened(0.35), 2)
	draw_rect(Rect2(x - 38, y - 250, 76, 12), Color(0.25, 0.17, 0.1))
	draw_rect(Rect2(x - 38, y - 90, 76, 12), Color(0.25, 0.17, 0.1))
	if pct < 0.5:
		draw_colored_polygon(PackedVector2Array([Vector2(x - 10, y - 200), Vector2(x + 14, y - 180), Vector2(x - 2, y - 150), Vector2(x + 12, y - 120), Vector2(x - 16, y - 130)]), Color(0.08, 0.05, 0.03))
	# Факел
	draw_line(Vector2(x + 50, y - 230), Vector2(x + 50, y - 190), Color(0.35, 0.22, 0.12), 4)
	draw_circle(Vector2(x + 50, y - 236), 7 + sin(time * 14.0), Color(1, 0.6, 0.2, 0.9))

func _draw_chest(x: float, o: Dictionary) -> void:
	var y := GROUND
	draw_rect(Rect2(x - 34, y - 46, 68, 40), Color(0.45, 0.28, 0.14))
	draw_rect(Rect2(x - 36, y - 56, 72, 14), Color(0.38, 0.23, 0.12))
	draw_rect(Rect2(x - 34, y - 46, 68, 40), Color(0.8, 0.62, 0.25), false, 2)
	draw_rect(Rect2(x - 5, y - 40, 10, 12), Color(0.85, 0.66, 0.3))

func _ell(cen: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(cen + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)

func shift_corpses(dx: float) -> void:
	for c in corpses:
		c["x"] -= dx
	corpses = corpses.filter(func(c): return c["x"] > -200.0)

func _draw_walkers() -> void:
	for c in corpses:
		Art.draw_unit(self, Vector2(c["x"], GROUND + 4), c["look"], int(c["facing"]) if c["facing"] != 0 else -1, {"t": 0.0, "dead": true}, SC * (1.12 if c.get("big", false) else 1.0))
	for w in walk_units:
		var wpos := Vector2(w["x"], GROUND)
		var wst := {"moving": walking, "x": w["x"], "speed_mps": ROAD_SPEED_MPS if walking else 0.0}
		if not _draw_model("w_" + w["look"], w["look"], wpos, 1, wst):
			Art.draw_unit(self, wpos, w["look"], 1, {"t": time + w["x"] * 0.01, "moving": walking}, SC)

## Расстояние между полосами глубины на экране
const LANE_PX := 30.0

## Глубина фигуры: полоса врага, герои — посередине дороги
func _depth(u: Dictionary) -> float:
	if u["side"] == "enemy":
		return float(u.get("lane", 1))
	return (BattleSim.LANES - 1) * 0.5

func _unit_order() -> Array:
	var arr: Array = sim.s["units"].duplicate()
	# Павшие снизу; живые враги — по глубине (кто ниже на дороге, тот ближе к камере и рисуется поверх)
	arr.sort_custom(func(a, b):
		var ka := (1 if a["alive"] else 0) * 10.0 + _depth(a)
		var kb := (1 if b["alive"] else 0) * 10.0 + _depth(b)
		return ka < kb)
	return arr

## Цвет области по умению: огонь, тьма или стрелы.
static func area_color(ab: String) -> Color:
	match ab:
		"hellfire":
			return Color(1.0, 0.45, 0.12)
		"curse":
			return Color(0.72, 0.4, 1.0)
	return Color(1.0, 0.86, 0.45)

## Овал области на дороге: заливка и контур.
func _area_ellipse(x: float, r: float, col: Color, fill_a: float, line_a: float, width := 2.5) -> void:
	if r < 2.0:
		return
	var c := Vector2(x, GROUND + 4)
	var ry := r * 0.24
	var pts := PackedVector2Array()
	for i in 48:
		var a := TAU * i / 48.0
		pts.append(c + Vector2(cos(a) * r, sin(a) * ry))
	if fill_a > 0.0:
		draw_colored_polygon(pts, Color(col.darkened(0.15), fill_a))
	pts.append(pts[0])
	draw_polyline(pts, Color(0.08, 0.04, 0.02, line_a * 0.55), width + 3.0, true)
	draw_polyline(pts, Color(col.lightened(0.15), line_a), width, true)

func _draw_areas() -> void:
	# Готовящиеся удары по области: метка на земле, пока герой не закончит подготовку
	for u in sim.s["units"]:
		if u["alive"] and u["side"] == "hero" and u["cast"] != null and u["cast"].has("x"):
			var c: Dictionary = u["cast"]
			var r: float = DB.ABILITIES[c["ab"]].get("area", 0.0)
			var k: float = clamp(c["t"] / c["total"], 0.0, 1.0)
			var col := area_color(c["ab"])
			_area_ellipse(float(c["x"]), r, col, 0.22 + 0.15 * k, 0.75 + 0.25 * k, 3.0)
			_area_ellipse(float(c["x"]), r * k, col, 0.0, 0.5, 1.5)
	# Превью под курсором при выборе области
	if target_mode == "ground" and hover_pos.x > -500.0:
		var col2 := area_color(target_ab)
		var pulse := 0.5 + 0.5 * sin(time * 6.0)
		_area_ellipse(hover_pos.x, target_radius, col2, 0.30 + 0.08 * pulse, 1.0, 3.5)
		draw_line(Vector2(hover_pos.x, GROUND - 6), Vector2(hover_pos.x, GROUND + 14), Color(col2, 0.9), 2.0)

func _draw_units() -> void:
	var focus: int = sim.s["focus"]
	var hero_focus := -1
	var sh = sim.hero_unit(selected_hero) if selected_hero != "" else null
	if sh != null:
		var hf = sim.hero_focus(sh)
		if hf != null:
			hero_focus = int(hf["uid"])
	for u in _unit_order():
		var v := _v(u["uid"])
		# Враги стоят на полосах глубины дороги; смена полосы — плавным шагом
		var ty := (_depth(u) - (BattleSim.LANES - 1) * 0.5) * LANE_PX
		v["py"] = lerp(float(v.get("py", ty)), ty, 0.15)
		var pos := Vector2(u["x"], GROUND + float(v["py"]))
		var moving := false
		if v.has("px"):
			moving = abs(v["px"] - u["x"]) > 0.3
		v["px"] = u["x"]
		# Кольца выбора
		if u["alive"]:
			if u["side"] == "hero" and u["key"] == selected_hero:
				draw_arc(pos + Vector2(0, -2), 40, 0, TAU, 32, Color(1, 0.8, 0.3, 0.9), 3)
			if u["uid"] == focus:
				draw_arc(pos + Vector2(0, -2), 42, 0, TAU, 32, Color(1, 0.25, 0.2, 0.9), 3)
			if "champion" in u["tags"]:
				_ell(pos + Vector2(0, 2), 44, 12, Color(1, 0.78, 0.25, 0.22 + 0.12 * sin(time * 4.0)))
			if u["uid"] == hero_focus:
				draw_arc(pos + Vector2(0, -2), 48, 0, TAU, 32, Color(1, 0.8, 0.3, 0.9), 2)
			if target_mode == "ground":
				if u["side"] == "enemy" and hover_pos.x > -500.0 and abs(u["x"] - hover_pos.x) <= target_radius + BattleSim.BODY * 0.5:
					draw_arc(pos + Vector2(0, -2), 40, 0, TAU, 32, Color(area_color(target_ab), 0.95), 3)
			elif target_mode != "" and u["uid"] == hover_uid:
				var ok = (target_mode == "enemy" and u["side"] == "enemy") or (target_mode == "ally" and u["side"] == "hero")
				draw_arc(pos + Vector2(0, -2), 46, 0, TAU, 32, Color(0.4, 1, 0.5) if ok else Color(0.6, 0.6, 0.6), 3)
			elif target_mode == "enemy" and u["side"] == "enemy":
				draw_arc(pos + Vector2(0, -2), 38, 0, TAU, 24, Color(1, 0.5, 0.4, 0.35 + 0.25 * sin(time * 6)), 2)
			elif target_mode == "ally" and u["side"] == "hero":
				draw_arc(pos + Vector2(0, -2), 38, 0, TAU, 24, Color(0.5, 1, 0.6, 0.35 + 0.25 * sin(time * 6)), 2)
		var stt := {"t": u["anim"], "moving": moving and u["alive"], "swing": v["swing"], "dead": not u["alive"],
			"flash": clamp(u["hurt"] / 0.18, 0.0, 1.0) * 0.7, "cast": u["cast"] != null}
		var sc := SC
		if u["key"] in ["brute", "captain"]:
			sc = SC * 1.12
		if u["task"] != null:
			stt["swing"] = abs(sin(time * 6.0))
		var facing := int(u["facing"]) if u["facing"] != 0 else (1 if u["side"] == "hero" else -1)
		stt["x"] = u["x"]
		if not _draw_model("u%d" % u["uid"], u["look"], pos, facing, stt):
			Art.draw_unit(self, pos, u["look"], facing, stt, sc)
		if u["alive"] and not sim.in_dark(u):
			_draw_unit_ui(u, pos)

func _draw_unit_ui(u: Dictionary, pos: Vector2) -> void:
	var top := pos.y - 112.0 * SC - 8.0
	if u["look"].begins_with("wolf"):
		top = pos.y - 70.0 * SC * (1.3 if u["look"] == "wolf_alpha" else 1.0) - 8.0
	if u["key"] in ["brute", "captain"]:
		top -= 20
	var bw := 70.0 if u["side"] == "enemy" else 56.0
	if "boss" in u["tags"]:
		bw = 110.0
	var champ: String = u.get("champion", "")
	if champ != "":
		bw = 90.0
	var pct: float = u["hp"] / u["max_hp"]
	draw_rect(Rect2(pos.x - bw * 0.5 - 1, top - 1, bw + 2, 9), Color(0, 0, 0, 0.8))
	draw_rect(Rect2(pos.x - bw * 0.5, top, bw * pct, 7), Color(0.9, 0.25, 0.22) if u["side"] == "enemy" else Color(0.4, 0.85, 0.35))
	var b = sim.get_effect(u, "barrier")
	if b != null:
		var bp: float = clamp(b["val"] / u["max_hp"], 0.0, 1.0)
		draw_rect(Rect2(pos.x - bw * 0.5, top - 4, bw * bp, 3), Color(1, 0.9, 0.5))
	if u["side"] == "enemy":
		var nm: String = u["name"]
		if champ != "":
			draw_string(UIK.fb(), Vector2(pos.x - 90, top - 22), nm, HORIZONTAL_ALIGNMENT_CENTER, 180, 14, Color(1, 0.82, 0.35))
			draw_string(UIK.f(), Vector2(pos.x - 90, top - 6), DB.CHAMPION_AFFIXES[champ]["name"], HORIZONTAL_ALIGNMENT_CENTER, 180, 12, Color(1, 0.7, 0.45, 0.9))
		else:
			draw_string(UIK.f(), Vector2(pos.x - 70, top - 6), nm, HORIZONTAL_ALIGNMENT_CENTER, 140, 13, Color(1, 0.9, 0.85, 0.85))
	# Эффекты
	var ex := pos.x - bw * 0.5
	var tags := {"taunt": ["П", Color(1, 0.7, 0.2)], "stun": ["О", Color(1, 1, 0.4)], "slow": ["З", Color(0.5, 0.9, 0.5)],
		"root": ["К", Color(0.4, 0.8, 0.3)], "vuln": ["У", Color(1, 0.5, 0.3)], "weak": ["С", Color(0.7, 0.5, 1)],
		"dot": ["Т", Color(0.7, 0.4, 1)], "burn": ["Г", Color(1, 0.5, 0.1)], "hot": ["+", Color(0.4, 1, 0.5)],
		"barrier": ["Щ", Color(1, 0.9, 0.5)], "wall": ["С", Color(0.6, 0.8, 1)], "taunting": ["П", Color(1, 0.8, 0.3)],
		"howl": ["Я", Color(1, 0.4, 0.3)], "guard": ["Г", Color(0.6, 0.8, 1)], "rally": ["Н", Color(1, 0.85, 0.35)],
		"doom": ["Р", Color(0.85, 0.45, 1)], "intercede": ["Х", Color(1, 0.95, 0.6)], "voice": ["!", Color(0.85, 0.45, 1)]}
	for e in u["effects"]:
		if tags.has(e["id"]):
			var tg: Array = tags[e["id"]]
			draw_rect(Rect2(ex, top + 10, 15, 15), Color(0, 0, 0, 0.7))
			draw_string(UIK.fb(), Vector2(ex + 2, top + 22), tg[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tg[1])
			ex += 17
	# Подготовка приёма
	if u["cast"] != null:
		var c: Dictionary = u["cast"]
		var cw := 130.0
		var cy := top - (36 if u["side"] == "enemy" else 22) - (18 if champ != "" else 0)
		var col := Color(1, 0.45, 0.2) if u["side"] == "enemy" else Color(1, 0.85, 0.4)
		draw_rect(Rect2(pos.x - cw * 0.5 - 2, cy - 2, cw + 4, 22), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(pos.x - cw * 0.5, cy, cw * clamp(c["t"] / c["total"], 0.0, 1.0), 18), Color(col, 0.75))
		draw_rect(Rect2(pos.x - cw * 0.5 - 2, cy - 2, cw + 4, 22), col, false, 1.5)
		draw_string(UIK.fb(), Vector2(pos.x - cw * 0.5, cy + 14), c["name"], HORIZONTAL_ALIGNMENT_CENTER, cw, 13, Color(1, 1, 1))
	if u["task"] != null:
		var tk: Dictionary = u["task"]
		var ty := top - 24
		draw_rect(Rect2(pos.x - 50, ty, 100, 16), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(pos.x - 50, ty, 100 * clamp(tk["t"] / tk["total"], 0.0, 1.0), 16), Color(0.5, 0.8, 1.0, 0.75))
		draw_string(UIK.fb(), Vector2(pos.x - 50, ty + 12), "Ремонт" if tk["type"] == "repair" else "Тушит", HORIZONTAL_ALIGNMENT_CENTER, 100, 12, Color.WHITE)
	if u["queued"] != null:
		draw_string(UIK.f(), Vector2(pos.x - 60, top - 22), "→ " + DB.ABILITIES[u["queued"]["ab"]]["name"], HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Color(1, 0.9, 0.6))

func _draw_projs() -> void:
	for p in projs:
		var k: float = p["t"] / p["dur"]
		var pos: Vector2 = p["a"].lerp(p["b"], k) + Vector2(0, -sin(k * PI) * 30.0)
		var dir: Vector2 = (p["b"] - p["a"]).normalized()
		match p["kind"]:
			"arrow", "big_arrow":
				draw_line(pos - dir * (18 if p["kind"] == "arrow" else 28), pos, Color(0.95, 0.9, 0.75), 2.5 if p["kind"] == "arrow" else 4.0)
				if p["kind"] == "big_arrow":
					draw_circle(pos, 6, Color(1, 0.9, 0.5, 0.6))
			"holy":
				draw_circle(pos, 7, Color(1, 0.9, 0.5))
				draw_circle(pos, 12, Color(1, 0.9, 0.5, 0.3))
			"shadow", "big_shadow":
				var r := 8.0 if p["kind"] == "shadow" else 13.0
				draw_circle(pos, r, Color(0.7, 0.3, 1.0))
				draw_circle(pos, r * 1.8, Color(0.7, 0.3, 1.0, 0.25))
				draw_line(pos - dir * 40, pos, Color(0.8, 0.4, 1.0, 0.5), r)
			"fire":
				draw_circle(pos, 10, Color(1, 0.5, 0.15))
				draw_circle(pos, 17, Color(1, 0.4, 0.1, 0.3))
			"nature":
				draw_circle(pos, 6, Color(0.5, 0.9, 0.3))

func _draw_fx() -> void:
	for e in fx:
		var k: float = e["t"] / e["dur"]
		var col := Color(1, 0.9, 0.5, 1.0 - k)
		match e["kind"]:
			"heal", "renew", "prayer", "potion":
				col = Color(0.5, 1.0, 0.55, 1.0 - k)
			"ward":
				col = Color(1, 0.92, 0.5, 1.0 - k)
			"taunt", "wall":
				col = Color(1, 0.6, 0.2, 1.0 - k)
			"curse", "bolt", "drain":
				col = Color(0.75, 0.4, 1.0, 1.0 - k)
			"hellfire":
				col = Color(1, 0.45, 0.1, 1.0 - k)
		if e.has("area"):
			var ac := area_color(e["kind"])
			_area_ellipse(e["pos"].x, e["area"] * (0.6 + 0.4 * k), ac, 0.35 * (1.0 - k), 1.0 - k, 4.0 * (1.0 - k) + 1.0)
			continue
		draw_arc(e["pos"], 20 + k * 60, 0, TAU, 32, col, 4.0 * (1.0 - k) + 1.0)
		if e["kind"] in ["heal", "renew", "prayer", "potion"]:
			for i in 5:
				var px: float = e["pos"].x - 24 + i * 12
				draw_string(UIK.fb(), Vector2(px, e["pos"].y - k * 70 - (i % 2) * 14), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)

func _draw_floats() -> void:
	for f in floats:
		var k: float = f["t"] / 1.2
		var p: Vector2 = f["pos"] + Vector2(0, -k * 50.0)
		var a = 1.0 - max(0.0, k - 0.5) * 2.0
		var fs := 22 if f["big"] else 16
		var col: Color = f["color"]
		col.a = a
		draw_string(UIK.fb(), p + Vector2(-60 + 1.5, 1.5), f["text"], HORIZONTAL_ALIGNMENT_CENTER, 120, fs, Color(0, 0, 0, a * 0.9))
		draw_string(UIK.fb(), p + Vector2(-60, 0), f["text"], HORIZONTAL_ALIGNMENT_CENTER, 120, fs, col)

# ================================================================ Ввод
func unit_at(p: Vector2) -> int:
	if sim == null:
		return -1
	var best := -1
	var bd := 1e9
	for u in sim.s["units"]:
		if not u["alive"]:
			continue
		var dx: float = abs(u["x"] - p.x)
		if dx < 40 and p.y > GROUND - 150 and p.y < GROUND + 30:
			if dx < bd:
				bd = dx
				best = u["uid"]
	return best

func object_at(p: Vector2) -> String:
	if sim == null:
		return ""
	for k in sim.s["objects"].keys():
		var o: Dictionary = sim.s["objects"][k]
		if abs(o["x"] - p.x) < 80 and p.y > GROUND - 220 and p.y < GROUND:
			return k
	return ""

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		hover_uid = unit_at(ev.position)
		hover_pos = ev.position
	elif ev is InputEventMouseButton and ev.pressed:
		if target_mode == "ground" and ev.button_index == MOUSE_BUTTON_LEFT:
			ground_clicked.emit(ev.position.x)
			accept_event()
			return
		var uid := unit_at(ev.position)
		if uid >= 0:
			unit_clicked.emit(uid, ev.button_index)
			accept_event()
		else:
			var o := object_at(ev.position)
			if o != "" and ev.button_index == MOUSE_BUTTON_LEFT:
				object_clicked.emit(o)
			elif ev.button_index == MOUSE_BUTTON_RIGHT:
				unit_clicked.emit(-1, MOUSE_BUTTON_RIGHT)
