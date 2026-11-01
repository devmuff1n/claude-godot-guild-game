class_name Stats
extends RefCounted
## Характеристики героев: естественные (по уровню) и итоговые (с экипировкой).

const PRIMARY := ["sta", "str", "agi", "int"]

## Собственные атрибуты: рост за уровень (DB.HEROES → grow). alloc — бонус сверху, игрой не используется (для тестов)
static func natural(hero_id: String, level: int, alloc: Dictionary = {}) -> Dictionary:
	var h: Dictionary = DB.HEROES.get(hero_id, {})
	var res := {}
	if h.is_empty():
		return res
	for k in PRIMARY:
		res[k] = int(floor(h["base"][k] + h["grow"][k] * float(level - 1))) + int(alloc.get(k, 0))
	return res

## equip: slot -> item или null; perks не влияют на числа (меняют поведение умений)
static func derive(hero_id: String, level: int, equip: Dictionary, alloc: Dictionary = {}) -> Dictionary:
	var nat := natural(hero_id, level, alloc)
	var gear := {}
	for slot in DB.SLOTS:
		var it = equip.get(slot)
		if it == null:
			continue
		var s := Items.stats(it)
		for k in s.keys():
			if k in ["dmg_min", "dmg_max", "interval", "range"]:
				continue
			gear[k] = gear.get(k, 0.0) + float(s[k])
	var p := {}
	for k in PRIMARY:
		p[k] = int(nat[k] + gear.get(k, 0.0))
	var d := {"level": level, "sta": p["sta"], "str": p["str"], "agi": p["agi"], "int": p["int"]}
	# Как в Classic: 10 здоровья за единицу выносливости плюс базовое здоровье уровня
	d["max_hp"] = int(20 + 12 * (level - 1) + p["sta"] * 10 + gear.get("hp", 0.0))
	d["max_mp"] = int(60 + p["int"] * 12 + gear.get("mp", 0.0))
	d["mp_regen"] = 1.5 + d["max_mp"] * 0.012
	d["sp"] = p["int"] * 1.0 + gear.get("sp", 0.0)
	d["armor"] = int(gear.get("armor", 0.0) + p["agi"] * 2.0)
	d["crit"] = 5.0 + p["agi"] * 0.08 + gear.get("crit", 0.0)
	d["hit"] = min(100.0, 95.0 + gear.get("hit", 0.0))
	d["dodge"] = 3.0 + p["agi"] * 0.1 + gear.get("dodge", 0.0)
	d["res_fire"] = gear.get("res_fire", 0.0)
	d["res_shadow"] = gear.get("res_shadow", 0.0)
	d["res_nature"] = gear.get("res_nature", 0.0)
	d["res_holy"] = gear.get("res_holy", 0.0)
	# Оружие
	var main = equip.get("main")
	var wtype := "fist"
	var dmin := 3.0
	var dmax := 5.0
	d["interval"] = 2.0
	d["range"] = 65.0
	if main != null:
		var ms := Items.stats(main)
		var mb := Items.base_of(main)
		wtype = mb.get("wtype", "fist")
		dmin = ms.get("dmg_min", 3)
		dmax = ms.get("dmg_max", 5)
		d["interval"] = ms.get("interval", 2.0)
		d["range"] = ms.get("range", 65.0)
	var bonus := 0.0
	var school := "phys"
	match wtype:
		"sword", "mace", "axe", "dagger", "fist":
			bonus = p["str"] * 0.45
		"bow":
			bonus = p["agi"] * 0.45
		"staff":
			bonus = p["int"] * 0.3 + gear.get("sp", 0.0) * 0.3
			school = DB.HEROES[hero_id]["school"]
	d["wtype"] = wtype
	d["school"] = school
	d["dmg_min"] = int(round(dmin + bonus))
	d["dmg_max"] = int(round(dmax + bonus))
	d["melee"] = wtype in ["sword", "mace", "axe", "dagger", "fist"]
	# Парирование: только с подходящим оружием ближнего боя
	if wtype in ["sword", "mace", "axe", "dagger"]:
		d["parry"] = 5.0 + p["str"] * 0.05 + gear.get("parry", 0.0)
	else:
		d["parry"] = 0.0
	# Блок: только со щитом
	var off = equip.get("off")
	if off != null and Items.base_of(off).get("wtype", "") == "shield":
		d["block"] = gear.get("block", 0.0) + 2.0
		d["block_val"] = int(gear.get("block_val", 0.0) + p["str"] * 0.3)
	else:
		d["block"] = 0.0
		d["block_val"] = 0
	return d

## Грубая «сила» героя для сравнения снаряжения (стрелка улучшения, «Надеть лучшее»).
## Защитник — живучесть и немного урона, лучница — урон из лука, заклинатели — сила заклинаний и мана.
static func power(hero_id: String, level: int, equip: Dictionary, alloc: Dictionary = {}) -> float:
	var d := derive(hero_id, level, equip, alloc)
	var red := armor_reduction(float(d["armor"]), level)
	var ehp: float = d["max_hp"] / (1.0 - red) * (1.0 + (d["dodge"] + d["parry"] + d["block"] * 0.5) / 100.0)
	var dps: float = (d["dmg_min"] + d["dmg_max"]) * 0.5 / d["interval"] * (1.0 + d["crit"] / 100.0 * 0.75)
	var res: float = (d["res_fire"] + d["res_shadow"] + d["res_nature"]) * 0.5
	var hero: Dictionary = DB.HEROES[hero_id]
	if "shield" in hero["weapons"]:
		return ehp + 12.0 * dps + res
	if "bow" in hero["weapons"]:
		return ehp * 0.4 + 40.0 * dps * d["hit"] / 100.0 + res
	return ehp * 0.4 + d["sp"] * 9.0 + d["max_mp"] * 0.4 + d["crit"] * 6.0 + res

## Формула Classic WoW: броня / (броня + 400 + 85 × уровень атакующего), уровень по шкале WoW
static func armor_reduction(armor: float, attacker_level: int) -> float:
	var w: float = float(DB.wow_level(attacker_level))
	return clamp(armor / (armor + 400.0 + 85.0 * w), 0.0, 0.75)

static func resist_reduction(res: float) -> float:
	return clamp(res / (res + 50.0), 0.0, 0.75)
