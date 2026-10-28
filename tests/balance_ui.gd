extends "res://tests/ui_smoke.gd"
## Меню баланса (F10): правка точки, сохранение в файл, применение в бою, пробный бой, возврат.
## GUILD_UITEST=balance godot --headless --path .   (data/balance.json восстанавливается после теста)

var ok := true

func check(cond: bool, what: String) -> void:
	p(("OK   " if cond else "FAIL ") + what)
	if not cond:
		ok = false

func _ready() -> void:
	main = get_parent()
	await wait(5)
	var backup := FileAccess.get_file_as_string(Balance.PATH)
	Game.slot = -1
	Game.state = Game._fresh_state()
	Game.state["intro_seen"] = true
	main.goto("village")
	await wait(3)
	# F10
	var ev := InputEventKey.new()
	ev.keycode = KEY_F10
	ev.pressed = true
	Input.parse_input_event(ev)
	await wait(3)
	var ed: BalanceEditor = null
	for c in main.get_children():
		if c is BalanceEditor:
			ed = c
	check(ed != null, "F10 открывает меню")
	check(get_tree().paused, "игра на паузе, пока меню открыто")
	# c1 → Опушка
	ed.focus({"cid": "c1", "point": 0})
	await wait(2)
	var n0: int = DB.CONTRACTS["c1"]["route"][0]["groups"][0].size()
	press("+ враг", ed)
	await wait(2)
	check(DB.CONTRACTS["c1"]["route"][0]["groups"][0].size() == n0 + 1, "«+ враг» добавляет врага в первую группу (сразу в игре)")
	# уровень первого врага +1 (через кнопку «+» степпера)
	var row: Control = ed.rows[0]["row"]
	row.get_node("%Level").get_node("%Plus").pressed.emit()
	await wait(1)
	check(Balance.elevel(DB.CONTRACTS["c1"]["route"][0]["groups"][0][0], 1) == 2, "уровень врага 1 → 2")
	# тип второго врага → громила
	var opt: OptionButton = ed.rows[1]["row"].get_node("%Type")
	opt.select(ed.type_ids.find("brute"))
	opt.item_selected.emit(ed.type_ids.find("brute"))
	await wait(1)
	check(Balance.etype(DB.CONTRACTS["c1"]["route"][0]["groups"][0][1]) == "brute", "тип врага меняется на громилу")
	ed.get_node("%HpPct").get_node("%Plus").pressed.emit()
	await wait(1)
	check(int(DB.CONTRACTS["c1"]["route"][0].get("hp_pct", 100)) == 105, "ОЗ точки 100% → 105%")
	press("Сохранить", ed)
	await wait(2)
	var saved = JSON.parse_string(FileAccess.get_file_as_string(Balance.PATH))
	var sp: Dictionary = saved["contracts"]["c1"]["points"][0]
	check(sp["groups"][0].size() == n0 + 1 and int(sp["groups"][0][0][1]) == 2 and sp["groups"][0][1][0] == "brute" and int(sp["hp_pct"]) == 105, "файл data/balance.json записан")
	# Бой в походе берёт новые данные
	var sim := BattleSim.new()
	var cfg := Game.arena_config({"groups": DB.CONTRACTS["c1"]["route"][0]["groups"], "level": 1}, {})
	cfg["hp_pct"] = 105
	sim.setup(cfg)
	var en := sim.alive_of("enemy")
	# Бой идёт волнами: сначала на поле только первая группа
	check(en.size() == n0 + 1, "в первой волне %d врагов" % en.size())
	check(sim.wave_info() == Vector2i(1, DB.CONTRACTS["c1"]["route"][0]["groups"].size()), "волны: %s" % sim.wave_info())
	check(int(en[0]["level"]) == 2 and int(en[1]["level"]) == 1, "у врагов свои уровни в бою (2 и 1)")
	var base := DB.enemy_stats("wolf", 2)
	check(is_equal_approx(en[0]["max_hp"], round(base["hp"] * 1.05)), "ОЗ ×105%% применяется (%d)" % en[0]["max_hp"])
	# Пробный бой
	press("▶ Сыграть", ed)
	await wait(5)
	check(main.current.get("arena") == true and main.current.sim != null, "«Сыграть этот бой» запускает бой")
	check(main.current.sim.alive_of("enemy").size() == n0 + 1, "в пробном бою тот же состав первой волны")
	check(not get_tree().paused, "пауза снята")
	main.current._leave_arena()
	await wait(4)
	var back: BalanceEditor = null
	for c in main.get_children():
		if c is BalanceEditor:
			back = c
	check(back != null and back.cid == "c1" and back.point == 0, "после боя меню открывается на той же точке")
	# Отменить правки → файл; Исходные → значения из кода
	press("Исходные значения", back)
	await wait(2)
	check(DB.CONTRACTS["c1"]["route"][0]["groups"][0].size() == n0, "«Исходные значения» возвращают состав из кода")
	press("Отменить правки", back)
	await wait(2)
	check(DB.CONTRACTS["c1"]["route"][0]["groups"][0].size() == n0 + 1, "«Отменить правки» возвращает то, что в файле")
	back.close()
	await wait(2)
	check(not get_tree().paused, "меню закрыто, пауза снята")
	# восстановить файл
	var f := FileAccess.open(Balance.PATH, FileAccess.WRITE)
	f.store_string(backup)
	f.close()
	p("RESULT " + ("PASS" if ok else "FAIL"))
	get_tree().quit()
