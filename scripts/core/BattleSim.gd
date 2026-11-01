class_name BattleSim
extends RefCounted
## Симуляция тактического автобоя. Всё состояние — в словаре `s` (сериализуемо),
## визуальные события копятся в `events` и не сохраняются.

const FORMATION_X := [900.0, 790.0, 680.0, 570.0]
const WAGON_X := 300.0
const GATE_X := 215.0
const CHEST_X := 330.0
const SPAWN_X := 1660.0
const AMBUSH_X := 40.0
const ATB_PER_SEC := 0.2
const WAVE_PAUSE := 2.0  # секунды передышки между волнами боя на дороге
const OBJ_NAMES := {"wagon": "Повозка", "gate": "Ворота", "chest": "Сундук с книгой"}

var s: Dictionary = {}
var events: Array = []
var rng := RandomNumberGenerator.new()

# ================================================================ Настройка
## cfg: heroes [{id, d (derive), hp, mp, atb, perks, level}], formation [id front→back], groups, ambush, level,
## mode, wagon {hp,max}, gate {hp,max}, chest bool, waves, kits, materials, potions {potion_hp, potion_mp}, night
func setup(cfg: Dictionary) -> void:
	rng.randomize()
	s = {
		"t": 0.0, "phase": "fight", "units": [], "next_uid": 1, "focus": -1, "order": "hold",
		"objects": {}, "pending": [], "level": int(cfg.get("level", 1)), "mode": cfg.get("mode", "route"),
		"wave": 0, "waves": cfg.get("waves", []), "kits": int(cfg.get("kits", 0)), "materials": int(cfg.get("materials", 0)),
		"potions": cfg.get("potions", {"potion_hp": 0, "potion_mp": 0}).duplicate(),
		"formation": cfg.get("formation", DB.HERO_IDS).duplicate(), "night": cfg.get("night", false),
		"outpost_amb": cfg.get("outpost_ambush", ["wolf"]).duplicate(), "shade_k": float(cfg.get("shade_k", 1.0)),
		"log": [], "loss": "", "boss": cfg.get("boss", false), "boss_time": 0.0, "boss_alive": false,
		"counters": {"potions": 0, "ko": {}, "dmg_taken": {}, "healing": 0, "wards": 0, "taunts": 0, "kills": {},
			"interrupts": 0, "curses": 0, "spell_dmg": 0, "xp": 0, "coins": 0, "heal_by": {}, "champions": 0, "by_hero": {}},
		"used": {},
		"rng_seed": 0, "rng_state": 0,
		"hp_mult": float(cfg.get("hp_pct", 100)) / 100.0, "dmg_mult": float(cfg.get("dmg_pct", 100)) / 100.0,
	}
	s["rng_seed"] = rng.seed
	for hc in cfg.get("heroes", []):
		_add_hero(hc)
	if cfg.get("wagon") != null:
		s["objects"]["wagon"] = {"x": WAGON_X, "hp": float(cfg["wagon"]["hp"]), "max": float(cfg["wagon"]["max"]), "burning": 0.0}
	if cfg.get("gate") != null:
		s["objects"]["gate"] = {"x": GATE_X, "hp": float(cfg["gate"]["hp"]), "max": float(cfg["gate"]["max"]), "burning": 0.0}
	if cfg.get("chest", false):
		s["objects"]["chest"] = {"x": CHEST_X, "hp": 300.0, "max": 300.0, "burning": 0.0}
	if s["mode"] == "outpost":
		s["phase"] = "prep"
		s["wave"] = 0
	else:
		# Бой на дороге идёт волнами: одна группа из groups — одна волна. Следующая выходит,
		# когда предыдущая перебита (см. _tick_waves). Чемпион приходит с последней волной,
		# засада бьёт в спину во время волны ambush_wave (по умолчанию — второй).
		var groups: Array = []
		for g in cfg.get("groups", []):
			if not g.is_empty():
				groups.append(g)
		var amb: Array = cfg.get("ambush", [])
		s["rwaves"] = groups
		s["rwave"] = 0
		s["rwave_t"] = -1.0
		s["champ"] = cfg.get("champion", {})
		s["amb"] = amb
		s["amb_wave"] = clampi(int(cfg.get("ambush_wave", 2)) - 1, 0, max(0, groups.size() - 1)) if amb.size() > 0 else -1
		_spawn_route_wave()
	_log("Бой начался!" if s["phase"] == "fight" else "Подготовка к обороне.")

func save_state() -> Dictionary:
	s["rng_state"] = rng.state
	return s.duplicate(true)

func load_state(st: Dictionary) -> void:
	s = st.duplicate(true)
	if not s.has("used"):
		s["used"] = {}
	rng.seed = int(s.get("rng_seed", 0))
	rng.state = int(s.get("rng_state", 0))
	# Бой, сохранённый до ступеней врагов: достраиваем приёмы по типу и уровню
	for u in s["units"]:
		if u["side"] != "enemy" or u.has("pas"):
			continue
		var t: String = u["key"]
		var lvl := int(u.get("level", 1))
		var sks: Array = DB.enemy_skills(t, lvl) if DB.ENEMIES.has(t) else []
		var pas := {}
		for sk in sks:
			if sk.get("passive", false):
				pas[sk["id"]] = true
		u["skills"] = sks
		u["pas"] = pas
		u.erase("skill")
		u["tier"] = DB.enemy_tier(lvl)
		if not u.has("hits"):
			u["hits"] = 0
		if not u.has("cds"):
			u["cds"] = {}

func _uid() -> int:
	var u: int = s["next_uid"]
	s["next_uid"] = u + 1
	return u

func _add_hero(hc: Dictionary) -> void:
	var d: Dictionary = hc["d"]
	var id: String = hc["id"]
	var slot: int = s["formation"].find(id)
	var u := {
		"uid": _uid(), "side": "hero", "key": id, "name": DB.hero_name(id), "look": id,
		"x": float(hc.get("x", FORMATION_X[clamp(slot, 0, 3)])), "hp": float(hc["hp"]), "max_hp": float(d["max_hp"]),
		"mp": float(hc["mp"]), "max_mp": float(d["max_mp"]), "mp_regen": 0.6 + d["max_mp"] * 0.005,
		"atb": float(hc.get("atb", 0.0)), "alive": float(hc["hp"]) > 0.0, "atk_t": rng.randf_range(0.2, 1.0),
		"interval": float(d["interval"]), "range": float(d["range"]), "dmg_min": float(d["dmg_min"]), "dmg_max": float(d["dmg_max"]),
		"school": d["school"], "armor": float(d["armor"]), "crit": float(d["crit"]), "hit": float(d["hit"]),
		"dodge": float(d["dodge"]), "parry": float(d["parry"]), "block": float(d["block"]), "block_val": float(d["block_val"]),
		"res": {"fire": d["res_fire"], "shadow": d["res_shadow"], "nature": d["res_nature"], "holy": d["res_holy"]},
		"sp": float(d["sp"]), "level": int(hc.get("level", 1)), "melee": d["melee"], "speed": 140.0,
		"effects": [], "cast": null, "cds": {}, "task": null, "queued": null, "tags": [], "focus": -1,
		"perks": hc.get("perks", {}), "slot": slot, "riposte_cd": 0.0, "facing": 1, "anim": 0.0, "hurt": 0.0,
	}
	if not u["alive"]:
		u["hp"] = 0.0
	if u["alive"] and perk(u, "firstblood"):
		u["atb"] = min(2.0, u["atb"] + 1.0)
		u["first_free"] = true
	s["units"].append(u)

## Чемпион: именной враг со свойством (DB.CHAMPION_AFFIXES). Сильнее обычного, за победу — лишняя вещь.
func _spawn_champion(ch: Dictionary, x: float) -> void:
	_spawn_group([ch["type"]], x, false)
	var u: Dictionary = s["units"][s["units"].size() - 1]
	var af: String = ch.get("affix", "stone")
	var k: Dictionary = DB.CHAMPION
	u["name"] = ch.get("name", u["name"])
	u["champion"] = af
	u["tags"].append("champion")
	u["max_hp"] = round(u["max_hp"] * float(k["hp"]))
	u["dmg_min"] = round(u["dmg_min"] * float(k["dmg"]))
	u["dmg_max"] = round(u["dmg_max"] * float(k["dmg"]))
	u["xp"] = int(u["xp"]) * int(k["xp"])
	u["coins"] = int(u["coins"]) * int(k["coins"])
	match af:
		"stone":
			u["max_hp"] = round(u["max_hp"] * 1.6)
			u["armor"] = u["armor"] * 2.0
		"swift":
			u["interval"] = u["interval"] / 1.5
			u["speed"] = u["speed"] * 1.5
	u["hp"] = u["max_hp"]
	_log("Чемпион: %s — %s!" % [u["name"], DB.CHAMPION_AFFIXES[af]["name"].to_lower()])

func _spawn_group(types: Array, x0: float, left: bool) -> void:
	var hp_k: float = s.get("hp_mult", 1.0)
	var dmg_k: float = s.get("dmg_mult", 1.0)
	var i := 0
	for entry in types:
		# Враг: "wolf" (уровень поручения) или ["wolf", 3] — свой уровень (см. Balance.gd)
		var t := Balance.etype(entry)
		var lvl := Balance.elevel(entry, s["level"])
		var e: Dictionary = DB.ENEMIES[t]
		var es := DB.enemy_stats(t, lvl)
		es["hp"] = max(1.0, round(es["hp"] * hp_k))
		if "phantom" in e["tags"] and not e.has("fixed_x"):
			es["hp"] = max(1.0, round(es["hp"] * float(s.get("shade_k", 1.0))))
		es["dmg_min"] = round(es["dmg_min"] * dmg_k)
		es["dmg_max"] = round(es["dmg_max"] * dmg_k)
		var x := x0 + i * 70.0 if not left else x0 - i * 45.0
		var sks := DB.enemy_skills(t, lvl)
		var pas := {}
		for sk in sks:
			if sk.get("passive", false):
				pas[sk["id"]] = true
		var u := {
			"uid": _uid(), "side": "enemy", "key": t, "name": DB.enemy_name(t, lvl), "look": e["look"], "tier": DB.enemy_tier(lvl),
			"x": x, "hp": es["hp"], "max_hp": es["hp"], "mp": 0.0, "max_mp": 0.0, "mp_regen": 0.0, "atb": 0.0,
			"alive": true, "atk_t": rng.randf_range(0.3, 1.2), "interval": float(e["interval"]), "range": float(e["range"]),
			"dmg_min": es["dmg_min"], "dmg_max": es["dmg_max"], "school": e.get("school", "phys"),
			"armor": es["armor"], "crit": 5.0, "hit": 95.0, "dodge": float(e.get("dodge", 3)),
			"parry": float(e.get("parry", 0)), "block": 0.0, "block_val": 0.0, "res": {"fire": 0.0, "shadow": 0.0, "nature": 0.0, "holy": 0.0},
			"sp": es["sp"], "level": lvl, "wlvl": es["wlvl"], "melee": e["range"] < 120, "speed": float(e["speed"]),
			"effects": [], "cast": null, "cds": {}, "task": null, "queued": null, "tags": e["tags"].duplicate(),
			"perks": {}, "slot": -1, "riposte_cd": 0.0, "facing": -1, "anim": 0.0, "hurt": 0.0,
			"xp": int(e["xp"] * (1.0 + 0.15 * (lvl - 1))), "coins": int(e["coins"] * (1.0 + 0.1 * (lvl - 1))),
			"skills": sks, "pas": pas, "skill_cd": rng.randf_range(3.0, 6.0), "ambusher": left, "last_hit": "", "hits": 0,
			"lane": rng.randi_range(0, LANES - 1), "pick": -1, "pick_t": 0.0,
		}
		if left:
			u["speed"] = max(u["speed"], 220.0)
			u["facing"] = 1
		# Неподвижный враг (обелиск пещеры): стоит на своём месте поля, никуда не идёт
		if e.has("fixed_x"):
			u["x"] = float(e["fixed_x"])
			u["anchor_x"] = u["x"]
			u["lane"] = 0
			u["summon"] = e.get("summon", "shade_wolf")
		# Рысь подкрадывается невидимой и бросается на задний ряд
		if pas.has("stalk"):
			u["effects"].append({"id": "hidden"})
			u["ambusher"] = true
		if "boss" in u["tags"]:
			s["boss_alive"] = true
		s["units"].append(u)
		events.append({"type": "spawn", "uid": u["uid"]})
		i += 1

func start_next_wave() -> void:
	if s["phase"] != "prep":
		return
	var waves: Array = s["waves"]
	if s["wave"] >= waves.size():
		return
	var wd = waves[s["wave"]]
	if wd is Dictionary:
		s["hp_mult"] = float(wd.get("hp_pct", 100)) / 100.0
		s["dmg_mult"] = float(wd.get("dmg_pct", 100)) / 100.0
	s["wave"] += 1
	var i := 0
	for g in Balance.wave_groups(wd):
		_spawn_group(g, SPAWN_X + i * 260.0, false)
		i += 1
	# Чемпион волны (поле champion у волны-словаря) выходит следом за её группами
	if wd is Dictionary and DB.ENEMIES.has(wd.get("champion", {}).get("type", "")):
		_spawn_champion(wd["champion"], SPAWN_X + i * 260.0)
	if s["wave"] >= 2:
		s["pending"].append({"t": s["t"] + rng.randf_range(5.0, 8.0), "types": s.get("outpost_amb", ["wolf"]).duplicate(), "left": true, "warned": false})
	s["phase"] = "fight"
	_log("Волна %d из %d!" % [s["wave"], waves.size()])

## Волны боя на дороге: сколько всего и какая идёт (1..N). Для заставы — свои волны (s["wave"]).
func wave_info() -> Vector2i:
	if s["mode"] == "outpost":
		return Vector2i(int(s["wave"]), s["waves"].size())
	return Vector2i(int(s.get("rwave", 0)), s.get("rwaves", []).size())

func _spawn_route_wave() -> void:
	var waves: Array = s.get("rwaves", [])
	var wi: int = s["rwave"]
	if wi >= waves.size():
		return
	s["rwave"] = wi + 1
	s["rwave_t"] = -1.0
	_spawn_group(waves[wi], SPAWN_X, false)
	var ch: Dictionary = s.get("champ", {})
	if wi == waves.size() - 1 and not ch.is_empty() and DB.ENEMIES.has(ch.get("type", "")):
		_spawn_champion(ch, SPAWN_X + waves[wi].size() * 70.0 + 70.0)
	if wi == int(s.get("amb_wave", -1)):
		s["pending"].append({"t": s["t"] + rng.randf_range(4.0, 7.0), "types": s["amb"], "left": true, "warned": false})
	if waves.size() > 1:
		_log("Волна %d из %d!" % [wi + 1, waves.size()])
		events.append({"type": "wave", "n": wi + 1, "of": waves.size()})

## Следующая волна выходит после короткой передышки, когда текущая перебита.
func _tick_waves(dt: float) -> void:
	if s["mode"] == "outpost" or int(s.get("rwave", 0)) >= s.get("rwaves", []).size():
		return
	if not alive_of("enemy").is_empty() or not s["pending"].is_empty():
		return
	if s["rwave_t"] < 0.0:
		s["rwave_t"] = WAVE_PAUSE
		_log("Волна отбита. Идут ещё!")
	s["rwave_t"] -= dt
	if s["rwave_t"] <= 0.0:
		_spawn_route_wave()

# ================================================================ Запросы
func units() -> Array:
	return s["units"]

func unit(uid: int) -> Variant:
	for u in s["units"]:
		if u["uid"] == uid:
			return u
	return null

func hero_unit(id: String) -> Variant:
	for u in s["units"]:
		if u["side"] == "hero" and u["key"] == id:
			return u
	return null

func alive_of(side: String) -> Array:
	var r := []
	for u in s["units"]:
		if u["side"] == side and u["alive"]:
			r.append(u)
	return r

func has_effect(u: Dictionary, id: String) -> bool:
	for e in u["effects"]:
		if e["id"] == id:
			return true
	return false

func get_effect(u: Dictionary, id: String) -> Variant:
	for e in u["effects"]:
		if e["id"] == id:
			return e
	return null

func add_effect(u: Dictionary, eff: Dictionary) -> void:
	# Обновляем существующий эффект того же типа
	for i in u["effects"].size():
		if u["effects"][i]["id"] == eff["id"]:
			u["effects"][i] = eff
			return
	u["effects"].append(eff)

func remove_effect(u: Dictionary, id: String) -> void:
	for i in range(u["effects"].size() - 1, -1, -1):
		if u["effects"][i]["id"] == id:
			u["effects"].remove_at(i)

func is_stunned(u: Dictionary) -> bool:
	return has_effect(u, "stun")

func slow_factor(u: Dictionary) -> float:
	var f := 1.0
	var e = get_effect(u, "slow")
	if e != null:
		f *= 1.0 - float(e["val"])
	var hs = get_effect(u, "haste")
	if hs != null:
		f *= 1.0 + float(hs["val"])
	return f

func perk(u: Dictionary, id: String) -> bool:
	for k in u["perks"].keys():
		if u["perks"][k] == id:
			return true
	return false

const BODY := 48.0
## Минимальный зазор между врагами с одной стороны от героев — чтобы толпа не сливалась в одну фигуру.
const ENEMY_GAP := 80.0
## Дальность прицельных умений стрелков и магов: с места достают почти до любого врага на поле.
const RANGED_SKILL_REACH := 1000.0
## Минимальное расстояние между центрами героев — фигурки не наезжают друг на друга.
const HERO_GAP := 80.0
## Полос глубины на дороге: столько врагов ближнего боя может одновременно бить одного героя с одной стороны.
const LANES := 4
## Как часто враг заново выбирает, на кого броситься (секунды, от и до).
const REPICK_MIN := 3.5
const REPICK_MAX := 7.0

## Расстояние между краями фигур (а не центрами)
func dist(a: Dictionary, b: Dictionary) -> float:
	return max(0.0, abs(float(a["x"]) - float(b["x"])) - BODY)

## Ночь: враг дальше NIGHT_SIGHT от всех героев скрыт во тьме — по нему нельзя бить прицельно.
const NIGHT_SIGHT := 360.0

func in_dark(e: Dictionary) -> bool:
	if e["side"] == "enemy" and has_effect(e, "hidden"):
		return true
	if not s.get("night", false) or e["side"] != "enemy":
		return false
	for h in alive_of("hero"):
		if dist(h, e) <= NIGHT_SIGHT:
			return false
	return true

func hero_busy(u: Dictionary) -> bool:
	return u["cast"] != null or u["task"] != null

func _log(t: String) -> void:
	s["log"].append(t)
	if s["log"].size() > 7:
		s["log"].pop_front()
	events.append({"type": "msg", "text": t})

func _float(u, text: String, col: Color, big := false) -> void:
	if u is Dictionary:
		events.append({"type": "float", "uid": u["uid"], "text": text, "color": col, "big": big})

func _float_obj(obj: String, text: String, col: Color) -> void:
	events.append({"type": "float_obj", "obj": obj, "text": text, "color": col})

# ================================================================ Шаг симуляции
func step(dt: float) -> void:
	for h in s["units"]:
		if h["alive"]:
			h["prev_goal"] = float(h.get("goal_x", h["x"]))
			h["goal_x"] = h["x"]
	if s["phase"] == "prep":
		# Передышка между волнами: герои спокойно возвращаются на свои места
		for u in alive_of("hero"):
			u["anim"] += dt
			_move_to(u, formation_x(u), dt * 0.6)
			u["facing"] = 1
		_separate_heroes()
		return
	if s["phase"] != "fight":
		return
	s["t"] += dt
	# Призванные посреди боя (созыв вожака, паучки из кладки)
	for q in s.get("spawn_q", []):
		_spawn_group(q["types"], float(q["x"]), bool(q.get("left", false)))
	s["spawn_q"] = []
	# Засады и отложенные появления
	for i in range(s["pending"].size() - 1, -1, -1):
		var p: Dictionary = s["pending"][i]
		if not p["warned"] and s["t"] >= p["t"] - 2.0:
			p["warned"] = true
			_log("Шорох в кустах за спиной отряда!")
			events.append({"type": "warn_left"})
		if s["t"] >= p["t"]:
			_spawn_group(p["types"], AMBUSH_X, true)
			_log("Засада! Звери бросаются на задний ряд.")
			s["pending"].remove_at(i)
	_tick_waves(dt)
	if s["boss_alive"]:
		s["boss_time"] += dt
	for u in s["units"]:
		if not u["alive"]:
			continue
		u["anim"] += dt
		u["hurt"] = max(0.0, u["hurt"] - dt)
		_tick_effects(u, dt)
		if not u["alive"]:
			continue
		for k in u["cds"].keys():
			u["cds"][k] = max(0.0, u["cds"][k] - dt)
		u["riposte_cd"] = max(0.0, u["riposte_cd"] - dt)
		if u["side"] == "hero":
			u["mp"] = min(u["max_mp"], u["mp"] + u["mp_regen"] * dt)
		if is_stunned(u):
			continue
		if u["cast"] != null:
			_tick_cast(u, dt)
			continue
		if u["side"] == "hero":
			_hero_ai(u, dt)
		else:
			_enemy_ai(u, dt)
	_separate_enemies()
	_separate_heroes()
	for u in s["units"]:
		if u.has("anchor_x"):
			u["x"] = u["anchor_x"]
	# Горение объектов
	for k in s["objects"].keys():
		var o: Dictionary = s["objects"][k]
		if o["burning"] > 0.0 and o["hp"] > 0.0:
			o["hp"] = max(0.0, o["hp"] - o["burning"] * dt)
	_check_end()

func _tick_effects(u: Dictionary, dt: float) -> void:
	for i in range(u["effects"].size() - 1, -1, -1):
		# Урон от яда может снять другой эффект (щит) — список укорачивается прямо в цикле
		if i >= u["effects"].size():
			continue
		var e: Dictionary = u["effects"][i]
		if e.has("t"):
			e["t"] -= dt
		match e["id"]:
			"dot", "burn":
				e["acc"] = e.get("acc", 0.0) + e["dps"] * dt
				if e["acc"] >= 1.0:
					var amt := floor(e["acc"])
					e["acc"] -= amt
					var src = unit(int(e.get("src", -1)))
					_apply_damage(u, amt, e.get("school", "shadow"), src, {"dot": true})
			"hot":
				e["acc"] = e.get("acc", 0.0) + e["hps"] * dt
				if e["acc"] >= 1.0:
					var amt2 := floor(e["acc"])
					e["acc"] -= amt2
					_heal(u, amt2, unit(int(e.get("src", -1))), false)
		if not u["alive"]:
			return
		if e.has("t") and e["t"] <= 0.0:
			for j in u["effects"].size():
				if is_same(u["effects"][j], e):
					u["effects"].remove_at(j)
					break
			if e["id"] == "doom":
				var ds = unit(int(e.get("src", -1)))
				var sp: float = ds["sp"] if ds != null else 20.0
				var amt3: float = (sp * 4.5 + 20.0) * (1.5 if has_effect(u, "curse_mark") else 1.0)
				events.append({"type": "cast_fx", "uid": u["uid"], "ab": "doom"})
				_apply_damage(u, amt3, "shadow", ds, {"crit": true, "spell": true})
				if not u["alive"]:
					return

func _tick_cast(u: Dictionary, dt: float) -> void:
	var c: Dictionary = u["cast"]
	c["t"] += dt
	if c["t"] >= c["total"]:
		u["cast"] = null
		if u["side"] == "hero":
			_resolve_ability(u, c["ab"], c["target"], float(c.get("x", NAN)))
		else:
			_resolve_enemy_skill(u, c)

# ---------------------------------------------------------------- ИИ героев
## Личная цель героя (выбрана через «Автоатака»), либо null
func hero_focus(u: Dictionary) -> Variant:
	var f = unit(int(u.get("focus", -1)))
	if f != null and f["alive"] and f["side"] == "enemy":
		return f
	return null

## Герой бьёт автоатаками только эту цель и сам идёт к ней; повторный выбор той же цели снимает приказ
func set_hero_focus(uid: int, target_uid: int) -> String:
	var u = unit(uid)
	var t = unit(target_uid)
	if u == null or u["side"] != "hero" or not u["alive"]:
		return "Герой не может атаковать."
	if t == null or t["side"] != "enemy" or not t["alive"]:
		return "Нужна цель-враг."
	if in_dark(t):
		return "Враг во тьме."
	if int(u.get("focus", -1)) == target_uid:
		u["focus"] = -1
		return ""
	u["focus"] = target_uid
	_float(t, "Цель: %s" % u["name"], Color(1, 0.6, 0.35))
	return ""

func _hero_target(u: Dictionary) -> Variant:
	var hf = hero_focus(u)
	if hf != null and not in_dark(hf):
		return hf
	var f = unit(int(s["focus"]))
	if f != null and f["alive"] and f["side"] == "enemy" and not in_dark(f):
		if s["order"] == "advance" or dist(u, f) <= u["range"] + 10.0:
			return f
	var best = null
	var bd := 1e9
	for e in alive_of("enemy"):
		if in_dark(e):
			continue
		var d := dist(u, e)
		if d < bd:
			bd = d
			best = e
	return best

func formation_x(u: Dictionary) -> float:
	var slot: int = s["formation"].find(u["key"])
	return FORMATION_X[clamp(slot, 0, 3)]

func _move_to(u: Dictionary, x: float, dt: float) -> bool:
	u["goal_x"] = x
	if has_effect(u, "root"):
		return abs(u["x"] - x) < 4.0
	var sp: float = u["speed"] * slow_factor(u)
	var dx: float = x - u["x"]
	if abs(dx) <= sp * dt:
		u["x"] = x
		return true
	u["x"] += sign(dx) * sp * dt
	u["facing"] = int(sign(dx))
	return false

func _hero_ai(u: Dictionary, dt: float) -> void:
	# Ремонт / тушение
	if u["task"] != null:
		var tk: Dictionary = u["task"]
		var o = s["objects"].get(tk["obj"])
		if o == null or o["hp"] <= 0.0:
			u["task"] = null
			return
		if _move_to(u, o["x"] + 45.0, dt):
			tk["t"] += dt
			if tk["t"] >= tk["total"]:
				_finish_task(u, tk)
		return
	# Отложенное умение (цель вне досягаемости)
	if u["queued"] != null:
		var q: Dictionary = u["queued"]
		if q.has("x"):
			var need_x := _ability_range(u, q["ab"])
			if absf(float(q["x"]) - u["x"]) <= need_x:
				u["queued"] = null
				use_ability_at(u["uid"], q["ab"], float(q["x"]))
				return
			_move_to(u, float(q["x"]) - sign(float(q["x"]) - u["x"]) * (need_x - 15.0), dt)
			return
		var tq = unit(int(q["target"]))
		if tq == null or not tq["alive"]:
			u["queued"] = null
		else:
			var need := _ability_range(u, q["ab"])
			if dist(u, tq) <= need:
				u["queued"] = null
				use_ability(u["uid"], q["ab"], tq["uid"])
				return
			_move_to(u, tq["x"] - sign(tq["x"] - u["x"]) * (need - 15.0 + BODY), dt)
			return
	var t = _hero_target(u)
	var home := formation_x(u)
	var desired := home
	if t == null and s["order"] == "advance" and s.get("night", false):
		# Ночью «К цели» ведёт отряд в темноту — к ближайшему скрытому врагу, пока его не станет видно
		var dark = null
		var dd := 1e9
		for e in alive_of("enemy"):
			if dist(u, e) < dd:
				dd = dist(u, e)
				dark = e
		if dark != null:
			_move_to(u, dark["x"] - sign(dark["x"] - u["x"]) * (NIGHT_SIGHT * 0.6), dt)
			u["facing"] = int(sign(dark["x"] - u["x"])) if dark["x"] != u["x"] else 1
			u["atk_t"] = max(0.0, u["atk_t"] - dt)
			return
	if t != null:
		var d := dist(u, t)
		var dir: float = sign(t["x"] - u["x"])
		if dir == 0:
			dir = 1.0
		if s["order"] == "advance" or hero_focus(u) != null:
			if d > u["range"]:
				desired = t["x"] - dir * (u["range"] - 15.0 + BODY)
			else:
				desired = u["x"]
		else:
			# Удержание строя: ближний бой может шагнуть не дальше 90 от своего места
			if u["melee"] and d > u["range"]:
				var want: float = t["x"] - dir * (u["range"] - 15.0 + BODY)
				desired = clamp(want, home - 90.0, home + 90.0)
			elif d <= u["range"]:
				desired = u["x"] if abs(u["x"] - home) < 95.0 else home
			# Стрелок в строю не подшагивает к цели: стоит на месте и ждёт, пока враг войдёт в дальность
		u["facing"] = int(dir)
	_move_to(u, _free_spot(u, desired), dt)
	if t != null and dist(u, t) <= u["range"] + 10.0:
		u["atk_t"] -= dt * slow_factor(u)
		if u["atk_t"] <= 0.0:
			u["atk_t"] = u["interval"]
			_auto_attack(u, t)
	else:
		u["atk_t"] = max(0.0, u["atk_t"] - dt)

# ---------------------------------------------------------------- ИИ врагов
func _enemy_target(u: Dictionary) -> Dictionary:
	# Возвращает {"unit": u?, "obj": ""}
	var tau = get_effect(u, "taunt")
	if tau != null:
		var src = unit(int(tau["src"]))
		if src != null and src["alive"]:
			return {"unit": src, "obj": ""}
	var heroes := alive_of("hero")
	if "raider" in u["tags"]:
		for k in ["wagon", "gate"]:
			if s["objects"].has(k) and s["objects"][k]["hp"] > 0.0:
				return {"unit": null, "obj": k}
	if "arsonist" in u["tags"]:
		for k in ["chest", "wagon", "gate"]:
			if s["objects"].has(k) and s["objects"][k]["hp"] > 0.0 and s["objects"][k]["burning"] <= 0.0:
				return {"unit": null, "obj": k}
	if heroes.size() > 0:
		# Враг бросается на выбранного героя и время от времени передумывает
		var cur = unit(int(u.get("pick", -1)))
		if cur == null or not cur["alive"] or cur["side"] != "hero" or float(u.get("pick_t", 0.0)) <= 0.0:
			cur = _pick_hero(u, heroes)
			u["pick"] = int(cur["uid"])
			u["pick_t"] = rng.randf_range(REPICK_MIN, REPICK_MAX)
		return {"unit": cur, "obj": ""}
	for k in ["wagon", "gate"]:
		if s["objects"].has(k) and s["objects"][k]["hp"] > 0.0:
			return {"unit": null, "obj": k}
	return {"unit": null, "obj": ""}

## Случайный выбор цели: ближние герои вероятнее, засада тянется к заднему ряду,
## герой, вокруг которого уже заняты все полосы, почти не выбирается.
func _pick_hero(u: Dictionary, heroes: Array) -> Dictionary:
	var ws := []
	var total := 0.0
	for h in heroes:
		var w := 1.0 / (1.0 + dist(u, h) / 350.0)
		if u.get("ambusher", false):
			w *= 1.0 + float(s["formation"].find(h["key"]))
		if h["task"] != null:
			w *= 0.7
		if u["melee"] and _melee_on(h, u) >= LANES:
			w *= 0.25
		if int(u.get("pick", -1)) == int(h["uid"]):
			w *= 1.5
		ws.append(w)
		total += w
	var r := rng.randf() * total
	for i in heroes.size():
		r -= ws[i]
		if r <= 0.0:
			return heroes[i]
	return heroes[heroes.size() - 1]

## Ближний бой: занять свободную полосу у цели, чтобы бить вместе с остальными, а не стоять в очереди.
func _take_lane(u: Dictionary, tg: Dictionary, dir: float) -> void:
	var used := {}
	for e in s["units"]:
		if e["side"] == "enemy" and e["alive"] and e["melee"] and e["uid"] != u["uid"] \
				and int(e.get("tgt", -1)) == int(tg["uid"]) and sign(tg["x"] - e["x"]) == dir:
			used[int(e["lane"])] = true
	if not used.has(int(u["lane"])):
		return
	var best := -1
	for l in LANES:
		if not used.has(l) and (best < 0 or abs(l - int(u["lane"])) < abs(best - int(u["lane"]))):
			best = l
	if best >= 0:
		u["lane"] = best

func _enemy_ai(u: Dictionary, dt: float) -> void:
	u["skill_cd"] = max(0.0, u["skill_cd"] - dt)
	u["pick_t"] = float(u.get("pick_t", 0.0)) - dt
	var tg := _enemy_target(u)
	var tx := 0.0
	var tname := ""
	u["tgt"] = int(tg["unit"]["uid"]) if tg["unit"] != null else -1
	if tg["unit"] != null:
		tx = tg["unit"]["x"]
	elif tg["obj"] != "":
		tx = s["objects"][tg["obj"]]["x"]
		tname = tg["obj"]
	else:
		return
	var dir: float = sign(tx - u["x"])
	if dir == 0:
		dir = -1.0
	if u.has("anchor_x"):
		# Неподвижный: только свои приёмы, без шага и автоатаки
		if u["skill_cd"] <= 0.0:
			for sk in u["skills"]:
				if not sk.get("passive", false) and float(u["cds"].get(sk["id"], 0.0)) <= 0.0 and _try_enemy_skill(u, sk, tg, abs(tx - u["x"])):
					return
		return
	u["facing"] = int(dir)
	if u["melee"] and tg["unit"] != null:
		_take_lane(u, tg["unit"], dir)
	var d: float = abs(tx - u["x"])
	var body := 0.0
	if tg["unit"] != null:
		body = BODY
		d = max(0.0, d - BODY)
	# Раненый в ярости: бьёт и бегает быстрее
	if u["pas"].has("frenzy") and u["hp"] < u["max_hp"] * 0.3 and not has_effect(u, "frenzy"):
		add_effect(u, {"id": "frenzy"})
		add_effect(u, {"id": "haste", "val": 0.35})
		_float(u, "Ярость!", Color(1, 0.35, 0.25), true)
	# Особые приёмы с подготовкой (у каждого своя перезарядка, между приёмами — короткая пауза)
	if u["skill_cd"] <= 0.0 and not has_effect(u, "hidden"):
		for sk in u["skills"]:
			if sk.get("passive", false) or float(u["cds"].get(sk["id"], 0.0)) > 0.0:
				continue
			if sk.get("once", false) and u.get("used_" + str(sk["id"]), false):
				continue
			if _try_enemy_skill(u, sk, tg, d):
				return
	var reach: float = u["range"]
	if tname != "":
		reach = 50.0 if u["melee"] else u["range"]
	if d > reach - 5.0:
		_move_to(u, tx - dir * (reach - 10.0 + body), dt)
	# Второй ряд толпы (оттеснён соседом) тоже дотягивается до цели
	var crowd := ENEMY_GAP + 5.0 if u.get("crowd", false) and tg["unit"] != null else 0.0
	if d <= reach + 10.0 + crowd:
		u["atk_t"] -= dt * slow_factor(u)
		if u["atk_t"] <= 0.0:
			u["atk_t"] = u["interval"]
			if tg["unit"] != null:
				_auto_attack(u, tg["unit"])
			else:
				_attack_object(u, tname)

## Сколько бойцов ближнего боя (кроме `except`) уже нацелены на героя.
func _melee_on(h: Dictionary, except: Dictionary) -> int:
	var n := 0
	for e in s["units"]:
		if e["side"] == "enemy" and e["alive"] and e["melee"] and e["uid"] != except["uid"] and int(e.get("tgt", -1)) == int(h["uid"]):
			n += 1
	return n

## Раздвигает врагов: в каждой полосе по каждую сторону от героев соседние фигуры держат зазор ENEMY_GAP,
## задний отступает назад (от героев), передний стоит на месте.
## Кому надо дальше вперёд (рубака за лучником), тот обходит соседа сбоку, а не упирается в него.
func _separate_enemies() -> void:
	var rows := {}
	var all_e := alive_of("enemy")
	for e in all_e:
		e["passing"] = 0
	for e in all_e:
		e["crowd"] = false
		var key := "%d:%d" % [1 if int(e["facing"]) > 0 else -1, int(e.get("lane", 0))]
		if not rows.has(key):
			rows[key] = []
		rows[key].append(e)
	for key in rows:
		var row: Array = rows[key]
		var from_left: bool = str(key).begins_with("1:")
		if from_left:
			row.sort_custom(func(a, b): return a["x"] > b["x"])
		else:
			row.sort_custom(func(a, b): return a["x"] < b["x"])
		var fwd := 1.0 if from_left else -1.0
		for i in range(1, row.size()):
			var front: Dictionary = row[i - 1]
			var back: Dictionary = row[i]
			# Обход: задний рвётся дальше, а передний стоит (лучник на дистанции);
			# или передний уже ушёл вперёд от стоящего — не отпихиваем стоящего назад.
			# Идущих вместе толпой по-прежнему держит зазор.
			var front_walks := _leaving(front, fwd)
			var back_walks := _leaving(back, fwd)
			if fwd * (float(back["x"]) - float(front["x"])) > -ENEMY_GAP and \
					((not front_walks and _wants_past(back, front, fwd)) or (front_walks and not back_walks)):
				# Проходящий (тот, кто идёт) шагает к камере, стоящий — вглубь
				var mover: Dictionary = front if front_walks else back
				var other: Dictionary = back if front_walks else front
				mover["passing"] = 1
				if int(other["passing"]) == 0:
					other["passing"] = -1
				continue
			if from_left:
				var lim2: float = row[i - 1]["x"] - ENEMY_GAP
				if row[i]["x"] > lim2:
					row[i]["x"] = lim2
					row[i]["crowd"] = true
			else:
				var lim: float = row[i - 1]["x"] + ENEMY_GAP
				if row[i]["x"] < lim:
					row[i]["x"] = lim
					row[i]["crowd"] = true
	_ease_side_steps(all_e)

## Не даёт героям стоять друг на друге: соседи по дороге держат зазор HERO_GAP.
## Расталкиваются оба; обездвиженный не сдвигается, занятый (подготовка, ремонт) — неохотно.
## Кому нужно пройти за соседа (цель движения дальше него), тот обходит его сбоку:
## проходящий шагает к камере, уступающий — чуть вглубь дороги (side_step для BattleView).
func _separate_heroes() -> void:
	var hs := alive_of("hero")
	for h in hs:
		h["passing"] = 0
	if hs.size() < 2:
		_ease_side_steps(hs)
		return
	hs.sort_custom(func(a, b): return a["x"] < b["x"] or (a["x"] == b["x"] and a["uid"] < b["uid"]))
	# Проходы попеременно слева и справа: цепочка прижатых друг к другу героев расходится за пару проходов
	for p in 16:
		var moved := false
		for j in range(1, hs.size()):
			var i: int = j if p % 2 == 0 else hs.size() - j
			var a: Dictionary = hs[i - 1]
			var b: Dictionary = hs[i]
			var gap: float = b["x"] - a["x"]
			if gap >= HERO_GAP - 0.01:
				continue
			# Обходящего не толкаем — ни пока он идёт мимо, ни пока уходит от соседа дальше
			if _wants_past(a, b, 1.0) or _wants_past(b, a, -1.0) or _leaving(a, -1.0) or _leaving(b, 1.0):
				continue
			var wa := _push_weight(a)
			var wb := _push_weight(b)
			if wa + wb <= 0.0:
				wa = 1.0
				wb = 1.0
			var push := HERO_GAP - gap
			a["x"] -= push * wa / (wa + wb)
			b["x"] += push * wb / (wa + wb)
			moved = true
		if not moved:
			break
	# Отмечаем обход уже после расталкивания: пара могла сблизиться, когда соседа сдвинули к ней
	for i in range(1, hs.size()):
		var a: Dictionary = hs[i - 1]
		var b: Dictionary = hs[i]
		if b["x"] - a["x"] >= HERO_GAP - 0.01:
			continue
		if _wants_past(a, b, 1.0) or _leaving(a, -1.0):
			a["passing"] = 1
			if int(b["passing"]) == 0:
				b["passing"] = -1
		if _wants_past(b, a, -1.0) or _leaving(b, 1.0):
			# Меняются местами: один обходит ближе к камере, другой — вглубь
			if int(a["passing"]) > 0:
				b["passing"] = -1
			else:
				b["passing"] = 1
				if int(a["passing"]) == 0:
					a["passing"] = -1
	_ease_side_steps(hs)

## Точка остановки без толкотни: если желанное место вплотную к стоящему соседу впереди по ходу,
## герой встаёт перед ним на HERO_GAP, а не вдавливается в него (и не расталкивает весь строй).
## Если цель дальше соседа — обходит его (см. _separate_heroes).
func _free_spot(u: Dictionary, x: float) -> float:
	var dir: float = sign(x - float(u["x"]))
	if absf(x - float(u["x"])) < 1.0:
		return x
	for _i in 2:
		for o in alive_of("hero"):
			if o["uid"] == u["uid"]:
				continue
			var ox: float = float(o["x"])
			if (ox - float(u["x"])) * dir <= 0.0:
				continue
			# Сосед сам куда-то идёт — он уйдёт с дороги
			if absf(float(o.get("prev_goal", ox)) - ox) > BODY * 0.5:
				continue
			if absf(x - ox) < HERO_GAP:
				x = ox - dir * HERO_GAP
		if (x - float(u["x"])) * dir < 0.0:
			return float(u["x"])
	return x

## Герой `u` идёт в сторону `dir` и его цель — за соседом `o`: соседа надо обойти, а не толкать.
func _wants_past(u: Dictionary, o: Dictionary, dir: float) -> bool:
	if has_effect(u, "root") or is_stunned(u):
		return false
	var g: float = float(u.get("goal_x", u["x"]))
	return (g - float(o["x"])) * dir > BODY * 0.5

## Герой `u` сам уходит в сторону `dir` (прочь от соседа) — расталкивать их незачем.
func _leaving(u: Dictionary, dir: float) -> bool:
	if has_effect(u, "root") or is_stunned(u):
		return false
	return (float(u.get("goal_x", u["x"])) - float(u["x"])) * dir > BODY * 0.5

## Плавный шаг в сторону при обходе: 1 — проходящий (ближе к камере), -1 — уступающий.
func _ease_side_steps(hs: Array) -> void:
	for h in hs:
		var want := 0.0
		if int(h["passing"]) > 0:
			want = 1.0
		elif int(h["passing"]) < 0:
			want = -0.6
		var cur: float = float(h.get("side_step", 0.0))
		h["side_step"] = move_toward(cur, want, 0.08)

func _push_weight(u: Dictionary) -> float:
	if has_effect(u, "root") or is_stunned(u):
		return 0.0
	if hero_busy(u):
		return 0.25
	return 1.0

func _try_enemy_skill(u: Dictionary, sk: Dictionary, tg: Dictionary, d: float) -> bool:
	var target_uid := -1
	var ok := false
	match sk["id"]:
		"charge":
			ok = tg["unit"] != null and d > 130.0 and d < 650.0
			if ok:
				target_uid = tg["unit"]["uid"]
		"web":
			ok = tg["unit"] != null and d <= u["range"] + 40.0 and not has_effect(tg["unit"], "root")
			if ok:
				target_uid = tg["unit"]["uid"]
		"maul", "dirty", "shieldbash":
			ok = tg["unit"] != null and d <= u["range"] + 15.0
			if ok and sk["id"] == "shieldbash":
				# Удар щитом бережёт для тех, кто готовит приём
				ok = tg["unit"]["cast"] != null or rng.randf() < 0.3
			if ok:
				target_uid = tg["unit"]["uid"]
		"sand":
			ok = tg["unit"] != null and d <= u["range"] + 15.0 and not has_effect(tg["unit"], "blind")
			if ok:
				target_uid = tg["unit"]["uid"]
		"roar", "rear":
			var near := 0
			for h in alive_of("hero"):
				if dist(u, h) <= (200.0 if sk["id"] == "roar" else 150.0):
					near += 1
			ok = near >= (1 if sk["id"] == "roar" else 2) or (sk["id"] == "rear" and near >= 1 and rng.randf() < 0.3)
		"call":
			ok = alive_of("hero").size() > 0 and d < 700.0
		"leap":
			var back = _back_hero(u)
			ok = back != null and dist(u, back) > 160.0
			if ok:
				target_uid = back["uid"]
		"snipe":
			var soft = _softest_hero()
			ok = soft != null and dist(u, soft) <= u["range"] + 60.0
			if ok:
				target_uid = soft["uid"]
		"ward":
			var low2 = null
			var lr2 := 0.8
			for e in alive_of("enemy"):
				var r2: float = e["hp"] / e["max_hp"]
				if r2 < lr2 and not has_effect(e, "barrier"):
					lr2 = r2
					low2 = e
			if low2 != null:
				ok = true
				target_uid = low2["uid"]
		"smoke", "oil":
			ok = tg["unit"] != null and d <= max(u["range"], 260.0)
			if ok:
				target_uid = tg["unit"]["uid"]
		"howl":
			ok = alive_of("hero").size() > 0 and d < 600.0
		"smash", "whirl":
			ok = tg["unit"] != null and d <= u["range"] + 15.0
			if ok:
				target_uid = tg["unit"]["uid"]
		"volley":
			ok = tg["unit"] != null and d <= u["range"]
			if ok:
				target_uid = tg["unit"]["uid"]
		"mend":
			var low = null
			var lr := 0.7
			for e in alive_of("enemy"):
				var r: float = e["hp"] / e["max_hp"]
				if r < lr and not has_effect(e, "burn_noheal"):
					lr = r
					low = e
			if low != null:
				ok = true
				target_uid = low["uid"]
		"ignite":
			ok = tg["obj"] != "" and d <= 70.0
		"pulse":
			ok = not alive_of("hero").is_empty() and alive_of("enemy").size() < 6
	if not ok:
		return false
	u["cast"] = {"ab": sk["id"], "name": sk["name"], "t": 0.0, "total": float(sk["cast"]), "target": target_uid, "obj": tg["obj"]}
	u["cds"][sk["id"]] = float(sk["cd"])
	u["skill_cd"] = 2.5
	if sk.get("once", false):
		u["used_" + str(sk["id"])] = true
	_log("%s готовит «%s»!" % [u["name"], sk["name"]])
	return true

func _resolve_enemy_skill(u: Dictionary, c: Dictionary) -> void:
	match c["ab"]:
		"pulse":
			# Обелиск выпускает двух духов того зверя, что живёт в этой пещере
			var lv: int = u["level"]
			var kind: String = u.get("summon", "shade_wolf")
			s["spawn_q"] = s.get("spawn_q", []) + [{"types": [[kind, lv], [kind, max(1, lv - 1)]], "x": u["x"] + 260.0}]
			_log("%s пульсирует — из тьмы выходят духи!" % u["name"])
		"howl":
			for e in alive_of("enemy"):
				if "beast" in e["tags"]:
					add_effect(e, {"id": "howl", "t": 8.0, "val": 0.3})
					if u["pas"].has("packhaste"):
						add_effect(e, {"id": "haste", "t": 8.0, "val": 0.3})
					_float(e, "Ярость", Color(1, 0.5, 0.3))
		"call":
			var lv: int = u["level"]
			var kind := "shade_wolf" if u["key"] == "captain" else "wolf"
			s["spawn_q"] = s.get("spawn_q", []) + [{"types": [[kind, lv], [kind, max(1, lv - 1)]], "x": SPAWN_X}]
			_log("%s зовёт стаю! Из чащи выходят волки." % u["name"])
		"charge":
			var tc = unit(int(c["target"]))
			if tc != null and tc["alive"]:
				var side: float = sign(u["x"] - tc["x"])
				if side == 0:
					side = 1.0
				u["x"] = tc["x"] + side * (BODY + 20.0)
				var r := _direct_hit(u, tc, 1.5, "phys", {})
				if r in ["hit", "crit", "block"]:
					add_effect(tc, {"id": "stun", "t": 1.0})
					_float(tc, "Сбит с ног", Color(1, 1, 0.4))
				events.append({"type": "shake"})
		"web":
			var tw = unit(int(c["target"]))
			if tw != null and tw["alive"]:
				events.append({"type": "proj", "from": u["uid"], "to": tw["uid"], "kind": "nature"})
				add_effect(tw, {"id": "root", "t": 3.0})
				add_effect(tw, {"id": "slow", "t": 4.0, "val": 0.3})
				_float(tw, "Паутина", Color(0.85, 0.9, 0.85))
		"maul":
			var tm = unit(int(c["target"]))
			if tm != null and tm["alive"] and dist(u, tm) <= u["range"] + 40.0:
				var r2 := _direct_hit(u, tm, 2.0, "phys", {"no_dodge": true})
				if r2 in ["hit", "crit", "block"] and not has_effect(tm, "root"):
					tm["x"] += sign(tm["x"] - u["x"]) * 110.0
					add_effect(tm, {"id": "stun", "t": 0.8})
				events.append({"type": "shake"})
		"roar":
			for h in alive_of("hero"):
				if dist(u, h) <= 200.0:
					h["atb"] = max(0.0, h["atb"] - 0.5)
					add_effect(h, {"id": "weak", "t": 5.0})
					_float(h, "Страх", Color(0.8, 0.6, 1.0))
			events.append({"type": "shake"})
		"rear":
			for h in alive_of("hero"):
				if dist(u, h) <= 150.0:
					_direct_hit(u, h, 1.8, "phys", {})
			events.append({"type": "shake"})
		"dirty":
			var td = unit(int(c["target"]))
			if td != null and td["alive"] and dist(u, td) <= u["range"] + 40.0:
				var r3 := _direct_hit(u, td, 1.2, "phys", {})
				if r3 in ["hit", "crit", "block"]:
					td["cast"] = null
					add_effect(td, {"id": "stun", "t": 1.5})
					_float(td, "Оглушён", Color(1, 1, 0.4))
		"shieldbash":
			var tb = unit(int(c["target"]))
			if tb != null and tb["alive"] and dist(u, tb) <= u["range"] + 40.0:
				if tb["cast"] != null:
					_float(tb, "Сбит!", Color(1, 1, 0.3), true)
				tb["cast"] = null
				tb["queued"] = null
				_direct_hit(u, tb, 0.8, "phys", {"no_dodge": true})
				add_effect(tb, {"id": "stun", "t": 1.0})
		"sand":
			var ts = unit(int(c["target"]))
			if ts != null and ts["alive"] and dist(u, ts) <= u["range"] + 40.0:
				add_effect(ts, {"id": "blind", "t": 5.0})
				_float(ts, "Ослеплён", Color(0.95, 0.85, 0.5))
		"leap":
			var tl = unit(int(c["target"]))
			if tl != null and tl["alive"]:
				var sd: float = sign(u["x"] - tl["x"])
				if sd == 0:
					sd = 1.0
				u["x"] = tl["x"] + sd * (BODY + 15.0)
				u["pick"] = int(tl["uid"])
				u["pick_t"] = 6.0
				_float(u, "Рывок!", Color(1, 0.6, 0.4))
		"snipe":
			var tn = unit(int(c["target"]))
			if tn != null and tn["alive"]:
				events.append({"type": "proj", "from": u["uid"], "to": tn["uid"], "kind": "arrow"})
				_direct_hit(u, tn, 2.2, "phys", {})
		"ward":
			var tr = unit(int(c["target"]))
			if tr != null and tr["alive"]:
				add_effect(tr, {"id": "barrier", "t": 10.0, "val": tr["max_hp"] * 0.25, "orig": tr["max_hp"] * 0.25})
				_float(tr, "Оберег", Color(0.6, 1.0, 0.6))
		"smoke":
			var tk = unit(int(c["target"]))
			if tk != null:
				for h in alive_of("hero"):
					if dist(h, tk) <= 130.0:
						add_effect(h, {"id": "dot", "t": 6.0, "dps": max(2.0, u["dmg_max"] * 0.35), "school": "nature", "src": u["uid"]})
						_float(h, "Дурман", Color(0.6, 0.9, 0.4))
		"oil":
			var to = unit(int(c["target"]))
			if to != null:
				for h in alive_of("hero"):
					if dist(h, to) <= 120.0:
						_direct_hit(u, h, 0.8, "fire", {})
						add_effect(h, {"id": "burn", "t": 4.0, "dps": max(2.0, u["dmg_max"] * 0.25), "school": "fire", "src": u["uid"]})
		"smash":
			var t = unit(int(c["target"]))
			if t != null and t["alive"] and dist(u, t) <= u["range"] + 40.0:
				_direct_hit(u, t, 3.0, "phys", {"no_dodge": true})
				events.append({"type": "shake"})
		"whirl":
			for h in alive_of("hero"):
				if dist(u, h) <= 150.0:
					_direct_hit(u, h, 1.6, "phys", {})
			events.append({"type": "shake"})
		"volley":
			var t2 = unit(int(c["target"]))
			if t2 != null:
				for h in alive_of("hero"):
					if dist(h, t2) <= 130.0:
						events.append({"type": "proj", "from": u["uid"], "to": h["uid"], "kind": "arrow"})
						var rv := _direct_hit(u, h, 1.1, "phys", {})
						if u["pas"].has("firearrows") and rv in ["hit", "crit", "block"]:
							add_effect(h, {"id": "burn", "t": 4.0, "dps": max(2.0, u["dmg_max"] * 0.2), "school": "fire", "src": u["uid"]})
		"mend":
			var t3 = unit(int(c["target"]))
			if t3 != null and t3["alive"]:
				_heal(t3, t3["max_hp"] * 0.3, u, false)
		"ignite":
			var o = s["objects"].get(c["obj"])
			if o != null and o["hp"] > 0.0:
				o["burning"] = o["max"] * (0.018 if c["obj"] != "chest" else 0.035)
				_log("%s в огне! Нужен герой, чтобы потушить." % OBJ_NAMES[c["obj"]])
				_float_obj(c["obj"], "Пожар!", Color(1, 0.5, 0.2))

## Свойства врага при попадании автоатакой
func _enemy_on_hit(a: Dictionary, t: Dictionary, res: String) -> void:
	if not (res in ["hit", "crit", "block"]):
		return
	var p: Dictionary = a.get("pas", {})
	a["hits"] = int(a.get("hits", 0)) + 1
	if p.has("hamstring") and rng.randf() < 0.3:
		add_effect(t, {"id": "slow", "t": 5.0, "val": 0.3})
		_float(t, "Хромает", Color(0.6, 0.9, 0.6))
	if p.has("rend") and rng.randf() < 0.3:
		add_effect(t, {"id": "bleed", "t": 6.0})
		add_effect(t, {"id": "dot", "t": 6.0, "dps": max(2.0, a["dmg_max"] * 0.3), "school": "bleed", "src": a["uid"]})
		_float(t, "Кровотечение", Color(0.9, 0.2, 0.2))
	if p.has("venom"):
		add_effect(t, {"id": "dot", "t": 6.0, "dps": max(1.5, a["dmg_max"] * 0.25), "school": "nature", "src": a["uid"]})
	if p.has("claws") and rng.randf() < 0.3 and t["alive"]:
		_direct_hit(a, t, 0.7, "phys", {})
	if p.has("fade") and int(a["hits"]) % 4 == 0:
		add_effect(a, {"id": "hidden", "t": 2.5})
		a["pick_t"] = 0.0
		_float(a, "В кусты!", Color(0.7, 0.8, 0.6))

## Середина строя героев (чтобы понять, с какой стороны враг)
func formation_center() -> float:
	var hs := alive_of("hero")
	if hs.is_empty():
		return 600.0
	var x := 0.0
	for h in hs:
		x += float(h["x"])
	return x / hs.size()

## Задний ряд: стрелок или маг дальше всех от врага
func _back_hero(u: Dictionary) -> Variant:
	var best = null
	var bd := -1.0
	for h in alive_of("hero"):
		if h["melee"]:
			continue
		var d := dist(u, h)
		if d > bd:
			bd = d
			best = h
	return best

## Герой с самой слабой бронёй
func _softest_hero() -> Variant:
	var best = null
	for h in alive_of("hero"):
		if best == null or float(h["armor"]) < float(best["armor"]):
			best = h
	return best

func _attack_object(u: Dictionary, obj: String) -> void:
	var o: Dictionary = s["objects"][obj]
	var dmg := rng.randf_range(u["dmg_min"], u["dmg_max"])
	if has_effect(u, "weak"):
		dmg *= 0.7
	o["hp"] = max(0.0, o["hp"] - dmg)
	events.append({"type": "swing", "uid": u["uid"]})
	_float_obj(obj, "-%d" % int(dmg), Color(1, 0.75, 0.4))

# ---------------------------------------------------------------- Атаки и урон
func _auto_attack(a: Dictionary, t: Dictionary) -> void:
	events.append({"type": "swing", "uid": a["uid"]})
	var mult := 1.0
	if a["side"] == "enemy" and has_effect(a, "hidden"):
		# Удар из засады: зверь выходит из кустов
		remove_effect(a, "hidden")
		mult = 2.0
		_float(a, "Из засады!", Color(1, 0.6, 0.3), true)
	if not a["melee"]:
		var kind := "arrow"
		if a["school"] == "holy": kind = "holy"
		elif a["school"] == "shadow": kind = "shadow"
		elif a["school"] == "nature": kind = "nature"
		events.append({"type": "proj", "from": a["uid"], "to": t["uid"], "kind": kind})
	var res := _direct_hit(a, t, mult, a["school"], {"auto": true})
	if a["side"] == "enemy" and t["alive"]:
		_enemy_on_hit(a, t, res)
	if a.get("champion", "") == "fiery" and t["alive"] and res in ["hit", "crit", "block"]:
		add_effect(t, {"id": "burn", "t": 6.0, "dps": max(2.0, a["dmg_max"] * 0.12), "school": "fire", "src": a["uid"]})
		_float(t, "Горит", Color(1, 0.55, 0.2))
	if a["side"] == "hero" and res in ["hit", "crit", "block"]:
		a["atb"] = min(2.0, a["atb"] + ATB_PER_SEC * a["interval"])

## Прямая атака: промах/уклонение/парирование/блок, крит, разброс. Возвращает исход.
func _direct_hit(a: Dictionary, t: Dictionary, mult: float, school: String, opt: Dictionary) -> String:
	if not t["alive"]:
		return "none"
	var phys := school == "phys"
	var miss: float = max(0.0, 100.0 - a["hit"])
	if has_effect(a, "blind"):
		miss += 50.0
	if not opt.get("no_dodge", false):
		miss += t["dodge"]
	var roll := rng.randf() * 100.0
	if roll < miss:
		_float(t, "Уклонение" if roll >= 100.0 - a["hit"] else "Промах", Color(0.8, 0.8, 0.8))
		_on_defended(t)
		return "miss"
	if phys and a["melee"] and t["parry"] > 0.0 and not opt.get("no_dodge", false):
		if rng.randf() * 100.0 < t["parry"]:
			_float(t, "Парирование", Color(0.8, 0.85, 1.0))
			_on_defended(t)
			return "parry"
	var dmg := rng.randf_range(a["dmg_min"], a["dmg_max"]) * mult
	if opt.has("base"):
		dmg = float(opt["base"]) * rng.randf_range(0.92, 1.08) * mult
	var crit_ch: float = a["crit"] + opt.get("crit_bonus", 0.0)
	var crit := rng.randf() * 100.0 < crit_ch
	if crit:
		dmg *= 1.75
	var outcome := "crit" if crit else "hit"
	if phys and t["block"] > 0.0 and rng.randf() * 100.0 < t["block"]:
		if t["side"] == "hero":
			_bh(t["key"])["absorbed"] += minf(dmg, float(t["block_val"]))
		dmg = max(0.0, dmg - t["block_val"])
		_float(t, "Блок", Color(0.75, 0.85, 1.0))
		_on_defended(t)
		outcome = "block"
	_apply_damage(t, dmg, school, a, {"crit": crit, "spell": opt.get("spell", false)})
	# Ответный удар Марека во время провокации
	if t["alive"] and t["side"] == "hero" and a["melee"] and perk(t, "riposte") and has_effect(t, "taunting") and t["riposte_cd"] <= 0.0 and dist(a, t) < 140.0:
		t["riposte_cd"] = 0.8
		_float(t, "Ответный удар", Color(1, 0.85, 0.4))
		_direct_hit(t, a, 0.6, "phys", {"no_dodge": true})
	return outcome

## Счётчики героя для итогов похода: урон, лечение, поглощено (броня, блок, щиты), прерывания
func _bh(key: String) -> Dictionary:
	var bh: Dictionary = s["counters"]["by_hero"]
	if not bh.has(key):
		bh[key] = {"dmg": 0.0, "heal": 0.0, "absorbed": 0.0, "int": 0}
	return bh[key]

func _on_defended(t: Dictionary) -> void:
	if t["side"] == "hero" and t["key"] == "marek":
		t["atb"] = min(2.0, t["atb"] + (0.3 if perk(t, "bastion") else 0.12))

func _apply_damage(t: Dictionary, dmg: float, school: String, src, opt: Dictionary) -> void:
	if not t["alive"]:
		return
	var raw := dmg
	if src != null:
		if has_effect(src, "weak"):
			dmg *= 0.7
		if has_effect(src, "howl"):
			dmg *= 1.3
		if has_effect(src, "rally"):
			dmg *= 1.2
	var v = get_effect(t, "vuln")
	if v != null:
		dmg *= 1.0 + float(v["val"])
	if has_effect(t, "wall"):
		dmg *= 0.5
	if has_effect(t, "intercede"):
		dmg *= 0.7
	if t["side"] == "hero":
		for h in alive_of("hero"):
			var g = get_effect(h, "guard")
			if g != null and h != t:
				dmg *= 0.8
				break
	if school == "phys":
		var arm: float = t["armor"]
		if has_effect(t, "taunting"):
			arm *= 1.25
		var lvl: int = src["level"] if src != null else s["level"]
		dmg *= 1.0 - Stats.armor_reduction(arm, lvl)
	else:
		dmg *= 1.0 - Stats.resist_reduction(float(t["res"].get(school, 0.0)))
	dmg = max(1.0, round(dmg))
	if t["side"] == "hero":
		s["counters"]["dmg_taken"][t["key"]] = s["counters"]["dmg_taken"].get(t["key"], 0) + int(raw)
		if t["key"] == "marek":
			t["atb"] = min(2.0, t["atb"] + 0.05 + dmg / t["max_hp"] * 0.6)
	if src != null and src["side"] == "hero" and src["key"] == "neris" and school != "phys":
		s["counters"]["spell_dmg"] += int(dmg)
	# Барьер
	var b = get_effect(t, "barrier")
	if b != null:
		var absorb: float = min(b["val"], dmg)
		b["val"] -= absorb
		dmg -= absorb
		if absorb > 0 and not opt.get("dot", false):
			_float(t, "Щит −%d" % int(absorb), Color(1.0, 0.9, 0.5))
		if b["val"] <= 0.0:
			remove_effect(t, "barrier")
			_float(t, "Щит разбит", Color(1.0, 0.8, 0.4))
			if b.get("radiance", false):
				_heal(t, b["orig"] * 0.5, unit(int(b.get("src", -1))), false)
	if t["side"] == "hero":
		_bh(t["key"])["absorbed"] += maxf(0.0, raw - maxf(0.0, dmg))
	if dmg <= 0.0:
		return
	if src != null and src["side"] == "hero" and t["side"] == "enemy":
		_bh(src["key"])["dmg"] += minf(dmg, maxf(0.0, t["hp"]))
	t["hp"] -= dmg
	t["hurt"] = 0.18
	if t["side"] == "enemy":
		var tp: Dictionary = t.get("pas", {})
		# Щетина кабана: бьющий вплотную получает часть урона назад
		if tp.has("bristle") and src != null and src["side"] == "hero" and src["alive"] and src["melee"] and not opt.get("dot", false) and not opt.get("reflect", false):
			_apply_damage(src, max(1.0, dmg * 0.15), "phys", null, {"reflect": true})
		# Уход в тень: раненый налётчик исчезает на несколько секунд
		if tp.has("vanish") and t["hp"] > 0.0 and t["hp"] < t["max_hp"] * 0.4 and not t.get("vanished", false):
			t["vanished"] = true
			t["cast"] = null
			add_effect(t, {"id": "hidden", "t": 3.0})
			_float(t, "Исчез!", Color(0.7, 0.7, 0.8))
	if src != null and src.get("champion", "") == "vampire" and src["alive"]:
		_heal(src, dmg * 0.6, null, false)
	if t["hp"] <= 0.0 and has_effect(t, "intercede"):
		t["hp"] = 1.0
		_float(t, "Заступничество", Color(1, 0.95, 0.6))
	if t["side"] == "hero" and t["key"] == "neris" and t["hp"] > 0.0 and t["hp"] < t["max_hp"] * 0.25 \
			and perk(t, "unleash") and not s["used"].has("unleash"):
		s["used"]["unleash"] = true
		add_effect(t, {"id": "voice", "t": 6.0})
		_float(t, "Голос на свободе", Color(0.85, 0.45, 1.0), true)
		_log("Нэрис отпускает Голос!")
	var col := Color(1, 0.35, 0.3) if t["side"] == "hero" else Color(1, 1, 1)
	if school == "shadow": col = Color(0.8, 0.5, 1.0)
	elif school == "fire": col = Color(1.0, 0.6, 0.2)
	elif school == "holy": col = Color(1.0, 0.95, 0.6)
	_float(t, "%d%s" % [int(dmg), "!" if opt.get("crit", false) else ""], col, opt.get("crit", false))
	if t["side"] == "enemy" and src != null and src["side"] == "hero":
		t["last_hit"] = src["key"]
	if t["hp"] <= 0.0:
		_kill(t)

## Средний уровень героев боя — от него считается урезание опыта за слабых врагов
func party_level() -> float:
	var n := 0
	var sum := 0.0
	for u in s["units"]:
		if u["side"] == "hero":
			n += 1
			sum += float(u.get("level", 1))
	return sum / n if n > 0 else 1.0

func _kill(t: Dictionary) -> void:
	if t["side"] == "hero" and not s["used"].has("lastrite"):
		var ai = hero_unit("aiden")
		if ai != null and ai["alive"] and ai != t and perk(ai, "lastrite"):
			s["used"]["lastrite"] = true
			t["hp"] = round(t["max_hp"] * 0.3)
			t["cast"] = null
			_float(t, "Последний обряд", Color(1, 0.95, 0.6), true)
			_log("Эйден читает последний обряд — %s встаёт!" % t["name"])
			return
	t["hp"] = 0.0
	t["alive"] = false
	t["cast"] = null
	t["task"] = null
	t["queued"] = null
	var was_cursed := has_effect(t, "curse_mark")
	t["effects"] = []
	if t["side"] == "hero":
		s["counters"]["ko"][t["key"]] = true
		_log("%s падает без сил!" % t["name"])
	else:
		var kp: Dictionary = t.get("pas", {})
		if kp.has("brood"):
			s["spawn_q"] = s.get("spawn_q", []) + [{"types": [["spiderling", t["level"]], ["spiderling", t["level"]]], "x": t["x"], "left": t["x"] < formation_center()}]
			_log("Из кладки высыпают паучки!")
		if kp.has("firepot"):
			for h in alive_of("hero"):
				if dist(h, t) <= 120.0:
					add_effect(h, {"id": "burn", "t": 4.0, "dps": max(2.0, t["dmg_max"] * 0.3), "school": "fire", "src": -1})
					_float(h, "Горит", Color(1, 0.55, 0.2))
		var xp_full := int(t["xp"])
		var xp_got := int(round(xp_full * DB.xp_factor(party_level(), int(t.get("level", s["level"])))))
		s["counters"]["xp"] += xp_got
		s["counters"]["xp_cut"] = int(s["counters"].get("xp_cut", 0)) + xp_full - xp_got
		s["counters"]["coins"] += int(t["coins"])
		var k: String = t.get("last_hit", "")
		if k != "":
			s["counters"]["kills"][k] = s["counters"]["kills"].get(k, 0) + 1
		if "boss" in t["tags"]:
			s["boss_alive"] = false
			_log("%s повержен!" % t["name"])
		if t.has("anchor_x"):
			# Обелиск разбит: все духи боя рассыпаются вместе с ним
			_log("%s рассыпается! Духи теряют опору." % t["name"])
			for o in alive_of("enemy"):
				if "phantom" in o["tags"] and o != t:
					o["hp"] = 0.0
					o["alive"] = false
					o["cast"] = null
					o["effects"] = []
					events.append({"type": "death", "uid": o["uid"]})
		if "champion" in t["tags"]:
			s["counters"]["champions"] = int(s["counters"].get("champions", 0)) + 1
			_log("Чемпион %s повержен!" % t["name"])
		if was_cursed:
			var n = hero_unit("neris")
			if n != null and n["alive"] and perk(n, "hunger"):
				n["mp"] = min(n["max_mp"], n["mp"] + 30.0)
				_float(n, "+30 МП", Color(0.5, 0.7, 1.0))
			if n != null and n["alive"] and perk(n, "leash"):
				var nb = null
				var nd := 1e9
				for e in alive_of("enemy"):
					if dist(e, t) < nd:
						nd = dist(e, t)
						nb = e
				if nb != null:
					_curse(n, nb)
		if s["focus"] == t["uid"]:
			s["focus"] = -1
		for h in s["units"]:
			if h["side"] == "hero" and int(h.get("focus", -1)) == t["uid"]:
				h["focus"] = -1
	events.append({"type": "death", "uid": t["uid"]})

func _heal(t: Dictionary, amt: float, src, crit_ok: bool) -> void:
	if not t["alive"]:
		return
	if has_effect(t, "burn_noheal"):
		amt *= 0.0
	var crit := false
	if crit_ok and src != null and rng.randf() * 100.0 < src["crit"]:
		amt *= 1.5
		crit = true
	var real: float = min(amt, t["max_hp"] - t["hp"])
	t["hp"] += real
	if real >= 1.0:
		_float(t, "+%d%s" % [int(real), "!" if crit else ""], Color(0.45, 1.0, 0.5), crit)
	if src != null and src["side"] == "hero" and t["side"] == "hero":
		s["counters"]["healing"] += int(real)
		_bh(src["key"])["heal"] += real
		if src["key"] == "aiden" and t["key"] != "aiden":
			s["counters"]["heal_by"][t["key"]] = s["counters"]["heal_by"].get(t["key"], 0) + int(real)

# ================================================================ Команды игрока
func ability_problem(uid: int, ab: String) -> String:
	var u = unit(uid)
	if u == null or not u["alive"]:
		return "Герой выбыл из боя."
	if s["phase"] != "fight":
		return "Сейчас нет боя."
	var a: Dictionary = DB.ABILITIES[ab]
	if is_stunned(u):
		return "Оглушён."
	if u["cast"] != null:
		return "Уже готовит приём."
	if u["task"] != null:
		return "Занят: %s." % ("ремонт" if u["task"]["type"] == "repair" else "тушение")
	var cost := ability_cost(u, ab)
	if u["atb"] < cost - 0.001:
		return "Нужно ATB: %d (есть %.1f)." % [cost, u["atb"]]
	if u["cds"].get(ab, 0.0) > 0.0:
		return "Перезарядка: %.1f с." % u["cds"][ab]
	var mp_need: float = a["mp"]
	if has_effect(u, "voice"):
		mp_need = 0.0
	if u["mp"] < mp_need:
		if ab == "bolt" and perk(u, "pact") and u["hp"] > u["max_hp"] * 0.2:
			return ""
		return "Мало маны: нужно %d." % int(mp_need)
	return ""

func ability_cost(u: Dictionary, ab: String) -> int:
	if ab == "bash" and perk(u, "stunner"):
		return 2
	return int(DB.ABILITIES[ab]["cost"])

func ability_cast_time(u: Dictionary, ab: String) -> float:
	var c: float = DB.ABILITIES[ab]["cast"]
	if has_effect(u, "voice"):
		return 0.0
	if ab == "aimed" and u.get("first_free", false):
		return 0.0
	if ab == "aimed" and perk(u, "quickdraw"):
		return 0.0
	if ab == "heal" and perk(u, "swiftprayer"):
		return c * 0.5
	return c

func _ability_range(u: Dictionary, ab: String) -> float:
	var a: Dictionary = DB.ABILITIES[ab]
	if a.get("melee", false):
		return u["range"] + 25.0
	if a["target"] in ["enemy", "ground"]:
		if not u["melee"]:
			return max(u["range"], RANGED_SKILL_REACH) + 20.0
		return max(u["range"], 340.0) + 20.0
	return 99999.0

## Умение по области: удар по точке дороги x. Возвращает "" при успехе или причину.
func use_ability_at(uid: int, ab: String, x: float) -> String:
	var p := ability_problem(uid, ab)
	if p != "":
		return p
	var u = unit(uid)
	var a: Dictionary = DB.ABILITIES[ab]
	if a["target"] != "ground":
		return "Это умение не бьёт по области."
	if absf(x - u["x"]) > _ability_range(u, ab):
		u["queued"] = {"ab": ab, "target": -1, "x": x}
		_float(u, "Сближается…", Color(0.9, 0.9, 0.7))
		return ""
	_pay(u, ab)
	var ct := ability_cast_time(u, ab)
	if ct > 0.0:
		u["cast"] = {"ab": ab, "name": a["name"], "t": 0.0, "total": ct, "target": -1, "x": x}
	else:
		_resolve_ability(u, ab, -1, x)
	return ""

## Враги, задетые областью радиуса r с центром в x (фигура задета краем).
func enemies_in_area(x: float, r: float) -> Array:
	var res := []
	for e in alive_of("enemy"):
		if absf(float(e["x"]) - x) <= r + BODY * 0.5:
			res.append(e)
	return res

## Применить умение. Возвращает "" при успехе или причину.
func use_ability(uid: int, ab: String, target_uid: int) -> String:
	var p := ability_problem(uid, ab)
	if p != "":
		return p
	var u = unit(uid)
	var a: Dictionary = DB.ABILITIES[ab]
	var t = unit(target_uid) if target_uid >= 0 else null
	if a["target"] == "ground":
		# Умение по области, вызванное по цели (ИИ, тесты): бьём туда, где она стоит
		if t == null or not t["alive"]:
			return "Нужна точка на дороге."
		return use_ability_at(uid, ab, float(t["x"]))
	if a["target"] == "enemy":
		if t == null or not t["alive"] or t["side"] != "enemy":
			return "Нужна живая вражеская цель."
		if in_dark(t):
			return "Враг во тьме."
		if dist(u, t) > _ability_range(u, ab):
			u["queued"] = {"ab": ab, "target": t["uid"]}
			_float(u, "Сближается…", Color(0.9, 0.9, 0.7))
			return ""
	elif a["target"] == "ally":
		if t == null or not t["alive"] or t["side"] != "hero":
			return "Нужен живой союзник."
	_pay(u, ab)
	var ct := ability_cast_time(u, ab)
	if ct > 0.0:
		u["cast"] = {"ab": ab, "name": a["name"], "t": 0.0, "total": ct, "target": target_uid}
	else:
		_resolve_ability(u, ab, target_uid)
	return ""

## Оплата умения: ATB, мана (или здоровье по Тёмному договору), перезарядка.
func _pay(u: Dictionary, ab: String) -> void:
	var a: Dictionary = DB.ABILITIES[ab]
	u["atb"] -= ability_cost(u, ab)
	if has_effect(u, "voice"):
		pass
	elif u["mp"] >= a["mp"]:
		u["mp"] -= a["mp"]
	else:
		# Тёмный договор
		u["hp"] = max(1.0, u["hp"] - u["max_hp"] * 0.15)
		_float(u, "Договор", Color(0.8, 0.4, 1.0))
	if a["cd"] > 0.0:
		u["cds"][ab] = a["cd"]
	u["queued"] = null

func _resolve_ability(u: Dictionary, ab: String, target_uid: int, at_x := NAN) -> void:
	var a: Dictionary = DB.ABILITIES[ab]
	var t = unit(target_uid) if target_uid >= 0 else null
	if a["target"] == "ground":
		if is_nan(at_x):
			at_x = float(t["x"]) if t != null else float(u["x"])
		events.append({"type": "cast_fx", "uid": u["uid"], "ab": ab})
		events.append({"type": "area_fx", "x": at_x, "r": float(a["area"]), "ab": ab, "uid": u["uid"]})
		_resolve_area(u, ab, at_x, enemies_in_area(at_x, float(a["area"])))
		return
	if a["target"] == "enemy" and (t == null or not t["alive"]):
		# Цель погибла во время подготовки — ближайший враг
		t = _hero_target(u)
		if t == null:
			_float(u, "Нет цели", Color(0.8, 0.8, 0.8))
			return
	if a["target"] == "ally" and (t == null or not t["alive"]):
		u["atb"] = min(2.0, u["atb"] + ability_cost(u, ab))
		u["mp"] = min(u["max_mp"], u["mp"] + a["mp"])
		_float(u, "Цель выбыла", Color(0.8, 0.8, 0.8))
		return
	events.append({"type": "cast_fx", "uid": u["uid"], "ab": ab})
	match ab:
		"taunt":
			var n := 0
			for e in alive_of("enemy"):
				if dist(u, e) <= 320.0:
					add_effect(e, {"id": "taunt", "t": 6.0, "src": u["uid"]})
					n += 1
			add_effect(u, {"id": "taunting", "t": 6.0})
			if perk(u, "warcry"):
				for e in alive_of("enemy"):
					if dist(u, e) <= 160.0:
						_interrupt(e, u)
						_direct_hit(u, e, 0.7, "phys", {"no_dodge": true})
				events.append({"type": "shake"})
			if perk(u, "bulwark"):
				add_effect(u, {"id": "barrier", "t": 6.0, "val": u["max_hp"] * 0.15, "orig": u["max_hp"] * 0.15, "src": u["uid"]})
			s["counters"]["taunts"] += 1
			_float(u, "Провокация (%d)" % n, Color(1, 0.8, 0.3))
		"bash":
			var mult := 1.5 if perk(u, "stunner") else 0.8
			_interrupt(t, u)
			_direct_hit(u, t, mult, "phys", {"no_dodge": true})
			if t["alive"]:
				add_effect(t, {"id": "stun", "t": 3.0 if perk(u, "stunner") else 1.5})
				_float(t, "Оглушён", Color(1, 1, 0.5))
		"wall":
			add_effect(u, {"id": "wall", "t": 7.0})
			if perk(u, "guardian"):
				add_effect(u, {"id": "guard", "t": 7.0})
			_float(u, "Стена щитов", Color(0.6, 0.8, 1.0))
		"cleave":
			for e in alive_of("enemy"):
				if e == t or dist(e, t) <= 110.0:
					_direct_hit(u, e, 1.2, "phys", {})
		"aimed":
			var m := 1.7 if perk(u, "quickdraw") else 2.2
			if perk(u, "predator") and ("beast" in t["tags"] or t["cast"] != null):
				m += 0.6
			u["first_free"] = false
			var cb := 100.0 if perk(u, "tavielsight") and has_effect(t, "vuln") else 40.0
			events.append({"type": "proj", "from": u["uid"], "to": t["uid"], "kind": "big_arrow"})
			_direct_hit(u, t, m, "phys", {"crit_bonus": cb, "no_dodge": true})
		"pin":
			events.append({"type": "proj", "from": u["uid"], "to": t["uid"], "kind": "arrow"})
			_interrupt(t, u)
			_direct_hit(u, t, 1.6 if perk(u, "thorns") else 0.9, "phys", {"no_dodge": true})
			if t["alive"]:
				add_effect(t, {"id": "slow", "t": 5.0, "val": 0.4})
				if perk(u, "thorns"):
					add_effect(t, {"id": "root", "t": 2.0})
				_float(t, "Замедлен", Color(0.6, 0.9, 0.6))
		"mark":
			add_effect(t, {"id": "vuln", "t": 8.0, "val": 0.25})
			_float(t, "Метка", Color(1, 0.6, 0.3))
			if perk(u, "twinmark"):
				var best = null
				var bd := 1e9
				for e in alive_of("enemy"):
					if e != t and dist(e, t) < bd:
						bd = dist(e, t)
						best = e
				if best != null:
					add_effect(best, {"id": "vuln", "t": 8.0, "val": 0.25})
					_float(best, "Метка", Color(1, 0.6, 0.3))
		"bolt":
			events.append({"type": "proj", "from": u["uid"], "to": t["uid"], "kind": "big_shadow"})
			_direct_hit(u, t, 1.0, "shadow", {"base": u["sp"] * 2.0 + 12.0, "no_dodge": true, "spell": true})
		"drain":
			events.append({"type": "proj", "from": u["uid"], "to": t["uid"], "kind": "shadow"})
			var before: float = t["hp"]
			_direct_hit(u, t, 1.0, "shadow", {"base": u["sp"] * 1.2 + 8.0, "no_dodge": true, "spell": true})
			_heal(u, max(0.0, before - max(0.0, t["hp"])), u, false)
		"heal":
			var amt: float = 30.0 + u["sp"] * 2.2
			if perk(u, "consecrate") and has_effect(t, "barrier"):
				amt *= 1.35
				var b = get_effect(t, "barrier")
				b["val"] = min(b["orig"], b["val"] + b["orig"] * 0.3)
				b["t"] = max(b["t"], 6.0)
			_heal(t, amt * rng.randf_range(0.93, 1.07), u, true)
		"ward":
			var cap: float = 40.0 + u["sp"] * 1.6
			add_effect(t, {"id": "barrier", "t": 12.0, "val": cap, "orig": cap, "src": u["uid"], "radiance": perk(u, "radiance")})
			s["counters"]["wards"] += 1
			_float(t, "Щит света", Color(1, 0.92, 0.55))
		"renew":
			var total: float = 25.0 + u["sp"] * 1.5
			add_effect(t, {"id": "hot", "t": 10.0, "hps": total / 10.0, "src": u["uid"]})
			_float(t, "Обновление", Color(0.6, 1.0, 0.6))
			if perk(u, "compassion"):
				var low = null
				var lr := 2.0
				for h in alive_of("hero"):
					if h != t and h["hp"] / h["max_hp"] < lr:
						lr = h["hp"] / h["max_hp"]
						low = h
				if low != null:
					add_effect(low, {"id": "hot", "t": 10.0, "hps": total / 10.0, "src": u["uid"]})
					_float(low, "Обновление", Color(0.6, 1.0, 0.6))
		"prayer":
			for h in alive_of("hero"):
				_heal(h, (20.0 + u["sp"] * 1.4) * rng.randf_range(0.93, 1.07), u, true)
				if perk(u, "dawn"):
					remove_effect(h, "burn")
					remove_effect(h, "dot")
					var cap2: float = (40.0 + u["sp"] * 1.6) * 0.5
					var cur = get_effect(h, "barrier")
					if cur == null or cur["val"] < cap2:
						add_effect(h, {"id": "barrier", "t": 12.0, "val": cap2, "orig": cap2, "src": u["uid"], "radiance": perk(u, "radiance")})
		"banner":
			for h in alive_of("hero"):
				if h != u:
					h["atb"] = min(2.0, h["atb"] + 1.0)
				add_effect(h, {"id": "rally", "t": 6.0})
				_float(h, "Знамя!", Color(1, 0.85, 0.35))
			_log("Марек поднимает знамя гильдии!")
		"deadeye":
			events.append({"type": "proj", "from": u["uid"], "to": t["uid"], "kind": "big_arrow"})
			if t["hp"] < t["max_hp"] * 0.3 and not "boss" in t["tags"]:
				_float(t, "В сердце!", Color(1, 0.4, 0.3), true)
				_apply_damage(t, t["hp"] + 1.0, "true", u, {"crit": true})
				if t["alive"]:
					_kill(t)
			else:
				_direct_hit(u, t, 3.5, "phys", {"no_dodge": true})
		"doom":
			add_effect(t, {"id": "doom", "t": 5.0, "src": u["uid"]})
			_float(t, "Рок", Color(0.8, 0.45, 1.0), true)
		"intercede":
			add_effect(t, {"id": "intercede", "t": 6.0})
			_float(t, "Заступничество", Color(1, 0.95, 0.6))

## Умения по области: `hit` — враги, задетые областью в точке x.
func _resolve_area(u: Dictionary, ab: String, x: float, hit: Array) -> void:
	match ab:
		"volley":
			for e in hit:
				events.append({"type": "proj", "from": u["uid"], "to": e["uid"], "kind": "arrow"})
				_direct_hit(u, e, 1.0, "phys", {})
		"curse":
			for e in hit:
				_curse(u, e)
			s["counters"]["curses"] += 1
		"hellfire":
			for e in hit:
				events.append({"type": "proj", "from": u["uid"], "to": e["uid"], "kind": "fire"})
				_direct_hit(u, e, 1.0, "fire", {"base": u["sp"] * 1.4 + 10.0, "no_dodge": true, "spell": true})
				if e["alive"]:
					var dur := 10.0 if perk(u, "wildfire") else 5.0
					add_effect(e, {"id": "burn", "t": dur, "dps": u["sp"] * 0.2 + 2.0, "school": "fire", "src": u["uid"]})
					if perk(u, "wildfire"):
						add_effect(e, {"id": "burn_noheal", "t": dur})
	if hit.is_empty():
		_float(u, "Мимо", Color(0.8, 0.8, 0.8))

## Проклятие слабости на одного врага (умение и перк «Обуздать Голос»)
func _curse(u: Dictionary, e: Dictionary) -> void:
	var dps: float = (u["sp"] * 0.25 + 3.0) * (2.0 if perk(u, "hunger") else 1.0)
	add_effect(e, {"id": "weak", "t": 8.0})
	add_effect(e, {"id": "dot", "t": 8.0, "dps": dps, "school": "shadow", "src": u["uid"]})
	add_effect(e, {"id": "curse_mark", "t": 8.0})
	if perk(u, "brittle"):
		var cur = get_effect(e, "vuln")
		if cur == null or cur["val"] < 0.15:
			add_effect(e, {"id": "vuln", "t": 8.0, "val": 0.15})
	_float(e, "Проклятие", Color(0.75, 0.45, 1.0))

func _interrupt(t: Dictionary, by: Dictionary) -> void:
	if t["cast"] != null and t["side"] == "enemy":
		_log("%s сорвал(а) «%s»!" % [by["name"], t["cast"]["name"]])
		_float(t, "Прервано!", Color(1, 1, 0.3), true)
		t["cast"] = null
		s["counters"]["interrupts"] += 1
		if by["side"] == "hero":
			_bh(by["key"])["int"] += 1

func set_focus(uid: int) -> void:
	var t = unit(uid)
	if t != null and t["alive"] and t["side"] == "enemy":
		s["focus"] = uid if s["focus"] != uid else -1

func set_order(o: String) -> void:
	s["order"] = o
	_log("Приказ: %s." % ("сблизиться с целью" if o == "advance" else "держать строй"))

func potion_problem(uid: int, kind: String, target_uid: int) -> String:
	var u = unit(uid)
	if u == null or not u["alive"]:
		return "Герой выбыл."
	if is_stunned(u) or u["cast"] != null or u["task"] != null:
		return "Герой занят."
	if u["atb"] < 0.999:
		return "Нужен 1 заряд ATB."
	if int(s["potions"].get(kind, 0)) <= 0:
		return "Зелий не осталось."
	var t = unit(target_uid)
	if t == null or t["side"] != "hero":
		return "Нужен союзник."
	if not t["alive"]:
		return "Зелья не воскрешают."
	return ""

func use_potion(uid: int, kind: String, target_uid: int) -> String:
	var p := potion_problem(uid, kind, target_uid)
	if p != "":
		return p
	var u = unit(uid)
	var t = unit(target_uid)
	u["atb"] -= 1.0
	s["potions"][kind] = int(s["potions"][kind]) - 1
	s["counters"]["potions"] += 1
	events.append({"type": "cast_fx", "uid": t["uid"], "ab": "potion"})
	if kind == "potion_hp":
		var real: float = min(t["max_hp"] * 0.45, t["max_hp"] - t["hp"])
		t["hp"] += real
		_float(t, "+%d" % int(real), Color(0.45, 1.0, 0.5))
	else:
		var r2: float = min(t["max_mp"] * 0.45, t["max_mp"] - t["mp"])
		t["mp"] += r2
		_float(t, "+%d МП" % int(r2), Color(0.5, 0.7, 1.0))
	_log("%s использует %s → %s." % [u["name"], DB.consumable_name(kind).to_lower(), t["name"]])
	return ""

# ---------------------------------------------------------------- Ремонт и тушение
func task_problem(uid: int, kind: String, obj: String) -> String:
	var u = unit(uid)
	if u == null or not u["alive"]:
		return "Герой выбыл."
	if not s["objects"].has(obj):
		return "Здесь нечего чинить."
	var o: Dictionary = s["objects"][obj]
	if o["hp"] <= 0.0:
		return "Уже разрушено."
	if u["task"] != null:
		return "Уже занят делом."
	if kind == "repair":
		if obj == "wagon" and s["kits"] <= 0:
			return "Нет ремонтных комплектов."
		if obj == "gate" and s["materials"] <= 0:
			return "Нет материалов."
		if obj == "chest":
			return "Сундук не чинят — только тушат."
		if o["hp"] >= o["max"]:
			return "Прочность полная."
	elif kind == "extinguish":
		if o["burning"] <= 0.0:
			return "Огня нет."
	return ""

func start_task(uid: int, kind: String, obj: String) -> String:
	var p := task_problem(uid, kind, obj)
	if p != "":
		return p
	var u = unit(uid)
	if s["phase"] == "prep":
		# Между волнами работа выполняется сразу
		_finish_task(u, {"type": kind, "obj": obj, "t": 0.0, "total": 0.0})
		return ""
	u["cast"] = null
	u["queued"] = null
	u["task"] = {"type": kind, "obj": obj, "t": 0.0, "total": 4.0 if kind == "repair" else 3.0}
	_log("%s: %s." % [u["name"], "ремонт — герой выведен из боя" if kind == "repair" else "тушит пожар"])
	return ""

func cancel_task(uid: int) -> void:
	var u = unit(uid)
	if u != null and u["task"] != null:
		u["task"] = null
		_float(u, "Отмена", Color(0.9, 0.9, 0.9))

func _finish_task(u: Dictionary, tk: Dictionary) -> void:
	var o: Dictionary = s["objects"][tk["obj"]]
	if tk["type"] == "repair":
		if tk["obj"] == "wagon":
			s["kits"] -= 1
		else:
			s["materials"] -= 1
		o["hp"] = min(o["max"], o["hp"] + o["max"] * 0.2)
		_float_obj(tk["obj"], "+20%", Color(0.5, 1.0, 0.5))
		_log("%s: ремонт завершён." % u["name"])
	else:
		o["burning"] = 0.0
		_float_obj(tk["obj"], "Потушено", Color(0.6, 0.85, 1.0))
		_log("%s потушил(а) огонь." % u["name"])
	u["task"] = null

# ---------------------------------------------------------------- Конец боя
func _check_end() -> void:
	if alive_of("hero").is_empty():
		s["phase"] = "lost"
		s["loss"] = "Отряд пал."
		_log(s["loss"])
		return
	for k in ["wagon", "gate"]:
		if s["objects"].has(k) and s["objects"][k]["hp"] <= 0.0:
			s["phase"] = "lost"
			s["loss"] = "Повозка разбита." if k == "wagon" else "Ворота пали."
			_log(s["loss"])
			return
	if alive_of("enemy").is_empty() and s["pending"].is_empty():
		if int(s.get("rwave", 0)) < s.get("rwaves", []).size():
			return
		if s["mode"] == "outpost" and s["wave"] < s["waves"].size():
			s["phase"] = "prep"
			# Между волнами: снять эффекты боя, кроме пожара объектов
			for u in s["units"]:
				u["cast"] = null
				u["queued"] = null
				u["task"] = null
			_log("Волна отбита. Передышка перед следующей атакой.")
		else:
			s["phase"] = "won"
			_log("Победа!")

func is_over() -> bool:
	return s["phase"] in ["won", "lost"]
