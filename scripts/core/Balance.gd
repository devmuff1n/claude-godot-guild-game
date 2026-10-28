class_name Balance
extends RefCounted
## Настройки баланса волн: файл data/balance.json поверх данных DB.gd.
## Меню F10 (BalanceEditor) правит этот файл; игра читает его при запуске.
##
## Враг в группе — строка "wolf" (уровень поручения) или пара ["wolf", 3] (свой уровень; 0 — уровень поручения).
## Точка маршрута: groups (волны врагов — выходят по очереди), ambush (засада сзади во время второй волны), hp_pct / dmg_pct (множители ОЗ и урона, %).

const PATH := "res://data/balance.json"
const USER_PATH := "user://balance.json"
const MAX_LEVEL := 15

## Исходные значения из DB.gd (до применения файла) — для кнопки «Исходные»
static var defaults: Dictionary = {}

# ---------------------------------------------------------------- Враг в группе
static func etype(entry) -> String:
	if entry is Array:
		return str(entry[0])
	if entry is Dictionary:
		return str(entry.get("type", ""))
	return str(entry)

## Уровень врага; 0 или отсутствие — уровень поручения (fallback)
static func elevel(entry, fallback: int) -> int:
	var l := 0
	if entry is Array and entry.size() > 1:
		l = int(entry[1])
	elif entry is Dictionary:
		l = int(entry.get("level", 0))
	return l if l > 0 else fallback

## Группы волны заставы: старый формат — массив групп, новый — {groups, hp_pct, dmg_pct}
static func wave_groups(w) -> Array:
	return w.get("groups", []) if w is Dictionary else w

# ---------------------------------------------------------------- Загрузка / сохранение
## Вызывается из DB._ready(): запомнить исходные значения и применить файл, если он есть
static func boot() -> void:
	defaults = export_doc()
	var doc := load_file()
	if not doc.is_empty():
		apply_doc(doc)

static func file_path() -> String:
	if OS.has_feature("template") and FileAccess.file_exists(USER_PATH):
		return USER_PATH
	return PATH

static func load_file() -> Dictionary:
	var p := file_path()
	if not FileAccess.file_exists(p):
		return {}
	var txt := FileAccess.get_file_as_string(p)
	var data = JSON.parse_string(txt)
	if not (data is Dictionary):
		push_error("balance.json: не удалось прочитать файл — используются значения из DB.gd")
		return {}
	return data

## Записать файл. Возвращает путь, куда записано, или "" при ошибке.
static func save_file(doc: Dictionary) -> String:
	# Из редактора Godot файл пишется прямо в проект; в собранной игре — в папку пользователя
	var targets := [USER_PATH] if OS.has_feature("template") else [PATH, USER_PATH]
	for p in targets:
		if p.begins_with("res://"):
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(p.get_base_dir()))
		var f := FileAccess.open(p, FileAccess.WRITE)
		if f == null:
			continue
		f.store_string(to_text(doc))
		f.close()
		return p
	return ""

# ---------------------------------------------------------------- DB → документ
static func _pair(entry, fallback: int) -> Array:
	return [etype(entry), elevel(entry, fallback)]

static func _pairs(list: Array, fallback: int) -> Array:
	var out := []
	for e in list:
		out.append(_pair(e, fallback))
	return out

static func _groups(groups: Array, fallback: int) -> Array:
	var out := []
	for g in groups:
		out.append(_pairs(g, fallback))
	return out

## Текущее состояние DB в виде документа баланса (уровни выписаны явно)
static func export_doc() -> Dictionary:
	var doc := {"version": 1,
		"_как_читать": "Удобнее править в игре: F10. Враг — [\"тип\", уровень], уровень 0 — уровень поручения. hp_pct / dmg_pct — здоровье и урон врагов точки в процентах (100 — без изменений). Одна строка в groups — одна волна: на дороге волны идут по очереди, следующая — когда перебита предыдущая (у заставы строки волны выходят разом). Засада (ambush) бьёт в спину во время второй волны.",
		"all_enemies": {"hp_pct": DB.enemy_hp_pct, "dmg_pct": DB.enemy_dmg_pct}}
	var types := {}
	for t in DB.ENEMIES:
		var e: Dictionary = DB.ENEMIES[t]
		types[t] = {"name": e["name"], "hp_k": e["hp_k"], "dmg_k": e["dmg_k"], "armor_k": e["armor_k"],
			"interval": e["interval"], "xp": e["xp"], "coins": e["coins"]}
	doc["enemy_types"] = types
	var contracts := {}
	for cid in DB.CONTRACTS:
		var c: Dictionary = DB.CONTRACTS[cid]
		var lvl := int(c["level"])
		var points := []
		if c.has("waves"):
			var waves: Array = c["waves"]
			for i in waves.size():
				var w = waves[i]
				points.append({"wave": i + 1, "name": "Волна %d" % (i + 1),
					"hp_pct": int(w.get("hp_pct", 100)) if w is Dictionary else 100,
					"dmg_pct": int(w.get("dmg_pct", 100)) if w is Dictionary else 100,
					"groups": _groups(wave_groups(w), lvl)})
		for i in c.get("route", []).size():
			var nd: Dictionary = c["route"][i]
			if nd["type"] != "battle":
				continue
			points.append({"node": i, "name": nd["name"], "hp_pct": int(nd.get("hp_pct", 100)), "dmg_pct": int(nd.get("dmg_pct", 100)),
				"groups": _groups(nd["groups"], lvl), "ambush": _pairs(nd.get("ambush", []), lvl)})
		contracts[cid] = {"name": c["name"], "level": lvl, "points": points}
	doc["contracts"] = contracts
	var events := {}
	for eid in DB.EVENTS:
		var ev: Dictionary = DB.EVENTS[eid]
		for k in ev["choices"].size():
			var ch: Dictionary = ev["choices"][k]
			if ch["fx"].has("battle"):
				# 0 — уровень того поручения, где встретилось событие
				var gs := []
				for g in ch["fx"]["battle"]:
					var gp := []
					for e in g:
						gp.append([etype(e), elevel(e, 0)])
					gs.append(gp)
				events["%s/%d" % [eid, k]] = {"name": "%s: %s" % [ev["title"], ch["text"]], "groups": gs}
	doc["events"] = events
	return doc

# ---------------------------------------------------------------- документ → DB
static func _clean_groups(groups: Array) -> Array:
	var out := []
	for g in groups:
		var gg := []
		for e in g:
			if DB.ENEMIES.has(etype(e)):
				gg.append([etype(e), int(e[1]) if e is Array and e.size() > 1 else 0])
		if not gg.is_empty():
			out.append(gg)
	return out

static func apply_doc(doc: Dictionary) -> void:
	var all: Dictionary = doc.get("all_enemies", {})
	DB.enemy_hp_pct = int(all.get("hp_pct", 100))
	DB.enemy_dmg_pct = int(all.get("dmg_pct", 100))
	var types: Dictionary = doc.get("enemy_types", {})
	for t in types:
		if not DB.ENEMIES.has(t):
			continue
		for k in ["hp_k", "dmg_k", "armor_k", "interval"]:
			if types[t].has(k):
				DB.ENEMIES[t][k] = float(types[t][k])
		for k in ["xp", "coins"]:
			if types[t].has(k):
				DB.ENEMIES[t][k] = int(types[t][k])
	var contracts: Dictionary = doc.get("contracts", {})
	for cid in contracts:
		if not DB.CONTRACTS.has(cid):
			continue
		var c: Dictionary = DB.CONTRACTS[cid]
		var cd: Dictionary = contracts[cid]
		if cd.has("level"):
			c["level"] = clampi(int(cd["level"]), 1, MAX_LEVEL)
		for p in cd.get("points", []):
			var groups := _clean_groups(p.get("groups", []))
			if p.has("wave") and c.has("waves"):
				var wi := int(p["wave"]) - 1
				if wi >= 0 and wi < c["waves"].size() and not groups.is_empty():
					c["waves"][wi] = {"groups": groups, "hp_pct": int(p.get("hp_pct", 100)), "dmg_pct": int(p.get("dmg_pct", 100))}
			elif p.has("node"):
				var ni := int(p["node"])
				# узлы маршрута могли сдвинуться (вставили событие): ищем точку по имени
				if p.has("name") and (ni < 0 or ni >= c.get("route", []).size() or c["route"][ni]["name"] != p["name"]):
					for j in c.get("route", []).size():
						if c["route"][j]["name"] == p["name"] and c["route"][j]["type"] == "battle":
							ni = j
							break
				if ni < 0 or ni >= c.get("route", []).size() or c["route"][ni]["type"] != "battle" or groups.is_empty():
					continue
				var nd: Dictionary = c["route"][ni]
				nd["groups"] = groups
				var amb := _clean_groups([p.get("ambush", [])])
				nd["ambush"] = amb[0] if not amb.is_empty() else []
				nd["hp_pct"] = int(p.get("hp_pct", 100))
				nd["dmg_pct"] = int(p.get("dmg_pct", 100))
	var events: Dictionary = doc.get("events", {})
	for key in events:
		var parts: PackedStringArray = str(key).split("/")
		if parts.size() != 2 or not DB.EVENTS.has(parts[0]):
			continue
		var chs: Array = DB.EVENTS[parts[0]]["choices"]
		var k := int(parts[1])
		if k < 0 or k >= chs.size() or not chs[k]["fx"].has("battle"):
			continue
		var groups := _clean_groups(events[key].get("groups", []))
		if not groups.is_empty():
			chs[k]["fx"]["battle"] = groups

# ---------------------------------------------------------------- Красивый JSON
## Пишет JSON так, чтобы одна группа врагов занимала одну строку
static func to_text(doc: Dictionary) -> String:
	return _fmt(doc, 0) + "\n"

static func _is_leafy(v) -> bool:
	# Массив, который печатается в одну строку: пара [тип, уровень] или группа из таких пар
	if not (v is Array):
		return false
	for x in v:
		if x is Dictionary:
			return false
		if x is Array:
			for y in x:
				if y is Array or y is Dictionary:
					return false
	return true

static func _scalar(v) -> String:
	if v is float and v == floor(v) and abs(v) < 1e9 and not str(v).contains("."):
		return str(int(v))
	return JSON.stringify(v)

static func _inline(d: Dictionary) -> String:
	var parts := []
	for k in d:
		parts.append(JSON.stringify(str(k)) + ": " + _scalar(d[k]))
	return ", ".join(parts)

static func _fmt(v, ind: int) -> String:
	var pad := "  ".repeat(ind)
	var pad2 := "  ".repeat(ind + 1)
	if v is Dictionary:
		if v.is_empty():
			return "{}"
		# Простые значения подряд — в одну строку, вложенные списки и словари — ниже
		var lines := []
		var flat := {}
		for k in v:
			var x = v[k]
			if x is Dictionary or (x is Array and not x.is_empty()):
				if not flat.is_empty():
					lines.append(pad2 + _inline(flat))
					flat = {}
				lines.append(pad2 + JSON.stringify(str(k)) + ": " + _fmt(x, ind + 1))
			else:
				flat[k] = x
		if not flat.is_empty():
			if lines.is_empty():
				return "{" + _inline(flat) + "}"
			lines.append(pad2 + _inline(flat))
		return "{\n" + ",\n".join(lines) + "\n" + pad + "}"
	if v is Array:
		if v.is_empty():
			return "[]"
		if _is_leafy(v):
			var parts := []
			for x in v:
				if x is Array:
					var ys := []
					for y in x:
						ys.append(_scalar(y))
					parts.append("[" + ", ".join(ys) + "]")
				else:
					parts.append(_scalar(x))
			return "[" + ", ".join(parts) + "]"
		var lines := []
		for x in v:
			lines.append(pad2 + _fmt(x, ind + 1))
		return "[\n" + ",\n".join(lines) + "\n" + pad + "]"
	return _scalar(v)
