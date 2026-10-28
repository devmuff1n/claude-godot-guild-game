extends Node
## Прогон автобоя ботом для проверки баланса и логики (запуск: godot --headless res://tests/Test.tscn)

func bot(sim: BattleSim) -> void:
	var want := "hold"
	for e in sim.alive_of("enemy"):
		if "ranged" in e["tags"] or "raider" in e["tags"]:
			want = "advance"
			if sim.s["focus"] < 0 or sim.unit(sim.s["focus"]) == null or not sim.unit(sim.s["focus"])["alive"]:
				sim.s["focus"] = e["uid"]
	if sim.s["order"] != want:
		sim.set_order(want)
	for u in sim.alive_of("hero"):
		if u["atb"] >= 1.0 and not sim.hero_busy(u):
			for h in sim.alive_of("hero"):
				if h["hp"] < h["max_hp"] * 0.3 and sim.potion_problem(u["uid"], "potion_hp", h["uid"]) == "":
					sim.use_potion(u["uid"], "potion_hp", h["uid"])
					break
	for u in sim.alive_of("hero"):
		if u["atb"] < 1.0 or sim.hero_busy(u):
			continue
		var enemies := sim.alive_of("enemy")
		if enemies.is_empty():
			return
		var caster = null
		for e in enemies:
			if e["cast"] != null:
				caster = e
		var tgt = enemies[0]
		match u["key"]:
			"aiden":
				var low = null
				var lr := 0.65
				for h in sim.alive_of("hero"):
					if h["hp"] / h["max_hp"] < lr:
						lr = h["hp"] / h["max_hp"]; low = h
				if low != null:
					sim.use_ability(u["uid"], "heal", low["uid"])
				else:
					var m = sim.hero_unit("marek")
					if m != null and m["alive"] and not sim.has_effect(m, "barrier"):
						sim.use_ability(u["uid"], "ward", m["uid"])
			"marek":
				if caster != null and sim.ability_problem(u["uid"], "bash") == "":
					sim.use_ability(u["uid"], "bash", caster["uid"])
				elif sim.ability_problem(u["uid"], "taunt") == "":
					sim.use_ability(u["uid"], "taunt", -1)
			"elira":
				if caster != null and sim.ability_problem(u["uid"], "pin") == "":
					sim.use_ability(u["uid"], "pin", caster["uid"])
				else:
					sim.use_ability(u["uid"], "aimed", tgt["uid"])
			"neris":
				if sim.ability_problem(u["uid"], "curse") == "":
					sim.use_ability(u["uid"], "curse", tgt["uid"])
				else:
					sim.use_ability(u["uid"], "bolt", tgt["uid"])

## Дипломатическая миссия: бот выбирает вариант с лучшим шансом (ответы без броска — если они верные).
func run_diplomacy(cid: String) -> Dictionary:
	var err := Game.start_diplomacy(cid)
	if err != "":
		print("ERR ", err)
		return {"res": {"kind": "error"}, "t": 0}
	while true:
		var opts: Array = Game.dip_beat()["options"]
		var best := 0
		var best_p := -1.0
		for i in opts.size():
			if Game.dip_option_problem(opts[i]) != "":
				continue
			var p: float = Game.dip_check_info(opts[i])["chance"] if opts[i].has("check") else (0.9 if opts[i].get("answer", true) and int(opts[i].get("ok", {}).get("favor", 0)) > 0 else 0.0)
			if p > best_p:
				best_p = p
				best = i
		var last := Game.dip_choose(best)
		print("  %s: %s — %s (расположение %d)" % [Game.dip_beat()["who"].get_slice(",", 0), last["text"].left(40), "успех" if last["ok"] else "провал", int(Game.dip()["favor"])])
		if Game.dip_next():
			break
	return {"res": Game.finish_diplomacy(), "t": 0}

func run_contract(cid: String, use_bot := true) -> Dictionary:
	if DB.CONTRACTS[cid].has("diplomacy"):
		return run_diplomacy(cid)
	var opts := {"purse": Game.default_purse(), "general": DB.CONTRACTS[cid]["general"][0], "personal": {"hero": "marek", "obj": "tank"}}
	var err := Game.start_expedition(cid, opts)
	if err != "":
		print("ERR ", err)
		return {"res": {"kind": "error"}, "t": 0}
	var total_t := 0.0
	var outcome := "victory"
	while not Game.route_finished():
		var n := Game.current_node()
		match n["type"]:
			"battle", "outpost":
				var sim := BattleSim.new()
				var bcfg := Game.battle_config(n.get("groups", []), n.get("ambush", []), n.get("boss", false), n.get("chest", false), n.get("champion", {}))
				bcfg["hp_pct"] = int(n.get("hp_pct", 100))
				bcfg["dmg_pct"] = int(n.get("dmg_pct", 100))
				sim.setup(bcfg)
				var t := 0.0
				var low := 1.0
				while not sim.is_over() and t < 600.0:
					if sim.s["phase"] == "prep":
						sim.start_next_wave()
					sim.step(0.05)
					if use_bot: bot(sim)
					t += 0.05
					var hs := 0.0
					var hm := 0.0
					for u in sim.s["units"]:
						if u["side"] == "hero":
							hs += max(0.0, u["hp"]); hm += u["max_hp"]
					low = min(low, hs / max(1.0, hm))
					# проверка сериализации посреди боя
					if int(t * 20) % 400 == 0:
						var st = str_to_var(var_to_str(sim.save_state()))
						sim.load_state(st)
				total_t += t
				var hp := []
				for u in sim.alive_of("hero"):
					hp.append("%s:%d/%d" % [u["key"], u["hp"], u["max_hp"]])
				var en := 0
				for u in sim.s["units"]:
					if u["side"] == "enemy": en += 1
				print("  %s %s за %.0fс, врагов %d, мин. HP отряда %d%%, зелий %d; живы: %s %s" % [n["name"], sim.s["phase"], t, en, int(low * 100), sim.s["counters"]["potions"], hp, sim.s.get("loss", "")])
				if sim.s["phase"] != "won":
					outcome = "defeat"
					break
				Game.absorb_battle(sim)
				Game.complete_node()
			"event":
				var ev: Dictionary = DB.EVENTS[n["event"]]
				var g := Game.apply_event_choice(ev["choices"][0])
				Game.complete_node()
			"camp":
				Game.camp_rest()
			_:
				Game.complete_node()
	var res := Game.finish_expedition(outcome)
	return {"res": res, "t": total_t}

func _ready() -> void:
	Game.slot = -1
	Game.state = Game._fresh_state()
	for cid in (OS.get_environment("CIDS").split(",") if OS.get_environment("CIDS") != "" else DB.STORY_ORDER + ["s1"]):
		Game.state["potions"]["potion_hp"] = max(4, Game.state["potions"]["potion_hp"])
		var afk := OS.get_environment("AFK") != ""
		if afk:
			# Пассивный прогон: герои без команд. Состояние откатывается, чтобы не влиять на основной прогон.
			var snap: Dictionary = Game.state.duplicate(true)
			var ra := run_contract(cid, false)
			print(cid, " AFK -> ", ra["res"]["kind"])
			Game.state = snap
		var r := run_contract(cid)
		var tries := 0
		while r["res"]["kind"] == "defeat" and tries < 3:
			tries += 1
			print("   retry")
			r = run_contract(cid)
		var lv := []
		for h in DB.HERO_IDS:
			lv.append("%s L%d J%d" % [h, Game.hero(h)["level"], Game.hero(h)["job"]])
		print(cid, " -> ", r["res"]["kind"], " t=", int(r["t"]), " treasury=", Game.state["treasury"], " ", lv)
		if r["res"]["kind"] != "victory" and false:
			# повтор
			r = run_contract(cid)
			print("   retry -> ", r["res"]["kind"])
		if Game.state["pending_choice"].size() > 0:
			Game.choose_pending(0)
		# Автоэкипировка лучших вещей
		for h in DB.HERO_IDS:
			for i in Game.storage().size():
				var it = Game.storage()[i]
				if it == null: continue
				var sl := Game.auto_slot(h, it)
				if Game.equip_problem(h, it, sl) == "":
					var cur = Game.hero(h)["equip"][sl]
					if cur == null or Items.price(it) > Items.price(cur):
						Game.equip_from_storage(h, i, sl)
	print("DONE story=", Game.state["story_stage"], " chapter=", Game.state["chapter_done"])
	get_tree().quit()
