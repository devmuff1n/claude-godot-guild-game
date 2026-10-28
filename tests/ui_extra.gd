extends "res://tests/ui_smoke.gd"
## Дополнительные пути: арена, поражение, ремонт повозки, пауза, журнал, лавка (продажа/выкуп), загрузка слота.

func _ready() -> void:
	main = get_parent()
	await wait(5)
	Game.slot = 2
	Game.state = Game._fresh_state()
	Game.state["intro_seen"] = true
	for c in ["c1", "c2"]:
		Game.state["completed"][c] = 1
	Game.state["story_stage"] = 2
	Game.save()
	main.goto("village")
	await wait(3)
	var v = main.current
	# Лавка: продажа и выкуп
	v.show_tab("shop")
	await wait(2)
	var t0: int = Game.state["treasury"]
	Game.sell_storage(0)
	p("sold, treasury %d -> %d, buyback=%d" % [t0, Game.state["treasury"], Game.state["shop"]["buyback"].size()])
	await wait(2)
	press("Выкупить")
	await wait(2)
	p("after buyback treasury=%d storage=%d" % [Game.state["treasury"], Game.storage_count()])
	press_tip("Купить: Яблоки")
	await wait(1)
	# Журнал: все пары
	v.show_tab("party")
	await wait(2)
	var pv = v.content.get_child(0)
	pv.sub = "journal"
	pv.refresh()
	await wait(2)
	press("Все пары", pv)
	await wait(2)
	press("Нэрис Вейль", pv)
	await wait(2)
	# Перки: проверка требований
	pv.sub = "heroes"
	pv.side_tab = "perks"
	pv.refresh()
	await wait(2)
	# Экипировка двуручного и щита
	var it := Items.make("bow_hunt", 1, "common", RandomNumberGenerator.new())
	Game.add_item(it)
	var idx := -1
	for i in Game.storage().size():
		if Game.storage()[i] != null and Game.storage()[i]["uid"] == it["uid"]:
			idx = i
	p("marek equip bow: '%s'" % Game.equip_from_storage("marek", idx))
	var plate := Items.make("plate_chest", 3, "rare", RandomNumberGenerator.new())
	Game.add_item(plate)
	for i in Game.storage().size():
		if Game.storage()[i] != null and Game.storage()[i]["uid"] == plate["uid"]:
			idx = i
	p("marek equip plate ilvl3: '%s'" % Game.equip_from_storage("marek", idx))
	p("aiden equip plate: '%s'" % Game.equip_from_storage("aiden", idx))
	# Заполнение кладовой и очередь
	var r := RandomNumberGenerator.new()
	while Game.free_slot() >= 0:
		Game.add_item(Items.random_item(2, r))
	Game.add_item(Items.random_item(2, r))
	p("storage full=%d queue=%d" % [Game.storage_count(), Game.state["queue"].size()])
	Game.sell_storage(5)
	p("take queue -> %d" % Game.take_queue())
	# Арена
	v.show_tab("arena")
	await wait(2)
	var av = v.content.get_child(0)
	av.preset = 3
	av.refresh()
	await wait(1)
	press("Начать испытание")
	await wait(5)
	var es = main.current
	es.speed = 25.0
	var tr0: int = Game.state["treasury"]
	var xp0: int = Game.hero("aiden")["xp"]
	es._obj_task("repair")
	es.repair_hero_opt.select(1)
	es._obj_task("repair")
	es._show_pause_menu()
	await wait(2)
	press("Продолжить")
	for i in 3000:
		bot(es.sim)
		await wait(1)
		if es.overlay.get_child_count() > 0:
			break
	p("arena over: " + es.sim.s["phase"] + " t=" + str(int(es.sim.s["t"])))
	press("Покинуть арену")
	await wait(3)
	p("arena no change: treasury %d==%d xp %d==%d" % [tr0, Game.state["treasury"], xp0, Game.hero("aiden")["xp"]])
	# Поражение в сюжетном бою
	v = main.current
	v.show_tab("board")
	await wait(2)
	var board = v.content.get_child(0)
	board.sel = "c3"
	board.refresh()
	await wait(1)
	press("Выступить")
	await wait(3)
	for i in 600:
		var e := Game.ex()
		if e.is_empty():
			break
		if e["phase"] == "prebattle":
			press("В бой")
		if e["phase"] == "battle" and main.current.sim != null:
			for u in main.current.sim.alive_of("hero"):
				main.current.sim._apply_damage(u, 9999, "phys", null, {})
			break
		await wait(1)
	await wait(5)
	press("Вернуться в деревню")
	await wait(3)
	p("defeat result: " + str(Game.state["last_result"].get("kind", "?")) + " exp=" + str(Game.state["expedition"]))
	press("Продолжить")
	await wait(2)
	main.goto("title")
	await wait(3)
	press("Продолжить")
	await wait(3)
	p("loaded screen: " + main.current.get_script().resource_path)
	get_tree().quit()
