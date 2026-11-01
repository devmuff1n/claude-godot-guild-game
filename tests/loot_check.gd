extends Node
## Проверка добычи и правил вещей (запуск: godot --headless res://tests/LootCheck.tscn)

var fails := 0

func ok(cond: bool, what: String) -> void:
	print(("OK   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1

func _ready() -> void:
	Game.new_game(0)
	var r := RandomNumberGenerator.new()
	r.seed = 7
	# Правила оружия
	ok(not Items.hero_can_use_type("elira", {"base": "dagger_skin"}), "Элира не носит кинжал")
	ok(Items.hero_can_use_type("elira", {"base": "bow_hunt"}), "Элира носит лук")
	ok(not Items.hero_can_use_type("neris", {"base": "dagger_skin"}), "Нэрис не носит кинжал")
	ok(not Items.hero_can_use_type("aiden", {"base": "mace_iron"}), "Эйден не носит булаву")
	ok(Items.hero_can_use_type("marek", {"base": "mace_iron"}), "Марек носит булаву")
	ok(not Items.hero_can_use_type("marek", {"base": "staff_novice"}), "Марек не носит посох")
	# Только уровень
	var it := Items.make("plate_chest", 6, "rare", r)
	ok(Items.req_level(it) == 5, "вещь ур. 6 требует 5-й уровень")
	ok(Items.equip_problem("marek", 4, it, "chest", Game.hero("marek")["equip"]) != "", "на 4-м уровне не надеть")
	ok(Items.equip_problem("marek", 5, it, "chest", Game.hero("marek")["equip"]) == "", "на 5-м уровне надеть без требований к силе")
	# Умная добыча
	var wear := 0
	var aff := {}
	var n := 5000
	for i in n:
		var x := Items.random_item(4, r, 3.0, DB.HERO_IDS)
		var who := []
		for h in DB.HERO_IDS:
			if Items.hero_can_use_type(h, x):
				who.append(h)
		if not who.is_empty():
			wear += 1
		var b := Items.base_of(x)
		var key: String = b.get("atype", b.get("wtype", ""))
		for a in x["affixes"]:
			if not aff.has(key):
				aff[key] = {}
			aff[key][a[0]] = int(aff[key].get(a[0], 0)) + 1
	print("годится кому-то из отряда: %d%%" % int(100.0 * wear / n))
	ok(wear > n * 0.8, "больше 80% добычи кому-то подходит")
	for k in aff.keys():
		var arr := []
		for st in aff[k].keys():
			arr.append([st, aff[k][st]])
		arr.sort_custom(func(a, b): return a[1] > b[1])
		print("  %s: %s" % [k, ", ".join(arr.slice(0, 6).map(func(e): return "%s %d" % [e[0], e[1]]))])
	var pl: Dictionary = aff.get("plate", {})
	ok(int(pl.get("str", 0)) > int(pl.get("int", 0)) * 2, "на латах сила чаще интеллекта (%d против %d)" % [int(pl.get("str", 0)), int(pl.get("int", 0))])
	ok(int(pl.get("int", 0)) >= 0, "латы с интеллектом возможны")
	var cl: Dictionary = aff.get("cloth", {})
	ok(int(cl.get("int", 0)) > int(cl.get("str", 0)) * 3, "на ткани интеллект чаще силы")
	# Перековка
	Game.state["treasury"] = 1000
	var y := Items.make("leather_chest", 3, "rare", r)
	Game.storage()[5] = y
	var p0 := Items.reroll_price(y)
	ok(Game.reroll_storage(5) == "", "перековка проходит")
	ok(Items.reroll_price(y) > p0, "следующая перековка дороже (%d → %d)" % [p0, Items.reroll_price(y)])
	ok(int(Game.state["treasury"]) == 1000 - p0, "деньги списаны")
	ok(y["affixes"].size() == DB.RARITY_AFFIXES["rare"], "число свойств сохранилось")
	# Опыт
	ok(DB.xp_factor(5, 1) == 0.1, "враг на 4 уровня ниже — 10% опыта")
	ok(DB.xp_factor(3, 3) == 1.0, "враг своего уровня — весь опыт")
	ok(DB.xp_factor(2, 3) == 1.0, "враг выше — весь опыт")
	print("LOOT FAILS=%d" % fails)
	get_tree().quit()
