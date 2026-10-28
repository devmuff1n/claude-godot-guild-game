extends "res://tests/balance_test.gd"
## Дипломатия: распределение исходов c8 для разных вложений очков черт (бот берёт лучший шанс) и проверки логики.
## N=500 godot --headless --path . res://tests/DiplomacyCheck.tscn

func _setup(alloc: Dictionary, premium: bool) -> void:
	Game.slot = -1
	Game.state = Game._fresh_state()
	for i in 7:
		Game.state["completed"][DB.STORY_ORDER[i]] = 1
	Game.state["story_stage"] = 7
	if premium:
		Game.state["premium_claimed"]["c7"] = true
	for id in DB.HERO_IDS:
		Game.hero(id)["job"] = DB.MAX_JOB
	Game.hero("aiden")["social"] = alloc.duplicate()

func _quiet_run() -> Dictionary:
	Game.start_diplomacy("c8")
	while true:
		var opts: Array = Game.dip_beat()["options"]
		var best := 0
		var best_p := -1.0
		for i in opts.size():
			if Game.dip_option_problem(opts[i]) != "":
				continue
			var o: Dictionary = opts[i]
			var gain := float(o.get("ok", {}).get("favor", 0))
			var loss := float(o.get("fail", {}).get("favor", 0))
			var p: float = 0.0
			if o.has("check"):
				var ch: float = Game.dip_check_info(o)["chance"]
				p = ch * gain + (1.0 - ch) * loss
			else:
				p = gain if o.get("answer", true) else loss
			if p > best_p:
				best_p = p
				best = i
		Game.dip_choose(best)
		if Game.dip_next():
			break
	var f := int(Game.dip()["favor"])
	return {"favor": f, "res": Game.finish_diplomacy()}

func _ready() -> void:
	var n := int(OS.get_environment("N")) if OS.get_environment("N") != "" else 300
	var builds := {
		"без очков": {},
		"4 в красноречие+харизму": {"elo": 2, "cha": 2},
		"4 в веру+харизму": {"faith": 2, "cha": 2},
		"4 в эрудицию+проницат.": {"lore": 2, "ins": 2},
		"2 крас. + 2 эрудиция": {"elo": 2, "lore": 2},
	}
	for prem in [true, false]:
		for bn in builds.keys():
			var counts := {}
			var fs := 0
			for i in n:
				Game.rng.seed = i * 7919 + 13
				_setup(builds[bn], prem)
				var r := _quiet_run()
				fs += int(r["favor"])
				var oid: String = Game.state["flags"]["c8_outcome"]
				counts[oid] = int(counts.get(oid, 0)) + 1
			print("%-26s книга цела=%s  среднее расположение %.1f  исходы %s" % [bn, prem, float(fs) / n, counts])
	# Логика
	var ok := true
	_setup({"elo": 1}, true)
	print("очки Эйдена: ", Game.social_points("aiden"), " (job ", Game.hero("aiden")["job"], ")")
	ok = ok and Game.social_points("aiden") == DB.MAX_JOB - 1
	ok = ok and Game.add_social("aiden", "elo") == "" and Game.social_value("aiden", "elo") == 4
	Game.start_diplomacy("c8")
	ok = ok and Game.add_social("aiden", "cha") != ""  # в пути нельзя
	var last := Game.dip_choose(0)
	var saved: Dictionary = str_to_var(var_to_str(Game.state))
	Game.state = saved
	ok = ok and Game.dip_choose(1).is_empty()  # повторный выбор после перезагрузки не переигрывается
	ok = ok and Game.dip()["last"]["opt"] == last["opt"]
	while not Game.dip_next():
		Game.dip_choose(0)
	var res := Game.finish_diplomacy()
	ok = ok and res["chapter_end"] and Game.state["chapter_done"] and int(Game.state["story_stage"]) == 8
	ok = ok and Game.state.get("diplomacy") == null and Game.start_diplomacy("c8") != ""
	print("c8 итог: ", res["lines"])
	print("DIPLO CHECK ", "OK" if ok else "FAIL")
	get_tree().quit()
