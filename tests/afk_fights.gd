extends "res://tests/balance_test.gd"
## Каждый бой поручения отдельно, с полным здоровьем: без команд (AFK) и с ботом.
## CID=c1 N=20 godot --headless --path . res://tests/AfkFights.tscn

func _ready() -> void:
	var cid := OS.get_environment("CID") if OS.get_environment("CID") != "" else "c1"
	var n := int(OS.get_environment("N")) if OS.get_environment("N") != "" else 10
	Game.slot = -1
	Game.state = Game._fresh_state()
	var c: Dictionary = DB.CONTRACTS[cid]
	for nd in c["route"]:
		if nd["type"] != "battle":
			continue
		for mode in ["afk", "bot"]:
			var wins := 0
			var hp := 0.0
			for i in n:
				var cfg := Game.arena_config({"groups": nd["groups"], "ambush": nd.get("ambush", []), "level": c["level"]}, {})
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
			print("%s %s: побед %d из %d, ОЗ после боя %d%%" % [nd["name"], mode, wins, n, int(100 * hp / max(1, wins))])
	get_tree().quit()
