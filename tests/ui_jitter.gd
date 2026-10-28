extends Node
## Проверка «дёрганья» HUD: во время настоящего боя (сопровождение повозки, открытое меню команд)
## каждый кадр замеряются прямоугольники элементов интерфейса. Любой сдвиг или изменение размера — ошибка.
var main

func _ready() -> void:
	main = get_parent()
	await get_tree().process_frame
	Game.slot = -1
	Game.state = Game._fresh_state()
	Game.state["intro_seen"] = true
	for c in ["c1", "c2"]:
		Game.state["completed"][c] = 1
	Game.state["story_stage"] = 2
	Game.start_expedition("c3", {"purse": 50, "general": "no_ko", "personal": {"hero": "elira", "obj": "kills"}})
	var nd: Dictionary = Game.ex()["route"][0]
	Game.ex()["battle_ctx"] = {"groups": nd["groups"], "ambush": nd.get("ambush", []), "boss": false, "chest": false, "source": "node"}
	Game.ex()["phase"] = "battle"
	main.goto("expedition")
	for i in 10:
		await get_tree().process_frame
	var es = main.current
	es.speed = 2.0
	es._open_menu("marek")
	for i in 5:
		await get_tree().process_frame
	var watch := {}
	var tb = es.top_bar
	for n in ["%AdvButton", "%HoldButton", "%Speed05", "%Speed1", "%Speed15", "%Speed2", "%PauseButton", "%MenuButton", "%Purse", "%TitleLabel"]:
		watch["top " + n] = tb.get_node(n)
	for id in es.cards.keys():
		var c: HeroCard = es.cards[id]
		watch["card " + id] = c
		for n in ["%HP", "%MP", "%Name", "%HpBar", "%MpBar", "%AtbBar"]:
			watch["card %s %s" % [id, n]] = c.get_node(n)
	watch["goals"] = es.get_node("%Goals")
	watch["objpanel"] = es.obj_panel
	watch["cmdmenu"] = es.cmd_menu
	var base := {}
	for k in watch.keys():
		base[k] = watch[k].get_global_rect()
	var bad := {}
	var frames := 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 25000 and es.sim != null and es.sim.s["phase"] == "fight":
		await get_tree().process_frame
		frames += 1
		# Применяем умение — в меню начинает тикать перезарядка
		if frames % 60 == 20 and es.sim != null:
			var m = es.sim.hero_unit("marek")
			if m != null and m["alive"] and es.sim.ability_problem(m["uid"], "taunt") == "":
				es._choose_ability("taunt")
		# Меню держим открытым, переоткрывая при закрытии (смерть героя и т.п.)
		if not es.cmd_menu.visible and es.sim != null:
			es._open_menu("marek")
			await get_tree().process_frame
			base["cmdmenu"] = es.cmd_menu.get_global_rect()
		for k in watch.keys():
			var r: Rect2 = watch[k].get_global_rect()
			if not r.is_equal_approx(base[k]):
				if not bad.has(k):
					bad[k] = "%s -> %s" % [base[k], r]
				base[k] = r
	print("[JITTER] frames=%d phase=%s" % [frames, es.sim.s["phase"] if es.sim != null else "none"])
	if bad.is_empty():
		print("[JITTER] OK: ни один элемент не сдвинулся")
	else:
		for k in bad.keys():
			print("[JITTER] MOVED ", k, ": ", bad[k])
	get_tree().quit()
