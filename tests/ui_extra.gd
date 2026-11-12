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
	# Перековка и арена — в Кузнице и на Тренировочном дворе, их строят после c8
	Game.state["completed"]["c8"] = 1
	for b in ["Smithy", "TrainingYard"]:
		Game.state["built"][b] = true
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
	for i in 1500:
		if not Game.story().is_empty():
			press("Пропустить")
		if main.current.sim != null and press("Следующая волна"):
			break
		await wait(1)
	var defense: BattleSim = main.current.sim
	if defense == null or defense.alive_of("enemy").is_empty():
		push_error("Не удалось начать оборону хутора")
		get_tree().quit(1)
		return
	# Засчитываем одного врага через симуляцию и затем проигрываем волну.
	defense._apply_damage(defense.alive_of("enemy")[0], 9999, "phys", null, {})
	for u in defense.alive_of("hero"):
		defense._apply_damage(u, 9999, "phys", null, {})
	await wait(3)
	var earned_xp := int(defense.s["counters"]["xp"])
	var returned_treasury := int(Game.state["treasury"]) + int(Game.ex()["purse"])
	if earned_xp <= 0 or defense.s["phase"] != "lost":
		push_error("Оборона не завершилась поражением с заработанным опытом")
		get_tree().quit(1)
		return
	# Загружаем бой из сохранения, сделанного на экране поражения.
	main.current.on_quit()
	main.goto("title")
	await wait(3)
	press("Продолжить")
	await wait(3)
	if not press("Вернуться в деревню"):
		push_error("После загрузки не появился экран поражения")
		get_tree().quit(1)
		return
	await wait(3)
	var result: Dictionary = Game.state["last_result"]
	if result["kind"] != "defeat" or not Game.ex().is_empty() or Game.state["treasury"] != returned_treasury:
		push_error("Поражение изменило награды или не завершило поход")
		get_tree().quit(1)
		return
	main.goto("title")
	await wait(3)
	press("Продолжить")
	await wait(3)
	for id in DB.HERO_IDS:
		if int(Game.hero(id)["xp"]) != earned_xp:
			push_error("Опыт за проигранный бой не сохранён: %s, ожидалось %d, получено %d" % [id, earned_xp, Game.hero(id)["xp"]])
			get_tree().quit(1)
			return
	p("defeat result: %s, +%d xp saved for every hero, treasury=%d" % [result["kind"], earned_xp, Game.state["treasury"]])
	p("loaded screen: " + main.current.get_script().resource_path)
	get_tree().quit()
