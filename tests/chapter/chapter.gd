extends Node
## Проходимость поручений главы 1 при разном «усилии» игрока (бот, см. tests/chapter/bot.gd).
## 1) Опорное прохождение c1→c7 ботом REF (повторы до победы), между поручениями — экипировка, перки,
##    зелья, награда. Перед каждым поручением — снимок сохранения.
## 2) Для каждого поручения и каждого уровня усилия — N попыток с этого снимка.
## 3) CAMPAIGN=1: вся глава с нового сохранения на одном уровне усилия, с повторами; сколько попыток уходит.
## TIERS="1.5,3,4.5,6,9,12" N=40 REF=2 CIDS=c1,c2,... godot --headless --path . res://tests/chapter/Chapter.tscn

const BotT := preload("res://tests/chapter/bot.gd")
const STORY := ["c1", "c2", "c3", "c4", "c5", "c6", "c7"]

func _env(k: String, d: String) -> String:
	return OS.get_environment(k) if OS.get_environment(k) != "" else d

func party_hp(sim: BattleSim) -> float:
	var h := 0.0
	var m := 0.0
	for u in sim.s["units"]:
		if u["side"] == "hero":
			h += max(0.0, u["hp"]); m += u["max_hp"]
	return h / max(1.0, m)

# ---------------------------------------------------------------- деревня
func gear_score(id: String) -> float:
	var d := Game.derived(id)
	var dps: float = (float(d["dmg_min"]) + float(d["dmg_max"])) * 0.5 / max(0.5, float(d["interval"]))
	var sc: float = float(d["max_hp"]) + float(d["armor"]) * 0.6 + dps * 20.0 + float(d["crit"]) * 3.0 + float(d["dodge"]) * 3.0
	sc += float(d.get("block", 0.0)) * 2.0 + float(d.get("parry", 0.0)) * 2.0 + float(d["hit"]) * 2.0
	if id in ["aiden", "neris"]:
		sc += float(d["sp"]) * 6.0 + float(d["max_mp"]) * 0.3
	return sc

func equip_all() -> void:
	if Game.has_method("equip_best"):
		for h in DB.HERO_IDS:
			Game.equip_best(h)
		return
	var changed := true
	var guard := 0
	while changed and guard < 40:
		changed = false
		guard += 1
		var st: Array = Game.storage()
		for i in st.size():
			if st[i] == null:
				continue
			var best_h := ""
			var best_gain := 0.5
			for h in DB.HERO_IDS:
				var it: Dictionary = st[i]
				var sl := Game.auto_slot(h, it)
				if Game.equip_problem(h, it, sl) != "":
					continue
				var before := gear_score(h)
				var eq: Dictionary = Game.hero(h)["equip"]
				var old = eq[sl]
				var old_off = eq.get("off")
				eq[sl] = it
				if sl == "main" and int(Items.base_of(it).get("hands", 1)) == 2:
					eq["off"] = null
				var gain := gear_score(h) - before
				eq[sl] = old
				eq["off"] = old_off
				if gain > best_gain:
					best_gain = gain
					best_h = h
			if best_h != "":
				if Game.equip_from_storage(best_h, i) == "":
					changed = true

## Лавка: покупать вещи, которые дают герою прирост силы ≥ 3% (запас 120 мон. на зелья)
func shop_buy() -> void:
	var guard := 0
	while guard < 10:
		guard += 1
		var stock: Array = Game.state["shop"]["stock"]
		var bi := -1
		var bg := 0.03
		for i in stock.size():
			if Game.shop_price(stock[i]) > int(Game.state["treasury"]) - 120:
				continue
			for h in DB.HERO_IDS:
				var g: Dictionary = Game.upgrade_gain(h, stock[i])
				if g["slot"] != "" and float(g["gain"]) > bg:
					bg = float(g["gain"])
					bi = i
		if bi < 0:
			return
		if Game.buy_item(bi) != "":
			return
		equip_all()

## ITEMS — откуда опорный бот берёт вещи: loot (добыча похода), reward (награда 1 из 3), shop (покупки).
## По умолчанию loot,reward; "none" — ни откуда (стартовые вещи).
func items_has(src: String) -> bool:
	var m := _env("ITEMS", "loot,reward")
	if OS.get_environment("SHOP") == "1" and src == "shop":
		return true
	return src in m.split(",")

func village(r: RandomNumberGenerator) -> void:
	if not Game.state["pending_choice"].is_empty():
		if items_has("reward"):
			Game.choose_pending(r.randi_range(0, Game.state["pending_choice"].size() - 1))
		else:
			Game.state["pending_choice"] = []
	if Game.has_method("take_queue"):
		Game.take_queue()
	if items_has("shop"):
		shop_buy()
	equip_all()
	# Перки: первый вариант доступной стадии (влияние перков по отдельности — в шуме, см. ревью)
	for h in DB.HERO_IDS:
		for stg in DB.PERK_STAGES.keys():
			if Game.perk_points(h) <= 0:
				break
			if Game.perk_stage_problem(h, stg) == "" and str(Game.perks_of(h).get(stg, "")) == "":
				var opts: Array = DB.PERKS[h][stg]
				Game.choose_perk(h, stg, opts[r.randi_range(0, opts.size() - 1)]["id"])
	# Очки характеристик, если есть (версии после ревью)
	if Game.has_method("spend_auto"):
		for h in DB.HERO_IDS:
			Game.spend_auto(h)
	# Зелья: добрать до 3 ОЗ / 2 маны
	while int(Game.state["potions"]["potion_hp"]) < 3 and Game.buy_cons("potion_hp") == "":
		pass
	while int(Game.state["potions"]["potion_mp"]) < 2 and Game.buy_cons("potion_mp") == "":
		pass

# ---------------------------------------------------------------- поход
func fight(groups: Array, nd: Dictionary, bot, rec: Dictionary) -> bool:
	var cfg := Game.battle_config(groups, nd.get("ambush", []), nd.get("boss", false), nd.get("chest", false), nd.get("champion", {}))
	if nd.has("hp_pct"):
		cfg["hp_pct"] = int(nd.get("hp_pct", 100))
	if nd.has("dmg_pct"):
		cfg["dmg_pct"] = int(nd.get("dmg_pct", 100))
	var sim := BattleSim.new()
	sim.setup(cfg)
	var t := 0.0
	while not sim.is_over() and t < 1500.0:
		if sim.s["phase"] == "prep":
			prep(sim, rec)
		sim.step(0.05)
		bot.tick(sim)
		t += 0.05
		rec["min_hp"] = min(rec["min_hp"], party_hp(sim))
	rec["time"] += t
	if OS.get_environment("DEBUG") == "1":
		print("  fight %s: t=%d phase=%s wave=%s/%s hp=%d%% loss=%s" % [nd.get("name", "?"), int(t), sim.s["phase"], sim.s.get("wave", 0), sim.s["waves"].size(), int(100 * party_hp(sim)), sim.s.get("loss", "")])
	rec["fights"] = int(rec.get("fights", 0)) + 1
	rec["ko"] += sim.s["counters"]["ko"].size()
	rec["potions"] += int(sim.s["counters"]["potions"])
	if sim.s["phase"] != "won":
		rec["lost_at"] = str(nd.get("name", "?"))
		if sim.s["mode"] == "outpost":
			rec["lost_at"] += " волна %d" % int(sim.s["wave"])
		rec["loss"] = str(sim.s.get("loss", ""))
		if OS.get_environment("DEBUGLOG") == "1":
			var lg: Array = sim.s["log"]
			print("---- LOST %s t=%d" % [nd.get("name", "?"), int(t)])
			for l in lg.slice(max(0, lg.size() - 45)):
				print("   | ", l)
		return false
	rec["end_hp"] = party_hp(sim)
	Game.absorb_battle(sim)
	return true

## Передышка между волнами обороны: потушить, починить ворота, выпустить следующую волну
func prep(sim: BattleSim, rec: Dictionary) -> void:
	for k in sim.s["objects"].keys():
		var o: Dictionary = sim.s["objects"][k]
		for h in sim.alive_of("hero"):
			if o["burning"] > 0.0 and sim.task_problem(h["uid"], "extinguish", k) == "":
				sim.start_task(h["uid"], "extinguish", k)
		var guard := 0
		while guard < 6 and o["hp"] < o["max"] * 0.75:
			guard += 1
			var done := false
			for h in sim.alive_of("hero"):
				if sim.task_problem(h["uid"], "repair", k) == "":
					sim.start_task(h["uid"], "repair", k)
					done = true
					break
			if not done:
				break
	rec["waves"] = int(sim.s.get("wave", 0)) + 1
	sim.start_next_wave()

func event_pick(ev_id: String, ev: Dictionary, r: RandomNumberGenerator) -> Dictionary:
	# Разумный игрок: первый вариант, который можно оплатить (обычно «помочь»), иначе последний
	var ch: Dictionary = ev["choices"][0]
	if Game.event_choice_problem(ch) != "":
		ch = ev["choices"][ev["choices"].size() - 1]
	return ch

func run_contract(cid: String, bot, r: RandomNumberGenerator) -> Dictionary:
	var rec := {"won": false, "time": 0.0, "min_hp": 1.0, "end_hp": 0.0, "ko": 0, "potions": 0, "lost_at": "", "loss": ""}
	var c: Dictionary = DB.CONTRACTS[cid]
	var opts := {"purse": Game.default_purse(), "general": c["general"][0] if c["general"].size() > 0 else "",
		"personal": {"hero": "aiden", "obj": "healing"}}
	var err := Game.start_expedition(cid, opts)
	if err != "":
		push_error(cid + ": " + err)
		rec["lost_at"] = "старт: " + err
		return rec
	while not Game.route_finished():
		var nd := Game.current_node()
		Game.walk_regen(2.6)
		match nd["type"]:
			"battle":
				if not fight(nd.get("groups", []), nd, bot, rec):
					Game.finish_expedition("defeat")
					return rec
				Game.complete_node()
			"event":
				var ev: Dictionary = DB.EVENTS[nd["event"]]
				var ch := event_pick(nd["event"], ev, r)
				var b := Game.apply_event_choice(ch)
				if not b.is_empty():
					if not fight(b, {"name": "Событие: " + str(ev["title"])}, bot, rec):
						Game.finish_expedition("defeat")
						return rec
				Game.complete_node()
			"outpost":
				if not fight([], nd, bot, rec):
					Game.finish_expedition("defeat")
					return rec
				Game.complete_node()
			"camp":
				Game.camp_rest()
			_:
				Game.complete_node()
	var res := Game.finish_expedition("victory")
	rec["won"] = true
	return rec

func new_save() -> void:
	Game.state = Game._fresh_state()
	Game.state["intro_seen"] = true
	equip_all()

func snapshot() -> Dictionary:
	return Game.state.duplicate(true)

func party_desc() -> String:
	var a := []
	for h in DB.HERO_IDS:
		a.append("%s %d" % [h, int(Game.hero(h)["level"])])
	return ", ".join(a)

# ---------------------------------------------------------------- диплом. финал c8
## Очки черт Эйдена: none — не тратить, spread — по кругу, focus — в черты его проверок (по числу проверок)
func social_build(mode: String) -> void:
	if mode == "none" or not Game.social_unlocked():
		return
	var order: Array = DB.SOCIAL_STATS.duplicate()
	if mode == "focus":
		var cnt := {}
		for b in DB.DIPLOMACY["capital"]["beats"]:
			for o in b.get("options", []):
				if o.has("check") and o.get("speaker", "aiden") == "aiden":
					cnt[o["check"]["stat"]] = int(cnt.get(o["check"]["stat"], 0)) + 1
		order.sort_custom(func(a, b): return int(cnt.get(a, 0)) > int(cnt.get(b, 0)))
		var k := 0
		while Game.social_points("aiden") > 0 and k < 40:
			for stt in order:
				if Game.add_social("aiden", stt) == "":
					break
			k += 1
		return
	var g := 0
	while Game.social_points("aiden") > 0 and g < 40:
		Game.add_social("aiden", order[g % order.size()])
		g += 1

func _exp_favor(opt: Dictionary) -> float:
	var okf := float(opt.get("ok", {}).get("favor", 0))
	var ff := float(opt.get("fail", {}).get("favor", 0))
	if opt.has("check"):
		var p: float = Game.dip_check_info(opt)["chance"]
		return p * okf + (1.0 - p) * ff
	return okf if bool(opt.get("answer", true)) else ff

func run_c8(mode: String) -> Dictionary:
	social_build(mode)
	var err := Game.start_diplomacy("c8")
	if err != "":
		return {"err": err}
	var guard := 0
	while not Game.dip_finished() and guard < 100:
		guard += 1
		var opts: Array = Game.dip_beat().get("options", [])
		var best := -1
		var bv := -1e9
		for i in opts.size():
			if Game.dip_option_problem(opts[i]) != "":
				continue
			var v := _exp_favor(opts[i])
			if v > bv:
				bv = v
				best = i
		if best >= 0:
			Game.dip_choose(best)
		Game.dip_next()
	var favor := int(Game.dip()["favor"])
	var out := Game.dip_outcome(favor, "c8")
	return {"err": "", "favor": favor, "outcome": str(out["id"])}

# ---------------------------------------------------------------- варианты экипировки
## GEARS: ref — как одел себя опорный бот; start — стартовые вещи (ничего не менял); lag2 — те же вещи на 2 уровня ниже
## (отстал на пару походов); common — те же вещи без свойств и редкости; plus3 / plus5 — всё заточено в Кузнице.
const START_GEAR := {
	"aiden": [["staff_novice", "main"], ["cloth_chest", "chest"], ["cloth_feet", "feet"]],
	"marek": [["sword_rusty", "main"], ["shield_wood", "off"], ["mail_chest", "chest"], ["mail_feet", "feet"]],
	"elira": [["bow_hunt", "main"], ["leather_chest", "chest"], ["leather_feet", "feet"]],
	"neris": [["staff_novice", "main"], ["cloth_chest", "chest"], ["cloth_head", "head"]],
}

func apply_gear(mode: String) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 99
	for h in DB.HERO_IDS:
		var eq: Dictionary = Game.hero(h)["equip"]
		if mode == "start":
			for sl in eq.keys():
				eq[sl] = null
			for g in START_GEAR[h]:
				eq[g[1]] = Items.make(g[0], 1, "common", r)
			continue
		for sl in eq.keys():
			var it = eq[sl]
			if it == null:
				continue
			match mode:
				"lag2":
					it["ilvl"] = maxi(1, int(it.get("ilvl", 1)) - 2)
					# свойства тоже слабее: масштабируем по росту ilvl
					for a in it.get("affixes", []):
						a[1] = max(1, int(round(float(a[1]) * 0.8))) if not a[0] in DB.PCT_STATS else snapped(float(a[1]) * 0.8, 0.1)
				"common":
					it["affixes"] = []
					it["rarity"] = "common"
				"plus3":
					it["plus"] = 3
				"plus5":
					it["plus"] = 5

## Средняя «сила» героев (Stats.power) по снимкам с этим вариантом экипировки
func gear_power(cid_snaps: Array, mode: String) -> String:
	var a := []
	for h in DB.HERO_IDS:
		var sm := 0.0
		for sn in cid_snaps:
			Game.state = sn.duplicate(true)
			apply_gear(mode)
			sm += Stats.power(h, int(Game.hero(h)["level"]), Game.hero(h)["equip"])
		a.append("%s %d" % [h, int(sm / cid_snaps.size())])
	return ", ".join(a)

# ---------------------------------------------------------------- варианты перков
## PERKS: ref — как выбрал опорный бот (случайно); none — без перков; a / b — везде первый / второй вариант;
## only:<id> — только этот один перк (у остальных пусто); without:<id> — как a/b по стадиям, но этот один снят.
## Стадии берутся только те, что у героя уже открыты на этом снимке.
func apply_perks(mode: String) -> void:
	if mode == "ref":
		return
	for h in DB.HERO_IDS:
		var pk: Dictionary = Game.hero(h)["perks"]
		for stg in DB.PERK_STAGES.keys():
			var open := Game.perk_stage_problem(h, stg) == "" and int(Game.hero(h)["job"]) - 1 >= int(stg)
			var opts: Array = DB.PERKS[h][stg]
			var v := ""
			if open:
				if mode == "a":
					v = opts[0]["id"]
				elif mode == "b":
					v = opts[1]["id"]
				elif mode.begins_with("only:"):
					for o in opts:
						if o["id"] == mode.substr(5):
							v = o["id"]
			pk[stg] = v

## Какие перки вообще открыты на снимке (для only:)
func open_perks(snap: Dictionary) -> Array:
	Game.state = snap.duplicate(true)
	var out := []
	for h in DB.HERO_IDS:
		for stg in DB.PERK_STAGES.keys():
			if Game.perk_stage_problem(h, stg) == "" and int(Game.hero(h)["job"]) - 1 >= int(stg):
				for o in DB.PERKS[h][stg]:
					out.append(o["id"])
	return out

# ---------------------------------------------------------------- main
func _ready() -> void:
	Game.slot = -1
	var r := RandomNumberGenerator.new()
	r.seed = int(_env("SEED", "7"))
	var n := int(_env("N", "40"))
	var ref := float(_env("REF", "2"))
	var tiers := _env("TIERS", "1.5,3,4.5,6,9,12")
	var cids := _env("CIDS", ",".join(STORY)).split(",")
	var out := _env("OUT", "user://chapter.json")
	var report := {"ref": ref, "progress": [], "tiers": {}, "campaign": {}}
	# 1) Опорное прохождение (SNAPS раз — снимки чередуются в проверке, чтобы не зависеть от одной добычи)
	var snaps := {}
	var ns := int(_env("SNAPS", "4"))
	for si in ns:
		new_save()
		for cid in STORY:
			village(r)
			if not snaps.has(cid):
				snaps[cid] = []
			snaps[cid].append(snapshot())
			var tries := 0
			var bot = BotT.new(ref)
			while true:
				tries += 1
				var before: Array = Game.storage().duplicate()
				var rec := run_contract(cid, bot, r)
				# Без добычи: всё, что поход положил в кладовую и очередь, убираем
				if not items_has("loot"):
					var st: Array = Game.storage()
					for k in st.size():
						if st[k] != null and not is_same(st[k], before[k]):
							st[k] = null
					Game.state["queue"] = []
				if rec["won"] or tries >= 15:
					break
				village(r)
			var pw := 0.0
			for h in DB.HERO_IDS:
				pw += Stats.power(h, int(Game.hero(h)["level"]), Game.hero(h)["equip"])
			var line := "REF#%d %s: попыток %d, после: %s, казна %d, сила %d" % [si, cid, tries, party_desc(), int(Game.state["treasury"]), int(pw)]
			print(line)
			report["progress"].append(line)
		village(r)
		if not snaps.has("c8"):
			snaps["c8"] = []
		snaps["c8"].append(snapshot())
	# 2) Каждое поручение со снимка
	for cid in cids:
		if cid == "c8":
			continue
		var rows := []
		var pmodes: Array = []
		for pm in _env("PERKS", "ref").split(","):
			if pm == "each":
				for pid in open_perks(snaps[cid][0]):
					pmodes.append("only:" + pid)
			else:
				pmodes.append(pm)
		for pm in pmodes:
			for gm in _env("GEARS", "ref").split(","):
				if pm == pmodes[0]:
					print("GEARPOW %s %s: %s" % [cid, gm, gear_power(snaps[cid], gm)])
				for ts in tiers.split(","):
					var react := float(ts)
					var w := 0
					var lost := {}
					var eh := 0.0
					var mh := 0.0
					var ko := 0.0
					var pot := 0.0
					for i in n:
						Game.state = snaps[cid][i % snaps[cid].size()].duplicate(true)
						apply_gear(gm)
						apply_perks(pm)
						var bot = BotT.new(react)
						var rec := run_contract(cid, bot, r)
						if rec["won"]:
							w += 1
							eh += rec["end_hp"]
							mh += rec["min_hp"]
							ko += rec["ko"]
							pot += rec["potions"]
						else:
							var key: String = rec["lost_at"] + ("" if rec["loss"] in ["", "Отряд пал."] else " (" + rec["loss"] + ")")
							lost[key] = int(lost.get(key, 0)) + 1
					var wd: float = max(1, w)
					var row := {"perks": pm, "gear": gm, "react": react, "n": n, "wins": w, "end_hp": eh / wd, "min_hp": mh / wd, "ko": ko / wd, "potions": pot / wd, "lost": lost}
					rows.append(row)
					print("TIER %s perks=%s gear=%s react=%s: побед %d/%d, ОЗ в конце %d%%, мин %d%%, нокаутов %.1f, зелий %.1f, поражения %s" % [
						cid, pm, gm, ts, w, n, 100 * eh / wd, 100 * mh / wd, ko / wd, pot / wd, lost])
		report["tiers"][cid] = rows
	# c8: дипломатия, усилие не влияет; варьируем черты Эйдена
	if "c8" in cids:
		report["c8"] = {}
		var nd := int(_env("N8", "2000"))
		for mode in ["none", "spread", "focus"]:
			var outs := {}
			var fav := 0.0
			var e8 := ""
			for i in nd:
				Game.state = snaps["c8"][i % snaps["c8"].size()].duplicate(true)
				var rr := run_c8(mode)
				if rr["err"] != "":
					e8 = rr["err"]
					break
				fav += rr["favor"]
				outs[rr["outcome"]] = int(outs.get(rr["outcome"], 0)) + 1
			var soc := {}
			for stt in DB.SOCIAL_STATS:
				soc[stt] = Game.social_value("aiden", stt)
			print("C8 %s: исходы %s, расположение в среднем %.1f, черты Эйдена %s %s" % [mode, outs, fav / max(1, nd), soc, e8])
			report["c8"][mode] = {"outcomes": outs, "favor": fav / max(1, nd), "aiden": soc, "err": e8}
	# 3) Кампания с повторами
	if _env("CAMPAIGN", "0") == "1":
		var nc := int(_env("NC", "10"))
		for ts in tiers.split(","):
			var react := float(ts)
			var per := {}
			var done := 0
			for k in nc:
				new_save()
				var ok := true
				for cid in STORY:
					village(r)
					var tries := 0
					var bot = BotT.new(react)
					while true:
						tries += 1
						var rec := run_contract(cid, bot, r)
						if rec["won"]:
							break
						if tries >= 8:
							ok = false
							break
						village(r)
					per[cid] = per.get(cid, []) + [tries]
					if not ok:
						break
				if ok:
					done += 1
			var avg := {}
			for cid in per.keys():
				var s := 0.0
				for t in per[cid]:
					s += t
				avg[cid] = snapped(s / per[cid].size(), 0.1)
			print("CAMPAIGN react=%s: глава пройдена %d/%d, попыток в среднем %s" % [ts, done, nc, avg])
			report["campaign"][ts] = {"done": done, "n": nc, "avg_tries": avg, "tries": per}
	var f := FileAccess.open(out, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
	get_tree().quit()
