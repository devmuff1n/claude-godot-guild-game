class_name IntroScreen
extends Control
## Вступительная кат-сцена в 3D-поселении (scenes/screens/IntroScreen.tscn): планы камеры, актёры-модели,
## субтитры в чёрных полосах. Сцена — данные DB.CUTSCENES["intro"] ("stage": "town"):
##   "actors": {id: {"at": [x, z] | [x, y, z], "face": [x, z] | id, "hidden": bool}} — кто стоит на площадке;
##   "shots":  {имя: {"pos": [x,y,z], "look": [x,y,z] | id | [id, id…], "fov": 40,
##             "follow": id | [id…], "offset": [x,y,z]}} — планы; follow — камера едет за актёрами со сдвигом offset.
## Шаги:
##   {"cam": имя} — монтажная склейка; {"cam": имя, "t": 3.0} — плавный проезд (не ждёт), "wait": true — ждёт.
##   {"say": id | "", "text": …, "cam": имя} — реплика (ждёт щелчка); "" — голос за кадром. cam — склейка перед репликой.
##   {"walk": id, "path": [[x,z]…], "speed": 1.3} — идёт по точкам (не ждёт); {"wait_walk": true} — ждать всех.
##   {"face": id, "to": id | [x,z]} — повернуться; {"anim": id, "clip": "MX_…"} — разовый клип модели;
##   {"gesture": "ortwin", "kind": "cane" | "nod"}; {"show": id}; {"wait": сек}; {"banner": текст, "t": сек};
##   {"fade_in": сек}; {"fade_out": сек} (ждёт).
## Щелчок, пробел или Enter — следующая реплика; «Пропустить» — сразу в поселение.

signal finished

const ACTOR_SCENES := {
	"aiden": "res://scenes/characters/AidenMX3D.tscn",
	"marek": "res://scenes/characters/MarekMX3D.tscn",
	"elira": "res://scenes/characters/EliraMX3D.tscn",
	"neris": "res://scenes/characters/NerisMX3D.tscn",
	"ortwin": "res://scenes/characters/Ortwin3D.tscn",
}
## Высота глаз (м): сюда смотрит камера, когда план нацелен на актёра
const EYE := {"aiden": 1.47, "marek": 1.6, "elira": 1.4, "neris": 1.38, "ortwin": 1.2}
const TYPE_CPS := 55.0       # скорость появления текста, знаков в секунду
const CLICK_DELAY := 0.2     # защита от двойного щелчка
const TURN_SPEED := 5.0      # скорость поворота актёра, рад/с (сглаженно)

var main
var params: Dictionary = {}

var data: Dictionary = {}
var steps: Array = []
var i := 0
var waiting := ""            # "", "click", "time", "walk", "cam", "fade", "done"
var wait_t := 0.0
var since_show := 0.0
var speaker := ""
var actors := {}             # id -> {node, path: Array[Vector3], speed, yaw, yaw_to}
var _cam_from := {}          # снимок камеры в начале проезда
var _look := Vector3.ZERO    # куда камера смотрит сейчас
var _cam_shot := ""
var _cam_t := 0.0
var _cam_len := 0.0
var _clock := 0.0
var _ended := false

@onready var cam: Camera3D = %CineCam


func _ready() -> void:
	%Skip.pressed.connect(skip)
	%Banner.modulate.a = 0.0
	%Fade.modulate.a = 1.0
	_clear_say()
	cam.current = true
	data = DB.CUTSCENES[params.get("id", "intro")]
	steps = data["steps"]
	for id in data.get("actors", {}).keys():
		_spawn(id, data["actors"][id])
	for id in data.get("actors", {}).keys():
		var f = data["actors"][id].get("face")
		if f != null:
			var a: Dictionary = actors[id]
			a["yaw"] = _yaw_to(a["node"].position, _point(f))
			a["yaw_to"] = a["yaw"]
			a["node"].rotation.y = a["yaw"]
	_run()


# ================================================================ Актёры
func _spawn(id: String, cfg: Dictionary) -> void:
	var n: Node3D = load(ACTOR_SCENES[id]).instantiate()
	%Actors.add_child(n)
	n.position = _v3(cfg["at"])
	n.visible = not cfg.get("hidden", false)
	actors[id] = {"node": n, "path": [], "speed": 1.3, "yaw": 0.0, "yaw_to": 0.0, "moving": false}


## Точка на площадке: [x, z], [x, y, z] или id актёра (его ноги)
func _point(p) -> Vector3:
	if typeof(p) == TYPE_STRING:
		return actors[p]["node"].position
	return _v3(p)


func _v3(a: Array) -> Vector3:
	return Vector3(a[0], 0.0, a[1]) if a.size() == 2 else Vector3(a[0], a[1], a[2])


## Поворот, при котором модель (смотрит вдоль +Z) глядит из from в to
func _yaw_to(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(d.x, d.z) if Vector2(d.x, d.z).length() > 0.01 else 0.0


func _eye(id: String) -> Vector3:
	return actors[id]["node"].position + Vector3(0, EYE.get(id, 1.6), 0)


func _hero(id: String) -> HeroModel3D:
	return actors[id]["node"] as HeroModel3D


func _update_actors(delta: float) -> void:
	for id in actors.keys():
		var a: Dictionary = actors[id]
		var n: Node3D = a["node"]
		if a["moving"]:
			var path: Array = a["path"]
			var step := float(a["speed"]) * delta
			while step > 0.0 and not path.is_empty():
				var to: Vector3 = path[0]
				var d := n.position.distance_to(to)
				if d <= step:
					n.position = to
					step -= d
					path.pop_front()
				else:
					n.position = n.position.move_toward(to, step)
					step = 0.0
			if not path.is_empty():
				a["yaw_to"] = _yaw_to(n.position, path[0])
			else:
				a["moving"] = false
				var h := _hero(id)
				if h:
					h.play_state("idle")
				if a.has("face_after"):
					a["yaw_to"] = _yaw_to(n.position, _point(a["face_after"]))
		a["yaw"] = lerp_angle(float(a["yaw"]), float(a["yaw_to"]), minf(1.0, delta * TURN_SPEED))
		n.rotation.y = a["yaw"]
	# Ортвин смотрит на того, кто говорит (или на Эйдена)
	if actors.has("ortwin"):
		var o: Ortwin3D = actors["ortwin"]["node"]
		var who := speaker if speaker != "" and speaker != "ortwin" and actors.has(speaker) else String(data.get("ortwin_looks", "aiden"))
		o.look_target = _eye(who) if actors.has(who) and actors[who]["node"].visible else null
		o.talking = speaker == "ortwin" and waiting == "click" and %Text.visible_ratio < 1.0


func _walking() -> bool:
	for a in actors.values():
		if a["moving"]:
			return true
	return false


# ================================================================ Камера
func _shot_state(name: String) -> Dictionary:
	var s: Dictionary = data["shots"][name]
	var pos: Vector3
	if s.has("follow"):
		pos = _center(s["follow"]) + _v3(s.get("offset", [0, 2, 4]))
	else:
		pos = _v3(s["pos"])
	var look: Vector3
	var l = s.get("look", [0, 1, 0])
	if typeof(l) == TYPE_STRING or (typeof(l) == TYPE_ARRAY and not l.is_empty() and typeof(l[0]) == TYPE_STRING):
		look = _center(l, true)
	else:
		look = _v3(l)
	return {"pos": pos, "look": look, "fov": float(s.get("fov", 40.0))}


## Середина группы актёров (ноги или, с eye, уровень глаз)
func _center(ids, eye := false) -> Vector3:
	var list: Array = ids if typeof(ids) == TYPE_ARRAY else [ids]
	var sum := Vector3.ZERO
	for id in list:
		sum += _eye(id) if eye else actors[id]["node"].position
	return sum / float(list.size())


func _cut(name: String) -> void:
	_cam_shot = name
	_cam_len = 0.0
	_cam_t = 0.0
	_apply_cam(_shot_state(name))


func _move(name: String, t: float) -> void:
	_cam_from = {"pos": cam.global_position, "look": _look, "fov": cam.fov}
	_cam_shot = name
	_cam_len = t
	_cam_t = 0.0


func _apply_cam(st: Dictionary) -> void:
	# лёгкое «дыхание» камеры в руках оператора
	var sway := Vector3(sin(_clock * 0.7) * 0.03, sin(_clock * 0.9 + 1.0) * 0.02, 0.0)
	cam.global_position = st["pos"] + sway
	cam.fov = st["fov"]
	_look = st["look"]
	if not st["pos"].is_equal_approx(st["look"]):
		cam.look_at(st["look"], Vector3.UP)


func _update_cam(delta: float) -> void:
	if _cam_shot == "":
		return
	var target := _shot_state(_cam_shot)
	if _cam_len > 0.0 and _cam_t < _cam_len:
		_cam_t = minf(_cam_len, _cam_t + delta)
		var k := smoothstep(0.0, 1.0, _cam_t / _cam_len)
		_apply_cam({"pos": _cam_from["pos"].lerp(target["pos"], k), "look": _cam_from["look"].lerp(target["look"], k),
			"fov": lerpf(_cam_from["fov"], target["fov"], k)})
	else:
		_apply_cam(target)


func _cam_moving() -> bool:
	return _cam_len > 0.0 and _cam_t < _cam_len


# ================================================================ Шаги
func _run() -> void:
	while i < steps.size():
		var st: Dictionary = steps[i]
		i += 1
		if st.has("say"):
			if st.has("cam"):
				_cut(String(st["cam"]))
			_say(String(st["say"]), String(st["text"]))
			waiting = "click"
			return
		if st.has("cam"):
			if st.has("t"):
				_move(String(st["cam"]), float(st["t"]))
				if st.get("wait", false):
					waiting = "cam"
					return
			else:
				_cut(String(st["cam"]))
			continue
		if st.has("walk"):
			var a: Dictionary = actors[st["walk"]]
			var path: Array = []
			for p in st["path"]:
				path.append(_v3(p))
			a["path"] = path
			a["speed"] = float(st.get("speed", 1.3))
			a["moving"] = true
			a["node"].visible = true
			if st.has("face"):
				a["face_after"] = st["face"]
			else:
				a.erase("face_after")
			var h := _hero(String(st["walk"]))
			if h:
				h.play_state("walk")
				h.set_walk_speed(float(a["speed"]))
			continue
		if st.has("wait_walk"):
			if _walking():
				waiting = "walk"
				return
			continue
		if st.has("face"):
			var fa: Dictionary = actors[st["face"]]
			fa["yaw_to"] = _yaw_to(fa["node"].position, _point(st["to"]))
			continue
		if st.has("place"):
			var pa: Dictionary = actors[st["place"]]
			pa["node"].position = _v3(st["at"])
			pa["node"].visible = true
			continue
		if st.has("anim"):
			var h2 := _hero(String(st["anim"]))
			if h2 and h2.anim and h2.anim.has_animation(String(st["clip"])):
				h2.anim.play(String(st["clip"]), 0.25)
			continue
		if st.has("gesture"):
			var o = actors[st["gesture"]]["node"]
			if o.has_method("gesture"):
				o.gesture(String(st.get("kind", "nod")))
			continue
		if st.has("show"):
			actors[st["show"]]["node"].visible = true
			continue
		if st.has("banner"):
			_banner(String(st["banner"]), float(st.get("t", 3.0)))
			continue
		if st.has("fade_in"):
			create_tween().tween_property(%Fade, "modulate:a", 0.0, float(st["fade_in"]))
			continue
		if st.has("fade_out"):
			_clear_say()
			var tw := create_tween()
			tw.tween_property(%Fade, "modulate:a", 1.0, float(st["fade_out"]))
			wait_t = float(st["fade_out"])
			waiting = "time"
			return
		if st.has("wait"):
			wait_t = float(st["wait"])
			waiting = "time"
			return
	_end()


func _say(who: String, text: String) -> void:
	speaker = who
	since_show = 0.0
	%Text.text = text
	%Text.visible_ratio = 0.0
	if who == "":
		%Speaker.text = " "
		%Portrait.modulate.a = 0.0
		%Text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		%Speaker.text = DB.HEROES[who]["full"] if DB.HEROES.has(who) else DB.STORY_NPCS[who]["full"]
		var tex := UIK.portrait(who)
		%Portrait.texture = tex
		%Portrait.modulate.a = 1.0 if tex else 0.0
		%Text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


func _clear_say() -> void:
	speaker = ""
	%Speaker.text = " "
	%Text.text = ""
	%Portrait.modulate.a = 0.0


func _banner(text: String, t: float) -> void:
	%Banner.text = text
	var tw := create_tween()
	tw.tween_property(%Banner, "modulate:a", 1.0, 0.8)
	tw.tween_interval(t)
	tw.tween_property(%Banner, "modulate:a", 0.0, 1.0)


func _advance() -> void:
	if waiting != "click" or since_show < CLICK_DELAY:
		return
	if %Text.visible_ratio < 1.0:
		%Text.visible_ratio = 1.0
		return
	_clear_say()
	waiting = ""
	_run()


func skip() -> void:
	if _ended:
		return
	i = steps.size()
	waiting = "done"
	_clear_say()
	var tw := create_tween()
	tw.tween_property(%Fade, "modulate:a", 1.0, 0.5)
	tw.tween_callback(_end)


func _end() -> void:
	if _ended:
		return
	_ended = true
	waiting = "done"
	finished.emit()
	Game.state["intro_seen"] = true
	Game.save()
	if main:
		main.goto("village", {"tab": "town"})


func _process(delta: float) -> void:
	_clock += delta
	since_show += delta
	_update_actors(delta)
	_update_cam(delta)
	if waiting == "click" and %Text.visible_ratio < 1.0:
		var n: int = maxi(1, %Text.text.length())
		%Text.visible_ratio = minf(1.0, %Text.visible_ratio + delta * TYPE_CPS / n)
	match waiting:
		"time":
			wait_t -= delta
			if wait_t <= 0.0:
				waiting = ""
				_run()
		"walk":
			if not _walking():
				waiting = ""
				_run()
		"cam":
			if not _cam_moving():
				waiting = ""
				_run()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		accept_event()


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed or ev.echo:
		return
	if ev.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		_advance()
		get_viewport().set_input_as_handled()
	elif ev.keycode == KEY_ESCAPE:
		skip()
		get_viewport().set_input_as_handled()
