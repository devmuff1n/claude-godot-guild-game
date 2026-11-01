extends Control
## Экран похода (scenes/screens/ExpeditionScreen.tscn): один бесшовный путь — дорога, бои прямо на ходу,
## события, привал, придорожная лавка, оборона заставы; также испытательная арена.

const SYSTEM_MENU := preload("res://scenes/ui/SystemMenu.tscn")
const CONFIRM := preload("res://scenes/ui/ConfirmDialog.tscn")
const CAMP := preload("res://scenes/ui/CampPanel.tscn")
const EVENT := preload("res://scenes/expedition/EventDialog.tscn")
const ROAD_SHOP := preload("res://scenes/expedition/RoadShopDialog.tscn")
## 3D-уровни поручений: дорога, сцены узлов маршрута, лес. Арена остаётся на нарисованном фоне.
const LEVELS := {
	"c1": "res://scenes/levels/c1.tscn", "c2": "res://scenes/levels/c2.tscn", "c3": "res://scenes/levels/c3.tscn",
	"c4": "res://scenes/levels/c4.tscn", "c5": "res://scenes/levels/c5.tscn", "c6": "res://scenes/levels/c6.tscn",
	"c7": "res://scenes/levels/c7.tscn",
	"sc1": "res://scenes/levels/sc1.tscn", "sc2": "res://scenes/levels/sc2.tscn", "sc3": "res://scenes/levels/sc3.tscn",
}
## Отряд идёт обычным шагом (~1,25 м/с у 3D-героев). Отрезок пути между узлами WALK_SPEED × walk_dur = 676 px
## не меняется (на нём стоят декорации уровней), поэтому при медленном шаге отрезок идёт дольше.
const WALK_SPEED := 150.0
const SEGMENT_PX := 676.0
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
var walk_dur := SEGMENT_PX / WALK_SPEED  # ≈4,5 с
var finished := false
var banner_t := 0.0
var victory_hold := 0.0
var level: RoadLevel = null
var shown_time := ""        # время суток, которое сейчас показано (свет, значок в верхней панели)
var pending_banner := ""    # надпись о смене времени суток ждёт, пока погаснет текущая
var cine_target := 0.0      # наезд камеры на событие: 1 — камера у диорамы, 0 — обычный вид
const CINE_IN := 1.5        # секунд на наезд
const CINE_OUT := 0.8
## Наезд: отряд крупнее в CINE_ZOOM раз; середина между ногами отряда и точкой события (CINE_MIX)
## встаёт в CINE_AIM: отряд слева внизу, диорама справа вверху, окно выбора справа внизу, над дорогой.
const CINE_ZOOM := 1.4
const CINE_MIX := 0.5
const CINE_AIM := Vector2(680, 440)
## Правый край диорамы при наезде (левее — окно выбора, оно начинается около x = 950–1010, смотря по ширине текста)
const CINE_RIGHT_PX := 930.0

@onready var view: BattleView = %View
@onready var overlay: Control = %Overlay
@onready var top_bar: ExpeditionTopBar = %TopBar
@onready var route_bar: RouteBar = top_bar.route
@onready var cmd_menu: CommandMenu = %CmdMenu
@onready var obj_panel: ObjectivePanel = %ObjPanel
@onready var prep_panel: OutpostPrepPanel = %PrepPanel
@onready var repair_hero_opt: OptionButton = obj_panel.get_node("%RepairHero")
@onready var cutscene: Cutscene = %Cutscene
@onready var cards := {"aiden": %Card_aiden, "marek": %Card_marek, "elira": %Card_elira, "neris": %Card_neris}

func _ready() -> void:
	arena = params.has("arena")
	if arena:
		arena_cfg = params["arena"]
	view.unit_clicked.connect(_on_unit_clicked)
	view.ground_clicked.connect(_on_ground_clicked)
	top_bar.order_selected.connect(_set_order)
	top_bar.speed_selected.connect(_set_speed)
	top_bar.pause_pressed.connect(_toggle_pause)
	top_bar.menu_pressed.connect(_show_pause_menu)
	cmd_menu.closed.connect(_close_menu)
	cmd_menu.ability_chosen.connect(_choose_ability)
	cmd_menu.potion_chosen.connect(_choose_potion)
	cmd_menu.attack_chosen.connect(_choose_attack)
	for id in cards.keys():
		cards[id].pressed.connect(_on_card_pressed)
		cards[id].hover_changed.connect(_on_card_hover)
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
	cutscene.screen = self
	cutscene.view = view
	cutscene.fight_requested.connect(_story_fight)
	cutscene.finished.connect(_story_done)
	_set_speed(1.0)
	top_bar.set_paused(false)
	top_bar.set_order("hold", false)
	_order_cards()
	if arena:
		%Goals.visible = false
		route_bar.visible = false
		top_bar.set_title("Испытательная арена")
		top_bar.set_purse(0, false)
		top_bar.set_time("")
		view.night = arena_cfg.get("night", false)
		_start_sim(arena_cfg)
	else:
		var c: Dictionary = DB.CONTRACTS[Game.ex()["cid"]]
		view.outpost = c.get("outpost", false)
		view.walk_wagon = Game.ex()["wagon"] != null
		_load_level(Game.ex()["cid"])
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
func _load_level(cid: String) -> void:
	var path: String = LEVELS.get(cid, "")
	if path == "" or not ResourceLoader.exists(path):
		return
	level = (load(path) as PackedScene).instantiate() as RoadLevel
	%LevelViewport.add_child(level)
	%LevelView.visible = true
	view.bg_3d = true

## Пройденный путь в пикселях: узел k достигается при (k + 1) отрезках ходьбы.
func _route_px() -> float:
	var e := Game.ex()
	var p := _walk_frac() if _mid_walk() else 1.0
	return (float(e["node"]) + p) * WALK_SPEED * walk_dur

## Отряд между пунктами: идёт по дороге или остановлен кат-сценой (и её боем) посреди отрезка.
func _mid_walk() -> bool:
	return Game.ex().get("phase", "") == "walk" or not Game.story().is_empty()

func _walk_frac() -> float:
	return float(Game.ex().get("walk_t", 0.0)) / walk_dur

func _sync_level() -> void:
	if level == null or arena:
		return
	level.set_scroll(_route_px())
	if sim != null and sim.s["objects"].has("gate"):
		var g: Dictionary = sim.s["objects"]["gate"]
		level.set_gate_damage(1.0 - g["hp"] / g["max"])

func _resume() -> void:
	var e := Game.ex()
	view.scroll = _route_px()
	_sync_level()
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
			var st := Game.story()
			if not st.is_empty():
				view.walking = false
				cutscene.play(st["id"], int(st["step"]))

func _update_route() -> void:
	if arena:
		return
	var e := Game.ex()
	var prog := _walk_frac() if _mid_walk() else 0.0
	route_bar.set_route(e["route"], int(e["node"]), prog, Game.ex_times())
	_update_daylight()

## Свет по времени суток (DayTime): в пункте — его время, по дороге между пунктами свет плавно меняется.
func _update_daylight() -> void:
	var e := Game.ex()
	if arena or e.is_empty():
		return
	var k := int(e["node"])
	var to := Game.time_at(k)
	var from := to
	var t := 1.0
	if _mid_walk() and k > 0 and not Game.route_finished():
		from = Game.time_at(k - 1)
		t = smoothstep(0.15, 0.85, _walk_frac())
	var p := DayTime.mix(from, to, t)
	if level != null:
		level.set_daylight(p)
	var now := to if t >= 0.5 else from
	view.night = now == "night"
	if view.bg_3d or now != "night":
		view.tint = p["tint"]
	else:
		view.tint = Color(1, 1, 1, 0)
	if now != shown_time:
		if shown_time != "":
			pending_banner = DayTime.BANNERS[now]
		shown_time = now
		top_bar.set_time(now)

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
		# Сцена-итог поручения (DB.CUTSCENES, node = длина маршрута), потом итоги
		var cs := Game.cutscene_due()
		if cs != "" and Game.story().is_empty():
			_start_story(cs)
		elif Game.story().is_empty():
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
			# Состав боя берётся из актуальных данных (меню баланса F10 могло их поменять после начала похода)
			var src: Dictionary = nd
			var live: Array = DB.CONTRACTS[e["cid"]].get("route", [])
			if int(e["node"]) < live.size() and live[int(e["node"])]["type"] == "battle":
				src = live[int(e["node"])]
			e["battle_ctx"] = {"groups": src["groups"].duplicate(true), "ambush": src.get("ambush", []).duplicate(true), "boss": nd.get("boss", false),
				"chest": nd.get("chest", false), "source": "node", "hp_pct": int(src.get("hp_pct", 100)), "dmg_pct": int(src.get("dmg_pct", 100)),
				"champion": src.get("champion", {}).duplicate()}
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
	_cine_out()
	Game.complete_node()
	Game.save()
	_clear_overlay()
	_update_route()
	_begin_walk()

# ================================================================ Бой
func _start_battle_from_ctx() -> void:
	var e := Game.ex()
	var ctx: Dictionary = e["battle_ctx"]
	var cfg := Game.battle_config(ctx["groups"], ctx["ambush"], ctx["boss"], ctx["chest"], ctx.get("champion", {}))
	cfg["hp_pct"] = int(ctx.get("hp_pct", 100))
	cfg["dmg_pct"] = int(ctx.get("dmg_pct", 100))
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
	_update_cine(delta)
	banner_t -= delta
	if banner_t <= 0.0 and pending_banner != "":
		_show_banner(pending_banner, 1.8)
		pending_banner = ""
	if banner_t <= 0.0:
		%Banner.text = ""
	elif banner_t < 0.4:
		%Banner.modulate.a = banner_t / 0.4
	if finished:
		return
	if sim == null:
		if not arena and Game.ex().get("phase", "") == "walk" and overlay.get_child_count() == 0 and not Game.route_finished() 				and Game.story().is_empty():
			var e := Game.ex()
			e["walk_t"] = float(e.get("walk_t", 0.0)) + delta
			# Кат-сцена отрезка: отряд останавливается на её месте пути
			var cs := Game.cutscene_due()
			if cs != "" and e["walk_t"] >= float(DB.CUTSCENES[cs]["at"]) * walk_dur:
				e["walk_t"] = float(DB.CUTSCENES[cs]["at"]) * walk_dur
				_sync_level()
				_update_route()
				_start_story(cs)
				_update_cards_walk()
				return
			view.scroll += delta * WALK_SPEED
			view.shift_corpses(delta * WALK_SPEED)
			_regroup(delta)
			Game.walk_regen(delta)
			_update_route()
			if e["walk_t"] >= walk_dur:
				e["walk_t"] = walk_dur
				_sync_level()
				e["walk_t"] = 0.0
				_arrive()
			else:
				_sync_level()
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
	for ev in sim.events:
		if ev["type"] == "death" and level != null:
			var du = sim.unit(int(ev["uid"]))
			if du != null and du.has("anchor_x"):
				level.break_obelisk()
				view.shake = 0.4
		if ev["type"] == "wave" and int(ev["n"]) > 1:
			_show_banner("Волна %d из %d" % [ev["n"], ev["of"]], 1.8)
	view.consume_events(sim.events)
	sim.events.clear()
	_update_battle_ui()
	_sync_level()
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
	_update_wave_pill()
	_refresh_goals_live()

## Счётчик волн боя: «2/3». Одна волна — счётчик не нужен; у заставы между волнами — своя панель.
func _update_wave_pill() -> void:
	var w := sim.wave_info()
	var show: bool = w.y > 1 and sim.s["phase"] == "fight"
	%WavePill.visible = show
	if not show:
		return
	%WavePill.set_value("%d/%d" % [w.x, w.y])
	%WavePill.tooltip_text = "Волна %d из %d. Следующая выйдет, когда эта будет перебита." % [w.x, w.y]

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
	if Game.ex()["battle_ctx"].get("source", "") == "story":
		_story_battle_won()
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
		elif not "phantom" in u["tags"]:
			view.corpses.append({"look": u["look"], "x": u["x"], "facing": u["facing"], "big": u["key"] in ["brute", "captain"], "tier": u.get("tier", 1)})
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
	var leave := "Вернуться к балансу" if arena_cfg.has("balance_test") else "Покинуть арену"
	var d := _confirm("ИСПЫТАНИЕ ОКОНЧЕНО", "Победа" if won else "Поражение", ("" if won else sim.s["loss"] + "\n") + "Время: %d с" % int(sim.s["t"]), [], [["Повторить", false], [leave, true]])
	d.chosen.connect(func(i: int):
		if i == 0:
			_start_sim(arena_cfg)
		else:
			_leave_arena())

func _leave_arena() -> void:
	finished = true
	if arena_cfg.has("balance_test"):
		# Пробный бой из меню баланса (F10): назад туда, откуда пришли, и снова открыть меню на той же точке
		main.goto("expedition" if not Game.ex().is_empty() else "village")
		main.open_balance(arena_cfg["balance_test"])
		return
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

## Выбор цели с клавиатуры: Tab / Shift+Tab — следующая цель, Enter — выбрать подсвеченную.
## В _input, а не в _unhandled_input: иначе Tab перехватит переключение фокуса кнопок.
func _input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed or finished or sim == null:
		return
	if targeting.is_empty() or not (view.target_mode in ["enemy", "ally"]) or overlay.get_child_count() > 0:
		return
	var k: int = ev.keycode
	if k == KEY_TAB:
		view.cycle_target(-1 if ev.shift_pressed else 1)
		get_viewport().set_input_as_handled()
	elif (k == KEY_ENTER or k == KEY_KP_ENTER) and not ev.echo and view.hover_uid >= 0:
		var t = sim.unit(view.hover_uid)
		if t != null and view.can_target(t):
			_apply_target(t)
		get_viewport().set_input_as_handled()

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
		_on_card_pressed(_card_order()[k - KEY_1])
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

## Карточка героя внизу: при выборе союзника — применить на этого героя, иначе — открыть его команды.
func _on_card_pressed(hid: String) -> void:
	if sim != null and view.target_mode == "ally" and not targeting.is_empty():
		var u = sim.hero_unit(hid)
		if u != null:
			_apply_target(u)
		return
	_open_menu(hid)

## Курсор над карточкой во время выбора союзника — подсветить этого героя и на поле.
func _on_card_hover(hid: String, on: bool) -> void:
	if sim == null:
		return
	var u = sim.hero_unit(hid)
	if on and u != null:
		view.hover_card_uid = int(u["uid"])
	elif u != null and view.hover_card_uid == int(u["uid"]):
		view.hover_card_uid = -1

func _sync_card_targets() -> void:
	for id in cards.keys():
		var u = sim.hero_unit(id) if sim != null else null
		cards[id].set_target_hint(view.target_mode == "ally" and u != null and u["alive"])

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
	if a["target"] == "ground":
		view.target_mode = "ground"
		view.target_radius = float(a["area"])
		view.target_ab = ab
	else:
		view.target_mode = "enemy" if a["target"] == "enemy" else "ally"
	_sync_card_targets()
	cmd_menu.visible = false
	_set_status("%s: %s" % ["Область" if a["target"] == "ground" else "Цель", a["name"]])

func _choose_attack() -> void:
	if sim.hero_unit(menu_hero) == null:
		return
	targeting = {"hero": menu_hero, "attack": true}
	view.target_mode = "enemy"
	_sync_card_targets()
	cmd_menu.visible = false
	_set_status("Цель: Автоатака")

func _choose_potion(kind: String) -> void:
	targeting = {"hero": menu_hero, "potion": kind}
	view.target_mode = "ally"
	_sync_card_targets()
	cmd_menu.visible = false
	_set_status("Кому: %s" % DB.CONSUMABLES[kind]["name"])

func _apply_target(t: Dictionary) -> void:
	var u = sim.hero_unit(targeting["hero"])
	if u == null:
		_cancel_target()
		return
	var res := ""
	if targeting.has("attack"):
		res = sim.set_hero_focus(u["uid"], t["uid"])
	elif targeting.has("ab"):
		res = sim.use_ability(u["uid"], targeting["ab"], t["uid"])
	else:
		res = sim.use_potion(u["uid"], targeting["potion"], t["uid"])
	if res != "":
		_show_banner(res, 1.6)
		return
	_cancel_target()
	_close_menu()

func _on_ground_clicked(x: float) -> void:
	if sim == null or not targeting.has("ab"):
		return
	var u = sim.hero_unit(targeting["hero"])
	if u == null:
		_cancel_target()
		return
	var res := sim.use_ability_at(u["uid"], targeting["ab"], x)
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
	view.hover_card_uid = -1
	_sync_card_targets()

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
		for g in Balance.wave_groups(waves[sim.s["wave"]]):
			for t in g:
				parts.append(DB.ENEMIES[Balance.etype(t)]["name"])
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

# ---------------------------------------------------------------- Наезд камеры
## Камера плавно подъезжает к отряду и диораме события (и отъезжает обратно).
func _update_cine(delta: float) -> void:
	if level == null:
		return
	if level.cine == 0.0 and cine_target == 0.0:
		if view.scale != Vector2.ONE or view.position != Vector2.ZERO:
			view.scale = Vector2.ONE
			view.position = Vector2.ZERO
		return
	var dur := CINE_IN if cine_target > level.cine else CINE_OUT
	level.set_cine(move_toward(level.cine, cine_target, delta / dur))
	var x := level.view_xform()
	# 2D-слой с героями повторяет наезд: масштаб и сдвиг всего слоя
	view.scale = Vector2(x.x, x.x)
	view.position = Vector2(x.y, x.z)

func _cine_in(event_id: String) -> void:
	if level == null or arena:
		return
	var hx := 0.0
	for w in view.walk_units:
		hx += float(w["x"])
	hx = hx / max(1, view.walk_units.size()) if not view.walk_units.is_empty() else 735.0
	var hero := Vector3((view.scroll + hx) / RoadLevel.PX_PER_M, 0.0, 0.0)
	if level.cine == 0.0:
		var box := level.event_bounds(event_id)
		if box.is_empty():
			level.plan_cine(hero, level.event_focus(event_id), CINE_ZOOM, CINE_MIX, CINE_AIM)
		else:
			var xl := 1e9
			var xr := -1e9
			for w in view.walk_units:
				xl = minf(xl, float(w["x"]))
				xr = maxf(xr, float(w["x"]))
			if view.walk_units.is_empty():
				xl = hx
				xr = hx
			level.plan_event_cine((view.scroll + xl) / RoadLevel.PX_PER_M, (view.scroll + xr) / RoadLevel.PX_PER_M,
				box, CINE_ZOOM, CINE_RIGHT_PX)
	cine_target = 1.0

func _cine_out() -> void:
	cine_target = 0.0

# ---------------------------------------------------------------- Событие
func _show_event() -> void:
	sim = null
	view.sim = null
	var e := Game.ex()
	var ev: Dictionary = DB.EVENTS[Game.current_node()["event"]]
	var first := level != null and level.cine == 0.0
	_cine_in(Game.current_node()["event"])
	var d: EventDialog = _open(EVENT.instantiate())
	if first:
		d.modulate.a = 0.0
		create_tween().tween_property(d, "modulate:a", 1.0, 0.35).set_delay(CINE_IN * 0.75)
	d.choice_picked.connect(_pick_event)
	d.continue_pressed.connect(_continue_path)
	d.fight_pressed.connect(func():
		var bat: Array = e.get("event_battle", [])
		e["event_battle"] = []
		e["battle_ctx"] = {"groups": bat, "ambush": [], "boss": false, "chest": false, "source": "event"}
		_clear_overlay()
		_cine_out()
		_start_battle_from_ctx())
	if e.get("event_result", "") != "":
		d.show_result(ev, e["event_result"], e.get("event_battle", []).size() > 0)
	else:
		d.show_choices(ev, int(e["purse"]), int(Game.state["potions"]["potion_hp"]), int(Game.state["potions"]["potion_mp"]))

func _pick_event(choice: Dictionary) -> void:
	var e := Game.ex()
	var ch := Game.resolve_event_choice(choice)
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

# ---------------------------------------------------------------- Кат-сцена
func _start_story(id: String) -> void:
	view.walking = false
	Game.set_story(id, 0)
	cutscene.play(id, 0)

## Бой из кат-сцены: актёры-звери становятся врагами там, где стоят, отряд дерётся с того места, где остановился.
func _story_fight(step: Dictionary) -> void:
	var e := Game.ex()
	_cine_out()
	e["battle_ctx"] = {"groups": step["fight"].duplicate(true), "ambush": [], "boss": false, "chest": false, "source": "story"}
	var xs: Array = []
	for aid in step.get("actors", []):
		var a := view.actor(aid)
		if not a.is_empty():
			xs.append(float(a["x"]))
	_start_battle_from_ctx()
	var k := 0
	for u in sim.s["units"]:
		if u["side"] == "enemy" and k < xs.size():
			u["x"] = xs[k]
			k += 1
	view.actors = view.actors.filter(func(a): return not (a["id"] in step.get("actors", [])))
	e["battle"] = sim.save_state()
	Game.save()

func _story_battle_won() -> void:
	var e := Game.ex()
	# Пусть проекция дотает и рассыплется пеплом на глазах
	await get_tree().create_timer(BattleView.ASH_FADE + 0.15).timeout
	if sim == null or finished:
		return
	Game.absorb_battle(sim)
	view.walk_units = []
	view.corpses = []
	for u in sim.s["units"]:
		if u["side"] == "hero":
			view.walk_units.append({"look": u["key"], "x": u["x"]})
		elif not "phantom" in u["tags"]:
			view.corpses.append({"look": u["look"], "x": u["x"], "facing": u["facing"], "big": false, "tier": u.get("tier", 1)})
	sim = null
	view.sim = null
	view.walking = false
	e["battle"] = null
	e["phase"] = "walk"
	Game.save()
	victory_hold = 0.0
	obj_panel.visible = false
	_update_route()
	var st := Game.story()
	cutscene.play(st["id"], int(st["step"]))

func _story_done() -> void:
	Game.end_story()
	_cine_out()
	_begin_walk()

## Наезд камеры кат-сцены: отряд и актёры крупнее в zoom раз; 0 — обычный вид.
func story_cam(zoom: float) -> void:
	if level == null or zoom <= 0.0:
		_cine_out()
		return
	if level.cine == 0.0:
		var hx := 735.0
		if not view.walk_units.is_empty():
			hx = 0.0
			for w in view.walk_units:
				hx += float(w["x"])
			hx /= view.walk_units.size()
		var ax := hx + 450.0
		if not view.actors.is_empty():
			ax = 0.0
			for a in view.actors:
				ax += float(a.get("to", a["x"]))
			ax /= view.actors.size()
		level.plan_cine(Vector3((view.scroll + hx) / RoadLevel.PX_PER_M, 0.0, 0.0), Vector3((view.scroll + ax) / RoadLevel.PX_PER_M, 0.0, 0.0),
			zoom, 0.5, Vector2(800, 610), false)
	cine_target = 1.0

## Во время кат-сцены панели похода прячутся за чёрными полосами.
func set_hud_shown(on: bool) -> void:
	for n in [top_bar, %Goals, %Cards, %LogLabel, %WavePill]:
		create_tween().tween_property(n, "modulate:a", 1.0 if on else 0.0, 0.3)

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
