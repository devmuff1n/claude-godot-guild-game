class_name Cutscene
extends Control
## Кат-сцена прямо на дороге (scenes/expedition/Cutscene.tscn): чёрные полосы сверху и снизу, реплики над
## героями, актёры (звери вне боя), наезд камеры. Шаги — DB.CUTSCENES. Бой из сцены ведёт ExpeditionScreen:
## по сигналу fight_requested он начинает настоящий бой, после победы снова запускает сцену с сохранённого шага (Game.story).

signal fight_requested(step: Dictionary)
signal finished

const ACTOR_FROM_X := 1720.0
const CLICK_DELAY := 0.25    # защита от двойного щелчка: реплику нельзя пролистать сразу после появления

var screen                   # ExpeditionScreen
var view: BattleView
var id := ""
var steps: Array = []
var i := 0
var waiting := ""            # "", "click", "time", "enter", "fight"
var wait_t := 0.0
var speaker := ""
var since_show := 0.0
var skipping := false
var active := false


func _ready() -> void:
	%Skip.pressed.connect(skip)
	%Bubble.modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP


## Начать сцену с шага from (0 — сначала; после сохранения посреди сцены — с сохранённого шага).
func play(cutscene_id: String, from := 0) -> void:
	id = cutscene_id
	steps = DB.CUTSCENES[id]["steps"]
	i = from
	skipping = false
	active = true
	_show_frame(true)
	_run()



## Промотать разговор до ближайшего боя или до конца сцены.
func skip() -> void:
	if not active or waiting == "fight":
		return
	skipping = true
	if waiting == "enter":
		for a in view.actors:
			a["x"] = a.get("to", a["x"])
			a["moving"] = false
		view.actors = view.actors.filter(func(o): return not o.get("leaving", false))
	_run()


func _show_frame(on: bool) -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0 if on else 0.0, 0.35)
	if not on:
		tw.tween_callback(func(): visible = active and waiting != "fight")
	if screen:
		screen.set_hud_shown(not on)


func _run() -> void:
	_hide_say()
	while i < steps.size():
		var st: Dictionary = steps[i]
		i += 1
		if st.has("say"):
			if skipping:
				continue
			_say(String(st["say"]), String(st["text"]))
			waiting = "click"
			return
		if st.has("enter"):
			var a := {"id": st["enter"], "look": st.get("look", "wolf"), "name": st.get("name", ""), "x": ACTOR_FROM_X,
				"to": float(st.get("x", 1150.0)), "speed": float(st.get("speed", 450.0)), "facing": int(st.get("facing", -1)), "moving": true,
				"dy": float(st.get("dy", 0.0)), "shade": st.get("shade", false)}
			view.actors = view.actors.filter(func(o): return o["id"] != a["id"])
			view.actors.append(a)
			if skipping or st.get("appear", false):
				a["x"] = a["to"]
				a["moving"] = false
				continue
			waiting = "enter"
			return
		if st.has("exit"):
			var ax := view.actor(String(st["exit"]))
			if not ax.is_empty():
				ax["to"] = ACTOR_FROM_X + 60.0
				ax["facing"] = 1
				ax["moving"] = true
				ax["leaving"] = true
				ax["speed"] = float(st.get("speed", ax.get("speed", 400.0)))
				if not skipping:
					waiting = "enter"
					return
				view.actors.erase(ax)
			continue
		if st.has("vanish"):
			var av := view.actor(String(st["vanish"]))
			if not av.is_empty():
				view.spawn_ash(float(av["x"]), BattleView.GROUND + float(av.get("dy", 0.0)))
				view.actors.erase(av)
			continue
		if st.has("anim"):
			if not skipping:
				_anim(st)
			continue
		if st.has("wait"):
			if skipping:
				continue
			wait_t = float(st["wait"])
			waiting = "time"
			return
		if st.has("cam"):
			screen.story_cam(float(st["cam"]))
			continue
		if st.has("banner"):
			screen._show_banner(String(st["banner"]), 2.2)
			continue
		if st.has("fight"):
			skipping = false
			waiting = "fight"
			active = false
			Game.set_story(id, i)
			_show_frame(false)
			fight_requested.emit(st)
			return
	_end()


func _end() -> void:
	waiting = ""
	active = false
	view.actors = []
	_show_frame(false)
	finished.emit()


func _anim(st: Dictionary) -> void:
	var who := String(st["anim"])
	var a := view.actor(who)
	if not a.is_empty():
		a["swing"] = 1.0
		return
	view.hero_anim(who, String(st.get("kind", "cast_release")))
	if st.has("at"):
		var p := view.speaker_anchor(String(st["at"]))
		if p.x >= 0.0:
			view.add_fx(p + Vector2(0, 50), String(st.get("fx", "ward")))


func _say(who: String, text: String) -> void:
	speaker = who
	since_show = 0.0
	if who == "":
		%Narration.text = text
		return
	%Narration.text = ""
	var a := view.actor(who)
	%Speaker.text = String(a.get("name", "")) if not a.is_empty() else DB.HEROES[who]["full"]
	%Text.text = text
	%Bubble.reset_size()
	_place_bubble()
	create_tween().tween_property(%Bubble, "modulate:a", 1.0, 0.15)


func _hide_say() -> void:
	speaker = ""
	%Narration.text = ""
	%Bubble.modulate.a = 0.0


func _place_bubble() -> void:
	if speaker == "":
		return
	var p := view.speaker_anchor(speaker)
	if p.x < 0.0:
		return
	p = view.get_transform() * p
	var sz: Vector2 = %Bubble.size
	var pos := p - Vector2(sz.x * 0.5, sz.y)
	pos.x = clampf(pos.x, 16.0, size.x - sz.x - 16.0)
	pos.y = clampf(pos.y, 80.0, size.y - 140.0 - sz.y)
	%Bubble.position = pos


func _advance() -> void:
	if not active or since_show < CLICK_DELAY:
		return
	if waiting == "click":
		_run()


func _process(delta: float) -> void:
	if not active or (screen and screen.overlay.get_child_count() > 0):
		return
	since_show += delta
	match waiting:
		"time":
			wait_t -= delta
			if wait_t <= 0.0:
				_run()
		"enter":
			var done := true
			for a in view.actors:
				if a.get("moving", false):
					a["x"] = move_toward(float(a["x"]), float(a["to"]), float(a["speed"]) * delta)
					if is_equal_approx(float(a["x"]), float(a["to"])):
						a["moving"] = false
					else:
						done = false
			if done:
				view.actors = view.actors.filter(func(o): return not o.get("leaving", false))
				_run()
		"click":
			_place_bubble()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		accept_event()


func _unhandled_input(ev: InputEvent) -> void:
	if not active or not (ev is InputEventKey) or not ev.pressed or ev.echo:
		return
	if ev.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		_advance()
		get_viewport().set_input_as_handled()
