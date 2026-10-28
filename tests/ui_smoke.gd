extends Node
## Сквозной прогон интерфейса: деревня → контракт → бои/события/привал → итоги → снаряжение. Нажимает настоящие кнопки.
var main
var log_lines := []
var steps := 0

func p(t: String) -> void:
	print("[UI] ", t)

func find_buttons(root: Node, prefix: String) -> Array:
	var r := []
	if root is Button and root.is_visible_in_tree() and not root.disabled and root.text.begins_with(prefix):
		r.append(root)
	for c in root.get_children():
		r.append_array(find_buttons(c, prefix))
	return r

func press(prefix: String, root: Node = null) -> bool:
	var bs := find_buttons(root if root != null else main, prefix)
	if bs.is_empty():
		return false
	p("press '" + bs[0].text.replace("\n", " / ") + "'")
	bs[0].pressed.emit()
	return true

## Нажать видимую активную кнопку, подсказка которой начинается с prefix (кнопки покупки без названия на самой кнопке)
func press_tip(prefix: String, root: Node = null) -> bool:
	for b in _all_buttons(root if root != null else main):
		if b.tooltip_text.begins_with(prefix):
			p("press tip '" + prefix + "'")
			b.pressed.emit()
			return true
	return false

func _all_buttons(root: Node) -> Array:
	var r := []
	if root is Button and root.is_visible_in_tree() and not root.disabled:
		r.append(root)
	for c in root.get_children():
		r.append_array(_all_buttons(c))
	return r

func wait(n := 2) -> void:
	for i in n:
		await get_tree().process_frame

func _ready() -> void:
	main = get_parent()
	await wait(5)
	Game.slot = 1
	Game.state = Game._fresh_state()
	Game.save()
	main.goto("village")
	await wait(3)
	press("За работу")
	await wait(3)
	for cid in (["c1"] if OS.get_environment("QUICK") != "" else ["c1", "c2", "c3", "s1"]):
		await run_contract(cid)
	p("DONE treasury=%d story=%d" % [Game.state["treasury"], Game.state["story_stage"]])
	# Проверка сохранения/загрузки посреди боя
	await save_load_test()
	get_tree().quit()

func run_contract(cid: String) -> void:
	var v = main.current
	v.show_tab("board")
	await wait(2)
	var board = v.content.get_child(0)
	board.sel = cid
	board.general = DB.CONTRACTS[cid]["general"][0]
	board.pers_hero = "aiden"
	board.pers_obj = "healing"
	board.refresh()
	await wait(2)
	if not press("Выступить"):
		p("cannot depart " + cid)
		return
	await wait(3)
	var guard := 0
	while main.current.get_script().resource_path.ends_with("ExpeditionScreen.gd") and guard < 20000:
		guard += 1
		var es = main.current
		var e := Game.ex()
		if e.is_empty():
			await wait(2)
			continue
		match e["phase"]:
			"prebattle":
				press("В бой")
			"battle":
				es.speed = 25.0
				if es.sim != null:
					bot(es.sim)
				if es.sim != null and es.sim.s["phase"] == "prep":
					press("Следующая волна")
				press("Вернуться в деревню")
			"event":
				if not press("В бой") and not press("Дальше"):
					# первый доступный выбор
					for b in get_tree().get_nodes_in_group("event_choice"):
						if b.is_visible_in_tree() and not b.disabled:
							p("event choice: " + b.get_node("%Text").text)
							b.pressed.emit()
							break
			"camp":
				await camp_flow(es)
			"shop":
				press_tip("Купить: Лечебное зелье")
				await wait(1)
				press("Дальше в путь")
		await wait(1)
	p("contract %s finished; guard=%d" % [cid, guard])
	await wait(3)
	press("Продолжить")
	await wait(2)
	press("В деревню")
	await wait(2)
	var vv = main.current
	vv.show_tab("home")
	await wait(2)
	press("Выбрать")
	await wait(2)
	# Экипировка: всё подходящее и лучшее
	for h in DB.HERO_IDS:
		for i in Game.storage().size():
			var it = Game.storage()[i]
			if it == null: continue
			var sl := Game.auto_slot(h, it)
			if Game.equip_problem(h, it, sl) == "":
				var cur = Game.hero(h)["equip"][sl]
				if cur == null or Items.price(it) > Items.price(cur):
					Game.equip_from_storage(h, i, sl)
		for st in [1, 2]:
			if Game.perk_stage_problem(h, st) == "" and Game.hero(h)["perks"][st] == "":
				p("perk " + h + " " + str(Game.choose_perk(h, st, DB.PERKS[h][st][0]["id"])))
	vv.show_tab("party")
	await wait(3)
	vv.show_tab("shop")
	await wait(2)
	press("Купить")
	await wait(2)
	vv.show_tab("party")
	await wait(2)
	var pv = vv.content.get_child(0)
	pv.sub = "journal"
	pv.refresh()
	await wait(2)

func camp_flow(es) -> void:
	var cp = null
	for c in es.overlay.get_children():
		if c is CampPanel:
			cp = c
	if cp == null:
		return
	for hid in DB.COMPANIONS:
		await wait(1)
		if press(DB.hero_name(hid) + " — «", cp):
			await wait(1)
			var bs := find_buttons(cp.dlg_box, "«")
			p("dialog buttons: %d, dialog=%s" % [bs.size(), str(cp.camp().get("dialog", {}))])
			if bs.size() > 0:
				bs[0].pressed.emit()
			await wait(1)
			p("after choice dialog=%s ok-buttons=%d" % [str(cp.camp().get("dialog", {})).substr(0, 80), find_buttons(cp, "Хорошо").size()])
			press("Хорошо", cp)
	await wait(1)
	if press("У костра", cp):
		await wait(1)
		var bs2 := find_buttons(cp.dlg_box, "")
		if bs2.size() > 0:
			bs2[0].pressed.emit()
		await wait(1)
		press("Хорошо", cp)
	await wait(1)
	if press("Марек", cp.get_node("%EveningHeroes")):
		await wait(1)
		press("Яблоки", cp) or press("Медовый", cp)
		await wait(1)
		press("Хорошо", cp)
	await wait(1)
	press("Журнал отряда", cp)
	await wait(2)
	press("Закрыть", cp)
	await wait(1)
	press("Спать до рассвета", cp)

func bot(sim: BattleSim) -> void:
	for e in sim.alive_of("enemy"):
		if "ranged" in e["tags"] or "raider" in e["tags"]:
			if sim.s["order"] != "advance":
				sim.set_order("advance")
	for u in sim.alive_of("hero"):
		if u["atb"] < 1.0 or sim.hero_busy(u):
			continue
		var en := sim.alive_of("enemy")
		if en.is_empty():
			return
		match u["key"]:
			"aiden":
				var low = null
				for h in sim.alive_of("hero"):
					if h["hp"] < h["max_hp"] * 0.6: low = h
				if low != null: sim.use_ability(u["uid"], "heal", low["uid"])
			"marek":
				sim.use_ability(u["uid"], "taunt", -1)
			"elira":
				sim.use_ability(u["uid"], "aimed", en[0]["uid"])
			"neris":
				sim.use_ability(u["uid"], "curse", en[0]["uid"])
	for k in sim.s["objects"].keys():
		var o: Dictionary = sim.s["objects"][k]
		if o["burning"] > 0.0:
			var el = sim.hero_unit("elira")
			if el != null and el["alive"] and el["task"] == null:
				sim.start_task(el["uid"], "extinguish", k)

func save_load_test() -> void:
	var v = main.current
	v.show_tab("board")
	await wait(2)
	var board = v.content.get_child(0)
	for cid in DB.STORY_ORDER:
		if Game.contract_available(cid) and Game.contract_done_count(cid) == 0:
			board.sel = cid
			break
	p("save test contract " + board.sel)
	board.refresh()
	await wait(1)
	press("Выступить")
	await wait(5)
	for i in 400:
		var e := Game.ex()
		if e.is_empty() or not main.current.get_script().resource_path.ends_with("ExpeditionScreen.gd"):
			await wait(1)
			continue
		if e["phase"] == "prebattle":
			press("В бой")
		if e["phase"] == "battle" and main.current.sim != null and main.current.sim.s["t"] > 4.0:
			break
		main.current.speed = 2.0
		await wait(1)
	var es = main.current
	var t0: float = es.sim.s["t"]
	var n_en: int = es.sim.alive_of("enemy").size()
	var hp0: float = es.sim.hero_unit("marek")["hp"]
	p("before quit slot=%d exp_empty=%s screen=%s" % [Game.slot, Game.ex().is_empty(), es.get_script().resource_path])
	es.on_quit()
	var chk = str_to_var(FileAccess.get_file_as_string(Game.slot_path(1)))
	p("file has expedition: %s" % str(chk.get("expedition") != null))
	main.goto("title")
	await wait(3)
	Game.state = {}
	var ok := Game.load_slot(1)
	p("load ok=%s phase=%s" % [ok, Game.ex()["phase"]])
	main.goto("expedition")
	await wait(3)
	var es2 = main.current
	p("resumed sim t=%.1f (saved %.1f) enemies=%d/%d marek hp %.0f/%.0f paused=%s" % [es2.sim.s["t"], t0, es2.sim.alive_of("enemy").size(), n_en, es2.sim.hero_unit("marek")["hp"], hp0, es2.paused])
	# Прервать поход: опыт откатывается
	var xp_before: int = Game.ex()["xp_start"]["aiden"]
	es2._on_exit_pressed()
	await wait(1)
	press("Прервать поход")
	await wait(3)
	p("abandon: aiden xp=%d start=%d treasury=%d" % [Game.hero("aiden")["xp"], xp_before, Game.state["treasury"]])
	press("Продолжить")
	await wait(2)
