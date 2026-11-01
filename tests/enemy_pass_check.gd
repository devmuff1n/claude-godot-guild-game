extends "res://tests/balance_test.gd"
## Ближний враг за спиной стоящего лучника в той же полосе должен обойти его и дойти до героя.
## godot --headless --path . res://tests/EnemyPassCheck.tscn

func _ready() -> void:
	Game.slot = -1
	Game.state = Game._fresh_state()
	var fails := 0
	for run in 5:
		var cfg := Game.arena_config({"groups": [["archer", "bandit"]], "level": 1}, {})
		var sim := BattleSim.new()
		sim.setup(cfg)
		var archer: Dictionary = {}
		var melee: Dictionary = {}
		for e in sim.alive_of("enemy"):
			if e["key"] == "archer":
				archer = e
			else:
				melee = e
		# Оба целятся в переднего героя и не передумывают: иначе случайный выбор цели
		# уводит лучника дальше ближнего (обходить некого) или ближнего — к дальнему герою (не успевает дойти)
		var front_hero: Dictionary = {}
		for h in sim.alive_of("hero"):
			if front_hero.is_empty() or h["x"] > front_hero["x"]:
				front_hero = h
		# Неубиваемые, без приёмов, в одной полосе; ближний — прямо за лучником
		for e in [archer, melee]:
			e["hp"] = 1e9
			e["max_hp"] = 1e9
			e["skill_cd"] = 1e9
			e["lane"] = 1
			e["pick"] = int(front_hero["uid"])
			e["pick_t"] = 1e9
		melee["x"] = archer["x"] + BattleSim.ENEMY_GAP
		var reached := false
		var passed := false
		var t := 0.0
		while t < 10.0 and not sim.is_over():
			sim.step(0.05)
			t += 0.05
			if melee["x"] < archer["x"]:
				passed = true
			var tg = sim.unit(int(melee.get("tgt", -1)))
			if tg != null and abs(tg["x"] - melee["x"]) - BattleSim.BODY <= melee["range"] + 10.0:
				reached = true
		var ok := passed and reached
		print("run %d: лучник x=%.0f, ближний x=%.0f (полоса %d/%d), обошёл=%s, дошёл до героя=%s — %s" % [
			run, archer["x"], melee["x"], int(archer["lane"]), int(melee["lane"]), passed, reached, "PASS" if ok else "FAIL"])
		if not ok:
			fails += 1
	print("FAILS=%d" % fails)
	get_tree().quit()
