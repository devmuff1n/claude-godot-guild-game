class_name BalanceEditor
extends Control
## Скрытое меню баланса (F10, только в отладочной сборке): состав волн, уровни врагов, множители точек,
## параметры типов врагов. Правки сразу действуют в игре, «Сохранить» пишет data/balance.json.
## Вёрстка — scenes/ui/balance/*.tscn, данные — scripts/core/Balance.gd.

const POINT_BTN := preload("res://scenes/ui/balance/BalancePointButton.tscn")
const GROUP := preload("res://scenes/ui/balance/BalanceGroup.tscn")
const ENEMY_ROW := preload("res://scenes/ui/balance/BalanceEnemyRow.tscn")
const TYPE_ROW := preload("res://scenes/ui/balance/BalanceTypeRow.tscn")
const EVENTS_KEY := "events"

var main
var doc: Dictionary = {}
var dirty := false
var tab := "waves"
var cid := "c1"
var point := 0
var keys: Array = []          # ключи поручений в списке (+ EVENTS_KEY)
var type_ids: Array = []      # типы врагов в порядке выпадающего списка
var rows: Array = []          # [{row, list, i}] — строки врагов текущей точки
var sums: Array = []          # [{label, list}] — подписи групп
var was_paused := false

func _ready() -> void:
	was_paused = get_tree().paused
	get_tree().paused = true
	doc = Balance.export_doc()
	type_ids = DB.ENEMIES.keys().filter(func(t): return not "minion" in DB.ENEMIES[t].get("tags", []))
	%TabWaves.pressed.connect(func(): _set_tab("waves"))
	%TabTypes.pressed.connect(func(): _set_tab("types"))
	%Close.pressed.connect(close)
	%Contract.item_selected.connect(func(i: int):
		cid = keys[i]
		point = 0
		_render_waves())
	%CLevel.changed.connect(_on_contract_level)
	%HpPct.changed.connect(func(v): _set_point_value("hp_pct", int(v)))
	%DmgPct.changed.connect(func(v): _set_point_value("dmg_pct", int(v)))
	%AddGroup.pressed.connect(_add_group)
	%AddAmbush.pressed.connect(_add_ambush)
	%AllHp.changed.connect(func(v): _set_all("hp_pct", int(v)))
	%AllDmg.changed.connect(func(v): _set_all("dmg_pct", int(v)))
	%SampleLvl.changed.connect(func(_v): _refresh_type_samples())
	%Save.pressed.connect(_save)
	%Revert.pressed.connect(_revert)
	%Defaults.pressed.connect(_defaults)
	%Play.pressed.connect(_play)
	_pick_start()
	%SampleLvl.set_value(_clevel())
	_fill_contracts()
	_set_tab("waves")
	_status("")

## Открыть сразу на нужной точке: {"cid": "c1", "point": 2, "tab": "waves"}
func focus(f: Dictionary) -> void:
	if f.is_empty():
		return
	if doc["contracts"].has(f.get("cid", "")) or f.get("cid", "") == EVENTS_KEY:
		cid = f["cid"]
		point = int(f.get("point", 0))
	_fill_contracts()
	_set_tab(f.get("tab", "waves"))

func close() -> void:
	if dirty:
		Game.toast.emit("Правки баланса действуют, но не сохранены в файл")
	get_tree().paused = was_paused
	queue_free()

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode in [KEY_ESCAPE, KEY_F10]:
		get_viewport().set_input_as_handled()
		close()

# ---------------------------------------------------------------- Выбор
## Стартовая точка: текущий бой похода, иначе первое поручение
func _pick_start() -> void:
	var e := Game.ex() if not Game.state.is_empty() else {}
	if e.is_empty() or not doc["contracts"].has(e["cid"]):
		return
	cid = e["cid"]
	var pts: Array = doc["contracts"][cid]["points"]
	for i in pts.size():
		if int(pts[i].get("node", -1)) == int(e["node"]):
			point = i
	if DB.CONTRACTS[cid].has("waves") and e.get("battle") is Dictionary:
		point = clampi(int(e["battle"].get("wave", 1)) - 1, 0, pts.size() - 1)

func _fill_contracts() -> void:
	keys = []
	%Contract.clear()
	var order: Array = DB.STORY_ORDER.duplicate()
	for k in doc["contracts"]:
		if not k in order:
			order.append(k)
	for k in order:
		if not doc["contracts"].has(k):
			continue
		keys.append(k)
		%Contract.add_item("%s · %s" % [k, doc["contracts"][k]["name"]])
	if not doc.get("events", {}).is_empty():
		keys.append(EVENTS_KEY)
		%Contract.add_item("Бои из событий")
	if not cid in keys:
		cid = keys[0]
	%Contract.select(keys.find(cid))

func _set_tab(t: String) -> void:
	tab = t
	UIK.mark(%TabWaves, t == "waves")
	UIK.mark(%TabTypes, t == "types")
	%Waves.visible = t == "waves"
	%Types.visible = t == "types"
	%Play.visible = t == "waves"
	if t == "waves":
		_render_waves()
	else:
		_render_types()

# ---------------------------------------------------------------- Данные текущей точки
func _points() -> Array:
	if cid == EVENTS_KEY:
		var out := []
		for k in doc["events"]:
			out.append(doc["events"][k])
		return out
	return doc["contracts"][cid]["points"]

func _cur() -> Dictionary:
	var pts := _points()
	point = clampi(point, 0, pts.size() - 1)
	return pts[point]

## Уровень поручения (для врагов с уровнем «авто»)
func _clevel() -> int:
	if cid != EVENTS_KEY:
		return int(doc["contracts"][cid]["level"])
	var e := Game.ex() if not Game.state.is_empty() else {}
	return int(DB.CONTRACTS[e["cid"]]["level"]) if not e.is_empty() else 1

func _changed() -> void:
	Balance.apply_doc(doc)
	dirty = true
	_status("")

# ---------------------------------------------------------------- Вкладка «Волны»
func _render_waves() -> void:
	%CLevelRow.visible = cid != EVENTS_KEY
	if cid != EVENTS_KEY:
		%CLevel.set_value(_clevel())
	UIK.clear(%Points)
	var pts := _points()
	if pts.is_empty():
		return
	point = clampi(point, 0, pts.size() - 1)
	for i in pts.size():
		var idx := i
		var b: Button = POINT_BTN.instantiate()
		%Points.add_child(b)
		b.text = "%s\n%s" % [pts[i]["name"], _short(pts[i])]
		b.tooltip_text = pts[i]["name"]
		UIK.mark(b, i == point)
		b.pressed.connect(func():
			point = idx
			_render_waves())
	_render_point()

func _short(p: Dictionary) -> String:
	var n := 0
	var lo := 99
	var hi := 0
	for g in p["groups"] + [p.get("ambush", [])]:
		for e in g:
			n += 1
			var l := Balance.elevel(e, _clevel())
			lo = min(lo, l)
			hi = max(hi, l)
	if n == 0:
		return "пусто"
	var lv := ("ур. %d" % lo) if lo == hi else ("ур. %d–%d" % [lo, hi])
	var pct := ""
	if int(p.get("hp_pct", 100)) != 100 or int(p.get("dmg_pct", 100)) != 100:
		pct = " · %d%%/%d%%" % [int(p.get("hp_pct", 100)), int(p.get("dmg_pct", 100))]
	return "%d %s · %s%s" % [n, _plural(n, "враг", "врага", "врагов"), lv, pct]

func _plural(n: int, one: String, few: String, many: String) -> String:
	var m10 := n % 10
	var m100 := n % 100
	if m10 == 1 and m100 != 11:
		return one
	if m10 >= 2 and m10 <= 4 and (m100 < 10 or m100 >= 20):
		return few
	return many

func _render_point() -> void:
	var scroll: int = %GroupsScroll.scroll_vertical
	var p := _cur()
	%PointName.text = p["name"]
	var has_pct := p.has("hp_pct")
	for n in [%HpPct, %DmgPct]:
		n.visible = has_pct
	%HpPct.get_parent().get_node("HpLabel").visible = has_pct
	%HpPct.get_parent().get_node("DmgLabel").visible = has_pct
	if has_pct:
		%HpPct.set_value(int(p.get("hp_pct", 100)))
		%DmgPct.set_value(int(p.get("dmg_pct", 100)))
	%AddAmbush.visible = p.has("ambush") and p["ambush"].is_empty()
	UIK.clear(%Groups)
	rows = []
	sums = []
	var gs: Array = p["groups"]
	# На дороге каждая группа — отдельная волна (выходят по очереди), у заставы группы волны идут разом
	var waves := not p.has("wave")
	%AddGroup.text = "+ волна" if waves else "+ группа"
	for gi in gs.size():
		_add_group_panel(("Волна %d" if waves else "Группа %d") % (gi + 1), gs[gi], func():
			gs.remove_at(gi)
			_structure_changed(), gs.size() > 1)
	if p.has("ambush") and not p["ambush"].is_empty():
		_add_group_panel("Засада сзади · волна %d" % mini(2, gs.size()), p["ambush"], func():
			p["ambush"].clear()
			_structure_changed(), true)
	_refresh_numbers()
	await get_tree().process_frame
	%GroupsScroll.scroll_vertical = scroll

func _add_group_panel(title: String, list: Array, on_remove: Callable, can_remove: bool) -> void:
	var g: PanelContainer = GROUP.instantiate()
	%Groups.add_child(g)
	g.get_node("%Title").text = title
	g.get_node("%RemoveGroup").visible = can_remove
	g.get_node("%RemoveGroup").pressed.connect(on_remove)
	g.get_node("%AddEnemy").pressed.connect(func():
		list.append(list[-1].duplicate() if not list.is_empty() else [type_ids[0], _clevel()])
		_structure_changed())
	sums.append({"label": g.get_node("%Sum"), "list": list})
	for i in list.size():
		_add_enemy_row(g.get_node("%Rows"), list, i)

func _add_enemy_row(parent: Control, list: Array, i: int) -> void:
	var r: PanelContainer = ENEMY_ROW.instantiate()
	parent.add_child(r)
	var opt: OptionButton = r.get_node("%Type")
	for t in type_ids:
		opt.add_item(DB.ENEMIES[t]["name"])
	var entry: Array = list[i]
	opt.select(type_ids.find(Balance.etype(entry)))
	opt.item_selected.connect(func(k: int):
		entry[0] = type_ids[k]
		_value_changed())
	var lv: BalanceStepper = r.get_node("%Level")
	lv.set_value(int(entry[1]) if entry.size() > 1 else 0)
	lv.changed.connect(func(v):
		if entry.size() < 2:
			entry.append(0)
		entry[1] = int(v)
		_value_changed())
	r.get_node("%Copy").pressed.connect(func():
		list.insert(i + 1, entry.duplicate())
		_structure_changed())
	r.get_node("%Remove").pressed.connect(func():
		if _total_enemies() <= 1:
			_status("В бою должен остаться хотя бы один враг")
			return
		list.remove_at(i)
		_structure_changed())
	rows.append({"row": r, "entry": entry})

func _total_enemies() -> int:
	var n := 0
	var p := _cur()
	for g in p["groups"] + [p.get("ambush", [])]:
		n += g.size()
	return n

func _structure_changed() -> void:
	var p := _cur()
	# пустые группы убираем, но хотя бы одна остаётся
	for gi in range(p["groups"].size() - 1, -1, -1):
		if p["groups"][gi].is_empty() and p["groups"].size() > 1:
			p["groups"].remove_at(gi)
	_changed()
	_render_waves.call_deferred()

func _value_changed() -> void:
	_changed()
	_refresh_numbers()
	var b := %Points.get_child(point) as Button
	if b != null:
		b.text = "%s\n%s" % [_cur()["name"], _short(_cur())]

func _set_point_value(k: String, v: int) -> void:
	_cur()[k] = v
	_value_changed()

func _add_group() -> void:
	var p := _cur()
	var src: Array = p["groups"][-1] if not p["groups"].is_empty() else []
	p["groups"].append(src.duplicate(true) if not src.is_empty() else [[type_ids[0], _clevel()]])
	_structure_changed()

func _add_ambush() -> void:
	var p := _cur()
	p["ambush"] = [["wolf", _clevel()], ["wolf", _clevel()]]
	_structure_changed()

func _on_contract_level(v: float) -> void:
	if cid == EVENTS_KEY:
		return
	var c: Dictionary = doc["contracts"][cid]
	var delta := int(v) - int(c["level"])
	c["level"] = int(v)
	# Враги поручения сдвигаются вместе с уровнем поручения
	for p in c["points"]:
		for g in p["groups"] + [p.get("ambush", [])]:
			for e in g:
				if e.size() > 1 and int(e[1]) > 0:
					e[1] = clampi(int(e[1]) + delta, 1, Balance.MAX_LEVEL)
	_changed()
	_render_waves()

# ---------------------------------------------------------------- Числа: враги, группы, оценка
## Параметры одного врага с учётом множителей точки
func _enemy(entry: Array, p: Dictionary) -> Dictionary:
	var t := Balance.etype(entry)
	var lvl := Balance.elevel(entry, _clevel())
	var es := DB.enemy_stats(t, lvl)
	var hk := float(p.get("hp_pct", 100)) / 100.0
	var dk := float(p.get("dmg_pct", 100)) / 100.0
	var e: Dictionary = DB.ENEMIES[t]
	var hp: float = max(1.0, round(es["hp"] * hk))
	var dmin: float = round(es["dmg_min"] * dk)
	var dmax: float = round(es["dmg_max"] * dk)
	return {"t": t, "lvl": lvl, "wlvl": es["wlvl"], "hp": hp, "dmin": dmin, "dmax": dmax, "armor": es["armor"],
		"interval": float(e["interval"]), "dps": (dmin + dmax) * 0.5 / float(e["interval"]),
		"xp": int(e["xp"] * (1.0 + 0.15 * (lvl - 1))), "coins": int(e["coins"] * (1.0 + 0.1 * (lvl - 1)))}

func _refresh_numbers() -> void:
	var p := _cur()
	for r in rows:
		var s := _enemy(r["entry"], p)
		var lab: Label = r["row"].get_node("%Stats")
		lab.text = "ОЗ %d · удар %d–%d · WoW %d" % [s["hp"], s["dmin"], s["dmax"], s["wlvl"]]
		lab.tooltip_text = "Уровень %d (WoW %d)\nЗдоровье %d · броня %d\nУдар %d–%d раз в %s с · урон/с ≈ %s\nОпыт %d · монеты %d" % [
			s["lvl"], s["wlvl"], s["hp"], s["armor"], s["dmin"], s["dmax"], _num(s["interval"]), _num(s["dps"]), s["xp"], s["coins"]]
	var tot_hp := 0.0
	var tot_dps := 0.0
	var n := 0
	for g in sums:
		var ghp := 0.0
		var gdps := 0.0
		for e in g["list"]:
			var s := _enemy(e, p)
			ghp += s["hp"]
			gdps += s["dps"]
		tot_hp += ghp
		tot_dps += gdps
		n += g["list"].size()
		g["label"].text = "%d · ОЗ %d · урон/с %s" % [g["list"].size(), ghp, _num(gdps)]
	%Summary.text = "Всего: %d %s · ОЗ %d · урон/с %s" % [n, _plural(n, "враг", "врага", "врагов"), tot_hp, _num(tot_dps)]
	var party := _party()
	%Party.visible = not party.is_empty()
	%Rating.visible = not party.is_empty()
	if party.is_empty():
		return
	%Party.text = "Отряд: ОЗ %d · урон/с %s" % [party["hp"], _num(party["dps"])]
	var r: float = (tot_hp / max(1.0, party["dps"])) / (party["hp"] / max(0.1, tot_dps))
	%Rating.text = "Оценка %s" % _num(r, 2)

func _party() -> Dictionary:
	if Game.state.is_empty():
		return {}
	var hp := 0.0
	var dps := 0.0
	for id in DB.HERO_IDS:
		var d := Game.derived(id)
		hp += float(d["max_hp"])
		dps += (float(d["dmg_min"]) + float(d["dmg_max"])) * 0.5 / max(0.5, float(d["interval"]))
	return {"hp": hp, "dps": dps}

func _num(v: float, digits := 1) -> String:
	var t := ("%." + str(digits) + "f") % v
	if digits > 0:
		while t.ends_with("0"):
			t = t.substr(0, t.length() - 1)
		if t.ends_with("."):
			t = t.substr(0, t.length() - 1)
	return t.replace(".", ",")

# ---------------------------------------------------------------- Вкладка «Типы врагов»
func _render_types() -> void:
	%AllHp.set_value(int(doc["all_enemies"].get("hp_pct", 100)))
	%AllDmg.set_value(int(doc["all_enemies"].get("dmg_pct", 100)))
	UIK.clear(%TypeRows)
	for t in type_ids:
		var td: Dictionary = doc["enemy_types"][t]
		var r: PanelContainer = TYPE_ROW.instantiate()
		%TypeRows.add_child(r)
		var e: Dictionary = DB.ENEMIES[t]
		r.get_node("%Name").text = e["name"]
		r.get_node("%Name").tooltip_text = "%s · %s · ранг: %s" % [t, e.get("wow", ""), e.get("rank", "normal")]
		r.set_meta("type", t)
		for k in [["Hp", "hp_k"], ["Dmg", "dmg_k"], ["Armor", "armor_k"], ["Interval", "interval"], ["Xp", "xp"], ["Coins", "coins"]]:
			var st: BalanceStepper = r.get_node("%" + k[0])
			var key: String = k[1]
			st.set_value(float(td[key]))
			st.changed.connect(func(v):
				td[key] = int(v) if key in ["xp", "coins"] else snappedf(v, 0.01)
				_changed()
				_refresh_type_samples())
	_refresh_type_samples()

func _refresh_type_samples() -> void:
	var lvl := int(%SampleLvl.value)
	for r in %TypeRows.get_children():
		var s := _enemy([r.get_meta("type"), lvl], {})
		r.get_node("%Sample").text = "ОЗ %d · удар %d–%d · урон/с %s" % [s["hp"], s["dmin"], s["dmax"], _num(s["dps"])]

func _set_all(k: String, v: int) -> void:
	doc["all_enemies"][k] = v
	_changed()
	_refresh_type_samples()

# ---------------------------------------------------------------- Кнопки внизу
func _status(msg: String) -> void:
	var path := Balance.file_path()
	%FileLabel.text = path.replace("res://", "").replace("user://", "папка игры/")
	%FileLabel.tooltip_text = ProjectSettings.globalize_path(path)
	if msg == "":
		msg = "● Есть несохранённые правки — они уже действуют в игре" if dirty else "Все правки сохранены"
	%Status.text = msg

func _save() -> void:
	var p := Balance.save_file(doc)
	if p == "":
		_status("Не удалось записать файл")
		return
	dirty = false
	_status("Сохранено в %s" % p.replace("res://", "").replace("user://", "папку игры/"))

func _revert() -> void:
	var d := Balance.load_file()
	doc = d if not d.is_empty() else Balance.defaults.duplicate(true)
	Balance.apply_doc(doc)
	doc = Balance.export_doc()
	dirty = false
	_fill_contracts()
	_set_tab(tab)
	_status("Правки отменены")

func _defaults() -> void:
	var def: Dictionary = Balance.defaults
	if tab == "types":
		doc["enemy_types"] = def["enemy_types"].duplicate(true)
		doc["all_enemies"] = def["all_enemies"].duplicate(true)
		_changed()
		_render_types()
		_status("Типы врагов: исходные значения (не забудьте сохранить)")
		return
	var p := _cur()
	var src = null
	if cid == EVENTS_KEY:
		var k: String = doc["events"].keys()[point]
		src = def["events"].get(k)
	else:
		for dp in def["contracts"].get(cid, {}).get("points", []):
			if dp.get("node", -1) == p.get("node", -2) or dp.get("wave", -1) == p.get("wave", -2):
				src = dp
	if src == null:
		return
	var pts := _points()
	if cid == EVENTS_KEY:
		doc["events"][doc["events"].keys()[point]] = src.duplicate(true)
	else:
		# Исходные уровни переносятся с учётом текущего уровня поручения
		var cp: Dictionary = src.duplicate(true)
		var delta := _clevel() - int(def["contracts"][cid]["level"])
		for g in cp["groups"] + [cp.get("ambush", [])]:
			for e in g:
				if int(e[1]) > 0:
					e[1] = clampi(int(e[1]) + delta, 1, Balance.MAX_LEVEL)
		pts[point] = cp
	_changed()
	_render_waves()
	_status("«%s»: исходные значения (не забудьте сохранить)" % p["name"])

## Сразиться с текущей точкой без последствий (как на испытательной арене)
func _play() -> void:
	if Game.state.is_empty() or main == null:
		_status("Сначала загрузите или начните игру — нужен отряд")
		return
	var p := _cur()
	var lvl := _clevel()
	var c: Dictionary = DB.CONTRACTS.get(cid, {})
	var preset := {"groups": p["groups"].duplicate(true), "ambush": p.get("ambush", []).duplicate(true), "level": lvl,
		"wagon": {"hp": 500.0, "max": 500.0} if c.get("escort", false) else null}
	var cfg := Game.arena_config(preset, {})
	cfg["hp_pct"] = int(p.get("hp_pct", 100))
	cfg["dmg_pct"] = int(p.get("dmg_pct", 100))
	cfg["night"] = DayTime.node_time_by_name(cid, str(p.get("name", ""))) == "night"
	cfg["balance_test"] = {"cid": cid, "point": point, "name": p["name"]}
	var cur = main.current
	if cur != null and cur.has_method("on_quit"):
		cur.on_quit()
	get_tree().paused = was_paused
	queue_free()
	main.goto("expedition", {"arena": cfg})
