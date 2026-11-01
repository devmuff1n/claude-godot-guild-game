extends Node
## Проверки боя: герои не стоят друг на друге, умения по области бьют по выбранной точке.
## Запуск: godot --headless --path . res://tests/CombatCheck.tscn

var fails := 0

func check(ok: bool, what: String) -> void:
	print(("OK   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1

func _sim(groups: Array, ambush := []) -> BattleSim:
	var sim := BattleSim.new()
	sim.setup(Game.battle_config(groups, ambush, false, false))
	return sim

## Минимальный зазор между стоящими героями. Пара, где один обходит другого сбоку (passing), не считается:
## там сближение задумано.
func _min_hero_gap(sim: BattleSim) -> float:
	var hs: Array = sim.alive_of("hero").duplicate()
	hs.sort_custom(func(a, b): return a["x"] < b["x"])
	var m := 1e9
	for i in range(1, hs.size()):
		if int(hs[i].get("passing", 0)) != 0 or int(hs[i - 1].get("passing", 0)) != 0:
			continue
		m = min(m, float(hs[i]["x"]) - float(hs[i - 1]["x"]))
	return m

func _ready() -> void:
	Game.slot = -1
	Game.state = Game._fresh_state()
	Game.start_expedition("c1", {"purse": Game.default_purse(), "general": DB.CONTRACTS["c1"]["general"][0], "personal": {"hero": "marek", "obj": "tank"}})
	for h in DB.HERO_IDS:
		Game.hero(h)["level"] = 5
	# 1. Натиск с засадой: все герои бегут к целям, минимальный зазор держится
	var sim := _sim([["bandit", "bandit", "wolf"], ["wolf", "bandit"]], ["wolf", "wolf"])
	sim.set_order("advance")
	var worst := 1e9
	var t := 0.0
	while not sim.is_over() and t < 120.0:
		sim.step(0.05)
		worst = min(worst, _min_hero_gap(sim))
		t += 0.05
	check(worst >= BattleSim.HERO_GAP - 0.5, "зазор между героями ≥ %d (минимум %.1f)" % [BattleSim.HERO_GAP, worst])

	# 2. Град стрел по точке: задеты только враги в области
	sim = _sim([["bandit", "bandit", "bandit", "bandit"]])
	var en := sim.alive_of("enemy")
	var xs := [1000.0, 1100.0, 1400.0, 1500.0]
	for i in en.size():
		en[i]["x"] = xs[i]
		en[i]["speed"] = 0.0
	var el = sim.hero_unit("elira")
	el["atb"] = 2.0
	el["mp"] = el["max_mp"]
	var hp0 := []
	for e in en:
		hp0.append(e["hp"])
	check(sim.use_ability_at(el["uid"], "volley", 1050.0) == "", "град стрел принят по точке")
	check(el["cast"] != null and is_equal_approx(float(el["cast"]["x"]), 1050.0), "подготовка хранит точку удара")
	for i in 40:
		sim.step(0.05)
		if el["cast"] == null:
			break
	var near_hit: bool = en[0]["hp"] < hp0[0] or en[1]["hp"] < hp0[1]
	var far_hit: bool = en[2]["hp"] < hp0[2] or en[3]["hp"] < hp0[3]
	check(near_hit and not far_hit, "область задела ближних и не тронула дальних")

	# 3. Проклятие по области накладывается на всех внутри
	sim = _sim([["bandit", "bandit", "bandit"]])
	en = sim.alive_of("enemy")
	for i in en.size():
		en[i]["x"] = [1000.0, 1080.0, 1400.0][i]
	var ne = sim.hero_unit("neris")
	ne["atb"] = 2.0
	ne["mp"] = ne["max_mp"]
	check(sim.use_ability_at(ne["uid"], "curse", 1040.0) == "", "проклятие принято по точке")
	check(sim.has_effect(en[0], "weak") and sim.has_effect(en[1], "weak") and not sim.has_effect(en[2], "weak"), "проклятие на двоих в области")
	# Старый вызов по цели тоже работает (ИИ, тесты)
	ne["atb"] = 2.0
	ne["cds"] = {}
	check(sim.use_ability(ne["uid"], "curse", en[2]["uid"]) == "" and sim.has_effect(en[2], "weak"), "вызов по цели бьёт в точку цели")

	# 4. Автоатака по выбранной цели: Элира бьёт только её, даже если она дальше других
	sim = _sim([["bandit", "bandit", "bandit"]])
	en = sim.alive_of("enemy")
	for i in en.size():
		en[i]["x"] = [1000.0, 1080.0, 1250.0][i]
		en[i]["speed"] = 0.0
		en[i]["skills"] = []
	el = sim.hero_unit("elira")
	var far: Dictionary = en[2]
	check(sim.set_hero_focus(el["uid"], sim.hero_unit("marek")["uid"]) != "", "цель автоатаки — только враг")
	check(sim.set_hero_focus(el["uid"], far["uid"]) == "", "цель автоатаки принята")
	var shots := 0
	var wrong := 0
	for i in 200:
		sim.events.clear()
		sim.step(0.05)
		for ev in sim.events:
			if ev["type"] == "proj" and ev["from"] == el["uid"]:
				shots += 1
				if ev["to"] != far["uid"]:
					wrong += 1
		if not far["alive"]:
			break
	check(shots > 0 and wrong == 0, "автоатаки Элиры только по цели (выстрелов %d, мимо цели %d)" % [shots, wrong])
	check(not far["alive"] or far["hp"] < far["max_hp"], "выбранная цель получила урон")
	if far["alive"]:
		check(sim.set_hero_focus(el["uid"], far["uid"]) == "" and sim.hero_focus(el) == null, "повторный выбор снимает цель")
	else:
		check(sim.hero_focus(el) == null, "после смерти цели приказ снят")
	print("FAILS=", fails)
	get_tree().quit(1 if fails > 0 else 0)
