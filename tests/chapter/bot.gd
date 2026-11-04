extends RefCounted
## «Игрок» с усилием effort: раз в `react` секунд (±20%) одна команда на весь отряд, герои по очереди.
## Старый режим (single=false): у каждого героя свой таймер, раз в `react` секунд (±20%),
## со своим сдвигом фазы. Когда приходит очередь героя, бот делает за него одно разумное действие
## (умение или зелье), если у героя есть заряд ATB. react <= 0 — без команд (AFK).

var react := 3.0
var jitter := 0.2
var rng := RandomNumberGenerator.new()
var next_t := {}
var actions := 0
var sim_id := 0
## true — одно действие на весь отряд за интервал (герои по очереди); false — у каждого героя свой таймер
var single := true
var next_any := 0.0
var rr := 0
## true — бот пользуется и умениями, открытыми позже (Base 3/5/7), и спасает повозку/сундук
var adv := true

func _init(r := 3.0, seed_v := 0) -> void:
	react = r
	if seed_v != 0:
		rng.seed = seed_v
	else:
		rng.randomize()

func _reset_for(sim: BattleSim) -> void:
	sim_id = sim.get_instance_id()
	next_t.clear()
	var t: float = sim.s["t"]
	next_any = t + rng.randf_range(0.3, max(0.3, react))
	for id in DB.HERO_IDS:
		# Первый взгляд на героя — в случайный момент первого интервала
		next_t[id] = t + rng.randf_range(0.3, max(0.3, react))

func tick(sim: BattleSim) -> void:
	if react <= 0.0 or sim.s["phase"] != "fight":
		return
	if sim.get_instance_id() != sim_id:
		_reset_for(sim)
	var t: float = sim.s["t"]
	if single:
		if t < next_any:
			return
		next_any = t + react * rng.randf_range(1.0 - jitter, 1.0 + jitter)
		# Игрок смотрит на героев по очереди и отдаёт одну команду первому, кому есть что делать
		var n := DB.HERO_IDS.size()
		for k in n:
			var i := (rr + k) % n
			var hu = sim.hero_unit(DB.HERO_IDS[i])
			if hu != null and hu["alive"] and act(sim, hu):
				actions += 1
				rr = (i + 1) % n
				return
		return
	for id in DB.HERO_IDS:
		if t < float(next_t[id]):
			continue
		next_t[id] = t + react * rng.randf_range(1.0 - jitter, 1.0 + jitter)
		var u = sim.hero_unit(id)
		if u != null and u["alive"] and act(sim, u):
			actions += 1

func _ratio(h: Dictionary) -> float:
	return h["hp"] / max(1.0, h["max_hp"])

func _visible_enemies(sim: BattleSim) -> Array:
	var r := []
	for e in sim.alive_of("enemy"):
		if not sim.in_dark(e):
			r.append(e)
	return r

func _lowest(arr: Array) -> Variant:
	var best = null
	for e in arr:
		if best == null or e["hp"] < best["hp"]:
			best = e
	return best

## Сколько врагов бьют героя h
func _pressure(sim: BattleSim, h: Dictionary) -> int:
	var n := 0
	for e in sim.alive_of("enemy"):
		if int(e.get("tgt", -1)) == int(h["uid"]):
			n += 1
	return n

## Точка, где врагов больше всего в радиусе r
func _cluster(enemies: Array, r: float) -> Variant:
	var best = null
	var bn := 0
	for e in enemies:
		var n := 0
		for o in enemies:
			if absf(float(o["x"]) - float(e["x"])) <= r:
				n += 1
		if n > bn:
			bn = n
			best = e
	return best

func _try(sim: BattleSim, u: Dictionary, ab: String, tgt) -> bool:
	if not Game.ability_unlocked(u["key"], ab):
		return false
	if sim.ability_problem(u["uid"], ab) != "":
		return false
	return sim.use_ability(u["uid"], ab, tgt["uid"] if tgt != null else -1) == ""

## Одно действие за героя u. true — команда отдана.
func act(sim: BattleSim, u: Dictionary) -> bool:
	if u["atb"] < 1.0 or sim.hero_busy(u) or sim.is_stunned(u):
		return false
	var enemies := _visible_enemies(sim)
	if enemies.is_empty():
		return false
	var heroes := sim.alive_of("hero")
	var low = null
	for h in heroes:
		if low == null or _ratio(h) < _ratio(low):
			low = h
	var caster = null
	for e in enemies:
		if e["cast"] != null:
			caster = e
	# Зелье тому, кто вот-вот упадёт (Эйден сначала пробует лечить сам)
	if low != null and _ratio(low) < 0.3:
		if u["key"] == "aiden" and _try(sim, u, "heal", low):
			return true
		if sim.potion_problem(u["uid"], "potion_hp", low["uid"]) == "":
			return sim.use_potion(u["uid"], "potion_hp", low["uid"]) == ""
	var weak = _lowest(enemies)
	if adv and _objects(sim, u):
		return true
	if adv and _advanced(sim, u, enemies, heroes, low, weak):
		return true
	match u["key"]:
		"aiden":
			if low != null and _ratio(low) < 0.6 and _try(sim, u, "heal", low):
				return true
			# Щит тому, на кого давят сильнее всего
			var hot = null
			var hp := 0
			for h in heroes:
				var p := _pressure(sim, h)
				if p > hp and not sim.has_effect(h, "barrier"):
					hp = p
					hot = h
			if hot != null and _try(sim, u, "ward", hot):
				return true
			if low != null and _ratio(low) < 0.85 and _try(sim, u, "heal", low):
				return true
		"marek":
			if caster != null and _try(sim, u, "bash", caster):
				return true
			var others := 0
			for h in heroes:
				if h["key"] != "marek":
					others += _pressure(sim, h)
			if others > 0 and _try(sim, u, "taunt", null):
				return true
			var near = null
			for e in enemies:
				if near == null or sim.dist(u, e) < sim.dist(u, near):
					near = e
			if near != null and sim.dist(u, near) < 140.0 and _try(sim, u, "bash", near):
				return true
		"elira":
			if caster != null and _try(sim, u, "pin", caster):
				return true
			if _try(sim, u, "aimed", weak):
				return true
		"neris":
			var c = _cluster(enemies, 110.0)
			if c != null and _try(sim, u, "curse", c):
				return true
			if _try(sim, u, "bolt", weak):
				return true
	# Мана кончилась — зелье маны себе
	if u["mp"] < 30.0 and sim.potion_problem(u["uid"], "potion_mp", u["uid"]) == "":
		return sim.use_potion(u["uid"], "potion_mp", u["uid"]) == ""
	return false


## Повозка / сундук: тушить пожар, чинить повозку ниже 45%
func _objects(sim: BattleSim, u: Dictionary) -> bool:
	if u["key"] == "aiden":
		return false
	for k in ["chest", "wagon"]:
		if sim.s["objects"].has(k):
			var o: Dictionary = sim.s["objects"][k]
			if o["hp"] > 0.0 and o["burning"] > 0.0 and sim.task_problem(u["uid"], "extinguish", k) == "":
				return sim.start_task(u["uid"], "extinguish", k) == ""
	if sim.s["objects"].has("wagon") and u["key"] in ["marek", "elira"]:
		var w: Dictionary = sim.s["objects"]["wagon"]
		if w["hp"] > 0.0 and w["hp"] < w["max"] * 0.45 and sim.task_problem(u["uid"], "repair", "wagon") == "":
			return sim.start_task(u["uid"], "repair", "wagon") == ""
	return false

func _big(enemies: Array) -> Variant:
	var best = null
	for e in enemies:
		if best == null or e["max_hp"] > best["max_hp"]:
			best = e
	return best

func _count_near(enemies: Array, x: float, r: float) -> int:
	var n := 0
	for o in enemies:
		if absf(float(o["x"]) - x) <= r:
			n += 1
	return n

## Умения, открытые позже: используются, когда ситуация явно подходит
func _advanced(sim: BattleSim, u: Dictionary, enemies: Array, heroes: Array, low, weak) -> bool:
	var big = _big(enemies)
	var tough: bool = big != null and ("boss" in big["tags"] or "champion" in big["tags"] or big["max_hp"] > 2.0 * u["max_hp"])
	match u["key"]:
		"aiden":
			if low != null and _ratio(low) < 0.35 and _try(sim, u, "intercede", low):
				return true
			var hurt := 0
			for h in heroes:
				if _ratio(h) < 0.6:
					hurt += 1
			if hurt >= 2 and _try(sim, u, "prayer", null):
				return true
			if low != null and _ratio(low) < 0.8 and not sim.has_effect(low, "renew") and _try(sim, u, "renew", low):
				return true
		"marek":
			if enemies.size() >= 3 and _try(sim, u, "banner", null):
				return true
			if _pressure(sim, u) >= 2 and _ratio(u) < 0.7 and _try(sim, u, "wall", null):
				return true
			var near = null
			for e in enemies:
				if near == null or sim.dist(u, e) < sim.dist(u, near):
					near = e
			if near != null and sim.dist(u, near) < 140.0 and _count_near(enemies, float(near["x"]), 110.0) >= 2 and _try(sim, u, "cleave", near):
				return true
		"elira":
			if tough and _try(sim, u, "deadeye", big):
				return true
			if tough and not sim.has_effect(big, "mark") and _try(sim, u, "mark", big):
				return true
			var c = _cluster(enemies, 200.0)
			if c != null and _count_near(enemies, float(c["x"]), 200.0) >= 3 and _try(sim, u, "volley", c):
				return true
		"neris":
			if tough and _try(sim, u, "doom", big):
				return true
			var c2 = _cluster(enemies, 180.0)
			if c2 != null and _count_near(enemies, float(c2["x"]), 180.0) >= 3 and _try(sim, u, "hellfire", c2):
				return true
			if _ratio(u) < 0.6 and _try(sim, u, "drain", weak):
				return true
	return false
