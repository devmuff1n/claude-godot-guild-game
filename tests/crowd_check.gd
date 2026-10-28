extends "res://tests/balance_test.gd"
## Толпа: сколько врагов ближнего боя одновременно бьют одного героя и на скольких разных героев бросаются.
## godot --headless --path . res://tests/CrowdCheck.tscn

func _ready() -> void:
	Game.slot = -1
	Game.state = Game._fresh_state()
	var c: Dictionary = DB.CONTRACTS["c1"]
	var fails := 0
	for nd in c["route"]:
		if nd["type"] != "battle":
			continue
		var best := 0
		var targets := {}
		for i in 10:
			var cfg := Game.arena_config({"groups": nd["groups"], "ambush": nd.get("ambush", []), "level": c["level"]}, {})
			var sim := BattleSim.new()
			sim.setup(cfg)
			var t := 0.0
			while not sim.is_over() and t < 120.0:
				sim.step(0.05)
				t += 0.05
				var on := {}
				for e in sim.alive_of("enemy"):
					var tg = sim.unit(int(e.get("tgt", -1)))
					if tg == null or not e["melee"]:
						continue
					targets[tg["key"]] = true
					if abs(tg["x"] - e["x"]) - BattleSim.BODY <= e["range"] + 10.0:
						on[tg["uid"]] = on.get(tg["uid"], 0) + 1
				for k in on:
					best = max(best, on[k])
		print("%s: больше всего бьют одного героя разом — %d, цели: %s" % [nd["name"], best, ", ".join(targets.keys())])
		if nd["name"] == "Логово" and best < 3:  # волна — до 3 волков, все бросаются на одного
			fails += 1
	print("FAILS=%d" % fails)
	get_tree().quit()
