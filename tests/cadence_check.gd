extends "res://tests/balance_test.gd"
## Ритм главы: бот проходит c1…c7 (перки берёт первые доступные), после каждого поручения печатает, что открылось,
## и прогоняет каждый бой следующего поручения N раз с полным здоровьем: без команд (AFK) и с ботом.
## N=20 godot --headless --path . res://tests/CadenceCheck.tscn

func _pick_perks() -> void:
	for id in DB.HERO_IDS:
		for st in DB.PERK_STAGES.keys():
			if Game.perk_stage_problem(id, st) == "" and Game.hero(id)["perks"].get(st, "") == "" and Game.perk_points(id) > 0:
				Game.choose_perk(id, st, DB.PERKS[id][st][0]["id"])

func _fight_stats(cid: String, n: int) -> void:
	var c: Dictionary = DB.CONTRACTS[cid]
	for nd in c["route"]:
		if nd["type"] != "battle":
			continue
		var line := "    %-14s" % nd["name"]
		for mode in ["afk", "bot"]:
			var wins := 0
			var hp := 0.0
			for i in n:
				Game.state["expedition"] = {"cid": cid, "node": c["route"].find(nd), "route": c["route"], "hero_state": {}, "wagon": {"hp": 500.0, "max": 500.0} if c.get("escort", false) else null,
					"gate": null, "kits": 2, "materials": 0}
				for id in DB.HERO_IDS:
					var d := Game.derived(id)
					Game.state["expedition"]["hero_state"][id] = {"hp": float(d["max_hp"]), "mp": float(d["max_mp"]), "atb": 0.0}
				var cfg := Game.battle_config(nd["groups"], nd.get("ambush", []), nd.get("boss", false), nd.get("chest", false), nd.get("champion", {}))
				cfg["potions"] = {"potion_hp": 2, "potion_mp": 1}
				cfg["hp_pct"] = nd.get("hp_pct", 100)
				cfg["dmg_pct"] = nd.get("dmg_pct", 100)
				var sim := BattleSim.new()
				sim.setup(cfg)
				var t := 0.0
				while not sim.is_over() and t < 300.0:
					sim.step(0.05)
					if mode == "bot": bot(sim)
					t += 0.05
				if sim.s["phase"] == "won":
					wins += 1
					var h := 0.0
					var m := 0.0
					for u in sim.s["units"]:
						if u["side"] == "hero":
							h += max(0.0, u["hp"]); m += u["max_hp"]
					hp += h / m
			line += "  %s %2d/%d (ОЗ %3d%%)" % [mode, wins, n, int(100 * hp / max(1, wins))]
		print(line)
	Game.state["expedition"] = null

func _ready() -> void:
	var n := int(OS.get_environment("N")) if OS.get_environment("N") != "" else 10
	Game.slot = -1
	Game.state = Game._fresh_state()
	for cid in DB.STORY_ORDER:
		Game.state["potions"]["potion_hp"] = max(4, Game.state["potions"]["potion_hp"])
		print("%s «%s»: особое — %s" % [cid, DB.CONTRACTS[cid]["name"], ", ".join(Game.contract_twists(cid).map(func(x): return x["title"])) if Game.has_method("contract_twists") else "-"])
		var snap: Dictionary = Game.state.duplicate(true)
		_fight_stats(cid, n)
		Game.state = snap
		var r := run_contract(cid)
		var tries := 0
		while r["res"]["kind"] != "victory" and tries < 5:
			tries += 1
			r = run_contract(cid)
		var lv := []
		for h in DB.HERO_IDS:
			lv.append("L%d J%d" % [Game.hero(h)["level"], Game.hero(h)["job"]])
		var un: Array = r["res"].get("unlocks", [])
		print("  -> %s (попыток %d), %s; открыто: %s" % [r["res"]["kind"], tries + 1, lv[0], ", ".join(un.map(func(x): return x["title"]))])
		if Game.state["pending_choice"].size() > 0:
			Game.choose_pending(0)
		for h in DB.HERO_IDS:
			for i in Game.storage().size():
				var it = Game.storage()[i]
				if it == null: continue
				var sl := Game.auto_slot(h, it)
				if Game.equip_problem(h, it, sl) == "":
					var cur = Game.hero(h)["equip"][sl]
					if cur == null or Items.price(it) > Items.price(cur):
						Game.equip_from_storage(h, i, sl)
		_pick_perks()
	get_tree().quit()
