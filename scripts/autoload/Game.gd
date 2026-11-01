extends Node
## Постоянное состояние гильдии, сохранения, экономика, развитие, поход и отношения.

signal changed
signal toast(text: String)

const SAVE_DIR := "user://saves/"
const SLOT_COUNT := 3
const SAVE_VERSION := 1

var state: Dictionary = {}
var slot: int = -1
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func notify(text: String) -> void:
	toast.emit(text)

func next_uid() -> int:
	if state.is_empty():
		return rng.randi()
	state["next_uid"] = int(state.get("next_uid", 1)) + 1
	return state["next_uid"]

# ================================================================ Слоты сохранений
func slot_path(i: int) -> String:
	return SAVE_DIR + "slot_%d.save" % i

func slot_info(i: int) -> Dictionary:
	var p := slot_path(i)
	if not FileAccess.file_exists(p):
		return {}
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {}
	var data = str_to_var(f.get_as_text())
	if not (data is Dictionary):
		return {"broken": true}
	var st: Dictionary = data
	var info := {"treasury": st.get("treasury", 0), "story": st.get("story_stage", 0), "saved": st.get("saved_at", ""),
		"exp": st.get("expedition") != null, "levels": [], "chapter_done": st.get("chapter_done", false)}
	if st.get("expedition") != null:
		info["exp_name"] = DB.CONTRACTS.get(st["expedition"]["cid"], {}).get("name", "")
	for h in DB.HERO_IDS:
		info["levels"].append(int(st["heroes"][h]["level"]))
	return info

func new_game(i: int) -> void:
	slot = i
	state = _fresh_state()
	save()

func load_slot(i: int) -> bool:
	var p := slot_path(i)
	if not FileAccess.file_exists(p):
		return false
	var f := FileAccess.open(p, FileAccess.READ)
	var data = str_to_var(f.get_as_text())
	if not (data is Dictionary):
		return false
	state = data
	slot = i
	_migrate()
	return true

func delete_slot(i: int) -> void:
	if FileAccess.file_exists(slot_path(i)):
		DirAccess.remove_absolute(slot_path(i))

func save() -> void:
	if slot < 0 or state.is_empty() or state.get("arena_only", false):
		return
	state["saved_at"] = Time.get_datetime_string_from_system(false, true)
	var tmp := slot_path(slot) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Не удалось сохранить")
		return
	f.store_string(var_to_str(state))
	f.close()
	var target := slot_path(slot)
	if FileAccess.file_exists(target):
		DirAccess.remove_absolute(target)
	var err := DirAccess.rename_absolute(tmp, target)
	if err != OK:
		# Запасной путь: прямая запись
		var f2 := FileAccess.open(target, FileAccess.WRITE)
		if f2 != null:
			f2.store_string(var_to_str(state))
			f2.close()

func _migrate() -> void:
	var fresh := _fresh_state()
	for k in fresh.keys():
		if not state.has(k):
			state[k] = fresh[k]
	for id in state.get("heroes", {}).keys():
		# Ручное распределение очков атрибутов убрано: рост атрибутов теперь целиком в DB.HEROES → grow
		state["heroes"][id].erase("alloc")
	_unequip_forbidden()

## Снять вещи, которые герой по правилам не носит (правила брони менялись) — в кладовую или в очередь выдачи.
## Посреди похода не трогаем: снаряжение там зафиксировано, снимем при следующей загрузке в деревне.
func _unequip_forbidden() -> void:
	if state.get("expedition") != null:
		return
	for id in state.get("heroes", {}).keys():
		var eq: Dictionary = state["heroes"][id]["equip"]
		for sl in eq.keys():
			var it = eq[sl]
			if it != null and not Items.hero_can_use_type(id, it):
				eq[sl] = null
				add_item(it)

func _fresh_state() -> Dictionary:
	var st := {
		"version": SAVE_VERSION, "next_uid": 100, "treasury": 120, "trust": 0, "story_stage": 0,
		"completed": {}, "premium_claimed": {}, "jxp_claimed": {}, "flags": {}, "chapter_done": false,
		"heroes": {}, "storage": [], "queue": [], "potions": {"potion_hp": 3, "potion_mp": 2, "kit": 0},
		"backpack": {"apple": 1, "bread": 1}, "shop": {"stock": [], "buyback": [], "gen": 0},
		"formation": ["marek", "aiden", "neris", "elira"],
		"relations": {}, "knowledge": {"facts": {}, "prefs": {}}, "topics_done": {}, "pair_done": {},
		"pending_choice": [], "expedition": null, "last_result": {}, "news": [], "saved_at": "",
		"intro_seen": false, "ending_seen": false, "diplomacy": null, "cutscenes_seen": {},
	}
	var prev := state
	state = st  # next_uid нужен для генерации
	st["storage"].resize(DB.STORAGE_SIZE)
	for i in DB.STORAGE_SIZE:
		st["storage"][i] = null
	var r := RandomNumberGenerator.new()
	r.seed = 12345
	var start_gear := {
		"aiden": [["staff_novice", "main"], ["cloth_chest", "chest"], ["cloth_feet", "feet"]],
		"marek": [["sword_rusty", "main"], ["shield_wood", "off"], ["mail_chest", "chest"], ["mail_feet", "feet"]],
		"elira": [["bow_hunt", "main"], ["leather_chest", "chest"], ["leather_feet", "feet"]],
		"neris": [["staff_novice", "main"], ["cloth_chest", "chest"], ["cloth_head", "head"]],
	}
	for h in DB.HERO_IDS:
		var eq := {}
		for sl in DB.SLOTS:
			eq[sl] = null
		for g in start_gear[h]:
			eq[g[1]] = Items.make(g[0], 1, "common", r)
		st["heroes"][h] = {"level": 1, "xp": 0, "job": 1, "jxp": 0, "perks": {1: "", 2: "", 3: ""}, "equip": eq}
	st["storage"][0] = Items.make("leather_hands", 1, "common", r)
	st["storage"][1] = Items.make("cloth_hands", 1, "uncommon", r)
	st["storage"][2] = Items.make("ring_copper", 1, "common", r)
	st["storage"][3] = Items.make("leather_head", 1, "common", r)
	var init_rel := {"aiden|marek": 5, "aiden|elira": 5, "aiden|neris": 0, "marek|elira": 5, "marek|neris": -5, "elira|neris": 3}
	for pk in DB.all_pairs():
		st["relations"][pk] = {"friend": init_rel.get(pk, 0), "romance": 0, "history": []}
	for h in DB.COMPANIONS:
		st["knowledge"]["prefs"][h] = {}
	_gen_shop(st, r)
	state = prev
	return st

# ================================================================ Герои
func hero(id: String) -> Dictionary:
	return state["heroes"][id]

func derived(id: String) -> Dictionary:
	var h := hero(id)
	return Stats.derive(id, int(h["level"]), h["equip"])

## Собственные атрибуты героя (растут сами с уровнем), без бонусов вещей
func own_stats(id: String) -> Dictionary:
	return Stats.natural(id, int(hero(id)["level"]))

func perks_of(id: String) -> Dictionary:
	return hero(id)["perks"]

func ability_unlocked(id: String, ab: String) -> bool:
	return int(hero(id)["level"]) >= int(DB.ABILITIES[ab]["lvl"])

func unlocked_abilities(id: String) -> Array:
	var r := []
	for ab in DB.HERO_ABILITIES[id]:
		if ability_unlocked(id, ab):
			r.append(ab)
	return r

func perk_points(id: String) -> int:
	var h := hero(id)
	var used := 0
	for st in DB.PERK_STAGES.keys():
		if h["perks"].get(st, "") != "":
			used += 1
	return int(h["job"]) - 1 - used

func perk_stage_problem(id: String, stage: int) -> String:
	var req: Dictionary = DB.PERK_STAGES[stage]
	var h := hero(id)
	var probs := []
	if int(h["level"]) < req["base"]:
		probs.append("Base %d" % req["base"])
	if int(h["job"]) < req["job"]:
		probs.append("Job %d" % req["job"])
	if int(state["story_stage"]) < req["story"]:
		probs.append("сюжет: выполнено поручений %d" % req["story"])
	if probs.is_empty():
		return ""
	return "Нужно: " + ", ".join(probs)

func choose_perk(id: String, stage: int, perk_id: String) -> String:
	if state["expedition"] != null:
		return "В походе сборку менять нельзя."
	var p := perk_stage_problem(id, stage)
	if p != "":
		return p
	var h := hero(id)
	var cur: String = h["perks"].get(stage, "")
	if cur == perk_id:
		return ""
	if cur == "" and perk_points(id) <= 0:
		return "Нет свободных очков Job."
	h["perks"][stage] = perk_id
	save()
	changed.emit()
	return ""

func _apply_levels() -> Array:
	var ups := []
	for id in DB.HERO_IDS:
		var h := hero(id)
		var before := int(h["level"])
		var d0 := _growth_stats(id)
		while int(h["level"]) < DB.MAX_LEVEL and int(h["xp"]) >= DB.xp_to_next(int(h["level"])):
			h["xp"] = int(h["xp"]) - DB.xp_to_next(int(h["level"]))
			h["level"] = int(h["level"]) + 1
		if int(h["level"]) > before:
			var new_ab := []
			for ab in DB.HERO_ABILITIES[id]:
				var l := int(DB.ABILITIES[ab]["lvl"])
				if l > before and l <= int(h["level"]):
					new_ab.append(DB.ABILITIES[ab]["name"])
			ups.append({"hero": id, "from": before, "to": int(h["level"]), "abilities": new_ab, "before": d0, "after": _growth_stats(id)})
	return ups

## Параметры для экрана повышения уровня («было → стало»)
func _growth_stats(id: String) -> Dictionary:
	var d := derived(id)
	var out := {}
	for k in ["max_hp", "max_mp", "dmg_min", "dmg_max", "armor", "sp", "sta", "str", "agi", "int"]:
		out[k] = int(d.get(k, 0))
	return out

func _add_jxp(id: String, amount: int) -> Array:
	var h := hero(id)
	var ups := []
	h["jxp"] = int(h["jxp"]) + amount
	while int(h["job"]) < DB.MAX_JOB and int(h["jxp"]) >= DB.jxp_to_next(int(h["job"])):
		h["jxp"] = int(h["jxp"]) - DB.jxp_to_next(int(h["job"]))
		h["job"] = int(h["job"]) + 1
		ups.append(int(h["job"]))
	return ups

# ================================================================ Кладовая и экипировка
func storage() -> Array:
	return state["storage"]

func free_slot() -> int:
	var st := storage()
	for i in st.size():
		if st[i] == null:
			return i
	return -1

func storage_count() -> int:
	var n := 0
	for it in storage():
		if it != null:
			n += 1
	return n

func add_item(item: Dictionary) -> bool:
	var i := free_slot()
	if i < 0:
		state["queue"].append(item)
		return false
	storage()[i] = item
	return true

func take_queue() -> int:
	var n := 0
	while state["queue"].size() > 0 and free_slot() >= 0:
		add_item(state["queue"].pop_front())
		n += 1
	if n > 0:
		save()
		changed.emit()
	return n

func move_item(a: int, b: int) -> void:
	var st := storage()
	var tmp = st[a]
	st[a] = st[b]
	st[b] = tmp
	save()
	changed.emit()

func auto_slot(id: String, item: Dictionary) -> String:
	var b := Items.base_of(item)
	var sl: String = b.get("slot", "")
	if sl == "ring":
		var eq: Dictionary = hero(id)["equip"]
		if eq["ring1"] == null:
			return "ring1"
		if eq["ring2"] == null:
			return "ring2"
		return "ring1"
	return sl

func equip_problem(id: String, item: Dictionary, sl: String) -> String:
	if state["expedition"] != null:
		return "Снаряжение меняют в деревне, не в походе."
	return Items.equip_problem(id, int(hero(id)["level"]), item, sl, hero(id)["equip"])

## Надеть вещь из ячейки кладовой. Прежняя вещь возвращается в кладовую.
func equip_from_storage(id: String, idx: int, sl: String = "") -> String:
	var st := storage()
	var item = st[idx]
	if item == null:
		return "Ячейка пуста."
	if sl == "":
		sl = auto_slot(id, item)
	var p := equip_problem(id, item, sl)
	if p != "":
		return p
	var eq: Dictionary = hero(id)["equip"]
	var b := Items.base_of(item)
	var extra_out = null
	if sl == "main" and int(b.get("hands", 1)) == 2 and eq["off"] != null:
		extra_out = eq["off"]
	st[idx] = eq[sl]
	eq[sl] = item
	if extra_out != null:
		eq["off"] = null
		if not add_item(extra_out):
			notify("Кладовая заполнена: %s ждёт в очереди выдачи." % Items.display_name(extra_out))
	save()
	changed.emit()
	return ""

## Насколько вещь усилит героя: {slot, gain} — лучший слот (у колец два) и прирост «силы» в долях.
## slot == "" — надеть нельзя.
func upgrade_gain(id: String, item: Dictionary) -> Dictionary:
	var h := hero(id)
	var lvl := int(h["level"])
	var eq: Dictionary = h["equip"]
	var slots := ["ring1", "ring2"] if Items.base_of(item).get("slot", "") == "ring" else [auto_slot(id, item)]
	var cur := Stats.power(id, lvl, eq)
	var best := {"slot": "", "gain": -1.0}
	for sl in slots:
		if Items.equip_problem(id, lvl, item, sl, eq) != "":
			continue
		var e2 := eq.duplicate()
		e2[sl] = item
		if sl == "main" and int(Items.base_of(item).get("hands", 1)) == 2:
			e2["off"] = null
		var g := Stats.power(id, lvl, e2) / maxf(1.0, cur) - 1.0
		if g > float(best["gain"]):
			best = {"slot": sl, "gain": g}
	return best

## «Надеть лучшее»: по очереди надевает из кладовой вещи, которые заметно усиливают героя. Возвращает число замен.
func equip_best(id: String) -> int:
	if state["expedition"] != null:
		return 0
	var n := 0
	var guard := 0
	var again := true
	while again and guard < 40:
		again = false
		guard += 1
		var best_i := -1
		var best := {"slot": "", "gain": 0.01}
		for i in storage().size():
			var it = storage()[i]
			if it == null or not Items.hero_can_use_type(id, it):
				continue
			var g := upgrade_gain(id, it)
			if g["slot"] != "" and float(g["gain"]) > float(best["gain"]):
				best = g
				best_i = i
		if best_i >= 0 and equip_from_storage(id, best_i, best["slot"]) == "":
			n += 1
			again = true
	return n

func unequip(id: String, sl: String) -> String:
	if state["expedition"] != null:
		return "Снаряжение меняют в деревне."
	var eq: Dictionary = hero(id)["equip"]
	if eq[sl] == null:
		return ""
	var i := free_slot()
	if i < 0:
		return "Кладовая заполнена (80/80)."
	storage()[i] = eq[sl]
	eq[sl] = null
	save()
	changed.emit()
	return ""

func unequip_to(id: String, sl: String, idx: int) -> String:
	if state["expedition"] != null:
		return "Снаряжение меняют в деревне."
	var eq: Dictionary = hero(id)["equip"]
	var st := storage()
	if st[idx] != null:
		# Обмен: попробуем надеть вещь из ячейки на это место
		return equip_from_storage(id, idx, sl)
	st[idx] = eq[sl]
	eq[sl] = null
	save()
	changed.emit()
	return ""

# ================================================================ Лавка
func discount() -> float:
	return min(0.15, int(state["trust"]) * 0.01)

func distinct_completed() -> int:
	return state["completed"].size()

func _gen_shop(st: Dictionary, r: RandomNumberGenerator) -> void:
	var dc: int = st["completed"].size()
	var ilvl: int = clamp(1 + dc, 1, 9)
	var quality := dc * 0.6
	var stock := []
	for i in 8:
		var it: Dictionary
		if i < 4:
			var hid: String = DB.HERO_IDS[i]
			var lvl: int = int(st["heroes"][hid]["level"]) if st["heroes"].has(hid) else 1
			it = Items.item_for_hero(hid, lvl + 1, ilvl, r, quality - 1.0)
		else:
			it = Items.random_item(ilvl, r, quality, DB.HERO_IDS)
		stock.append(it)
	st["shop"]["stock"] = stock
	st["shop"]["gen"] = int(st["shop"].get("gen", 0)) + 1

func refresh_shop() -> void:
	_gen_shop(state, rng)

func shop_price(item: Dictionary) -> int:
	return int(ceil(Items.price(item) * (1.0 - discount())))

func cons_price(id: String, road := false) -> int:
	var base: int = DB.CONSUMABLES[id]["price"] if DB.CONSUMABLES.has(id) else DB.GIFTS[id]["price"]
	var p := base * (1.0 - discount())
	if road:
		p = base * 1.25
	return int(ceil(p))

func backpack_count() -> int:
	var n := 0
	for k in state["backpack"].keys():
		n += int(state["backpack"][k])
	return n

func buy_item(idx: int) -> String:
	var stock: Array = state["shop"]["stock"]
	if idx < 0 or idx >= stock.size():
		return "Нет товара."
	var it: Dictionary = stock[idx]
	var p := shop_price(it)
	if int(state["treasury"]) < p:
		return "Не хватает денег в казне."
	state["treasury"] = int(state["treasury"]) - p
	stock.remove_at(idx)
	if not add_item(it):
		notify("Кладовая заполнена — вещь ждёт в очереди выдачи.")
	save()
	changed.emit()
	return ""

func buy_cons(id: String, road := false) -> String:
	var p := cons_price(id, road)
	var exd = state["expedition"]
	if road:
		if exd == null or int(exd["purse"]) < p:
			return "В походном кошельке не хватает монет."
	elif int(state["treasury"]) < p:
		return "Не хватает денег в казне."
	if DB.GIFTS.has(id) and backpack_count() >= DB.BACKPACK_CAP:
		return "Походный рюкзак полон (%d)." % DB.BACKPACK_CAP
	if road:
		exd["purse"] = int(exd["purse"]) - p
		exd["spent"] = int(exd.get("spent", 0)) + p
	else:
		state["treasury"] = int(state["treasury"]) - p
	if DB.GIFTS.has(id):
		state["backpack"][id] = int(state["backpack"].get(id, 0)) + 1
	else:
		state["potions"][id] = int(state["potions"].get(id, 0)) + 1
	save()
	changed.emit()
	return ""

func sell_storage(idx: int) -> String:
	if state["expedition"] != null:
		return "Продавать можно в деревенской лавке."
	var it = storage()[idx]
	if it == null:
		return ""
	var p := Items.sell_price(it)
	state["treasury"] = int(state["treasury"]) + p
	storage()[idx] = null
	state["shop"]["buyback"].push_front({"item": it, "price": p})
	if state["shop"]["buyback"].size() > 12:
		state["shop"]["buyback"].pop_back()
	save()
	changed.emit()
	return ""

func sell_cons(id: String) -> String:
	var src: Dictionary = state["backpack"] if DB.GIFTS.has(id) else state["potions"]
	if int(src.get(id, 0)) <= 0:
		return "Нечего продавать."
	src[id] = int(src[id]) - 1
	var base: int = DB.CONSUMABLES[id]["price"] if DB.CONSUMABLES.has(id) else DB.GIFTS[id]["price"]
	state["treasury"] = int(state["treasury"]) + max(1, int(base * 0.4))
	save()
	changed.emit()
	return ""

func buyback(idx: int) -> String:
	var bb: Array = state["shop"]["buyback"]
	if idx < 0 or idx >= bb.size():
		return ""
	var e: Dictionary = bb[idx]
	if int(state["treasury"]) < int(e["price"]):
		return "Не хватает денег в казне."
	if free_slot() < 0:
		return "Кладовая заполнена."
	state["treasury"] = int(state["treasury"]) - int(e["price"])
	add_item(e["item"])
	bb.remove_at(idx)
	save()
	changed.emit()
	return ""

## Перековка: новые случайные свойства вещи из кладовой. Цена растёт с каждой попыткой (Items.reroll_price).
## Свойства подкручиваются под случайного героя, который может носить вещь.
func reroll_storage(idx: int) -> String:
	var st := storage()
	if idx < 0 or idx >= st.size() or st[idx] == null:
		return "Выберите вещь в кладовой."
	var it: Dictionary = st[idx]
	if not Items.can_reroll(it):
		return "У обычной вещи нет свойств для перековки."
	var p := Items.reroll_price(it)
	if int(state["treasury"]) < p:
		return "Не хватает денег в казне."
	state["treasury"] = int(state["treasury"]) - p
	var who := []
	for h in DB.HERO_IDS:
		if Items.hero_can_use_type(h, it):
			who.append(h)
	Items.reroll(it, rng, who[rng.randi_range(0, who.size() - 1)] if not who.is_empty() else "")
	save()
	changed.emit()
	return ""

func choose_pending(idx: int) -> void:
	var pc: Array = state["pending_choice"]
	if idx < 0 or idx >= pc.size():
		return
	var it: Dictionary = pc[idx]
	state["pending_choice"] = []
	if not add_item(it):
		notify("Кладовая заполнена — награда ждёт в очереди выдачи.")
	save()
	changed.emit()

# ================================================================ Контракты
func contract_available(cid: String) -> bool:
	var c: Dictionary = DB.CONTRACTS[cid]
	for r in c["requires"]:
		if not state["completed"].has(r):
			return false
	return true

func contract_done_count(cid: String) -> int:
	return int(state["completed"].get(cid, 0))

func default_purse() -> int:
	return min(int(state["treasury"]), 60)

func start_expedition(cid: String, opts: Dictionary) -> String:
	if state["expedition"] != null:
		return "Уже в походе."
	var c: Dictionary = DB.CONTRACTS[cid]
	if c.has("diplomacy"):
		return "Это дипломатическая миссия: в путь — через start_diplomacy()."
	if not contract_available(cid):
		return "Контракт ещё не открыт."
	var purse := int(opts.get("purse", 0))
	if purse < 0 or purse > int(state["treasury"]):
		return "В казне нет такой суммы."
	state["treasury"] = int(state["treasury"]) - purse
	var hs := {}
	var xp0 := {}
	for id in DB.HERO_IDS:
		var d := derived(id)
		hs[id] = {"hp": float(d["max_hp"]), "mp": float(d["max_mp"]), "atb": 0.0}
		xp0[id] = int(hero(id)["xp"])
	var route: Array = []
	if c.get("outpost", false):
		route = [{"type": "outpost", "name": c.get("outpost_name", "Застава")}]
	else:
		route = c["route"].duplicate(true)
	for n in route:
		n["done"] = false
	var exd := {
		"cid": cid, "purse": purse, "purse_start": purse, "road_earned": 0, "spent": 0,
		"node": 0, "route": route, "phase": "walk", "walk_t": 0.0, "hero_state": hs, "xp_start": xp0,
		"general": opts.get("general", ""), "personal": opts.get("personal", {}),
		"counters": {"potions": 0, "ko": {}, "dmg_taken": {}, "healing": 0, "wards": 0, "taunts": 0, "kills": {},
			"interrupts": 0, "curses": 0, "spell_dmg": 0, "xp": 0, "coins": 0},
		"flags": {}, "battle": null, "battle_ctx": {}, "event_result": "", "camp": {}, "road_shop": [],
		"wagon": {"hp": 500.0, "max": 500.0} if c.get("escort", false) else null,
		"kits": int(c.get("kits", 0)) + int(state["potions"].get("kit", 0)) if c.get("escort", false) else 0,
		"gate": {"hp": float(c.get("gate_hp", 600)), "max": float(c.get("gate_hp", 600))} if c.get("outpost", false) else null,
		"materials": int(c.get("materials", 0)), "rel_battle": {}, "boss_time": -1.0, "chest_ok": true,
		"xp_gain": 0, "log": [],
	}
	if c.get("escort", false):
		state["potions"]["kit"] = 0
	state["expedition"] = exd
	if opts.has("formation"):
		state["formation"] = opts["formation"].duplicate()
	save()
	changed.emit()
	return ""

func ex() -> Dictionary:
	return state["expedition"] if state["expedition"] != null else {}

func current_node() -> Dictionary:
	var e := ex()
	if e.is_empty() or int(e["node"]) >= e["route"].size():
		return {}
	return e["route"][int(e["node"])]

## Конфигурация боя для текущего узла (или доп. боя из события)
## champion — именной враг узла маршрута (DB.CONTRACTS → route → champion), в боях из событий его нет.
func battle_config(groups: Array, ambush: Array, boss: bool, chest: bool, champion := {}) -> Dictionary:
	var e := ex()
	var c: Dictionary = DB.CONTRACTS[e["cid"]]
	var heroes := []
	for id in DB.HERO_IDS:
		var h := hero(id)
		heroes.append({"id": id, "d": derived(id), "hp": e["hero_state"][id]["hp"], "mp": e["hero_state"][id]["mp"],
			"atb": e["hero_state"][id]["atb"], "perks": h["perks"].duplicate(), "level": int(h["level"])})
	var cfg := {"heroes": heroes, "formation": state["formation"], "groups": groups, "ambush": ambush,
		"level": int(c["level"]), "mode": "outpost" if c.get("outpost", false) else "route",
		"wagon": e["wagon"], "gate": e["gate"], "chest": chest, "waves": c.get("waves", []),
		"kits": int(e["kits"]), "materials": int(e["materials"]), "night": current_time() == "night", "boss": boss,
		"outpost_ambush": c.get("outpost_ambush", ["wolf"]), "shade_k": shade_k(),
		"potions": {"potion_hp": int(state["potions"]["potion_hp"]), "potion_mp": int(state["potions"]["potion_mp"])}}
	if not champion.is_empty():
		cfg["champion"] = champion
	return cfg

func set_formation(f: Array) -> void:
	state["formation"] = f.duplicate()
	save()

## Записать итог боя (победа) в поход
func absorb_battle(sim: BattleSim) -> void:
	var e := ex()
	var st: Dictionary = sim.s
	for u in st["units"]:
		if u["side"] != "hero":
			continue
		var hs: Dictionary = e["hero_state"][u["key"]]
		hs["hp"] = u["hp"] if u["alive"] else max(1.0, round(u["max_hp"] * 0.15))
		hs["mp"] = u["mp"]
		hs["atb"] = u["atb"]
	state["potions"]["potion_hp"] = int(st["potions"]["potion_hp"])
	state["potions"]["potion_mp"] = int(st["potions"]["potion_mp"])
	if st["objects"].has("wagon") and e["wagon"] != null:
		e["wagon"]["hp"] = st["objects"]["wagon"]["hp"]
	if st["objects"].has("gate") and e["gate"] != null:
		e["gate"]["hp"] = st["objects"]["gate"]["hp"]
	if st["objects"].has("chest"):
		e["chest_ok"] = st["objects"]["chest"]["hp"] > 0.0
	e["kits"] = int(st["kits"])
	e["materials"] = int(st["materials"])
	var c: Dictionary = st["counters"]
	var ec: Dictionary = e["counters"]
	for k in ["potions", "healing", "wards", "taunts", "interrupts", "curses", "spell_dmg", "xp", "xp_cut", "coins", "champions"]:
		ec[k] = int(ec.get(k, 0)) + int(c.get(k, 0))
	for k in c["ko"].keys():
		ec["ko"][k] = true
	for k in c["dmg_taken"].keys():
		ec["dmg_taken"][k] = int(ec["dmg_taken"].get(k, 0)) + int(c["dmg_taken"][k])
	for k in c["kills"].keys():
		ec["kills"][k] = int(ec["kills"].get(k, 0)) + int(c["kills"][k])
	if not ec.has("by_hero"):
		ec["by_hero"] = {}
	for k in c.get("by_hero", {}).keys():
		var dst: Dictionary = ec["by_hero"].get(k, {"dmg": 0, "heal": 0, "absorbed": 0, "int": 0})
		for f in ["dmg", "heal", "absorbed", "int"]:
			dst[f] = int(dst.get(f, 0)) + int(round(float(c["by_hero"][k].get(f, 0))))
		ec["by_hero"][k] = dst
	# Опыт начисляется сразу, уровень — после попытки
	for id in DB.HERO_IDS:
		hero(id)["xp"] = int(hero(id)["xp"]) + int(c["xp"])
	e["xp_gain"] = int(e.get("xp_gain", 0)) + int(c["xp"])
	e["purse"] = int(e["purse"]) + int(c["coins"])
	e["road_earned"] = int(e["road_earned"]) + int(c["coins"])
	if st.get("boss", false):
		e["boss_time"] = float(st["boss_time"])
	# Лечение и защита сближают
	for k in c.get("heal_by", {}).keys():
		if int(c["heal_by"][k]) >= 60 and int(e["rel_battle"].get(k, 0)) < 3:
			e["rel_battle"][k] = int(e["rel_battle"].get(k, 0)) + 1
			change_rel("aiden", k, 1, 0, "%s благодарна(ен) за лечение в бою." % DB.hero_name(k))

func walk_regen(dt: float) -> void:
	var e := ex()
	for id in DB.HERO_IDS:
		var d := derived(id)
		var hs: Dictionary = e["hero_state"][id]
		hs["mp"] = min(float(d["max_mp"]), float(hs["mp"]) + (0.6 + d["max_mp"] * 0.005) * dt)

# ---------------------------------------------------------------- События
func event_choice_problem(ch: Dictionary) -> String:
	var e := ex()
	var req: Dictionary = ch.get("req", {})
	if req.has("purse") and int(e["purse"]) < int(req["purse"]):
		return "Нужно %d мон. в кошельке." % req["purse"]
	if req.has("potion_hp") and int(state["potions"]["potion_hp"]) < int(req["potion_hp"]):
		return "Нет лечебного зелья."
	if req.has("kit") and int(e["kits"]) < int(req["kit"]):
		return "Нет ремкомплекта."
	return ""

func effect_text(fx: Dictionary) -> String:
	var parts := []
	if fx.has("purse"):
		var v := int(fx["purse"])
		parts.append(("+%d мон. в кошелёк" if v > 0 else "%d мон.") % v)
	if fx.has("heal_pct"):
		var v2 := int(fx["heal_pct"])
		parts.append(("+%d%% ОЗ отряду" if v2 > 0 else "%d%% ОЗ отряду") % v2)
	if fx.has("mana_pct"):
		var vm := int(fx["mana_pct"])
		parts.append(("+%d%% МП отряду" if vm > 0 else "%d%% МП отряду") % vm)
	if fx.has("hp_hero"):
		for k in fx["hp_hero"].keys():
			parts.append("%s %d%% ОЗ" % [DB.hero_name(k), int(fx["hp_hero"][k])])
	if fx.has("mana_hero"):
		for k in fx["mana_hero"].keys():
			parts.append("%s %d%% МП" % [DB.hero_name(k), int(fx["mana_hero"][k])])
	for k in ["potion_hp", "potion_mp", "kit"]:
		if fx.has(k):
			var n := int(fx[k])
			parts.append("%s%d %s" % ["+" if n > 0 else "", n, DB.consumable_name(k).to_lower()])
	if fx.has("gift"):
		parts.append("+%s в рюкзак" % DB.consumable_name(fx["gift"]).to_lower())
	if fx.has("wagon_pct"):
		parts.append("+%d%% прочности повозки" % int(fx["wagon_pct"]))
	if fx.has("trust"):
		var vt := int(fx["trust"])
		parts.append(("+%d доверия деревни" if vt > 0 else "%d доверия деревни") % vt)
	if fx.has("battle"):
		parts.append("бой")
	if fx.has("rel"):
		for k in fx["rel"].keys():
			var a: PackedStringArray = k.split("|")
			var dv := int(fx["rel"][k])
			parts.append("%s–%s %s" % [DB.hero_name(a[0]), DB.hero_name(a[1]), ("↑" if dv > 0 else "↓")])
	if fx.get("helped", false):
		parts.append("помощь людям")
	if parts.is_empty():
		return "без последствий"
	return ", ".join(parts)

## Текст последствий варианта события; у варианта с шансом — успех и провал.
func choice_text(ch: Dictionary) -> String:
	if not ch.has("chance"):
		return effect_text(ch.get("fx", {}))
	return "%d%%: %s  ·  иначе: %s" % [int(ch["chance"]), effect_text(ch.get("fx", {})), effect_text(ch.get("fail_fx", {}))]

## Бросок для варианта с шансом: возвращает вариант с итоговыми fx и say.
func resolve_event_choice(ch: Dictionary) -> Dictionary:
	if not ch.has("chance"):
		return ch
	var out := ch.duplicate()
	if randf() * 100.0 >= float(ch["chance"]):
		out["fx"] = ch.get("fail_fx", {})
		out["say"] = ch.get("fail_say", ch.get("say", ""))
	return out

## Применить выбор события. Возвращает массив групп для доп. боя (или пустой)
func apply_event_choice(ch: Dictionary) -> Array:
	var e := ex()
	var fx: Dictionary = ch.get("fx", {})
	if fx.has("purse"):
		var v := int(fx["purse"])
		e["purse"] = max(0, int(e["purse"]) + v)
		if v > 0:
			e["road_earned"] = int(e["road_earned"]) + v
		else:
			e["spent"] = int(e.get("spent", 0)) - v
	for id in DB.HERO_IDS:
		var d := derived(id)
		var hs: Dictionary = e["hero_state"][id]
		if fx.has("heal_pct"):
			hs["hp"] = clamp(hs["hp"] + d["max_hp"] * float(fx["heal_pct"]) / 100.0, 1.0, float(d["max_hp"]))
		if fx.has("mana_pct"):
			hs["mp"] = clamp(hs["mp"] + d["max_mp"] * float(fx["mana_pct"]) / 100.0, 0.0, float(d["max_mp"]))
		if fx.has("hp_hero") and fx["hp_hero"].has(id):
			hs["hp"] = clamp(hs["hp"] + d["max_hp"] * float(fx["hp_hero"][id]) / 100.0, 1.0, float(d["max_hp"]))
		if fx.has("mana_hero") and fx["mana_hero"].has(id):
			hs["mp"] = clamp(hs["mp"] + d["max_mp"] * float(fx["mana_hero"][id]) / 100.0, 0.0, float(d["max_mp"]))
	for k in ["potion_hp", "potion_mp"]:
		if fx.has(k):
			state["potions"][k] = max(0, int(state["potions"][k]) + int(fx[k]))
	if fx.has("kit"):
		e["kits"] = max(0, int(e["kits"]) + int(fx["kit"]))
	if fx.has("gift") and backpack_count() < DB.BACKPACK_CAP:
		state["backpack"][fx["gift"]] = int(state["backpack"].get(fx["gift"], 0)) + 1
	if fx.has("wagon_pct") and e["wagon"] != null:
		e["wagon"]["hp"] = min(e["wagon"]["max"], e["wagon"]["hp"] + e["wagon"]["max"] * float(fx["wagon_pct"]) / 100.0)
	if fx.has("trust"):
		state["trust"] = int(state["trust"]) + int(fx["trust"])
	if fx.get("helped", false):
		e["flags"]["helped"] = true
	for fk in ["flag", "flag2"]:
		if fx.has(fk):
			e["flags"][fx[fk]] = true
	if fx.has("fact"):
		learn_fact(fx["fact"], "confirmed")
	if fx.has("rel"):
		for k in fx["rel"].keys():
			var a: PackedStringArray = k.split("|")
			change_rel(a[0], a[1], int(fx["rel"][k]), 0, "Дорога: %s" % ch["text"])
	return fx.get("battle", [])

# ---------------------------------------------------------------- Узлы маршрута
func complete_node() -> void:
	var e := ex()
	e["route"][int(e["node"])]["done"] = true
	e["node"] = int(e["node"]) + 1
	e["phase"] = "walk"
	e["walk_t"] = 0.0
	e["battle"] = null
	e["camp"] = {}
	e["road_shop"] = []
	e["event_result"] = ""

## Время суток пунктов текущего похода (DayTime.route_times): "morning" / "day" / "evening" / "night".
func ex_times() -> Array:
	var e := ex()
	if e.is_empty() or not e.has("cid"):
		return []
	return DayTime.contract_times(e["cid"], e.get("route", []))

## Время суток в пункте i текущего похода (за концом маршрута — время последнего пункта).
func time_at(i: int) -> String:
	var times := ex_times()
	if times.is_empty():
		return "day"
	return times[clampi(i, 0, times.size() - 1)]

## Время суток сейчас: в пути — пункт, к которому идёт отряд (свет меняется плавно по дороге).
func current_time() -> String:
	var e := ex()
	return time_at(int(e.get("node", 0))) if not e.is_empty() else "day"

## Кат-сцена на текущем отрезке пути (DB.CUTSCENES) или, после последнего пункта, сцена-итог; если её ещё не видели: id или "".
func cutscene_due() -> String:
	var e := ex()
	if e.is_empty():
		return ""
	var id := DB.cutscene_for(String(e["cid"]), int(e["node"]))
	if id == "" or state.get("cutscenes_seen", {}).has(id):
		return ""
	return id

## Разбитые обелиски пещер ослабляют духов зверей: −10% здоровья за каждый.
func obelisks_broken() -> int:
	var n := 0
	for cid in DB.SIDE_ORDER:
		if DB.CONTRACTS[cid].get("cave", false) and int(state.get("completed", {}).get(cid, 0)) > 0:
			n += 1
	return n

func shade_k() -> float:
	return 1.0 - 0.1 * obelisks_broken()

## Идущая кат-сцена похода: {id, step} или пусто.
func story() -> Dictionary:
	var e := ex()
	return e.get("story", {}) if not e.is_empty() and e.get("story") is Dictionary else {}

func set_story(id: String, step: int) -> void:
	ex()["story"] = {"id": id, "step": step}
	save()

func end_story() -> void:
	var st := story()
	if not st.is_empty():
		state["cutscenes_seen"][st["id"]] = 1
	ex().erase("story")
	save()

func route_finished() -> bool:
	var e := ex()
	return int(e["node"]) >= e["route"].size()

func gen_road_shop() -> void:
	var e := ex()
	if e["road_shop"].size() > 0:
		return
	e["road_shop"] = ["potion_hp", "potion_mp", "apple", "berries", "wine", "tea"]
	if e["wagon"] != null:
		e["road_shop"].append("kit")

# ================================================================ Итоги
func check_objective(id: String) -> bool:
	var e := ex()
	var c: Dictionary = e["counters"]
	match id:
		"no_ko": return c["ko"].is_empty()
		"few_potions": return int(c["potions"]) <= 2
		"helpful": return e["flags"].get("helped", false)
		"thrift": return int(e["purse"]) >= int(e["purse_start"])
		"wagon80": return e["wagon"] != null and e["wagon"]["hp"] >= e["wagon"]["max"] * 0.8
		"gate60": return e["gate"] != null and e["gate"]["hp"] >= e["gate"]["max"] * 0.6
		"fast_boss": return float(e["boss_time"]) >= 0.0 and float(e["boss_time"]) <= 100.0
		"carters_all": return e["flags"].get("carter1", false) and e["flags"].get("carter2", false) and e["flags"].get("carter3", false)
		"chest_safe": return e.get("chest_ok", true) and float(e["boss_time"]) >= 0.0
	return false

func personal_progress(hid: String, obj: Dictionary) -> Array:
	var e := ex()
	var c: Dictionary = e["counters"]
	var v := 0
	match obj["stat"]:
		"dmg_taken": v = int(c["dmg_taken"].get(hid, 0))
		"kills": v = int(c["kills"].get(hid, 0))
		_: v = int(c.get(obj["stat"], 0))
	return [v, int(obj["goal"])]

func personal_obj_def(hid: String, oid: String) -> Dictionary:
	for o in DB.PERSONAL_OBJECTIVES.get(hid, []):
		if o["id"] == oid:
			return o
	return {}

## kind: "victory" / "defeat" / "abandon". Применяет итоги атомарно и сохраняет.
func finish_expedition(kind: String) -> Dictionary:
	var e := ex()
	var cid: String = e["cid"]
	var c: Dictionary = DB.CONTRACTS[cid]
	var res := {"kind": kind, "cid": cid, "name": c["name"], "lines": [], "coins": 0, "items": [], "levels": [], "jobs": [],
		"purse_return": 0, "choice": false, "outro": "", "chapter_end": false, "unlocks": [], "next": []}
	var snap := unlock_snapshot()
	var lines: Array = res["lines"]
	if kind == "abandon":
		for id in DB.HERO_IDS:
			hero(id)["xp"] = int(e["xp_start"][id])
		var ret: int = max(0, int(e["purse"]) - int(e["road_earned"]))
		state["treasury"] = int(state["treasury"]) + ret
		res["purse_return"] = ret
		lines.append("Поход прерван. Опыт попытки отменён.")
		lines.append("Дорожный заработок (%d мон.) не возвращается; покупки и расходы не отменяются." % int(e["road_earned"]))
	elif kind == "defeat":
		var ret2: int = int(e["purse"])
		state["treasury"] = int(state["treasury"]) + ret2
		res["purse_return"] = ret2
		lines.append("Отряд отступил к деревне. Опыт сохранён (+%d каждому), оставшиеся деньги возвращены в казну." % int(e["xp_gain"]))
		lines.append("Наград за победу нет.")
		# Утешительный приз: одна обычная вещь чуть ниже уровня поручения, если отряд успел повоевать
		if int(e["xp_gain"]) > 0:
			var cons := Items.consolation_item(maxi(1, int(c["level"]) - 1), rng, DB.HERO_IDS)
			res["items"].append(cons)
			res["consolation"] = true
			if not add_item(cons):
				lines.append("Кладовая заполнена — %s в очереди выдачи." % Items.display_name(cons))
		res["levels"] = _apply_levels()
	else:
		var first := contract_done_count(cid) == 0
		var pay: int = int(c["pay"]) if first else int(c["repeat_pay"])
		var total := pay
		lines.append("%s: %d мон." % ["Оплата контракта" if first else "Оплата повтора", pay])
		var prem: Dictionary = c["premium"]
		if check_objective(prem["check"]):
			if state["premium_claimed"].has(cid):
				lines.append("Премия «%s»: условие выполнено, но уже получена ранее." % prem["name"])
			else:
				state["premium_claimed"][cid] = true
				total += int(prem["coins"])
				lines.append("Премия «%s»: +%d мон." % [prem["name"], prem["coins"]])
		else:
			lines.append("Премия «%s» упущена (победа засчитана)." % prem["name"])
		var gen: String = e.get("general", "")
		if gen != "":
			var g: Dictionary = DB.GENERAL_OBJECTIVES[gen]
			if check_objective(gen):
				total += int(g["coins"])
				var key := "%s:gen:%s" % [cid, gen]
				var jtxt := ""
				if not state["jxp_claimed"].has(key):
					state["jxp_claimed"][key] = true
					for id in DB.HERO_IDS:
						for j in _add_jxp(id, int(g["jxp"])):
							res["jobs"].append([id, j])
					jtxt = ", +%d JXP всем" % g["jxp"]
				lines.append("Общее поручение «%s»: +%d мон.%s" % [g["name"], g["coins"], jtxt])
			else:
				lines.append("Общее поручение «%s» не выполнено." % g["name"])
		var pers: Dictionary = e.get("personal", {})
		if pers.has("hero"):
			var hid: String = pers["hero"]
			var od := personal_obj_def(hid, pers["obj"])
			var pr := personal_progress(hid, od)
			if pr[0] >= pr[1]:
				total += 20
				var key2 := "%s:pers:%s:%s" % [cid, hid, od["id"]]
				var jt := ""
				if not state["jxp_claimed"].has(key2):
					state["jxp_claimed"][key2] = true
					for j in _add_jxp(hid, 60):
						res["jobs"].append([hid, j])
					jt = ", +60 JXP"
				if hid != "aiden":
					change_rel("aiden", hid, 3, 0, "%s справился(лась) с личным поручением «%s»." % [DB.hero_name(hid), od["name"]])
				lines.append("Личное поручение %s «%s»: +20 мон.%s" % [DB.hero_name(hid), od["name"], jt])
			else:
				lines.append("Личное поручение %s «%s»: %d/%d." % [DB.hero_name(hid), od["name"], pr[0], pr[1]])
		if first:
			for id in DB.HERO_IDS:
				for j in _add_jxp(id, int(c["jxp"])):
					res["jobs"].append([id, j])
			lines.append("Освоение поручения: +%d JXP всем героям." % c["jxp"])
		else:
			lines.append("Освоение (JXP) за это поручение уже получено.")
		state["treasury"] = int(state["treasury"]) + total
		res["coins"] = total
		var ret3: int = int(e["purse"])
		state["treasury"] = int(state["treasury"]) + ret3
		res["purse_return"] = ret3
		lines.append("Остаток кошелька в казну: %d мон." % ret3)
		# Добыча
		var ilvl: int = int(c["level"])
		var q := distinct_completed() * 0.5
		var champs := int(e["counters"].get("champions", 0))
		for i in 2 + champs:
			# За каждого побеждённого чемпиона — ещё одна вещь, получше обычной
			var it := Items.random_item(clamp(ilvl + rng.randi_range(0, 1), 1, 10), rng, q + (1.0 if i >= 2 else 0.0), DB.HERO_IDS)
			res["items"].append(it)
			if not add_item(it):
				lines.append("Кладовая заполнена — %s в очереди выдачи." % Items.display_name(it))
		if champs > 0:
			lines.append("Чемпионы повержены: +%d %s в добыче." % [champs, "вещь" if champs == 1 else "вещи"])
		if first:
			var heroes := DB.HERO_IDS.duplicate()
			# Перемешать
			for i in range(heroes.size() - 1, 0, -1):
				var j := rng.randi_range(0, i)
				var tmp = heroes[i]
				heroes[i] = heroes[j]
				heroes[j] = tmp
			var choice := []
			for i in 3:
				var hid2: String = heroes[i]
				choice.append(Items.item_for_hero(hid2, int(hero(hid2)["level"]) + 1, ilvl + 1, rng, q + 1.0))
			state["pending_choice"] = choice
			res["choice"] = true
		state["completed"][cid] = contract_done_count(cid) + 1
		if first:
			state["trust"] = int(state["trust"]) + 2
			if int(c["story"]) > int(state["story_stage"]):
				state["story_stage"] = int(c["story"])
			res["outro"] = c["outro"]
			if c.get("finale", false):
				state["chapter_done"] = true
				res["chapter_end"] = true
		res["levels"] = _apply_levels()
		_gen_shop(state, rng)
		lines.append("Ассортимент лавки обновлён.")
	res["by_hero"] = e["counters"].get("by_hero", {}).duplicate(true)
	var cut := int(e["counters"].get("xp_cut", 0))
	if kind != "abandon" and cut > 0:
		lines.append("Опыт за врагов ниже уровнем отряда урезан: −%d" % cut)
	res["unlocks"] = unlocks_since(snap)
	if kind == "victory":
		var nxt := next_story_contract()
		if nxt != "":
			res["next"] = contract_twists(nxt)
	state["expedition"] = null
	state["last_result"] = res
	save()
	changed.emit()
	return res

# ================================================================ Новинки после поручений
## Что сейчас открыто: этапы перков (у кого доступны), умения героев, доступные побочные поручения.
func unlock_snapshot() -> Dictionary:
	var stages := {}
	for st in DB.PERK_STAGES.keys():
		for id in DB.HERO_IDS:
			if perk_stage_problem(id, st) == "":
				stages[st] = true
	var abil := {}
	for id in DB.HERO_IDS:
		for ab in unlocked_abilities(id):
			abil[ab] = true
	var side := {}
	for cid in DB.CONTRACTS.keys():
		if DB.CONTRACTS[cid].get("side", false) and contract_available(cid):
			side[cid] = true
	return {"stages": stages, "abilities": abil, "side": side, "social": social_unlocked()}

## Новинки по сравнению со снимком: [{kind, title, tip}]. Уровень героев к этому моменту уже применён.
func unlocks_since(before: Dictionary) -> Array:
	var now := unlock_snapshot()
	var out := []
	var by_hero := {}
	for ab in now["abilities"].keys():
		if not before["abilities"].has(ab):
			var hid: String = DB.ABILITIES[ab]["hero"]
			if not by_hero.has(hid):
				by_hero[hid] = []
			by_hero[hid].append(DB.ABILITIES[ab]["name"])
	if not by_hero.is_empty():
		var tip := []
		var strong := false
		for hid in DB.HERO_IDS:
			if by_hero.has(hid):
				tip.append("%s: %s" % [DB.hero_name(hid), ", ".join(by_hero[hid])])
				for ab in DB.HERO_ABILITIES[hid]:
					if int(DB.ABILITIES[ab]["lvl"]) >= 7 and DB.ABILITIES[ab]["name"] in by_hero[hid]:
						strong = true
		out.append({"kind": "skills", "title": "Сильные приёмы" if strong else "Новые умения", "tip": "\n".join(tip)})
	for st in now["stages"].keys():
		if not before["stages"].has(st):
			var names := []
			for hid in DB.HERO_IDS:
				var pair := []
				for pk in DB.PERKS[hid][st]:
					pair.append(pk["name"])
				names.append("%s: %s" % [DB.hero_name(hid), " / ".join(pair)])
			out.append({"kind": "perks", "title": "Перки · этап %s" % DB.STAGE_NAMES[st], "tip": "Отряд → Перки\n" + "\n".join(names)})
	if now["social"] and not before.get("social", false):
		var tip2 := []
		for st in DB.SOCIAL_STATS:
			tip2.append(DB.SOCIAL_NAMES[st])
		out.append({"kind": "social", "title": "Черты характера", "tip": "Отряд → Черты\n%s\nОчко черты — за каждый Job Level." % ", ".join(tip2)})
	for cid in now["side"].keys():
		if not before["side"].has(cid):
			out.append({"kind": "contract", "title": DB.CONTRACTS[cid]["name"], "tip": DB.CONTRACTS[cid]["desc"]})
	return out

## Следующее сюжетное поручение, которое ещё не выполнено (или "")
func next_story_contract() -> String:
	for cid in DB.STORY_ORDER:
		if contract_done_count(cid) == 0:
			return cid
	return ""

## Угроза боя: (Σ эффективного здоровья) × (Σ урона в секунду) — «закон квадратов» Ланчестера.
## Знахарь добавляет здоровья группе, чемпион — свои множители.
func fight_threat(groups: Array, ambush: Array, lvl: int, champion := {}) -> float:
	var hp := 0.0
	var dps := 0.0
	var heal := 0.0
	var list := []
	for g in groups:
		list.append_array(g)
	list.append_array(ambush)
	if not champion.is_empty():
		list.append({"type": champion["type"], "champion": champion.get("affix", "")})
	for entry in list:
		var t := Balance.etype(entry)
		var es := DB.enemy_stats(t, Balance.elevel(entry, lvl))
		var e: Dictionary = DB.ENEMIES[t]
		var h: float = es["hp"] / (1.0 - Stats.armor_reduction(es["armor"], lvl))
		var d: float = (es["dmg_min"] + es["dmg_max"]) * 0.5 / float(e["interval"])
		# каждый приём или свойство врага на его ступени делает его опаснее
		d *= 1.0 + 0.12 * DB.enemy_skills(t, Balance.elevel(entry, lvl)).size()
		var af: String = entry.get("champion", "") if entry is Dictionary else ""
		if af != "":
			h *= DB.CHAMPION["hp"]
			d *= DB.CHAMPION["dmg"]
			match af:
				"stone": h *= 1.6 * 1.3
				"swift": d *= 1.5
				"vampire": h *= 1.35
				"fiery": d *= 1.3
		if t == "healer":
			heal += 0.2
		hp += h
		dps += d
	return hp * (1.0 + heal) * dps

## Ранг угрозы поручения: E … SSS. Шкала на всю игру, глава 1 (уровни 1–7) укладывается в E–D.
## score — опасность «для своего уровня»: бои маршрута (самый тяжёлый и средний) относительно
## эталонного боя с четырьмя разбойниками того же уровня; ночь, обоз и сундук добавляют.
## points ≈ уровень × √(score / 5) — по ним и выбирается ранг (пороги THREAT_RANKS, с запасом на будущие главы).
const THREAT_RANKS := [["E", 5.0], ["D", 10.0], ["C", 18.0], ["B", 28.0], ["A", 40.0], ["S", 52.0], ["SS", 64.0], ["SSS", 1e9]]
const THREAT_INFO := {
	"E": ["Пустяк", "Работа для только что собранной ватаги. Ошибки ещё прощаются."],
	"D": ["Простое", "По силам обученному отряду, если не зевать."],
	"C": ["Серьёзное", "Без слаженности и хорошего снаряжения не обойтись."],
	"B": ["Опасное", "Одна ошибка может стоить героя."],
	"A": ["Тяжёлое", "Работа для лучших гильдий королевства."],
	"S": ["Героическое", "О таких поручениях потом поют в трактирах."],
	"SS": ["Легендарное", "Возвращаются не все. Но о вернувшихся помнят века."],
	"SSS": ["Немыслимое", "Легенда — или эпитафия."],
}
## Цвет буквы ранга (пока нет картинок в assets/ui/ranks/)
const THREAT_COLORS := {"E": Color(0.7, 0.72, 0.66), "D": Color(0.55, 0.85, 0.45), "C": Color(0.45, 0.75, 1.0),
	"B": Color(0.8, 0.55, 1.0), "A": Color(1.0, 0.62, 0.3), "S": Color(1.0, 0.38, 0.3),
	"SS": Color(1.0, 0.82, 0.35), "SSS": Color(1.0, 0.95, 0.75)}

func contract_threat(cid: String) -> Dictionary:
	var c: Dictionary = DB.CONTRACTS[cid]
	if c.has("diplomacy"):
		return {"rank": c.get("rank", "D"), "score": 0.0, "points": 0.0, "fights": [], "top": -1}
	var lvl := int(c["level"])
	var ref := fight_threat([["bandit", "bandit", "bandit", "bandit"]], [], lvl)
	var fights := []
	if c.get("outpost", false):
		for w in c.get("waves", []):
			fights.append(fight_threat(Balance.wave_groups(w), [], lvl) / ref)
	for n in c.get("route", []):
		if n.get("type", "") == "battle":
			fights.append(fight_threat(n.get("groups", []), n.get("ambush", []), lvl, n.get("champion", {})) / ref)
	if fights.is_empty():
		return {"rank": "E", "score": 0.0, "points": 0.0, "fights": fights, "top": -1}
	var top: float = fights.max()
	var avg := 0.0
	for f in fights:
		avg += f
	avg /= fights.size()
	# Самый тяжёлый бой и средний бой поровну; каждый лишний бой без отдыха — +5%
	var score := (top + avg) * 0.5 * (1.0 + 0.05 * (fights.size() - 1))
	if c.get("night", false): score *= 1.2
	if c.get("escort", false): score *= 1.15
	if c.get("chest", false): score *= 1.1
	var points := lvl * sqrt(score / 5.0)
	var rank := "SSS"
	for r in THREAT_RANKS:
		if points < float(r[1]):
			rank = r[0]
			break
	return {"rank": rank, "score": score, "points": points, "fights": fights, "top": fights.find(top)}

## Особые условия поручения: [{title, tip, icon}] — из поля twists; чемпионы на маршруте не называются,
## вместо них одна общая плашка «Возможны опасные враги».
func contract_twists(cid: String) -> Array:
	var c: Dictionary = DB.CONTRACTS[cid]
	var out := []
	for t in c.get("twists", []):
		out.append({"title": t[0], "tip": t[1], "icon": "event"})
	for n in c.get("route", []):
		if n.has("champion"):
			out.append({"title": "Возможны опасные враги", "icon": "skull",
				"tip": "Говорят, на этом пути видели кого-то пострашнее обычных врагов.\nЗа победу над ним — лишняя вещь в добыче."})
			break
	var f := contract_xp_factor(cid)
	if f < 1.0:
		out.append({"title": "Отряд сильнее", "icon": "xp",
			"tip": "Отряд (ур. %d) выше врагов поручения (ур. %d): они падают быстрее,\nно опыта за них — %d%% от обычного." % [int(party_level()), int(c["level"]), int(round(f * 100.0))]})
	return out

## Средний уровень отряда
func party_level() -> float:
	var sum := 0.0
	for id in DB.HERO_IDS:
		sum += float(hero(id)["level"])
	return sum / DB.HERO_IDS.size()

## Доля опыта за врагов поручения при нынешнем уровне отряда (DB.xp_factor)
func contract_xp_factor(cid: String) -> float:
	return DB.xp_factor(party_level(), int(DB.CONTRACTS[cid]["level"]))

## Подсказка к рангу: название ранга, описание, опасность для своего уровня и самый тяжёлый бой.
func threat_tip(cid: String) -> String:
	var t := contract_threat(cid)
	var info: Array = THREAT_INFO[t["rank"]]
	var tip := "Ранг %s — %s\n%s" % [t["rank"], info[0], info[1]]
	if DB.CONTRACTS[cid].has("diplomacy"):
		var dcs := []
		for b in dip_scenario(cid)["beats"]:
			for o in b["options"]:
				if o.has("check"):
					dcs.append(int(o["check"]["dc"]))
		return tip + "\n\nБоёв нет. Проверки черт: КС %d–%d." % [dcs.min(), dcs.max()]
	var sc: float = t["score"]
	tip += "\n\nДля своего уровня: " + ("полегче обычного" if sc < 4.7 else ("как обычно" if sc < 5.9 else "тяжелее обычного")) + "."
	var c: Dictionary = DB.CONTRACTS[cid]
	if not c.get("outpost", false) and int(t["top"]) >= 0:
		var k := 0
		for n in c.get("route", []):
			if n.get("type", "") == "battle":
				if k == int(t["top"]):
					tip += "\nСамый тяжёлый бой: %s." % n["name"]
				k += 1
	return tip

# ================================================================ Отношения и знания
func rel(a: String, b: String) -> Dictionary:
	return state["relations"][DB.pair_key(a, b)]

func change_rel(a: String, b: String, friend: int, romance: int, why: String) -> void:
	var r := rel(a, b)
	if friend != 0:
		r["friend"] = clamp(int(r["friend"]) + friend, -50, 100)
	if romance != 0:
		r["romance"] = clamp(int(r["romance"]) + romance, 0, 100)
	if friend != 0 or romance != 0:
		r["history"].push_front({"text": why, "friend": friend, "romance": romance, "stage": int(state["story_stage"])})
		if r["history"].size() > 30:
			r["history"].pop_back()

func learn_fact(fid: String, status: String) -> bool:
	var facts: Dictionary = state["knowledge"]["facts"]
	var cur: String = facts.get(fid, "")
	if cur == "confirmed":
		return false
	if status == "assumed" and cur == "assumed":
		return false
	facts[fid] = status
	return true

func fact_text(fid: String) -> String:
	var f: Dictionary = DB.FACTS[fid]
	if state["knowledge"]["facts"].get(fid, "") == "assumed":
		return f.get("assumed", f["text"])
	return f["text"]

func pref_status(hid: String, gift: String) -> String:
	return state["knowledge"]["prefs"].get(hid, {}).get(gift, "")

func next_topic(hid: String) -> Variant:
	var r := rel("aiden", hid)
	for t in DB.TOPICS[hid]:
		if state["topics_done"].has(t["id"]):
			continue
		if int(r["friend"]) >= int(t["friend"]) and int(state["story_stage"]) >= int(t["story"]):
			return t
		return {"locked": true, "title": t["title"], "need_friend": t["friend"], "need_story": t["story"]}
	return null

func choice_allowed(hid: String, ch: Dictionary) -> bool:
	if ch.has("req_romance"):
		return int(rel("aiden", hid)["romance"]) >= int(ch["req_romance"])
	return true

func do_topic(hid: String, topic: Dictionary, ci: int) -> String:
	var ch: Dictionary = topic["choices"][ci]
	state["topics_done"][topic["id"]] = ci
	var notes := []
	change_rel("aiden", hid, int(ch.get("friend", 0)), int(ch.get("romance", 0)), "Разговор «%s»: «%s»" % [topic["title"], ch["text"]])
	if topic.has("fact") and learn_fact(topic["fact"], "confirmed"):
		notes.append("Журнал: " + fact_text(topic["fact"]))
	if topic.has("fact_assumed") and learn_fact(topic["fact_assumed"], "assumed"):
		notes.append("Журнал (предположение): " + fact_text(topic["fact_assumed"]))
	if topic.has("confirm") and learn_fact(topic["confirm"], "confirmed"):
		notes.append("Подтверждено: " + fact_text(topic["confirm"]))
	if topic.has("pref"):
		var p: Array = topic["pref"]
		if pref_status(p[0], p[1]) == "":
			state["knowledge"]["prefs"][p[0]][p[1]] = "assumed"
			notes.append("Предположение: %s любит %s." % [DB.hero_name(p[0]), DB.consumable_name(p[1]).to_lower()])
	var e := ex()
	if not e.is_empty():
		e["camp"]["talked_" + hid] = true
	save()
	changed.emit()
	var out: String = ch["say"]
	if ch.get("romance", 0) > 0:
		notes.append("Симпатия ↑ (отдельно от дружбы)")
	if notes.size() > 0:
		out += "\n\n" + "\n".join(notes)
	return out

func next_pair_scene() -> Variant:
	for p in DB.PAIR_SCENES:
		if state["pair_done"].has(p["id"]):
			continue
		if int(state["story_stage"]) >= int(p["story"]):
			return p
	return null

func do_pair_scene(p: Dictionary, ci: int) -> String:
	var ch: Dictionary = p["choices"][ci]
	state["pair_done"][p["id"]] = ci
	for k in ch["pair"].keys():
		var a: PackedStringArray = k.split("|")
		change_rel(a[0], a[1], int(ch["pair"][k]), 0, "У костра: %s — «%s»" % [p["title"], ch["text"]])
	var e := ex()
	if not e.is_empty():
		e["camp"]["pair"] = true
	save()
	changed.emit()
	return ch["say"]

## Личный вечер: подарок из рюкзака расходуется один раз (сохранение сразу).
func personal_evening(hid: String, gift: String) -> String:
	var e := ex()
	if e.is_empty() or e["camp"].get("evening", false):
		return ""
	if int(state["backpack"].get(gift, 0)) <= 0:
		return ""
	state["backpack"][gift] = int(state["backpack"][gift]) - 1
	if int(state["backpack"][gift]) <= 0:
		state["backpack"].erase(gift)
	var lines: Dictionary = DB.EVENING_LINES[hid]
	var out := ""
	if DB.PREFERENCES[hid] == gift:
		change_rel("aiden", hid, 9, 0, "Личный вечер: %s пришлись по душе." % DB.consumable_name(gift))
		state["knowledge"]["prefs"][hid][gift] = "confirmed"
		out = lines["love"] + "\n\nПредпочтение подтверждено. Дружба ↑↑."
	elif gift in DB.LIKES_OK[hid]:
		change_rel("aiden", hid, 4, 0, "Личный вечер: %s." % DB.consumable_name(gift))
		state["knowledge"]["prefs"][hid][gift] = "ok"
		out = lines["ok"] + "\n\nНеплохо, но не любимое. Дружба ↑."
	else:
		change_rel("aiden", hid, 1, 0, "Личный вечер: %s — не то." % DB.consumable_name(gift))
		state["knowledge"]["prefs"][hid][gift] = "no"
		out = lines["meh"] + "\n\nНе угадал. Журнал отметил это."
	e["camp"]["evening"] = true
	e["camp"]["evening_with"] = hid
	save()
	changed.emit()
	return out

func camp_rest() -> void:
	var e := ex()
	for id in DB.HERO_IDS:
		var d := derived(id)
		var hs: Dictionary = e["hero_state"][id]
		hs["hp"] = min(float(d["max_hp"]), hs["hp"] + d["max_hp"] * 0.4)
		hs["mp"] = min(float(d["max_mp"]), hs["mp"] + d["max_mp"] * 0.5)
	complete_node()
	save()
	changed.emit()

# ================================================================ Арена
func arena_config(preset: Dictionary, perks_override: Dictionary) -> Dictionary:
	var heroes := []
	for id in DB.HERO_IDS:
		var d := derived(id)
		var pk: Dictionary = perks_override.get(id, hero(id)["perks"]).duplicate()
		heroes.append({"id": id, "d": d, "hp": d["max_hp"], "mp": d["max_mp"], "atb": 0.0, "perks": pk, "level": int(hero(id)["level"])})
	return {"heroes": heroes, "formation": state["formation"], "groups": preset["groups"], "ambush": preset.get("ambush", []),
		"level": int(preset.get("level", 1)), "mode": "arena", "wagon": preset.get("wagon"), "gate": null, "chest": false,
		"kits": 2 if preset.get("wagon") != null else 0, "materials": 0, "boss": false,
		"night": preset.get("night", false), "champion": preset.get("champion", {}),
		"potions": {"potion_hp": 3, "potion_mp": 3}}

# ================================================================ Социальные черты
## Черты (DB.SOCIAL_STATS) — вторичные характеристики для проверок характера в дипломатии.
## Очки: по одному за каждый Job Level героя; вложенные очки лежат в hero["social"] {черта: очков}.
func social_unlocked() -> bool:
	return int(state["story_stage"]) >= DB.SOCIAL_UNLOCK_STORY

## Значение черты: природное (DB.SOCIAL_BASE) + очки. У сюжетных спутников (DB.STORY_NPCS) — фиксированное.
func social_value(id: String, stat: String) -> int:
	if DB.STORY_NPCS.has(id):
		return int(DB.STORY_NPCS[id]["social"].get(stat, 0))
	return int(DB.SOCIAL_BASE.get(id, {}).get(stat, 0)) + int(hero(id).get("social", {}).get(stat, 0))

func social_points(id: String) -> int:
	var used := 0
	for v in hero(id).get("social", {}).values():
		used += int(v)
	return int(hero(id)["job"]) - used

func social_problem(id: String, stat: String) -> String:
	if state["expedition"] != null or state.get("diplomacy") != null:
		return "В пути черты менять нельзя."
	if not social_unlocked():
		return "Откроется после «%s»." % DB.CONTRACTS[DB.STORY_ORDER[DB.SOCIAL_UNLOCK_STORY - 1]]["name"]
	if social_points(id) <= 0:
		return "Нет свободных очков. Новое очко — с каждым Job Level."
	if social_value(id, stat) >= DB.SOCIAL_MAX:
		return "Черта на пределе: %d." % DB.SOCIAL_MAX
	return ""

func add_social(id: String, stat: String) -> String:
	var p := social_problem(id, stat)
	if p != "":
		return p
	var h := hero(id)
	if not h.has("social"):
		h["social"] = {}
	h["social"][stat] = int(h["social"].get(stat, 0)) + 1
	save()
	changed.emit()
	return ""

func reset_social(id: String) -> String:
	if state["expedition"] != null or state.get("diplomacy") != null:
		return "В пути черты менять нельзя."
	hero(id)["social"] = {}
	save()
	changed.emit()
	return ""

# ================================================================ Дипломатия
## Миссия без боёв (поручение с полем "diplomacy"): сцены из DB.DIPLOMACY, варианты ответа с проверками черт.
## Состояние — state["diplomacy"]: номер сцены, расположение двора (favor), деньги, флаги, итог последнего выбора (last).
## Бросок делается и сохраняется сразу, поэтому перезагрузка его не переигрывает.
func dip() -> Dictionary:
	return state["diplomacy"] if state.get("diplomacy") != null else {}

func dip_scenario(cid := "") -> Dictionary:
	if cid == "":
		cid = dip()["cid"]
	return DB.DIPLOMACY[DB.CONTRACTS[cid]["diplomacy"]]

func dip_beat() -> Dictionary:
	var d := dip()
	var beats: Array = dip_scenario()["beats"]
	return beats[int(d["beat"])] if int(d["beat"]) < beats.size() else {}

func dip_finished() -> bool:
	return int(dip()["beat"]) >= dip_scenario()["beats"].size()

func start_diplomacy(cid: String) -> String:
	if state["expedition"] != null or state.get("diplomacy") != null:
		return "Отряд уже в пути."
	var c: Dictionary = DB.CONTRACTS[cid]
	if not c.has("diplomacy"):
		return "Это не дипломатическая миссия."
	if not contract_available(cid):
		return "Поручение ещё не открыто."
	if contract_done_count(cid) > 0:
		return "Миссия уже завершена."
	state["diplomacy"] = {"cid": cid, "beat": 0, "favor": 0, "coins": 0, "flags": {}, "log": [], "last": {}}
	save()
	changed.emit()
	return ""

func dip_option_problem(opt: Dictionary) -> String:
	var req: Dictionary = opt.get("req", {})
	if req.has("premium") and not state["premium_claimed"].has(req["premium"]):
		var rc: Dictionary = DB.CONTRACTS[req["premium"]]
		return "Нужна премия «%s» в поручении «%s»." % [rc["premium"]["name"], rc["name"]]
	return ""

## Напарник говорящего в миссии (второй участник)
func dip_partner(speaker: String) -> String:
	for p in dip_scenario()["party"]:
		if p != speaker:
			return p
	return ""

static func dip_name(id: String) -> String:
	return DB.STORY_NPCS[id]["name"] if DB.STORY_NPCS.has(id) else DB.hero_name(id)

## Расчёт проверки варианта: черта, бонусы сцены, помощь напарника, шанс успеха.
func dip_check_info(opt: Dictionary) -> Dictionary:
	var ck: Dictionary = opt["check"]
	var sp: String = opt.get("speaker", "aiden")
	var stat: String = ck["stat"]
	var mod := social_value(sp, stat)
	var bonus := 0
	var why := []
	var bmap: Dictionary = dip_beat().get("bonus", {})
	for f in bmap.keys():
		if dip()["flags"].has(f):
			bonus += int(bmap[f][0])
			why.append("+%d: %s" % [int(bmap[f][0]), bmap[f][1]])
	var helper := dip_partner(sp)
	var adv := helper != "" and social_value(helper, stat) >= DB.SOCIAL_HELP
	var need := int(ck["dc"]) - mod - bonus  # сколько нужно выбросить на d20
	var p: float = clamp((21.0 - need) / 20.0, 0.05, 0.95)
	if adv:
		p = 1.0 - (1.0 - p) * (1.0 - p)
	return {"speaker": sp, "stat": stat, "dc": int(ck["dc"]), "mod": mod, "bonus": bonus, "why": why,
		"adv": adv, "helper": helper, "chance": p}

## Выбрать вариант i текущей сцены: бросок, последствия, запись итога в last.
func dip_choose(i: int) -> Dictionary:
	var d := dip()
	if d.is_empty() or not d["last"].is_empty() or dip_finished():
		return {}
	var opt: Dictionary = dip_beat()["options"][i]
	if dip_option_problem(opt) != "":
		return {}
	var last := {"opt": i, "text": opt["text"], "check": opt.has("check")}
	var ok := false
	if opt.has("check"):
		var info := dip_check_info(opt)
		var rolls := [rng.randi_range(1, 20)]
		if info["adv"]:
			rolls.append(rng.randi_range(1, 20))
		var best: int = rolls.max()
		var total: int = best + int(info["mod"]) + int(info["bonus"])
		ok = best == 20 or (best != 1 and total >= int(info["dc"]))
		last.merge({"rolls": rolls, "roll": best, "total": total, "mod": info["mod"], "bonus": info["bonus"], "why": info["why"],
			"dc": info["dc"], "stat": info["stat"], "speaker": info["speaker"], "adv": info["adv"], "helper": info["helper"]})
	else:
		ok = bool(opt.get("answer", true))
	var r: Dictionary = opt.get("ok" if ok else "fail", {})
	last["ok"] = ok
	last["say"] = r.get("say", "")
	last["favor"] = int(r.get("favor", 0))
	last["coins"] = int(r.get("coins", 0))
	d["favor"] = int(d["favor"]) + last["favor"]
	d["coins"] = int(d["coins"]) + last["coins"]
	if r.has("flag"):
		d["flags"][r["flag"]] = true
	d["last"] = last
	d["log"].append({"beat": int(d["beat"]), "opt": i, "ok": ok, "favor": last["favor"]})
	save()
	changed.emit()
	return last

## К следующей сцене. true — сцены кончились, пора подводить итог.
func dip_next() -> bool:
	var d := dip()
	d["last"] = {}
	d["beat"] = int(d["beat"]) + 1
	save()
	return dip_finished()

func dip_outcome(favor: int, cid := "") -> Dictionary:
	for o in dip_scenario(cid)["outcomes"]:
		if favor >= int(o["min"]):
			return o
	return dip_scenario(cid)["outcomes"][-1]

## Итоги миссии — в том же виде, что и итоги похода (ResultDialog).
func finish_diplomacy() -> Dictionary:
	var d := dip()
	var cid: String = d["cid"]
	var c: Dictionary = DB.CONTRACTS[cid]
	var res := {"kind": "victory", "cid": cid, "name": c["name"], "lines": [], "coins": 0, "items": [], "levels": [], "jobs": [],
		"purse_return": 0, "choice": false, "outro": "", "chapter_end": false, "unlocks": [], "next": []}
	var snap := unlock_snapshot()
	var lines: Array = res["lines"]
	var favor := int(d["favor"])
	var out := dip_outcome(favor, cid)
	var first := contract_done_count(cid) == 0
	var total: int = int(c["pay"]) if first else int(c["repeat_pay"])
	lines.append("Оплата контракта: %d мон." % total)
	lines.append("Расположение двора: %d" % favor)
	lines.append("Итог: %s" % out["name"])
	var prem: Dictionary = c["premium"]
	if out["id"] == "triumph" and not state["premium_claimed"].has(cid):
		state["premium_claimed"][cid] = true
		total += int(prem["coins"])
		lines.append("Премия «%s»: +%d мон." % [prem["name"], prem["coins"]])
	elif out["id"] != "triumph":
		lines.append("Премия «%s» упущена (миссия засчитана)." % prem["name"])
	var spent := int(d["coins"])
	if spent != 0:
		lines.append("Расходы и подарки в столице: %+d мон." % spent)
	total += spent
	if first:
		for id in DB.HERO_IDS:
			for j in _add_jxp(id, int(c["jxp"])):
				res["jobs"].append([id, j])
		lines.append("Освоение поручения: +%d JXP всем героям." % c["jxp"])
		var heroes := DB.HERO_IDS.duplicate()
		for i in range(heroes.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = heroes[i]
			heroes[i] = heroes[j]
			heroes[j] = tmp
		var choice := []
		var q := distinct_completed() * 0.5
		for i in 3:
			var hid: String = heroes[i]
			choice.append(Items.item_for_hero(hid, int(hero(hid)["level"]) + 1, int(c["level"]) + 1, rng, q + 1.0))
		state["pending_choice"] = choice
		res["choice"] = true
	state["treasury"] = max(0, int(state["treasury"]) + total)
	res["coins"] = total
	state["completed"][cid] = contract_done_count(cid) + 1
	if first:
		state["trust"] = int(state["trust"]) + 2
		if int(c["story"]) > int(state["story_stage"]):
			state["story_stage"] = int(c["story"])
		state["flags"]["%s_outcome" % cid] = out["id"]
		res["outro"] = out["text"] + " " + c["outro"]
		if c.get("finale", false):
			state["chapter_done"] = true
			res["chapter_end"] = true
	res["levels"] = _apply_levels()
	res["unlocks"] = unlocks_since(snap)
	state["diplomacy"] = null
	state["last_result"] = res
	save()
	changed.emit()
	return res
