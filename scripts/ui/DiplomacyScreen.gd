extends Control
## Дипломатическая миссия (scenes/screens/DiplomacyScreen.tscn): делегация слева, сцена разговора по центру.
## Вариант ответа → бросок d20 + черта против КС (Game.dip_choose) → итог сцены → «Дальше».
## Вёрстка — в сцене; варианты — из scenes/ui/DiploOption.tscn, последствия — ResourcePill.

const OPTION := preload("res://scenes/ui/DiploOption.tscn")
const PILL := preload("res://scenes/ui/ResourcePill.tscn")
const SYSTEM_MENU := preload("res://scenes/ui/SystemMenu.tscn")

var main
var params: Dictionary = {}
var rolling := false

func _ready() -> void:
	%NextButton.pressed.connect(_on_next)
	%MenuButton.pressed.connect(_show_menu)
	if Game.dip().is_empty():
		main.goto.call_deferred("village")
		return
	refresh(false)

func on_quit() -> void:
	Game.save()

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_ESCAPE and %Overlay.get_child_count() == 0:
		get_viewport().set_input_as_handled()
		_show_menu()

func refresh(animate: bool) -> void:
	var d := Game.dip()
	var c: Dictionary = DB.CONTRACTS[d["cid"]]
	var beat := Game.dip_beat()
	%Title.text = c["name"]
	%Favor.set_value(str(int(d["favor"])))
	%Favor.tooltip_text = "Расположение двора: %d\nТриумф — от %d, успех — от %d." % [int(d["favor"]),
		int(Game.dip_scenario()["outcomes"][0]["min"]), int(Game.dip_scenario()["outcomes"][1]["min"])]
	# Маршрут: пройденные места отмечены
	var route: Array = c["route"].duplicate(true)
	var place := int(beat["place"])
	for i in route.size():
		route[i]["done"] = i < place
	var times := DayTime.contract_times(d["cid"])
	%Route.set_route(route, place, 0.0, times)
	_set_time(times[place] if place < times.size() else "day")
	_fill_delegation()
	%Place.text = str(route[place]["name"]).to_upper()
	%Who.text = beat["who"]
	%Text.text = beat["text"]
	if d["last"].is_empty():
		_show_options(beat)
	else:
		_show_result(d["last"], animate)

## Время суток места (DayTime): значок в верхней панели и окраска фона.
func _set_time(t: String) -> void:
	%TimePill.icon_kind = ExpeditionTopBar.TIME_ICONS[t]
	%TimePill.set_value(DayTime.NAMES[t])
	%TimePill.tooltip_text = "Время суток: %s" % str(DayTime.NAMES[t]).to_lower()
	%Background.modulate = DayTime.PRESETS[t]["backdrop"]

func _fill_delegation() -> void:
	var party: Array = Game.dip_scenario()["party"]
	for i in 2:
		(get_node("%%Card%d" % i) as DelegateCard).setup(party[i])

## Строка под вариантом: кто говорит, черта, КС и шанс
func _check_line(opt: Dictionary) -> Array:
	if not opt.has("check"):
		return ["Без броска", ""]
	var info := Game.dip_check_info(opt)
	var t := "%s · %s %d" % [Game.dip_name(info["speaker"]), DB.SOCIAL_NAMES[info["stat"]], int(info["mod"])]
	if int(info["bonus"]) != 0:
		t += " %+d" % int(info["bonus"])
	t += " · КС %d · шанс %d%%" % [int(info["dc"]), int(round(float(info["chance"]) * 100.0))]
	var tip := "d20 + %s (%d) против КС %d. 20 — всегда успех, 1 — всегда провал." % [DB.SOCIAL_NAMES[info["stat"]], int(info["mod"]), int(info["dc"])]
	for w in info["why"]:
		tip += "\n" + w
	if info["adv"]:
		t += " · помогает %s" % Game.dip_name(info["helper"])
		tip += "\n%s помогает (%s %d): два кубика, берётся лучший." % [Game.dip_name(info["helper"]), DB.SOCIAL_NAMES[info["stat"]], Game.social_value(info["helper"], info["stat"])]
	return [t, tip]

func _show_options(beat: Dictionary) -> void:
	%Result.visible = false
	%Options.visible = true
	UIK.clear(%Options)
	var opts: Array = beat["options"]
	for i in opts.size():
		var opt: Dictionary = opts[i]
		var b: Button = OPTION.instantiate()
		%Options.add_child(b)
		b.get_node("%Text").text = opt["text"]
		var cl := _check_line(opt)
		b.get_node("%Check").text = cl[0]
		b.tooltip_text = cl[1]
		var prob := Game.dip_option_problem(opt)
		if prob != "":
			b.disabled = true
			b.tooltip_text = prob
			b.get_node("%Check").text = "🔒 " + cl[0]
		var idx := i
		b.pressed.connect(func(): _choose(idx))

func _choose(i: int) -> void:
	if rolling:
		return
	var last := Game.dip_choose(i)
	if last.is_empty():
		return
	refresh(true)

func _show_result(last: Dictionary, animate: bool) -> void:
	%Options.visible = false
	UIK.clear(%Options)
	%Result.visible = true
	%Said.text = last["text"]
	%Outcome.text = last["say"]
	%Roll.visible = last["check"]
	UIK.clear(%Effects)
	if last["favor"] != 0:
		_pill("trust", "%+d" % int(last["favor"]), "Расположение двора", UIK.GREEN if last["favor"] > 0 else UIK.RED)
	if last["coins"] != 0:
		_pill("coin", "%+d" % int(last["coins"]), "Казна гильдии (спишется по возвращении)" if last["coins"] < 0 else "Казна гильдии (по возвращении)", UIK.GOLD_HI if last["coins"] > 0 else UIK.RED)
	%Effects.visible = %Effects.get_child_count() > 0
	if not last["check"]:
		%NextButton.disabled = false
		return
	var parts := "%d + %s %d" % [int(last["roll"]), DB.SOCIAL_NAMES[last["stat"]], int(last["mod"])]
	if int(last["bonus"]) != 0:
		parts += " %+d" % int(last["bonus"])
	%Formula.text = "%s = %d · КС %d" % [parts, int(last["total"]), int(last["dc"])]
	var ftip := "Говорит: %s" % Game.dip_name(last["speaker"])
	if last["adv"]:
		ftip += "\nПомощь: %s — кубики %s, взят лучший." % [Game.dip_name(last["helper"]), " и ".join(last["rolls"].map(func(x): return str(x)))]
	for w in last.get("why", []):
		ftip += "\n" + w
	%Formula.tooltip_text = ftip
	var crit := ""
	if int(last["roll"]) == 20:
		crit = "КРИТИЧЕСКИЙ УСПЕХ"
	elif int(last["roll"]) == 1:
		crit = "КРИТИЧЕСКИЙ ПРОВАЛ"
	%Verdict.text = crit if crit != "" else ("УСПЕХ" if last["ok"] else "ПРОВАЛ")
	%Verdict.add_theme_color_override("font_color", UIK.GREEN if last["ok"] else UIK.RED)
	if not animate:
		%DieValue.text = str(int(last["roll"]))
		return
	# Кубик «катится»: числа мелькают, затем выпавшее значение; итог появляется после броска
	rolling = true
	%NextButton.disabled = true
	%Verdict.modulate.a = 0.0
	%Formula.modulate.a = 0.0
	%Outcome.modulate.a = 0.0
	%Effects.modulate.a = 0.0
	var tw := create_tween()
	for k in 10:
		tw.tween_callback(func(): %DieValue.text = str(randi_range(1, 20)))
		tw.tween_interval(0.05 + k * 0.012)
	tw.tween_callback(func(): %DieValue.text = str(int(last["roll"])))
	tw.tween_property(%Verdict, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(%Formula, "modulate:a", 1.0, 0.2)
	tw.tween_property(%Outcome, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(%Effects, "modulate:a", 1.0, 0.25)
	tw.tween_callback(func():
		rolling = false
		%NextButton.disabled = false)

func _pill(kind: String, val: String, tip: String, col: Color) -> void:
	var p: ResourcePill = PILL.instantiate()
	p.icon_kind = kind
	p.value_width = 0.0
	p.tooltip_text = tip
	%Effects.add_child(p)
	p.set_value(val, col)

func _on_next() -> void:
	if rolling:
		return
	if Game.dip_next():
		var res := Game.finish_diplomacy()
		main.goto("village", {"result": res})
	else:
		refresh(false)

func _show_menu() -> void:
	UIK.clear(%Overlay)
	%Overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var m: SystemMenu = SYSTEM_MENU.instantiate()
	%Overlay.add_child(m)
	m.setup("Миссия", ["resume", "save", "main_menu"])
	m.chosen.connect(_on_menu)

func _on_menu(a: String) -> void:
	UIK.clear(%Overlay)
	%Overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match a:
		"save":
			Game.save()
			Game.notify("Игра сохранена.")
		"main_menu":
			Game.save()
			main.goto("title")
