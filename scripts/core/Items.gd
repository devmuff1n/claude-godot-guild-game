class_name Items
extends RefCounted
## Предметы: параметры экземпляра, требования, генерация добычи, цены.

const IMPLICIT := {
	"amulet_bone": {"sta": 3.0}, "amulet_sun": {"sp": 5.0},
	"ring_copper": {"hit": 1.0}, "ring_silver": {"crit": 1.5},
}
const RARITY_PRICE := {"common": 1.0, "uncommon": 1.6, "rare": 2.6, "epic": 4.2}
const RARITY_WEIGHTS := {"common": 55.0, "uncommon": 30.0, "rare": 12.0, "epic": 3.0}

static func base_of(item: Dictionary) -> Dictionary:
	return DB.BASES.get(item.get("base", ""), {})

static func is_weapon(item: Dictionary) -> bool:
	var b := base_of(item)
	return b.has("wtype") and b["wtype"] != "shield"

static func display_name(item: Dictionary) -> String:
	var b := base_of(item)
	var n: String = b.get("name", "???")
	var aff: Array = item.get("affixes", [])
	if aff.size() > 0:
		var pre: String = DB.AFFIX_PREFIX.get(aff[0][0], "")
		if pre != "":
			n = "%s · %s" % [n, pre.to_lower()]
	return n

static func rarity_color(item: Dictionary) -> Color:
	return DB.RARITY_COLORS.get(item.get("rarity", "common"), Color.WHITE)

static func ilvl_mult(ilvl: int, k: float) -> float:
	return 1.0 + k * float(ilvl - 1)

## Все числовые параметры конкретного экземпляра
static func stats(item: Dictionary) -> Dictionary:
	var b := base_of(item)
	var ilvl: int = int(item.get("ilvl", 1))
	var s := {}
	if b.has("dmg"):
		var m := ilvl_mult(ilvl, 0.13)
		s["dmg_min"] = int(round(b["dmg"][0] * m))
		s["dmg_max"] = int(round(b["dmg"][1] * m))
		s["interval"] = b["interval"]
		s["range"] = b["range"]
	if b.has("sp"):
		s["sp"] = round(b["sp"] * ilvl_mult(ilvl, 0.2))
	if b.has("armor"):
		s["armor"] = round(b["armor"] * ilvl_mult(ilvl, 0.18))
	if b.has("armor_t"):
		s["armor"] = max(1.0, round(b["armor_t"] * ilvl_mult(ilvl, 0.3)))
	if b.has("block"):
		s["block"] = float(b["block"])
		s["block_val"] = round(b["block_val"] * ilvl_mult(ilvl, 0.18))
	var imp: Dictionary = IMPLICIT.get(item.get("base", ""), {})
	for k in imp.keys():
		s[k] = s.get(k, 0.0) + snapped(imp[k] * ilvl_mult(ilvl, 0.3), 0.1)
	for a in item.get("affixes", []):
		s[a[0]] = s.get(a[0], 0.0) + a[1]
	return s

static func requirements(item: Dictionary) -> Dictionary:
	var b := base_of(item)
	var ilvl: int = int(item.get("ilvl", 1))
	var r := {}
	for k in b.get("req", {}).keys():
		r[k] = int(round(b["req"][k] * ilvl_mult(ilvl, 0.1)))
	return r

static func price(item: Dictionary) -> int:
	var b := base_of(item)
	return int(round(b.get("price", 10) * ilvl_mult(int(item.get("ilvl", 1)), 0.25) * RARITY_PRICE.get(item.get("rarity", "common"), 1.0)))

static func sell_price(item: Dictionary) -> int:
	return max(1, int(price(item) * 0.3))

static func type_label(item: Dictionary) -> String:
	var b := base_of(item)
	if b.has("wtype"):
		var t: String = DB.WEAPON_TYPE_NAMES[b["wtype"]]
		if b.get("hands", 1) == 2:
			t += ", двуручное"
		return t
	var at: String = b.get("atype", "")
	var slot_name: String = "Кольцо" if b.get("slot", "") == "ring" else DB.SLOT_NAMES.get(b.get("slot", ""), "")
	return "%s, %s" % [slot_name, DB.ARMOR_TYPE_NAMES.get(at, at)]

## Проверка: может ли герой надеть вещь в слот. Возвращает "" или причину отказа.
static func equip_problem(hero_id: String, level: int, item: Dictionary, slot: String, equip: Dictionary) -> String:
	var b := base_of(item)
	if b.is_empty():
		return "Неизвестный предмет."
	var hero: Dictionary = DB.HEROES[hero_id]
	var bslot: String = b["slot"]
	var ok_slot := false
	if bslot == "ring":
		ok_slot = slot == "ring1" or slot == "ring2"
	else:
		ok_slot = slot == bslot
	if not ok_slot:
		return "Не подходит для слота «%s»." % DB.SLOT_NAMES.get(slot, slot)
	if b.has("wtype"):
		if not (b["wtype"] in hero["weapons"]):
			return "%s не владеет типом оружия: %s." % [hero["name"], DB.WEAPON_TYPE_NAMES[b["wtype"]]]
		if b["wtype"] == "shield":
			var mainit = equip.get("main")
			if mainit != null and int(base_of(mainit).get("hands", 1)) == 2:
				return "Щит нельзя взять при двуручном оружии."
	elif b.has("atype") and b["atype"] != "jewel":
		if not (b["atype"] in hero["armors"]):
			return "%s не носит броню типа «%s»." % [hero["name"], DB.ARMOR_TYPE_NAMES[b["atype"]]]
	var nat := Stats.natural(hero_id, level)
	var req := requirements(item)
	for k in req.keys():
		if nat.get(k, 0) < req[k]:
			return "Нужно %s %d (собственное значение %s: %d, бонусы вещей не учитываются)." % [DB.STAT_NAMES[k], req[k], hero["name"], int(nat.get(k, 0))]
	return ""

## Генерация экземпляра
static func make(base_id: String, ilvl: int, rarity: String, rng: RandomNumberGenerator) -> Dictionary:
	var b: Dictionary = DB.BASES[base_id]
	var item := {"uid": Game.next_uid(), "base": base_id, "ilvl": ilvl, "rarity": rarity, "affixes": []}
	var n: int = DB.RARITY_AFFIXES[rarity]
	var pool := []
	for a in DB.AFFIXES:
		var st: String = a[0]
		if st == "block" and b.get("wtype", "") != "shield":
			continue
		if st == "parry" and not (b.get("wtype", "") in ["sword", "mace", "dagger", "shield"]):
			continue
		pool.append(a)
	# Перемешиваем детерминированно через rng
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	for i in min(n, pool.size()):
		var a: Array = pool[i]
		var hi: float = a[1] + a[2] * float(ilvl)
		var v: float = hi * rng.randf_range(0.55, 1.0)
		if a[0] in DB.PCT_STATS:
			v = snapped(v, 0.1)
		else:
			v = max(1.0, round(v))
		item["affixes"].append([a[0], v])
	return item

static func roll_rarity(rng: RandomNumberGenerator, quality: float) -> String:
	var w := RARITY_WEIGHTS.duplicate()
	w["uncommon"] += quality * 4.0
	w["rare"] += quality * 2.5
	w["epic"] += quality * 0.8
	w["common"] = max(10.0, w["common"] - quality * 6.0)
	var total := 0.0
	for k in w.keys():
		total += w[k]
	var r := rng.randf() * total
	for k in DB.RARITY:
		r -= w[k]
		if r <= 0.0:
			return k
	return "common"

static func bases_for_level(ilvl: int) -> Array:
	var res := []
	for k in DB.BASES.keys():
		if int(DB.BASES[k].get("minlvl", 1)) <= ilvl:
			res.append(k)
	res.sort()
	return res

static func random_item(ilvl: int, rng: RandomNumberGenerator, quality: float = 0.0) -> Dictionary:
	var pool := bases_for_level(ilvl)
	var base_id: String = pool[rng.randi_range(0, pool.size() - 1)]
	return make(base_id, ilvl, roll_rarity(rng, quality), rng)

## Вещь, подходящая конкретному герою (по владению и требованиям на текущем уровне)
static func item_for_hero(hero_id: String, level: int, ilvl: int, rng: RandomNumberGenerator, quality: float) -> Dictionary:
	var hero: Dictionary = DB.HEROES[hero_id]
	var nat := Stats.natural(hero_id, level)
	var pool := []
	for k in bases_for_level(ilvl):
		var b: Dictionary = DB.BASES[k]
		if b.has("wtype") and not (b["wtype"] in hero["weapons"]):
			continue
		if b.has("atype") and b["atype"] != "jewel" and not (b["atype"] in hero["armors"]):
			continue
		var ok := true
		for st in b.get("req", {}).keys():
			if nat.get(st, 0) < int(round(b["req"][st] * ilvl_mult(ilvl, 0.1))):
				ok = false
		if ok:
			pool.append(k)
	if pool.is_empty():
		return random_item(ilvl, rng, quality)
	var base_id: String = pool[rng.randi_range(0, pool.size() - 1)]
	var rar := roll_rarity(rng, quality + 1.0)
	if rar == "common":
		rar = "uncommon"
	return make(base_id, ilvl, rar, rng)

static func stat_line(k: String, v) -> String:
	var nm: String = DB.STAT_NAMES.get(k, k)
	if k in DB.PCT_STATS:
		return "+%s %s" % [UIK.fmt_pct(float(v)), nm]
	return "+%d %s" % [int(v), nm]

## Может ли герой в принципе носить вещь этого типа (тип оружия / брони; украшения — все)
static func hero_can_use_type(hero_id: String, item: Dictionary) -> bool:
	var b := base_of(item)
	if b.is_empty() or not DB.HEROES.has(hero_id):
		return false
	var hero: Dictionary = DB.HEROES[hero_id]
	if b.has("wtype"):
		return b["wtype"] in hero["weapons"]
	var at: String = b.get("atype", "")
	return at == "jewel" or at in hero["armors"]

## Хватает ли собственных характеристик героя для требований вещи
static func meets_requirements(hero_id: String, level: int, item: Dictionary) -> bool:
	var nat := Stats.natural(hero_id, level)
	var req := requirements(item)
	for k in req.keys():
		if nat.get(k, 0) < req[k]:
			return false
	return true

# ---------------------------------------------------------------- Подсказка в духе WoW Classic
# Цвета — как в клиенте WoW: качество предмета, белый текст, жёлтый уровень предмета, зелёные «Если на персонаже», красные запреты.
const TT_WHITE := Color(1, 1, 1)
const TT_YELLOW := Color(1, 0.82, 0)
const TT_GREEN := Color(0, 1, 0)
const TT_RED := Color(1, 0.125, 0.125)
const QUALITY_COLORS := {"common": Color(1, 1, 1), "uncommon": Color(0.118, 1, 0), "rare": Color(0, 0.439, 0.867), "epic": Color(0.639, 0.208, 0.933)}
const TT_SLOT_NAMES := {
	"head": "Голова", "chest": "Грудь", "hands": "Кисти рук", "waist": "Пояс", "feet": "Ступни",
	"neck": "Шея", "ring": "Палец", "off": "Левая рука", "main": "Правая рука",
}
## Характеристики вещи — строками под бронёй/уроном, как свойства в Diablo («+3 к силе», «+1,6% к меткости»).
## Порядок: атрибуты, боевые параметры, сопротивления. Белые — от основы вещи, синие — случайные свойства.
const TT_STAT_LINES := [
	["str", "к силе"], ["agi", "к ловкости"], ["sta", "к выносливости"], ["int", "к интеллекту"],
	["hp", "к здоровью"], ["mp", "к мане"], ["sp", "к силе заклинаний"],
	["hit", "к меткости"], ["crit", "к шансу критического удара"], ["dodge", "к уклонению"],
	["parry", "к парированию"], ["block", "к шансу блока"],
	["res_fire", "к сопротивлению огню"], ["res_nature", "к сопротивлению силам природы"],
	["res_shadow", "к сопротивлению тьме"], ["res_holy", "к сопротивлению свету"],
]
const TT_MAGIC := Color(0.47, 0.47, 1.0)

static func quality_color(item: Dictionary) -> Color:
	return QUALITY_COLORS.get(item.get("rarity", "common"), TT_WHITE)

static func _num(v: float, digits: int = 1) -> String:
	return (("%." + str(digits) + "f") % v).replace(".", ",")

static func _row(left: String, lc: Color = TT_WHITE, right: String = "", rc: Color = TT_WHITE, kind: String = "") -> Dictionary:
	return {"l": left, "lc": lc, "r": right, "rc": rc, "kind": kind}

## Строки подсказки: [{l, lc, r, rc, kind}], kind: "title" / "money" / "".
## hero_id — для кого проверять запреты (красный тип брони, требования); note — красная строка-причина.
static func tooltip_lines(item: Dictionary, hero_id: String = "", level: int = 1, note: String = "") -> Array:
	var b := base_of(item)
	var s := stats(item)
	var rows := []
	rows.append(_row(display_name(item), quality_color(item), "", TT_WHITE, "title"))
	rows.append(_row("Уровень предмета %d" % int(item.get("ilvl", 1)), TT_YELLOW))
	# Слот слева, тип справа; тип красный, если выбранный герой такое не носит
	var type_ok := hero_id == "" or hero_can_use_type(hero_id, item)
	var bad := TT_WHITE if type_ok else TT_RED
	if b.has("wtype"):
		var wt: String = b["wtype"]
		var slot_l := "Правая рука"
		if wt == "shield":
			slot_l = "Левая рука"
		elif wt == "bow":
			slot_l = "Дальний бой"
		elif int(b.get("hands", 1)) == 2:
			slot_l = "Двуручное"
		rows.append(_row(slot_l, TT_WHITE, String(DB.WEAPON_TYPE_NAMES[wt]).capitalize(), bad))
	else:
		var at: String = b.get("atype", "")
		var right := "" if at == "jewel" else String(DB.ARMOR_TYPE_NAMES.get(at, at)).capitalize()
		rows.append(_row(TT_SLOT_NAMES.get(b.get("slot", ""), ""), TT_WHITE, right, bad))
	var aff := {}
	for a in item.get("affixes", []):
		aff[a[0]] = true
	if s.has("dmg_min"):
		rows.append(_row("Урон: %d - %d" % [s["dmg_min"], s["dmg_max"]], TT_WHITE, "Скорость %s" % _num(s["interval"], 2)))
		var dps := (float(s["dmg_min"]) + float(s["dmg_max"])) * 0.5 / float(s["interval"])
		rows.append(_row("(%s ед. урона в секунду)" % _num(dps)))
		rows.append(_row("Дальность: %d" % int(s["range"])))
	if s.has("armor"):
		rows.append(_row("Броня: %d" % int(s["armor"]), TT_MAGIC if aff.has("armor") else TT_WHITE))
	if s.has("block_val"):
		rows.append(_row("Блок: %d" % int(s["block_val"])))
	for e in TT_STAT_LINES:
		var k: String = e[0]
		if not s.has(k):
			continue
		var v: String = ("+" + UIK.fmt_pct(float(s[k]))) if k in DB.PCT_STATS else "+%d" % int(s[k])
		rows.append(_row("%s %s" % [v, e[1]], TT_MAGIC if aff.has(k) else TT_WHITE))
	# Кто из отряда может носить (аналог строки «Классы:»)
	if not (b.get("atype", "") == "jewel"):
		var who := []
		for h in DB.HERO_IDS:
			if hero_can_use_type(h, item):
				who.append(DB.HEROES[h]["name"])
		rows.append(_row("Герои: %s" % ", ".join(who), bad))
	var req := requirements(item)
	var nat := Stats.natural(hero_id, level) if hero_id != "" else {}
	for k in req.keys():
		var ok: bool = hero_id == "" or nat.get(k, 0) >= req[k]
		rows.append(_row("Требуется: %s %d" % [DB.STAT_NAMES[k], req[k]], TT_WHITE if ok else TT_RED))
	# Особые свойства («Если на персонаже: …») — только уникальные эффекты вещи, не характеристики
	for t in base_of(item).get("equip", []) + item.get("equip", []):
		rows.append(_row("Если на персонаже: " + String(t), TT_GREEN))
	if note != "":
		rows.append(_row(note, TT_RED))
	rows.append(_row("Цена продажи:", TT_WHITE, str(sell_price(item)), TT_WHITE, "money"))
	return rows

static func _bb_row(r: Dictionary) -> String:
	var t := "[color=#%s]%s[/color]" % [Color(r["lc"]).to_html(false), r["l"]]
	if r["r"] != "":
		t += "  [color=#%s]%s[/color]" % [Color(r["rc"]).to_html(false), r["r"]]
	return t

## Те же строки одним BBCode-текстом (для карточек наград). from — с какой строки начинать.
static func tooltip_bb(item: Dictionary, hero_id: String = "", level: int = 1, note: String = "", from: int = 0) -> String:
	var rows := tooltip_lines(item, hero_id, level, note)
	var out := []
	for i in range(from, rows.size()):
		out.append(_bb_row(rows[i]))
	return "\n".join(out)
