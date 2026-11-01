extends Control
## Корневой узел (scenes/Main.tscn): переключает экраны-сцены, показывает уведомления, сохраняет при закрытии окна.

const SCREENS := {
	"title": "res://scenes/screens/TitleScreen.tscn",
	"village": "res://scenes/screens/VillageScreen.tscn",
	"expedition": "res://scenes/screens/ExpeditionScreen.tscn",
	"diplomacy": "res://scenes/screens/DiplomacyScreen.tscn",
}
const TOAST := preload("res://scenes/ui/Toast.tscn")
const BALANCE := preload("res://scenes/ui/balance/BalanceEditor.tscn")

var current: Control
@onready var host: Control = %ScreenHost
@onready var toast_box: VBoxContainer = %ToastBox

func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	Game.toast.connect(_toast)
	var shot: String = OS.get_environment("GUILD_SHOT")
	if shot != "":
		_shot_later(shot, float(OS.get_environment("GUILD_SHOT_T")) if OS.get_environment("GUILD_SHOT_T") != "" else 2.0)
	if OS.get_environment("GUILD_DUMP") != "":
		var dn := Node.new()
		dn.set_script(load("res://tests/dump.gd"))
		add_child(dn)
	if OS.get_environment("GUILD_UITEST") != "":
		var tn := Node.new()
		var tests := {"extra": "res://tests/ui_extra.gd", "jitter": "res://tests/ui_jitter.gd", "sizes": "res://tests/ui_sizes.gd", "balance": "res://tests/balance_ui.gd", "video": "res://tests/autoplay_video.gd", "anim": "res://tests/anim_rec.gd", "cutscene": "res://tests/cutscene_check.gd", "cutshots": "res://tests/cutscene_shots.gd"}
		tn.set_script(load(tests.get(OS.get_environment("GUILD_UITEST"), "res://tests/ui_smoke.gd")))
		add_child(tn)
		return
	var start: String = OS.get_environment("GUILD_START")
	if start != "":
		_debug_start(start)
	else:
		goto("title")

func _shot_later(path: String, t: float) -> void:
	await get_tree().create_timer(t).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	get_tree().quit()

func goto(name: String, params: Dictionary = {}) -> void:
	if current != null:
		current.queue_free()
		current = null
	var scene: PackedScene = load(SCREENS[name])
	var scr: Control = scene.instantiate()
	scr.set("main", self)
	scr.set("params", params)
	host.add_child(scr)
	current = scr

## Скрытое меню баланса волн: F10 (только в отладочной сборке — при запуске из редактора Godot)
func _input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_F10 and OS.is_debug_build():
		get_viewport().set_input_as_handled()
		open_balance()

func open_balance(focus := {}) -> BalanceEditor:
	for c in get_children():
		if c is BalanceEditor:
			return c
	var ed: BalanceEditor = BALANCE.instantiate()
	ed.main = self
	add_child(ed)
	ed.focus(focus)
	return ed

func _toast(text: String) -> void:
	var t: Control = TOAST.instantiate()
	t.get_node("%Text").text = text
	toast_box.add_child(t)
	# Не больше трёх уведомлений одновременно
	while toast_box.get_child_count() > 3:
		var old := toast_box.get_child(0)
		toast_box.remove_child(old)
		old.queue_free()
	t.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(t, "modulate:a", 1.0, 0.15)
	tw.tween_interval(2.6)
	tw.tween_property(t, "modulate:a", 0.0, 0.5)
	tw.tween_callback(t.queue_free)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if current != null and current.has_method("on_quit"):
			current.on_quit()
		elif not Game.state.is_empty():
			Game.save()
		get_tree().quit()

## Отладочный старт для автоматических скриншотов (переменная окружения GUILD_START)
func _debug_start(mode: String) -> void:
	Game.slot = -1
	Game.state = Game._fresh_state()
	Game.state["intro_seen"] = true
	# result_c5 — итоги первого выполнения c5; fight_c5_2 — бой c5 в узле 2; board_c5 — доска с выбранным c5
	# walk_c1_4 — отряд в пути к пункту 4 поручения c1, на середине дороги (смена времени суток)
	if mode.begins_with("walk_c"):
		var wp := mode.split("_")
		Game.start_expedition(wp[1], {"purse": 60, "general": DB.CONTRACTS[wp[1]]["general"][0], "personal": {}})
		Game.ex()["node"] = int(wp[2])
		for i in int(wp[2]):
			Game.ex()["route"][i]["done"] = true
		Game.ex()["walk_t"] = 1.0
		goto("expedition")
		return
	if mode.begins_with("result_c") or mode.begins_with("fight_c") or mode.begins_with("board_c"):
		var parts := mode.split("_")
		var cid: String = parts[1]
		var k := DB.STORY_ORDER.find(cid)
		for i in k:
			Game.state["completed"][DB.STORY_ORDER[i]] = 1
		Game.state["story_stage"] = k
		for id in DB.HERO_IDS:
			Game.hero(id)["level"] = [1, 2, 3, 4, 5, 6, 7, 8][k]
			Game.hero(id)["job"] = min(DB.MAX_JOB, [1, 2, 2, 3, 4, 4, 4, 4][k])
		if mode.begins_with("board_c"):
			goto("village", {"tab": "board"})
			return
		Game.start_expedition(cid, {"purse": 60, "general": DB.CONTRACTS[cid]["general"][0], "personal": {}})
		if mode.begins_with("result_c"):
			for id in DB.HERO_IDS:
				Game.hero(id)["xp"] = DB.xp_to_next(int(Game.hero(id)["level"]))
			Game.ex()["counters"]["champions"] = 1
			goto("village", {"result": Game.finish_expedition("victory")})
			return
		var ni := int(parts[2])
		var nd: Dictionary = Game.ex()["route"][ni]
		Game.ex()["node"] = ni
		Game.ex()["battle_ctx"] = {"groups": nd["groups"], "ambush": nd.get("ambush", []), "boss": nd.get("boss", false), "chest": nd.get("chest", false),
			"source": "node", "champion": nd.get("champion", {})}
		Game.ex()["phase"] = "battle"
		goto("expedition")
		return
	# diplo — миссия c8 с начала, diplo_<N> — на сцене N, diplo_<N>_r — с итогом броска, diplo_end — итоги; party_social — вкладка «Черты»
	if mode.begins_with("diplo") or mode == "party_social":
		for i in 7:
			Game.state["completed"][DB.STORY_ORDER[i]] = 1
		Game.state["story_stage"] = 7
		Game.state["premium_claimed"]["c7"] = true
		for id in DB.HERO_IDS:
			Game.hero(id)["level"] = 8
			Game.hero(id)["job"] = DB.MAX_JOB
		Game.hero("aiden")["social"] = {"elo": 2, "cha": 1, "faith": 1}
		if mode == "party_social":
			goto("village", {"tab": "party"})
			current.show_tab("party", {"side_tab": "social", "hero_id": "aiden"})
			return
		Game.start_diplomacy("c8")
		var dp := mode.split("_")
		if mode == "diplo_end":
			while true:
				Game.dip_choose(0)
				if Game.dip_next():
					break
			goto("village", {"result": Game.finish_diplomacy()})
			return
		if dp.size() > 1:
			for i in int(dp[1]):
				Game.dip_choose(0)
				Game.dip_next()
			if dp.size() > 2:
				Game.rng.seed = 7
				var beat := Game.dip_beat()
				for i in beat["options"].size():
					if beat["options"][i].has("check"):
						Game.dip_choose(i)
						break
		goto("diplomacy")
		return
	match mode:
		"village", "town", "party", "board", "shop", "journal", "arena":
			var tabs := {"village": "home", "town": "town", "party": "party", "board": "board", "shop": "shop", "journal": "party", "arena": "arena"}
			goto("village", {"tab": tabs[mode]})
			if mode == "journal":
				current.show_tab("party", {"sub": "journal"})
		"battle", "escort", "outpost", "camp", "event", "fight", "fight3", "fight7":
			var cid: String = {"battle": "c1", "escort": "c4", "outpost": "c3", "camp": "c1", "event": "c1", "fight": "c1", "fight3": "c4", "fight7": "c7"}[mode]
			for c in (DB.STORY_ORDER.slice(0, 6) if mode == "fight7" else ["c1", "c2", "c3"]):
				if mode != "battle":
					Game.state["completed"][c] = 1
			Game.state["story_stage"] = 3 if mode != "battle" else 0
			Game.start_expedition(cid, {"purse": 50, "general": "no_ko", "personal": {"hero": "elira", "obj": "kills"}})
			if mode == "camp":
				Game.ex()["node"] = 3
				Game.ex()["phase"] = "camp"
			elif mode.begins_with("fight"):
				var nd: Dictionary = Game.ex()["route"][0 if mode != "fight7" else 4]
				Game.ex()["node"] = 0 if mode != "fight7" else 4
				Game.ex()["battle_ctx"] = {"groups": nd["groups"], "ambush": nd.get("ambush", []), "boss": nd.get("boss", false), "chest": nd.get("chest", false), "source": "node"}
				Game.ex()["phase"] = "battle"
			elif mode == "event":
				Game.ex()["node"] = 1
				Game.ex()["phase"] = "event"
			goto("expedition")
		"result", "reward", "perks":
			Game.start_expedition("c1", {"purse": 60, "general": "helpful", "personal": {"hero": "marek", "obj": "tank"}})
			for id in DB.HERO_IDS:
				Game.hero(id)["xp"] = 130
			Game.ex()["flags"]["helped"] = true
			var res := Game.finish_expedition("victory")
			if mode == "result":
				goto("village", {"result": res})
			elif mode == "reward":
				goto("village")
			else:
				goto("village", {"tab": "party"})
				current.show_tab("party", {"side_tab": "perks", "hero_id": "elira"})
		"balance", "balance_types":
			_debug_start("fight")
			await get_tree().create_timer(1.5).timeout
			var bp: PackedStringArray = (OS.get_environment("GUILD_BALANCE_POINT") if OS.get_environment("GUILD_BALANCE_POINT") != "" else "c2:2").split(":")
			open_balance({"cid": bp[0], "point": int(bp[1]), "tab": "types" if mode == "balance_types" else "waves"})
		"intro":
			Game.state["intro_seen"] = false
			goto("village")
		"roadshop":
			_debug_start("event")
			Game.ex()["node"] = 2
			Game.ex()["phase"] = "shop"
			Game.ex()["route"][2] = {"type": "shop", "name": "Придорожная лавка"}
			Game.gen_road_shop()
			goto("expedition")
		"pause", "abandon":
			_debug_start("fight")
			await get_tree().create_timer(1.0).timeout
			if mode == "pause":
				current._show_pause_menu()
			else:
				current._on_exit_pressed()
		"menu":
			_debug_start("fight")
			await get_tree().create_timer(2.5).timeout
			current._open_menu("marek")
		"camptalk":
			_debug_start("camp")
			await get_tree().create_timer(1.0).timeout
			for c in current.overlay.get_children():
				if c is CampPanel:
					c._open_topic("elira")
		_:
			goto("title")
