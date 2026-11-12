extends Node
## Стройка и Кузница: стройка открывается, когда делегация c8 уходит в столицу; заточка, разборка, реагенты
## (запуск: godot --headless --path . res://tests/BuildCheck.tscn)

var fails := 0

func ok(cond: bool, what: String) -> void:
	print(("OK   " if cond else "FAIL ") + what)
	if not cond:
		fails += 1

func _ready() -> void:
	Game.slot = -1
	Game.state = Game._fresh_state()
	ok(Game.building_built("GuildHall"), "Дом гильдии стоит с начала")
	ok(not Game.building_built("PartyInn"), "Дом отряда до c1 не стоит")
	Game.state["completed"]["c1"] = 1
	ok(Game.building_built("PartyInn") and not Game.feature_open("shop"), "после c1 Дом отряда стоит сам, лавки ещё нет")
	Game.state["completed"]["c2"] = 1
	ok(Game.feature_open("shop") and Game.building_built("Market"), "после c2 открыта лавка (рынок стоит сам)")
	for c in ["c3", "c4", "c5", "c6", "c7"]:
		Game.state["completed"][c] = 1
	ok(not Game.feature_open("forge") and not Game.feature_open("arena"), "до c8 нет кузницы и арены")
	ok(not Game.feature_open("build"), "до отправки делегации нет стройки")
	Game.state["treasury"] = 5000
	ok(Game.build("Smithy") != "", "до отправки делегации кузницу не построить")
	# Делегация уходит: два дня пути, стройка открыта
	ok(Game.start_diplomacy("c8") == "" and Game.dip_traveling() and Game.dip_days() == DB.DIPLO_TRAVEL_DAYS, "делегация в пути %d дня" % Game.dip_days())
	ok(Game.feature_open("build") and Game.buildable_count() == 1, "в пути открыта стройка, строится одна кузница")
	ok(Game.dip_choose(0).is_empty(), "в пути сцены миссии не начинаются")
	ok(Game.start_expedition("c1", {"purse": 0}) != "", "пока делегация в пути, походов нет")
	ok(Game.build("Alchemist") != "" and Game.build("TrainingYard") != "", "другие здания пока не строятся")
	ok(not Game.feature_open("forge"), "Кузницы нет, пока не построена")
	var t0 := int(Game.state["treasury"])
	ok(Game.build("Smithy") == "" and int(Game.state["treasury"]) == t0 - int(DB.BUILDINGS["Smithy"]["price"]), "кузница построена за свою цену")
	ok(Game.feature_open("forge") and Game.build("Smithy") != "", "кузница открыта, второй раз не строится")
	ok(not Game.feature_open("arena"), "арены нет")
	Game.dip_wait_day()
	Game.dip_wait_day()
	ok(not Game.dip_traveling() and not Game.dip_choose(0).is_empty(), "через два дня делегация на месте")
	Game.state["diplomacy"] = null
	# Реагенты и заточка
	var r := RandomNumberGenerator.new()
	r.seed = 5
	var sw: Dictionary = Game.hero("marek")["equip"]["main"]
	var s0 := Items.stats(sw)
	ok(Game.sharpen(sw) != "", "без реагентов не точится")
	Game.add_reagents({"scrap": 40, "hide": 40, "ash": 20})
	for i in DB.SHARPEN_MAX:
		var why := Game.sharpen(sw)
		ok(why == "", "заточка +%d %s" % [i + 1, why])
	var s5 := Items.stats(sw)
	ok(int(s5["dmg_max"]) > int(s0["dmg_max"]) and Items.display_name(sw).ends_with("+5"), "урон %d → %d, имя «%s»" % [s0["dmg_max"], s5["dmg_max"], Items.display_name(sw)])
	ok(Game.sharpen(sw) != "", "выше +%d не точится" % DB.SHARPEN_MAX)
	ok(Game.reagent_count("scrap") == 40 - (2 + 4 + 6 + 8 + 10) and Game.reagent_count("ash") == 20 - (1 + 2 + 3), "реагенты списаны (лом %d, пепел %d)" % [Game.reagent_count("scrap"), Game.reagent_count("ash")])
	Game.state["storage"][10] = Items.make("ring_silver", 6, "rare", r)
	var y := Game.salvage_yield(Game.state["storage"][10])
	var ash0 := Game.reagent_count("ash")
	ok(Game.salvage_storage(10) == "" and Game.state["storage"][10] == null and Game.reagent_count("ash") == ash0 + int(y["ash"]), "разборка кольца: %s" % Game.reagents_text(y))
	# Добыча реагентов в бою
	var sim := BattleSim.new()
	sim.setup({})
	sim.drop_rng.seed = 1
	for i in 40:
		sim._drop_reagents({"tags": ["beast"]})
	sim._drop_reagents({"tags": ["human", "boss"]})
	sim._drop_reagents({"tags": ["beast", "minion"]})
	var got: Dictionary = sim.s["counters"]["reagents"]
	ok(int(got.get("hide", 0)) > 10 and int(got.get("scrap", 0)) == 3 and int(got.get("ash", 0)) == 2, "с врагов: %s" % Game.reagents_text(got))

	var snapshot: Dictionary = str_to_var(var_to_str(sim.save_state()))
	var resumed := BattleSim.new()
	resumed.load_state(snapshot)
	ok(resumed.drop_rng.state == sim.drop_rng.state, "снимок восстанавливает позицию генератора реагентов")
	var same_drops := true
	for i in 20:
		sim._drop_reagents({"tags": ["beast"]})
		resumed._drop_reagents({"tags": ["beast"]})
		same_drops = same_drops and resumed.s["counters"]["reagents"] == sim.s["counters"]["reagents"]
	ok(same_drops, "после загрузки реагенты выпадают в той же последовательности")

	snapshot.erase("drop_rng_state")
	resumed.load_state(snapshot)
	var legacy_rng := RandomNumberGenerator.new()
	legacy_rng.seed = int(snapshot["rng_seed"]) ^ 0x5eed
	ok(resumed.drop_rng.state == legacy_rng.state and resumed.s["counters"]["reagents"] == snapshot["counters"]["reagents"],
		"старый снимок сохраняет накопленные реагенты и запускает генератор от исходного seed")

	Game.refresh_shop()
	ok(Game.state["shop"]["stock"].size() == DB.SHOP_STOCK + 2, "кузница: в лавке на 2 вещи больше")
	ok(Game.recruit_candidates().is_empty(), "новых героев пока нет")
	print("BUILD FAILS=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
