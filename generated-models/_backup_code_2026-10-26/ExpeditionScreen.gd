extends Control
## Экран похода (scenes/screens/ExpeditionScreen.tscn): один бесшовный путь — дорога, бои прямо на ходу,
## события, привал, придорожная лавка, оборона заставы; также испытательная арена.

const SYSTEM_MENU := preload("res://scenes/ui/SystemMenu.tscn")
const CONFIRM := preload("res://scenes/ui/ConfirmDialog.tscn")
const CAMP := preload("res://scenes/ui/CampPanel.tscn")
const EVENT := preload("res://scenes/expedition/EventDialog.tscn")
const ROAD_SHOP := preload("res://scenes/expedition/RoadShopDialog.tscn")
const WALK_SPEED := 260.0
const REGROUP_SPEED := 90.0

var main
var params: Dictionary = {}
var arena := false
var arena_cfg: Dictionary = {}
var sim: BattleSim = null

var speed := 1.0
var paused := false
var menu_hero := ""
var targeting: Dictionary = {}  # {hero, ab} или {hero, potion}
var autosave_t := 0.0
var walk_dur := 2.6
var finished := false
var banner_t := 0.0
var victory_hold := 0.0

@onready var view: BattleView = %View
@onready var overlay: Control = %Overlay
@onready var top_bar: ExpeditionTopBar = %TopBar
@onready var route_bar: RouteBar = top_bar.route
@onready var cmd_menu: CommandMenu = %CmdMenu
@onready var obj_panel: ObjectivePanel = %ObjPanel
@onready var prep_panel: OutpostPrepPanel = %PrepPanel
@onready var repair_hero_opt: OptionButton = obj_panel.get_node("%RepairHero")
@onready var cards := {"aiden": %Card_aiden, "marek": %Card_marek, "elira": %Card_elira, "neris": %Card_neris}

func _ready() -> void:
	arena = params.has("arena")
	if arena:
		arena_cfg = params["arena"]
	view.unit_clicked.connect(_on_unit_clicked)
	top_bar.order_selected.connect(_set_order)
	top_bar.speed_selected.connect(_set_speed)
	top_bar.pause_pressed.connect(_toggle_pause)
	top_bar.menu_pressed.connect(_show_pause_menu)
	cmd_menu.closed.connect(_close_menu)
	cmd_menu.ability_chosen.connect(_choose_ability)
	cmd_menu.potion_chosen.connect(_choose_potion)
	for id in cards.keys():
		cards[id].pressed.connect(_open_menu)
	obj_panel.task_requested.connect(func(kind: String, _h: String): _obj_task(kind))
	obj_panel.cancel_requested.connect(func(h: String):
		if sim != null:
			sim.cancel_task(sim.hero_unit(h)["uid"]))
	prep_panel.repair_pressed.connect(func(): _prep_task("repair"))
	prep_panel.extinguish_pressed.connect(func(): _prep_task("extinguish"))
	prep_panel.next_pressed.connect(func():
		sim.start_next_wave()
		_save_battle())
	prep_panel.save_pressed.connect(func():
		_save_battle()
		Game.notify("Сохранено."))
	_set_speed(1.0)
	top_bar.set_paused(false)
	top_bar.set_order("hold", false)
	_order_cards()
	if arena:
		%Goals.visible = false
		route_bar.visible = false
		top_bar.set_title("Испытательная арена")
		top_bar.set_purse(0, false)
		_start_sim(arena_cfg)
	else:
		var c: Dictionary = DB.CONTRACTS[Game.ex()["cid"]]
		view.night = c.get("night", false)
		view.outpost = c.get("outpost", false)
		view.walk_wagon = Game.ex()["wagon"] != null
		_resume()

func _order_cards() -> void:
	var order := _card_order()
	for i in order.size():
		var card: HeroCard = cards[order[i]]
		%Cards.move_child(card, i)
		card.set_num(i + 1)

func _card_order() -> Array:
	var f: Array = Game.state["formation"].duplicate()
	f.reverse()
	return f

# ================================================================ Путь
func _resume() -> void:
	var e := Game.ex()
	top_bar.set_title(DB.CONTRACTS[e["cid"]]["name"])
	_place_party()
	_update_route()
	_refresh_goals_live()
	match e["phase"]:
		"battle", "prebattle":
			if e["battle"] != null:
				sim = BattleSim.new()
				sim.load_state(e["battle"])
				view.sim = sim
				_after_sim_ready()
				paused = true
				top_bar.set_paused(true)
				_show_banner("Пауза", 2.0)
			else:
				_start_battle_from_ctx()
		"event":
			_show_event()
		"camp":
			_show_camp()
		"shop":
			_show_road_shop()
		_:
			_begin_walk()

func _update_route() -> void:
	if arena:
		return
	var e := Game.ex()
	var prog := float(e.get("walk_t", 0.0)) / walk_dur if e["phase"] == "walk" else 0.0
	route_bar.set_route(e["route"], int(e["node"]), prog)

## Герои на своих местах в строю (начало похода или загрузка)
func _place_party() -> void:
	var f: Array = Game.state["formation"]
	view.walk_units = []
	for i in f.size():
		view.walk_units.append({"look": f[i], "x": BattleSim.FORMATION_X[i]})

## Подтянуть идущих героев к местам в строю — без рывков
func _regroup(dt: float) -> void:
	var f: Array = Game.state["formation"]
	for w in view.walk_units:
		var target: float = BattleSim.FORMATION_X[f.find(w["look"])]
		w["x"] = move_toward(w["x"], target, REGROUP_SPEED * dt)

func _begin_walk() -> void:
	sim = null
	view.sim = null
	view.walking = true
	Game.ex()["phase"] = "walk"
	if Game.route_finished():
		_finish("victory")
		return
	obj_panel.visible = false
	prep_panel.visible = false
	top_bar.set_order("hold", false)
	_refresh_goals_live()

func _arrive() -> void:
	view.walking = false
	var e := Game.ex()
	var nd := Game.current_node()
	match nd["type"]:
		"battle":
			e["battle_ctx"] = {"groups": nd["groups"], "ambush": nd.get("ambush", []), "boss": nd.get("boss", false), "chest": nd.get("chest", false), "source": "node"}
			_start_battle_from_ctx()
		"outpost":
			e["battle_ctx"] = {"groups": [], "ambush": [], "boss": false, "chest": false, "source": "node"}
			_start_battle_from_ctx()
		"event":
			e["phase"] = "event"
			Game.save()
			_show_event()
		"camp":
			e["phase"] = "camp"
			Game.save()
			_show_camp()
		"shop":
			e["phase"] = "shop"
			Game.gen_road_shop()
			Game.save()
			_show_road_shop()

func _continue_path() -> void:
	Game.complete_node()
	Game.save()
	_clear_overlay()
	_update_route()
	_begin_walk()

# ================================================================ Бой
func _start_battle_from_ctx() -> void:
	var e := Game.ex()
	var ctx: Dictionary = e["battle_ctx"]
	var cfg := Game.battle_config(ctx["groups"], ctx["ambush"], ctx["boss"], ctx["chest"])
	# Бой начинается там, где отряд стоит на дороге
	for hc in cfg["heroes"]:
		for w in view.walk_units:
			if w["look"] == hc["id"]:
				hc["x"] = w["x"]
	_start_sim(cfg)
	e["phase"] = "battle"
	e["battle"] = sim.save_state()
	Game.save()
	if ctx["ambush"].size() > 0:
		_show_banner("Элира: «В кустах позади кто-то есть»", 2.5)

func _start_sim(cfg: Dictionary) -> void:
	_clear_overlay()
	sim = BattleSim.new()
	sim.setup(cfg)
	view.sim = sim
	view.walking = false
	_after_sim_ready()

func _after_sim_ready() -> void:
	view.vis = {}
	obj_panel.visible = sim.s["objects"].size() > 0
	_setup_obj_panel()
	_refresh_goals_live()

func _process(delta: float) -> void:
	banner_t -= delta
	if banner_t <= 0.0:
		%Banner.text = ""
	elif banner_t < 0.4:
		%Banner.modulate.a = banner_t / 0.4
	if finished:
		return
	if sim == null:
		if not arena and Game.ex().get("phase", "") == "walk" and overlay.get_child_count() == 0 and not Game.route_finished():
			var e := Game.ex()
			e["walk_t"] = float(e.get("walk_t", 0.0)) + delta
			view.scroll += delta * WALK_SPEED
			view.shift_corpses(delta * WALK_SPEED)
			_regroup(delta)
			Game.walk_regen(delta)
			_update_route()
			if e["walk_t"] >= walk_dur:
				e["walk_t"] = 0.0
				_arrive()
		_update_cards_walk()
		return
	var mult := speed
	if paused or not targeting.is_empty() or overlay.get_child_count() > 0:
		mult = 0.0
	elif cmd_menu.visible:
		mult *= 0.25
	var dt := delta * mult
	while dt > 0.0001 and sim.s["phase"] in ["fight", "prep"]:
		var st: float = min(dt, 0.05)
		sim.step(st)
		dt -= st
	view.consume_events(sim.events)
	sim.events.clear()
	_update_battle_ui()
	if not arena:
		autosave_t += delta
		if autosave_t > 15.0:
			autosave_t = 0.0
			_save_battle()
	if sim.s["phase"] == "won" and victory_hold <= 0.0:
		victory_hold = 0.01
		_on_battle_won()
	elif sim.s["phase"] == "lost" and overlay.get_child_count() == 0:
		_on_battle_lost()

func _save_battle() -> void:
	if arena or sim == null or Game.ex().is_empty():
		return
	Game.ex()["battle"] = sim.save_state()
	Game.save()

func on_quit() -> void:
	if not arena and sim != null and not finished and not Game.ex().is_empty():
		_save_battle()
	elif not arena and not Game.ex().is_empty():
		Game.save()

func _update_battle_ui() -> void:
	var lines: Array = sim.s["log"]
	%LogLabel.text = "\n".join(lines.slice(max(0, lines.size() - 4)))
	top_bar.set_order(sim.s["order"], sim.s["phase"] == "fight")
	for u in sim.s["units"]:
		if u["side"] != "hero":
			continue
		var st := ""
		if not u["alive"]:
			st = "Без сил"
		elif u["cast"] != null:
			st = "Готовит: %s" % u["cast"]["name"]
		elif u["task"] != null:
			st = "Ремонт" if u["task"]["type"] == "repair" else "Тушит пожар"
		elif sim.is_stunned(u):
			st = "Оглушён"
		elif u["queued"] != null:
			st = "→ %s" % DB.ABILITIES[u["queued"]["ab"]]["name"]
		cards[u["key"]].update_from(u["hp"], u["max_hp"], u["mp"], u["max_mp"], u["atb"], u["alive"], st)
		cards[u["key"]].set_active(u["key"] == menu_hero)
	view.selected_hero = menu_hero
	if cmd_menu.visible and menu_hero != "":
		cmd_menu.refresh()
	_update_obj_panel()
	_update_prep_panel()
	_refresh_goals_live()

func _update_cards_walk() -> void:
	if arena or Game.ex().is_empty():
		return
	var e := Game.ex()
	for id in DB.HERO_IDS:
		var d := Game.derived(id)
		var hs: Dictionary = e["hero_state"][id]
		cards[id].update_from(hs["hp"], d["max_hp"], hs["mp"], d["max_mp"], hs["atb"], true, "")

func _show_banner(t: String, dur := 2.0) -> void:
	%Banner.text = t
	%Banner.modulate.a = 1.0
	banner_t = dur

func _on_battle_won() -> void:
	_close_menu()
	_cancel_target()
	if arena:
		_arena_end(true)
		return
	var c: Dictionary = sim.s["counters"]
	var e := Game.ex()
	Game.absorb_battle(sim)
	var msg := "Победа! +%d мон. · +%d опыта" % [int(c["coins"]), int(c["xp"])]
	# Отряд продолжает путь с того места, где закончился бой; павшие враги остаются на дороге
	view.walk_units = []
	view.corpses = []
	for u in sim.s["units"]:
		if u["side"] == "hero":
			view.walk_units.append({"look": u["key"], "x": u["x"]})
		else:
			view.corpses.append({"look": u["look"], "x": u["x"], "facing": u["facing"], "big": u["key"] in ["brute", "captain"]})
	_show_banner(msg, 2.5)
	sim = null
	view.sim = null
	e["battle"] = null
	Game.complete_node()
	Game.save()
	victory_hold = 0.0
	_update_route()
	if Game.route_finished():
		await get_tree().create_timer(1.6).timeout
		_finish("victory")
	else:
		_begin_walk()

func _on_battle_lost() -> void:
	_close_menu()
	_cancel_target()
	if arena:
		_arena_end(false)
		return
	var d := _confirm("ПОРАЖЕНИЕ", "Отряд отступает", sim.s["loss"], [], [["Вернуться в деревню", true, "Опыт и оставшиеся деньги сохраняются; наград за победу нет."]])
	d.chosen.connect(func(_i): _finish("defeat"))

func _finish(kind: String) -> void:
	if finished:
		return
	finished = true
	main.goto("village", {"result": Game.finish_expedition(kind)})

func _arena_end(won: bool) -> void:
	var d := _confirm("ИСПЫТАНИЕ ОКОНЧЕНО", "Победа" if won else "Поражение", ("" if won else sim.s["loss"] + "\n") + "Время: %d с" % int(sim.s["t"]), [], [["Повторить", false], ["Покинуть арену", true]])
	d.chosen.connect(func(i: int):
		if i == 0:
			_start_sim(arena_cfg)
		else:
			_leave_arena())

func _leave_arena() -> void:
	finished = true
	main.goto("village", {"tab": "arena"})

# ---------------------------------------------------------------- Приказы и ввод
func _set_order(o: String) -> void:
	if sim != null:
		sim.set_order(o)

func _set_speed(s: float) -> void:
	speed = s
	top_bar.set_speed(s)

func _toggle_pause() -> void:
	paused = not paused
	top_bar.set_paused(paused)
	if paused:
		_show_banner("Пауза", 1.2)

func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed or ev.echo or finished:
		return
	var k: int = ev.keycode
	if k == KEY_ESCAPE:
		if not targeting.is_empty():
			_cancel_target()
		elif cmd_menu.visible:
			_close_menu()
		elif overlay.get_child_count() == 0:
			_show_pause_menu()
		return
	if overlay.get_child_count() > 0:
		return
	if k == KEY_SPACE:
		_toggle_pause()
	elif k == KEY_C:
		_set_order("advance")
	elif k == KEY_N:
		_set_order("hold")
	elif k >= KEY_1 and k <= KEY_4:
		_open_menu(_card_order()[k - KEY_1])
	get_viewport().set_input_as_handled()

func _on_unit_clicked(uid: int, button: int) -> void:
	if sim == null:
		return
	if button == MOUSE_BUTTON_RIGHT:
		if not targeting.is_empty():
			_cancel_target()
		else:
			_close_menu()
		return
	var u = sim.unit(uid)
	if u == null:
		return
	if not targeting.is_empty():
		_apply_target(u)
		return
	if u["side"] == "enemy":
		sim.set_focus(uid)
		if sim.s["focus"] == uid:
			sim._float(u, "Фокус", Color(1, 0.5, 0.4))
	else:
		_open_menu(u["key"])

# ---------------------------------------------------------------- Меню команд
func _open_menu(hid: String) -> void:
	if sim == null or sim.s["phase"] in ["won", "lost"]:
		return
	_cancel_target()
	menu_hero = hid
	cmd_menu.items_mode = false
	cmd_menu.open_for(sim, hid)
	cmd_menu.visible = true
	cmd_menu.modulate.a = 0.0
	await get_tree().process_frame
	if menu_hero == hid and cmd_menu.visible:
		_place_menu()
	cmd_menu.modulate.a = 1.0

## Меню стоит над карточкой героя; ширина постоянная, высота зависит только от числа умений
func _place_menu() -> void:
	var card: HeroCard = cards[menu_hero]
	cmd_menu.reset_size()
	var sz := cmd_menu.get_combined_minimum_size()
	var cp := card.global_position
	cmd_menu.position = Vector2(clamp(cp.x + (card.size.x - sz.x) * 0.5, 10, 1600 - sz.x - 10), cp.y - sz.y - 10)

func _close_menu() -> void:
	cmd_menu.visible = false
	menu_hero = ""

func _choose_ability(ab: String) -> void:
	var u = sim.hero_unit(menu_hero)
	if u == null:
		return
	var p := sim.ability_problem(u["uid"], ab)
	if p != "":
		_show_banner(p, 1.5)
		return
	var a: Dictionary = DB.ABILITIES[ab]
	if a["target"] in ["self", "allies"]:
		sim.use_ability(u["uid"], ab, u["uid"])
		_close_menu()
		return
	targeting = {"hero": menu_hero, "ab": ab}
	view.target_mode = "enemy" if a["target"] == "enemy" else "ally"
	cmd_menu.visible = false
	_set_status("Цель: %s" % a["name"])

func _choose_potion(kind: String) -> void:
	targeting = {"hero": menu_hero, "potion": kind}
	view.target_mode = "ally"
	cmd_menu.visible = false
	_set_status("Кому: %s" % DB.CONSUMABLES[kind]["name"])

func _apply_target(t: Dictionary) -> void:
	var u = sim.hero_unit(targeting["hero"])
	if u == null:
		_cancel_target()
		return
	var res := sim.use_ability(u["uid"], targeting["ab"], t["uid"]) if targeting.has("ab") else sim.use_potion(u["uid"], targeting["potion"], t["uid"])
	if res != "":
		_show_banner(res, 1.6)
		return
	_cancel_target()
	_close_menu()

func _cancel_target() -> void:
	if not targeting.is_empty():
		targeting = {}
		_set_status("")
		if menu_hero != "":
			cmd_menu.visible = true
	view.target_mode = ""

func _set_status(t: String) -> void:
	%StatusLabel.text = t
	%StatusPanel.visible = t != ""

# ---------------------------------------------------------------- Объекты: повозка, ворота, сундук
func _main_obj() -> String:
	var o: Dictionary = sim.s["objects"]
	if o.has("gate"):
		return "gate"
	if o.has("wagon"):
		return "wagon"
	return "chest"

func _setup_obj_panel() -> void:
	if sim == null or sim.s["objects"].is_empty():
		return
	obj_panel.setup(_main_obj())

func _obj_task(kind: String) -> void:
	if sim == null:
		return
	var u = sim.hero_unit(obj_panel.selected_hero())
	var target := _main_obj()
	if kind == "extinguish":
		for k in sim.s["objects"].keys():
			if sim.s["objects"][k]["burning"] > 0.0:
				target = k
	var p := sim.start_task(u["uid"], kind, target)
	if p != "":
		_show_banner(p, 1.6)

func _update_obj_panel() -> void:
	if sim == null or not obj_panel.visible:
		return
	var k := _main_obj()
	var o: Dictionary = sim.s["objects"][k]
	var res := 0
	if k == "wagon":
		res = int(sim.s["kits"])
	elif k == "gate":
		res = int(sim.s["materials"])
	var burning := false
	for kk in sim.s["objects"].keys():
		if sim.s["objects"][kk]["burning"] > 0.0:
			burning = true
	var u = sim.hero_unit(obj_panel.selected_hero())
	obj_panel.update(o, res, u if u != null else {}, burning)

# ---------------------------------------------------------------- Оборона заставы: передышка между волнами
func _update_prep_panel() -> void:
	var on: bool = sim.s["phase"] == "prep" and not arena
	prep_panel.visible = on
	if not on:
		return
	var waves: Array = sim.s["waves"]
	var parts := []
	if sim.s["wave"] < waves.size():
		for g in waves[sim.s["wave"]]:
			for t in g:
				parts.append(DB.ENEMIES[t]["name"])
	var any = sim.alive_of("hero")[0]
	prep_panel.update(int(sim.s["wave"]) + 1, waves.size(), sim.s["objects"]["gate"], int(sim.s["materials"]), parts, sim.task_problem(any["uid"], "repair", "gate") == "")

func _prep_task(kind: String) -> void:
	var m = sim.hero_unit("marek")
	var u = m if m != null and m["alive"] else sim.alive_of("hero")[0]
	var r := sim.start_task(u["uid"], kind, "gate")
	if r != "":
		_show_banner(r, 1.5)

# ---------------------------------------------------------------- Цели
func _live_counters() -> Dictionary:
	var c: Dictionary = Game.ex()["counters"].duplicate(true)
	if sim != null:
		var sc: Dictionary = sim.s["counters"]
		for k in ["potions", "healing", "wards", "taunts", "interrupts", "curses", "spell_dmg"]:
			c[k] = int(c.get(k, 0)) + int(sc.get(k, 0))
		for k in sc["ko"].keys():
			c["ko"][k] = true
		for k in sc["dmg_taken"].keys():
			c["dmg_taken"][k] = int(c["dmg_taken"].get(k, 0)) + int(sc["dmg_taken"][k])
		for k in sc["kills"].keys():
			c["kills"][k] = int(c["kills"].get(k, 0)) + int(sc["kills"][k])
	return c

func _refresh_goals_live() -> void:
	if arena or Game.ex().is_empty():
		return
	var e := Game.ex()
	var c: Dictionary = DB.CONTRACTS[e["cid"]]
	var lc := _live_counters()
	var rows := []
	var prem: Dictionary = c["premium"]
	rows.append(["Премия: " + prem["name"], _goal_state(prem["check"], lc), "Премия: +%d мон.%s" % [prem["coins"], " (уже получена)" if Game.state["premium_claimed"].has(e["cid"]) else ""]])
	if e["general"] != "":
		var g: Dictionary = DB.GENERAL_OBJECTIVES[e["general"]]
		rows.append([g["name"], _goal_state(e["general"], lc), g["desc"]])
	if e["personal"].has("hero"):
		var hid: String = e["personal"]["hero"]
		var od := Game.personal_obj_def(hid, e["personal"]["obj"])
		var v := 0
		match od["stat"]:
			"dmg_taken": v = int(lc["dmg_taken"].get(hid, 0))
			"kills": v = int(lc["kills"].get(hid, 0))
			_: v = int(lc.get(od["stat"], 0))
		rows.append(["%s: %s %d/%d" % [DB.hero_name(hid), od["name"], min(v, od["goal"]), od["goal"]], 1 if v >= od["goal"] else 0, od["desc"]])
	top_bar.set_purse(int(e["purse"]))
	%Goals.set_rows(rows)

## 1 — выполнено, 0 — в процессе, -1 — провалено
func _goal_state(id: String, lc: Dictionary) -> int:
	var e := Game.ex()
	match id:
		"no_ko": return -1 if lc["ko"].size() > 0 else 0
		"few_potions": return -1 if int(lc["potions"]) > 2 else 0
		"helpful": return 1 if e["flags"].get("helped", false) else 0
		"thrift": return 1 if int(e["purse"]) >= int(e["purse_start"]) else 0
		"wagon80":
			var w = sim.s["objects"].get("wagon") if sim != null else e["wagon"]
			if w == null: return 0
			return 1 if w["hp"] >= w["max"] * 0.8 else -1
		"gate60":
			var g = sim.s["objects"].get("gate") if sim != null else e["gate"]
			if g == null: return 0
			return 1 if g["hp"] >= g["max"] * 0.6 else -1
		"fast_boss":
			if sim != null and sim.s["boss"]:
				return -1 if sim.s["boss_time"] > 75.0 else 0
			return 0
		"carters_all":
			var n := 0
			for f in ["carter1", "carter2", "carter3"]:
				if e["flags"].get(f, false): n += 1
			return 1 if n == 3 else 0
		"chest_safe":
			if sim != null and sim.s["objects"].has("chest"):
				return -1 if sim.s["objects"]["chest"]["hp"] <= 0.0 else 0
			return 0 if e.get("chest_ok", true) else -1
	return 0

# ================================================================ Окна поверх
func _clear_overlay() -> void:
	UIK.clear(overlay)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _open(c: Control) -> Control:
	_clear_overlay()
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(c)
	return c

func _confirm(caption: String, title: String, text: String, bullets: Array, buttons: Array, dim := true) -> ConfirmDialog:
	var d: ConfirmDialog = _open(CONFIRM.instantiate())
	d.setup(caption, title, text, bullets, buttons, dim)
	return d

# ---------------------------------------------------------------- Событие
func _show_event() -> void:
	sim = null
	view.sim = null
	var e := Game.ex()
	var ev: Dictionary = DB.EVENTS[Game.current_node()["event"]]
	var d: EventDialog = _open(EVENT.instantiate())
	d.choice_picked.connect(_pick_event)
	d.continue_pressed.connect(_continue_path)
	d.fight_pressed.connect(func():
		var bat: Array = e.get("event_battle", [])
		e["event_battle"] = []
		e["battle_ctx"] = {"groups": bat, "ambush": [], "boss": false, "chest": false, "source": "event"}
		_clear_overlay()
		_start_battle_from_ctx())
	if e.get("event_result", "") != "":
		d.show_result(ev, e["event_result"], e.get("event_battle", []).size() > 0)
	else:
		d.show_choices(ev, int(e["purse"]), int(Game.state["potions"]["potion_hp"]), int(Game.state["potions"]["potion_mp"]))

func _pick_event(ch: Dictionary) -> void:
	var e := Game.ex()
	e["event_battle"] = Game.apply_event_choice(ch)
	e["event_result"] = ch.get("say", "")
	Game.save()
	_refresh_goals_live()
	_show_event()

# ---------------------------------------------------------------- Придорожная лавка
func _show_road_shop() -> void:
	sim = null
	view.sim = null
	var d: RoadShopDialog = _open(ROAD_SHOP.instantiate())
	d.leave_pressed.connect(_continue_path)
	d.buy_requested.connect(func(cid: String):
		_road_buy(cid)
		d.refresh(Game.current_node()["name"], Game.ex()["road_shop"])
		_refresh_goals_live())
	d.refresh(Game.current_node()["name"], Game.ex()["road_shop"])

func _road_buy(cid: String) -> void:
	var e := Game.ex()
	var price := Game.cons_price(cid, true)
	var r := ""
	if cid == "kit":
		if int(e["purse"]) < price:
			r = "Не хватает монет."
		else:
			e["purse"] = int(e["purse"]) - price
			e["kits"] = int(e["kits"]) + 1
			Game.save()
	else:
		r = Game.buy_cons(cid, true)
	if r != "":
		Game.notify(r)

# ---------------------------------------------------------------- Привал
func _show_camp() -> void:
	sim = null
	view.sim = null
	_clear_overlay()
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var camp: CampPanel = CAMP.instantiate()
	camp.screen = self
	overlay.add_child(camp)

func camp_leave() -> void:
	Game.camp_rest()
	_clear_overlay()
	_update_route()
	_show_banner("+40% ОЗ, +50% МП", 2.0)
	_begin_walk()

# ---------------------------------------------------------------- Пауза и выход
func _show_pause_menu() -> void:
	if overlay.get_child_count() > 0:
		return
	var was := paused
	paused = true
	var m: SystemMenu = _open(SYSTEM_MENU.instantiate())
	if arena:
		m.setup("Пауза", ["resume", "abandon"], true)
		m.get_node("%Abandon").text = "Покинуть арену"
	else:
		m.setup("Пауза", ["resume", "save", "abandon", "main_menu"], true)
	m.chosen.connect(func(a: String): _on_menu(a, was))

func _on_menu(a: String, was_paused: bool) -> void:
	match a:
		"resume":
			paused = was_paused
			_clear_overlay()
		"save":
			if sim != null:
				_save_battle()
			else:
				Game.save()
			Game.notify("Игра сохранена.")
		"abandon":
			if arena:
				_leave_arena()
			else:
				_clear_overlay()
				_on_exit_pressed(was_paused)
		"main_menu":
			on_quit()
			finished = true
			main.goto("title")

func _on_exit_pressed(was_paused := false) -> void:
	if arena:
		_leave_arena()
		return
	paused = true
	var e := Game.ex()
	var d := _confirm("ПОХОД", "Прервать поход?", "", [
		"Опыт этой попытки: отменяется",
		"Вернётся в казну: %d мон." % max(0, int(e["purse"]) - int(e["road_earned"])),
		"Дорожный заработок: %d мон. — не вернётся" % int(e["road_earned"]),
		"Покупки и расходы: не возвращаются"],
		[["Остаться", false], ["Прервать поход", true]])
	d.chosen.connect(func(i: int):
		if i == 1:
			_finish("abandon")
		else:
			paused = was_paused
			_clear_overlay())
