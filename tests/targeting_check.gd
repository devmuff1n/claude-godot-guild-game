extends Node
## Наведение в бою: союзные приёмы — по карточке героя, атакующие — только по врагам, попадание по силуэту.
## Запуск: GUILD_START=fight3 godot --path . res://tests/TargetingCheck.tscn
var fails := 0

func ok(c: bool, t: String) -> void:
	print("[TGT] ", "ok   " if c else "FAIL ", t)
	if not c:
		fails += 1

func _ready() -> void:
	var main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	var scr = null
	for i in 600:
		await get_tree().process_frame
		scr = main.current
		if scr != null and scr.get("sim") != null and scr.sim.s["phase"] == "fight" and scr.sim.alive_of("enemy").size() >= 2:
			break
	for i in 90:
		await get_tree().process_frame
	var sim: BattleSim = scr.sim
	var view: BattleView = scr.view
	var aiden = sim.hero_unit("aiden")
	aiden["atb"] = 2.0
	aiden["mp"] = aiden["max_mp"]
	# 1. Союзный приём: карточки подсвечены, клик по карточке применяет
	scr._open_menu("aiden")
	await get_tree().process_frame
	scr._choose_ability("ward")
	ok(view.target_mode == "ally", "ward → режим выбора союзника")
	ok(scr.cards["marek"].target_hint, "карточки подсвечены как цели")
	var mp0: float = aiden["mp"]
	scr._on_card_pressed("marek")
	ok(scr.targeting.is_empty() and view.target_mode == "", "клик по карточке Марека применил приём")
	ok(aiden["mp"] < mp0 or aiden["cast"] != null, "мана потрачена / каст начат")
	ok(not scr.cards["marek"].target_hint, "подсветка карточек снята")
	# 2. Атака: только враги
	scr._open_menu("elira")
	await get_tree().process_frame
	scr._choose_attack()
	ok(view.target_mode == "enemy", "атака → режим выбора врага")
	for h in sim.alive_of("hero"):
		var c: Vector2 = view.unit_rect(h).get_center()
		var got := view.unit_at(c)
		ok(got < 0 or sim.unit(got)["side"] == "enemy", "наведение на героя %s не выбирает союзника" % h["key"])
	ok(not scr.cards["marek"].target_hint, "в режиме атаки карточки не подсвечены")
	# 3. Точность: центр силуэта каждого видимого врага выбирает именно его (если не перекрыт)
	var hit := 0
	var tot := 0
	for e in sim.alive_of("enemy"):
		if sim.in_dark(e):
			continue
		tot += 1
		view.hover_uid = -1
		var c2: Vector2 = view.unit_rect(e).get_center()
		if view.unit_at(c2) == e["uid"]:
			hit += 1
		# верх силуэта (голова) тоже попадает
		var r: Rect2 = view.unit_rect(e)
		view.hover_uid = -1
		var top_hit = view.unit_at(Vector2(r.get_center().x, r.position.y + 12))
		ok(top_hit >= 0, "голова врага %s (полоса %d) кликабельна" % [e["key"], int(e.get("lane", 0))])
		# плашка со здоровьем и именем: края и середина выбирают этого врага
		var br: Rect2 = view.bar_rect(e)
		for px in [br.position.x + 3, br.get_center().x, br.end.x - 3]:
			for py in [br.position.y + 3, br.end.y - 3]:
				view.hover_uid = -1
				ok(view.unit_at(Vector2(px, py)) == e["uid"], "плашка врага %s (%d,%d) выбирает его" % [e["key"], px, py])
	print("[TGT] центров попало: %d/%d" % [hit, tot])
	# 4. Враг прямо за героем: герой просвечивает, клик по герою и по плашке выбирает врага, Tab перебирает всех
	var marek = sim.hero_unit("marek")
	var hid_e = null
	for e in sim.alive_of("enemy"):
		if not sim.in_dark(e):
			hid_e = e
			break
	hid_e["x"] = marek["x"] + 6.0
	hid_e["lane"] = 0
	view._v(hid_e["uid"])["py"] = (0 - (BattleSim.LANES - 1) * 0.5) * BattleView.LANE_PX
	await get_tree().process_frame
	ok(view._heroes_covering_enemies().has(marek["uid"]), "Марек, заслоняющий врага, просвечивает")
	view.hover_uid = -1
	ok(view.unit_at(view.unit_rect(marek).get_center()) == hid_e["uid"], "клик по Мареку выбирает врага за ним")
	view.hover_uid = -1
	ok(view.unit_at(view.bar_rect(hid_e).get_center()) == hid_e["uid"], "клик по плашке врага за Мареком выбирает его")
	var seen := {}
	view.hover_uid = -1
	var n_t := 0
	for e in sim.alive_of("enemy"):
		if view.can_target(e):
			n_t += 1
	for i in n_t:
		seen[view.cycle_target(1)] = true
	ok(seen.size() == n_t and not seen.has(-1), "Tab перебирает всех %d врагов" % n_t)
	view.hover_uid = hid_e["uid"]
	await get_tree().process_frame
	await get_tree().process_frame
	if OS.get_environment("TGT_SHOT") != "":
		get_viewport().get_texture().get_image().save_png(OS.get_environment("TGT_SHOT").replace(".png", "_behind.png"))
	ok(hit >= tot - 1, "центры силуэтов выбирают своих врагов")
	# Картинка: наведение на врага
	var en = sim.alive_of("enemy")[0]
	view.hover_pos = view.unit_rect(en).get_center()
	view.hover_uid = view.unit_at(view.hover_pos)
	await get_tree().process_frame
	await get_tree().process_frame
	var shot := OS.get_environment("TGT_SHOT")
	if shot != "":
		get_viewport().get_texture().get_image().save_png(shot)
	scr._cancel_target()
	# Скриншот выбора союзника
	scr._open_menu("aiden")
	await get_tree().process_frame
	aiden["atb"] = 2.0
	aiden["mp"] = aiden["max_mp"]
	scr._choose_ability("heal")
	scr._on_card_hover("neris", true)
	scr.cards["neris"]._set_hovered(true)
	await get_tree().process_frame
	await get_tree().process_frame
	if shot != "":
		get_viewport().get_texture().get_image().save_png(shot.replace(".png", "_ally.png"))
	print("[TGT] DONE fails=%d" % fails)
	get_tree().quit()
