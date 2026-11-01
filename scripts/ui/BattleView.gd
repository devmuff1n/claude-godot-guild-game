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
var actors: Array = []       # актёры кат-сцены вне боя: [{id, look, name, x, facing, moving, swing}]
var ash: Array = []          # хлопья пепла: враги-проекции (тег phantom) гибнут без тела
var walk_wagon := false
var selected_hero := ""
var target_mode := ""        # "", "enemy", "ally", "ground"
var target_radius := 0.0     # радиус области в режиме "ground"
var target_ab := ""          # умение, для которого выбирается область (цвет превью)
var hover_uid := -1
var hover_pos := Vector2(-1000, -1000)
var hover_card_uid := -1     # герой, над чьей карточкой внизу сейчас курсор (выбор союзника)
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
	"neris": "res://scenes/characters/NerisMX3D.tscn",
	"elira": "res://scenes/characters/EliraMX3D.tscn",
	"marek": "res://scenes/characters/MarekMX3D.tscn",
	"aiden": "res://scenes/characters/AidenMX3D.tscn",
}
## Чем 3D-модель отвечает на обычную атаку: Нэрис бьёт магией из посоха, остальные — своим «attack» (Элира — быстрый выстрел).
const MODEL_ATTACK := {"neris": "cast_release"}
const ROAD_SPEED_PX := 150.0  # отряд на дороге идёт шагом со скоростью прокрутки (ExpeditionScreen.WALK_SPEED)
## Вид героев выбирает игрок (Settings.hero_look, меню паузы): "3d" — модели MODEL_LOOKS, "2d" — спрайты
## SPRITE_LOOKS, "simple" — фигурки Art. Герой без ассетов выбранного вида рисуется фигуркой Art.
var models := {}             # ключ юнита -> Hero3DSprite
## Герои с покадровой рисованной анимацией (SpriteHero) для вида "2d".
const SPRITE_LOOKS := {
	"aiden": "res://assets/sprites/aiden/aiden_actor.tscn",
	"neris": "res://assets/sprites/neris/neris_actor.tscn",
}
var sprites := {}            # ключ юнита -> SpriteHero

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(func():
		hover_pos = Vector2(-1000, -1000)
		hover_uid = -1)
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
	# Враги двигаются и под неподвижным курсором — цель под ним пересчитываем каждый кадр
	if target_mode in ["enemy", "ally"] and hover_pos.x > -500.0:
		hover_uid = unit_at(hover_pos)
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
		if v.has("ash_t"):
			v["ash_t"] += delta
	for a in actors:
		a["swing"] = max(0.0, float(a.get("swing", 0.0)) - delta * 2.5)
	for p in ash:
		p["t"] += delta
		p["v"] += Vector2(18.0, -10.0) * delta
		p["p"] += p["v"] * delta
	ash = ash.filter(func(p): return p["t"] < p["life"])
	for k in models.keys():
		var m: Hero3DSprite = models[k]
		m.render_target_update_mode = SubViewport.UPDATE_ALWAYS if m.used else SubViewport.UPDATE_DISABLED
		m.unused_t = 0.0 if m.used else m.unused_t + delta
		m.used = false
		if m.unused_t > 3.0:
			m.queue_free()
			models.erase(k)
	for k in sprites.keys():
		var sp: SpriteHero = sprites[k]
		sp.unused_t = 0.0 if sp.used else sp.unused_t + delta
		sp.used = false
		if sp.unused_t > 3.0:
			sp.queue_free()
			sprites.erase(k)
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
					_model_event(int(e["uid"]), "cast_release", String(e["ab"]))
			"shake":
				shake = 0.25
			"death":
				var ud = sim.unit(int(e["uid"])) if sim != null else null
				if ud != null and "phantom" in ud["tags"]:
					_v(int(e["uid"]))["ash_t"] = 0.0
					spawn_ash(float(ud["x"]), GROUND + float(_v(int(e["uid"])).get("py", 0.0)))
			"warn_left":
				warn_left = 2.2

## ab — умение из события cast_fx: если у 3D-модели есть свой клип "skill_<ab>" (Марек), играет он.
func _model_event(uid: int, kind: String, ab := "") -> void:
	if sim == null:
		return
	var u = sim.unit(uid)
	if u == null:
		return
	if sprites.has(_model_key(u)):
		sprites[_model_key(u)].one_shot(kind)
		return
	if not models.has(_model_key(u)):
		return
	var m: Hero3DSprite = models[_model_key(u)]
	if ab != "" and m.hero and m.hero.has_state("skill_" + ab):
		kind = "skill_" + ab
	m.one_shot(MODEL_ATTACK.get(u["look"], "attack") if kind == "attack" else kind)


## Ключ 3D-модели юнита: герой отряда — по имени (одна модель на бой и дорогу), остальные — по uid.
func _model_key(u: Dictionary) -> String:
	return "h_" + String(u["key"]) if u["side"] == "hero" else "u%d" % u["uid"]


## Нарисовать юнита 3D-моделью, если для его облика она есть. false — рисовать как раньше.
func _draw_model(key: String, look: String, pos: Vector2, facing: int, st: Dictionary) -> bool:
	var mode := Settings.hero_look()
	if mode == "2d" and SPRITE_LOOKS.has(look):
		return _draw_sprite(key, look, pos, facing, st)
	if mode != "3d" or not MODEL_LOOKS.has(look):
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


## Нарисовать юнита покадровой анимацией (SpriteHero).
func _draw_sprite(key: String, look: String, pos: Vector2, facing: int, st: Dictionary) -> bool:
	var sp: SpriteHero = sprites.get(key)
	if sp == null:
		var scene := load(SPRITE_LOOKS[look]) as PackedScene
		if scene == null:
			return false
		sp = scene.instantiate()
		sp.name = "Sprite_" + key
		add_child(sp)
		sprites[key] = sp
	sp.drive(st)
	if not st.get("dead", false):
		_ell(pos, Art.shadow_w(look) * SC, 7 * SC, Color(0, 0, 0, 0.35 * float(st.get("alpha", 1.0))))
	sp.draw_on(self, pos, facing, st)
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
	_draw_ash()
	_draw_projs()
	_draw_fx()
	_draw_floats()
	# при наезде камеры (ExpeditionScreen меняет scale/position слоя) затемнение остаётся на весь экран
	draw_set_transform_matrix(get_transform().affine_inverse())
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
			var head := Vector2(u["x"], GROUND + float(v.get("py", 0.0)) - Art.head_h(u["look"]) * _tier_k(u) * SC)
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
		Art.draw_unit(self, Vector2(c["x"], GROUND + 4), c["look"], int(c["facing"]) if c["facing"] != 0 else -1, {"t": 0.0, "dead": true, "tier": c.get("tier", 1)}, SC * (1.12 if c.get("big", false) else 1.0) * [1.0, 1.06, 1.12][clampi(int(c.get("tier", 1)), 1, 3) - 1])
	for a in actors:
		var apos := Vector2(float(a["x"]), GROUND + float(a.get("dy", 0.0)))
		Art.draw_unit(self, apos, a["look"], int(a.get("facing", -1)), {"t": time + float(a["x"]) * 0.01, "moving": a.get("moving", false),
			"swing": float(a.get("swing", 0.0)), "alpha": float(a.get("alpha", 1.0)), "shade": a.get("shade", false)},
			SC * (1.12 if a["look"] in ["brute", "captain"] else 1.0))
	var order: Array = walk_units.duplicate()
	order.sort_custom(func(a, b): return _hero_stagger(a["look"]) > _hero_stagger(b["look"]))
	for w in order:
		var wpos := Vector2(w["x"], GROUND - _hero_stagger(w["look"]) * LANE_PX)
		var wst := {"moving": walking, "x": w["x"], "speed_mps": ROAD_SPEED_PX / Hero3DSprite.PX_PER_M if walking else 0.0, "gait": "walk"}
		# та же модель, что была в бою (ключ по герою): после боя она продолжает с текущей позы, без T-позы
		if not _draw_model("h_" + w["look"], w["look"], wpos, 1, wst):
			Art.draw_unit(self, wpos, w["look"], 1, {"t": time + w["x"] * 0.01, "moving": walking}, SC)

## Расстояние между полосами глубины на экране
const LANE_PX := 30.0

## Глубина фигуры: полоса врага, герои — посередине дороги (обходя соседа, шагают в сторону)
func _depth(u: Dictionary) -> float:
	if u["side"] == "enemy":
		return float(u.get("lane", 1)) + float(u.get("side_step", 0.0)) * 0.6
	return (BattleSim.LANES - 1) * 0.5 + float(u.get("side_step", 0.0)) - _hero_stagger(String(u["key"]))

## Герои строя через одного стоят чуть дальше по дороге (доля полосы): соседние фигуры не сливаются,
## а тот, кто дальше, рисуется позади.
const HERO_STAGGER := 0.33

func _hero_stagger(id: String) -> float:
	var f: Array = sim.s["formation"] if sim != null else Game.state.get("formation", [])
	var i := f.find(id)
	return HERO_STAGGER if i >= 0 and i % 2 == 1 else 0.0

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
	# Выбор врага: герои, заслоняющие врагов, становятся полупрозрачными, а враги рисуются поверх них
	var picking_enemy := target_mode == "enemy"
	var see_through := {}
	if picking_enemy:
		see_through = _heroes_covering_enemies()
	var ui_pass: Array = []
	var order := _unit_order()
	if picking_enemy:
		var heroes_first := order.filter(func(x): return x["side"] != "enemy" or not x["alive"])
		heroes_first.append_array(order.filter(func(x): return x["side"] == "enemy" and x["alive"]))
		order = heroes_first
	for u in order:
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
			elif target_mode != "" and can_target(u):
				var hot: bool = u["uid"] == hover_uid or u["uid"] == hover_card_uid
				var tc := Color(1, 0.42, 0.32) if target_mode == "enemy" else Color(0.45, 1, 0.55)
				if hot:
					_ell(pos + Vector2(0, 2), 50, 14, Color(tc, 0.28))
					draw_arc(pos + Vector2(0, -2), 46, 0, TAU, 40, Color(0.05, 0.03, 0.02, 0.6), 6)
					draw_arc(pos + Vector2(0, -2), 46, 0, TAU, 40, tc.lightened(0.25), 3.5)
				else:
					draw_arc(pos + Vector2(0, -2), 38, 0, TAU, 24, Color(tc, 0.35 + 0.25 * sin(time * 6)), 2)
		var stt := {"t": u["anim"], "moving": moving and u["alive"], "swing": v["swing"], "dead": not u["alive"],
			"flash": clamp(u["hurt"] / 0.18, 0.0, 1.0) * 0.7, "cast": u["cast"] != null}
		# Проекция не падает, а тает на месте, рассыпаясь пеплом
		if not u["alive"] and "phantom" in u["tags"]:
			var fade := 1.0 - float(v.get("ash_t", 9.0)) / ASH_FADE
			if fade <= 0.0:
				continue
			stt["dead"] = false
			stt["alpha"] = fade * (0.7 + 0.3 * sin(time * 40.0))
			stt["flash"] = 0.35 * fade
		var sc := SC * _tier_k(u)
		if u["key"] in ["brute", "captain"]:
			sc *= 1.12
		stt["tier"] = int(u.get("tier", 1))
		stt["shade"] = "phantom" in u["tags"]
		if u["alive"] and sim.has_effect(u, "hidden"):
			stt["alpha"] = 0.22 + 0.06 * sin(time * 5.0 + u["uid"])
		elif see_through.has(u["uid"]):
			stt["alpha"] = 0.38
		if u["task"] != null:
			stt["swing"] = abs(sin(time * 6.0))
		var facing := int(u["facing"]) if u["facing"] != 0 else (1 if u["side"] == "hero" else -1)
		stt["x"] = u["x"]
		if not _draw_model(_model_key(u), u["look"], pos, facing, stt):
			Art.draw_unit(self, pos, u["look"], facing, stt, sc)
		if u["alive"] and not sim.in_dark(u):
			ui_pass.append([u, pos])
	# Полоски здоровья и подписи — после всех фигур, чтобы плашку врага за спиной героя было видно и по ней можно было кликнуть.
	# Плашки врагов — поверх героев.
	for it in ui_pass:
		if it[0]["side"] != "enemy":
			_draw_unit_ui(it[0], it[1])
	for it in ui_pass:
		if it[0]["side"] == "enemy":
			_draw_unit_ui(it[0], it[1])

## Герои, чей силуэт перекрывает силуэт врага, которого сейчас можно выбрать целью.
func _heroes_covering_enemies() -> Dictionary:
	var res := {}
	var foes: Array = []
	for e in sim.s["units"]:
		if e["side"] == "enemy" and can_target(e):
			foes.append(unit_rect(e))
	for h in sim.s["units"]:
		if h["side"] != "hero" or not h["alive"]:
			continue
		var hr := unit_rect(h).grow(-6.0)
		for fr in foes:
			if hr.intersects(fr):
				res[h["uid"]] = true
				break
	return res

## Перебор целей с клавиатуры (Tab / Shift+Tab): по порядку слева направо.
func cycle_target(dir: int) -> int:
	var arr: Array = sim.s["units"].filter(func(x): return can_target(x))
	if arr.is_empty():
		return -1
	arr.sort_custom(func(a, b): return a["x"] < b["x"])
	var i := -1
	for k in arr.size():
		if arr[k]["uid"] == hover_uid:
			i = k
	i = posmod(i + dir, arr.size()) if i >= 0 else (0 if dir > 0 else arr.size() - 1)
	hover_uid = int(arr[i]["uid"])
	hover_pos = Vector2(-1000, -1000)   # курсор больше не ведёт выбор, пока мышь не сдвинется
	return hover_uid

## Враги старших ступеней чуть крупнее.
func _tier_k(u: Dictionary) -> float:
	if u["side"] != "enemy":
		return 1.0
	return [1.0, 1.06, 1.12][clampi(int(u.get("tier", 1)), 1, 3) - 1]

## Полоска здоровья над юнитом: x — верх полоски, y — её ширина. Общая для отрисовки и наведения.
func _bar_geom(u: Dictionary, pos: Vector2) -> Vector2:
	var top := pos.y - Art.top_h(u["look"]) * SC * _tier_k(u) - 8.0
	if u["key"] in ["brute", "captain"]:
		top -= 20
	var bw := 70.0 if u["side"] == "enemy" else 56.0
	if "boss" in u["tags"]:
		bw = 110.0
	if u.get("champion", "") != "":
		bw = 90.0
	return Vector2(top, bw)

func _draw_unit_ui(u: Dictionary, pos: Vector2) -> void:
	var bg := _bar_geom(u, pos)
	var top := bg.x
	var bw := bg.y
	var champ: String = u.get("champion", "")
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
		"doom": ["Р", Color(0.85, 0.45, 1)], "intercede": ["Х", Color(1, 0.95, 0.6)], "voice": ["!", Color(0.85, 0.45, 1)],
		"haste": ["Б", Color(1, 0.85, 0.3)], "blind": ["Сл", Color(0.85, 0.8, 0.6)], "bleed": ["Кр", Color(0.95, 0.2, 0.2)],
		"hidden": ["Т", Color(0.6, 0.7, 0.6)]}
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
		# Читаемая угроза (Into the Breach): над полосой приёма — кого он заденет
		if u["side"] == "enemy":
			var tgt := ""
			var tu = sim.unit(int(c.get("target", -1)))
			if tu != null and tu["side"] == "hero":
				tgt = "→ " + String(tu["name"])
			elif int(c.get("target", -1)) < 0 and String(c.get("obj", "")) != "":
				tgt = "→ " + ("повозка" if c["obj"] == "wagon" else ("ворота" if c["obj"] == "gate" else "сундук"))
			if tgt != "":
				draw_string_outline(UIK.fb(), Vector2(pos.x - cw * 0.5, cy - 6), tgt, HORIZONTAL_ALIGNMENT_CENTER, cw, 13, 3, Color(0, 0, 0, 0.9))
				draw_string(UIK.fb(), Vector2(pos.x - cw * 0.5, cy - 6), tgt, HORIZONTAL_ALIGNMENT_CENTER, cw, 13, Color(1, 0.72, 0.55))
	if u["task"] != null:
		var tk: Dictionary = u["task"]
		var ty := top - 24
		draw_rect(Rect2(pos.x - 50, ty, 100, 16), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(pos.x - 50, ty, 100 * clamp(tk["t"] / tk["total"], 0.0, 1.0), 16), Color(0.5, 0.8, 1.0, 0.75))
		draw_string(UIK.fb(), Vector2(pos.x - 50, ty + 12), "Ремонт" if tk["type"] == "repair" else "Тушит", HORIZONTAL_ALIGNMENT_CENTER, 100, 12, Color.WHITE)
	if u["queued"] != null:
		draw_string(UIK.f(), Vector2(pos.x - 60, top - 22), "→ " + DB.ABILITIES[u["queued"]["ab"]]["name"], HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Color(1, 0.9, 0.6))

# ================================================================ Кат-сцены
const ASH_FADE := 0.9

## Хлопья пепла и угольки на месте исчезнувшей проекции.
func spawn_ash(x: float, ground_y: float) -> void:
	for i in 120:
		var ember := i % 7 == 0
		var col := Color(1.0, 0.32, 0.1) if ember else Color(0.08, 0.07, 0.08).lerp(Color(0.62, 0.6, 0.58), randf() * randf())
		ash.append({"p": Vector2(x + randf_range(-50, 50), ground_y - randf_range(6, 80)),
			"v": Vector2(randf_range(-30, 30), randf_range(-90, -20)), "t": -randf() * ASH_FADE * 0.7,
			"life": randf_range(1.8, 3.2), "col": col, "r": randf_range(2.5, 5.5) if not ember else randf_range(1.5, 2.6)})
	# тёмный выдох: клуб дыма на месте тела
	ash.append({"p": Vector2(x, ground_y - 40), "v": Vector2(10, -12), "t": 0.0, "life": 1.4, "col": Color(0.06, 0.04, 0.07), "r": 0.0, "puff": true})

func _draw_ash() -> void:
	for p in ash:
		if p["t"] < 0.0:
			continue
		var k: float = p["t"] / p["life"]
		var col: Color = p["col"]
		if p.get("puff", false):
			col.a = 0.45 * (1.0 - k)
			_ell(p["p"], 40.0 + 70.0 * k, 26.0 + 40.0 * k, col)
			continue
		col.a = (1.0 - k * k) * 0.95
		draw_circle(p["p"], float(p["r"]) * (1.0 - k * 0.5), col)

## Короткое движение героя вне боя (3D-модель или спрайт; у простых фигурок — ничего).
func hero_anim(id: String, kind: String) -> void:
	var key := "h_" + id
	if sprites.has(key):
		sprites[key].one_shot(kind)
	elif models.has(key):
		models[key].one_shot(kind)

func add_fx(pos: Vector2, kind: String) -> void:
	fx.append({"pos": pos, "kind": kind, "t": 0.0, "dur": 0.9})

func actor(id: String) -> Dictionary:
	for a in actors:
		if a["id"] == id:
			return a
	return {}

## Точка над головой говорящего (координаты слоя): герой на дороге или в бою, либо актёр кат-сцены.
func speaker_anchor(id: String) -> Vector2:
	var a := actor(id)
	if not a.is_empty():
		return Vector2(float(a["x"]), GROUND - Art.top_h(a["look"]) * SC - 14.0)
	var x := NAN
	if sim != null:
		var u = sim.hero_unit(id)
		if u != null:
			x = float(u["x"])
	else:
		for w in walk_units:
			if w["look"] == id:
				x = float(w["x"])
	if is_nan(x):
		return Vector2(-1, -1)
	var y := GROUND - _hero_stagger(id) * LANE_PX
	var h := Art.top_h(id) * SC + 18.0
	if Settings.hero_look() == "3d" and MODEL_LOOKS.has(id):
		h = 228.0
	elif Settings.hero_look() == "2d" and SPRITE_LOOKS.has(id):
		h = 205.0
	return Vector2(x, y - h)

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
## Можно ли выбрать юнит целью в текущем режиме наведения: атакующие приёмы — только видимые враги,
## союзные — только герои. Без режима наведения кликабельны все живые.
func can_target(u: Dictionary) -> bool:
	if not u["alive"]:
		return false
	match target_mode:
		"enemy":
			return u["side"] == "enemy" and not sim.in_dark(u)
		"ally":
			return u["side"] == "hero"
		"ground":
			return false
	return true

## Прямоугольник, где юнит нарисован на экране: от ног (с учётом полосы глубины) до полоски здоровья.
func unit_rect(u: Dictionary) -> Rect2:
	var k := _tier_k(u)
	var py := float(_v(u["uid"]).get("py", (_depth(u) - (BattleSim.LANES - 1) * 0.5) * LANE_PX))
	var feet := GROUND + py
	var h := Art.top_h(u["look"]) * SC * k + 14.0
	if u["key"] in ["brute", "captain"]:
		h += 20.0
	var hw := 26.0
	match u["look"]:
		"wolf", "wolf_alpha", "boar", "lynx", "spider":
			hw = 40.0
		"bear":
			hw = 50.0
		"spiderling":
			hw = 24.0
	hw *= k
	return Rect2(u["x"] - hw, feet - h, hw * 2.0, h + 14.0)

## Плашка над юнитом — полоска здоровья вместе с именем над ней: наведение на неё тоже выбирает юнита.
func bar_rect(u: Dictionary) -> Rect2:
	var py := float(_v(u["uid"]).get("py", (_depth(u) - (BattleSim.LANES - 1) * 0.5) * LANE_PX))
	var bg := _bar_geom(u, Vector2(u["x"], GROUND + py))
	var above := 6.0
	if u["side"] == "enemy":
		above = 36.0 if u.get("champion", "") != "" else 20.0
	return Rect2(u["x"] - bg.y * 0.5 - 4.0, bg.x - above, bg.y + 8.0, above + 12.0)

## Юнит под курсором. Сначала ищем того, в чей силуэт попала точка (при наложении — ближайшего к центру,
## а из равных — стоящего ближе к камере); если не попали ни в кого, берём ближайшего в пределах MAGNET px.
## Текущая подсвеченная цель держится, пока соседняя не станет заметно ближе, — подсветка не скачет.
const MAGNET := 28.0
func unit_at(p: Vector2) -> int:
	if sim == null:
		return -1
	var best := -1
	var bs := 1e9
	var cur_s := 1e9
	for u in sim.s["units"]:
		if not can_target(u):
			continue
		var r := unit_rect(u)
		var c := r.get_center()
		var sc: float
		var br := bar_rect(u)
		if not sim.in_dark(u) and br.has_point(p):
			# Попали в плашку со здоровьем — это самый точный выбор
			sc = 0.05 + abs(p.x - br.get_center().x) / br.size.x * 0.1
		elif r.has_point(p):
			sc = abs(p.x - c.x) / (r.size.x * 0.5) * 0.7 + abs(p.y - c.y) / (r.size.y * 0.5) * 0.3 - _depth(u) * 0.04
		else:
			var dx: float = max(r.position.x - p.x, 0.0, p.x - r.end.x)
			var dy: float = max(r.position.y - p.y, 0.0, p.y - r.end.y)
			var d := Vector2(dx, dy).length()
			if d > MAGNET:
				continue
			sc = 1.0 + d / MAGNET
		if u["uid"] == hover_uid:
			cur_s = sc
		if sc < bs:
			bs = sc
			best = u["uid"]
	if cur_s < 1e8 and cur_s <= bs + 0.18:
		return hover_uid
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
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if (hover_uid >= 0 and target_mode in ["enemy", "ally"]) else Control.CURSOR_ARROW
	elif ev is InputEventMouseButton and ev.pressed:
		if target_mode == "ground" and ev.button_index == MOUSE_BUTTON_LEFT:
			ground_clicked.emit(ev.position.x)
			accept_event()
			return
		var uid := unit_at(ev.position)
		hover_uid = uid
		if uid >= 0:
			unit_clicked.emit(uid, ev.button_index)
			accept_event()
		elif target_mode != "":
			# В режиме наведения клик мимо цели ничего не делает (правая кнопка — отмена)
			if ev.button_index == MOUSE_BUTTON_RIGHT:
				unit_clicked.emit(-1, MOUSE_BUTTON_RIGHT)
			accept_event()
		else:
			var o := object_at(ev.position)
			if o != "" and ev.button_index == MOUSE_BUTTON_LEFT:
				object_clicked.emit(o)
			elif ev.button_index == MOUSE_BUTTON_RIGHT:
				unit_clicked.emit(-1, MOUSE_BUTTON_RIGHT)
