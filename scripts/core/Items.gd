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

## Требуемый уровень героя. Требований к характеристикам нет — только уровень (как в WoW).
static func req_level(item: Dictionary) -> int:
	return maxi(1, int(item.get("ilvl", 1)) - 1)

## Собственные атрибуты героя на уровне (без бонусов вещей)
static func own_stats(hero_id: String, level: int) -> Dictionary:
	return Stats.natural(hero_id, level)

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
	if b.has("wtype") and int(b.get("hands", 1)) == 2 and hero.get("one_hand", false):
		return "%s не берёт двуручное оружие." % hero["name"]
	if level < req_level(item):
		return "Нужен %d-й уровень (сейчас %d-й)." % [req_level(item), level]
	return ""

## Генерация экземпляра
## target — герой, под которого «подкручены» свойства: его статы выпадают чаще (DB.HEROES → affix_w),
## но любое свойство остаётся возможным. Пустой target — все свойства равновероятны.
static func make(base_id: String, ilvl: int, rarity: String, rng: RandomNumberGenerator, target := "") -> Dictionary:
	var item := {"uid": Game.next_uid(), "base": base_id, "ilvl": ilvl, "rarity": rarity, "affixes": []}
	item["affixes"] = roll_affixes(base_id, ilvl, int(DB.RARITY_AFFIXES[rarity]), rng, target)
	return item

## Вес случайного свойства для героя; у неупомянутых свойств небольшой вес, чтобы «чужие» вещи тоже попадались.
const OFF_AFFIX_W := 0.35

static func roll_affixes(base_id: String, ilvl: int, n: int, rng: RandomNumberGenerator, target := "") -> Array:
	var b: Dictionary = DB.BASES[base_id]
	var wmap: Dictionary = DB.HEROES[target].get("affix_w", {}) if DB.HEROES.has(target) else {}
	var out := []
	var pool := []
	for a in DB.AFFIXES:
		var st: String = a[0]
		if st == "block" and b.get("wtype", "") != "shield":
			continue
		if st == "parry" and not (b.get("wtype", "") in ["sword", "mace", "dagger", "shield"]):
			continue
		pool.append(a)
	var picked := []
	for _i in mini(n, pool.size()):
		var total := 0.0
		for a in pool:
			total += float(wmap.get(a[0], OFF_AFFIX_W)) if not wmap.is_empty() else 1.0
		var r := rng.randf() * total
		var k := pool.size() - 1
		for i in pool.size():
			r -= float(wmap.get(pool[i][0], OFF_AFFIX_W)) if not wmap.is_empty() else 1.0
			if r <= 0.0:
				k = i
				break
		picked.append(pool[k])
		pool.remove_at(k)
	for a in picked:
		var hi: float = a[1] + a[2] * float(ilvl)
		var v: float = hi * rng.randf_range(0.55, 1.0)
		if a[0] in DB.PCT_STATS:
			v = snapped(v, 0.1)
		else:
			v = max(1.0, round(v))
		out.append([a[0], v])
	return out

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

## Доля добычи со случайной основой (может не подойти никому из отряда).
const WILD_LOOT := 0.2

## Случайная вещь. party — герои отряда: чаще выпадают вещи, которые они носят, со «своими» свойствами.
## Пустой party — старое поведение: любая основа, свойства равновероятны.
static func random_item(ilvl: int, rng: RandomNumberGenerator, quality: float = 0.0, party: Array = []) -> Dictionary:
	if not party.is_empty() and rng.randf() >= WILD_LOOT:
		var hid: String = party[rng.randi_range(0, party.size() - 1)]
		var base_h := pick_base_for(hid, ilvl, 99, rng)
		if base_h != "":
			return make(base_h, ilvl, roll_rarity(rng, quality), rng, hid)
	var pool := bases_for_level(ilvl)
	var base_id: String = pool[rng.randi_range(0, pool.size() - 1)]
	# Основа случайная, но свойства всё равно тянутся к тому, кто из отряда может её носить
	var who := []
	for h in party:
		if hero_can_use_type(h, {"base": base_id}):
			who.append(h)
	return make(base_id, ilvl, roll_rarity(rng, quality), rng, who[rng.randi_range(0, who.size() - 1)] if not who.is_empty() else "")

## Утешительный приз за поражение: обычная вещь (без свойств) для кого-то из отряда
static func consolation_item(ilvl: int, rng: RandomNumberGenerator, party: Array) -> Dictionary:
	var hid: String = party[rng.randi_range(0, party.size() - 1)]
	var base_id := pick_base_for(hid, ilvl, 99, rng)
	if base_id == "":
		base_id = bases_for_level(ilvl)[0]
	return make(base_id, ilvl, "common", rng)

## Случайная основа, которую герой может носить (тип, хват) и надеть на уровне level. "" — нет такой.
static func pick_base_for(hero_id: String, ilvl: int, level: int, rng: RandomNumberGenerator) -> String:
	var pool := []
	for k in bases_for_level(ilvl):
		var probe := {"base": k, "ilvl": ilvl}
		if hero_can_use_type(hero_id, probe) and req_level(probe) <= level:
			pool.append(k)
	if pool.is_empty():
		return ""
	return pool[rng.randi_range(0, pool.size() - 1)]

## Вещь, подходящая конкретному герою (тип, хват, уровень), не ниже необычной, со свойствами под него
static func item_for_hero(hero_id: String, level: int, ilvl: int, rng: RandomNumberGenerator, quality: float) -> Dictionary:
	var base_id := pick_base_for(hero_id, ilvl, level, rng)
	if base_id == "":
		return random_item(ilvl, rng, quality)
	var rar := roll_rarity(rng, quality + 1.0)
	if rar == "common":
		rar = "uncommon"
	return make(base_id, ilvl, rar, rng, hero_id)

# ---------------------------------------------------------------- Перековка свойств
## Цена перековки растёт с каждой попыткой (×1,6), отсчёт хранится в самой вещи.
static func reroll_price(item: Dictionary) -> int:
	var base := maxf(8.0, price(item) * 0.35)
	return int(round(base * pow(1.6, int(item.get("rerolls", 0)))))

static func can_reroll(item: Dictionary) -> bool:
	return int(DB.RARITY_AFFIXES.get(item.get("rarity", "common"), 0)) > 0

## Новые случайные свойства (то же число, тот же уровень). target — под кого подкручивать.
static func reroll(item: Dictionary, rng: RandomNumberGenerator, target := "") -> void:
	item["affixes"] = roll_affixes(item["base"], int(item.get("ilvl", 1)), int(DB.RARITY_AFFIXES[item.get("rarity", "common")]), rng, target)
	item["rerolls"] = int(item.get("rerolls", 0)) + 1

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
		if int(b.get("hands", 1)) == 2 and hero.get("one_hand", false):
			return false
		return b["wtype"] in hero["weapons"]
	var at: String = b.get("atype", "")
	return at == "jewel" or at in hero["armors"]

## Дорос ли герой до вещи
static func meets_requirements(_hero_id: String, level: int, item: Dictionary) -> bool:
	return level >= req_level(item)

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
	var rl := req_level(item)
	if rl > 1:
		rows.append(_row("Требуется уровень %d" % rl, TT_WHITE if hero_id == "" or level >= rl else TT_RED))
	# Особые свойства («Если на персонаже: …») — только уникальные эффекты вещи, не характеристики
	for t in base_of(item).get("equip", []) + item.get("equip", []):
		rows.append(_row("Если на персонаже: " + String(t), TT_GREEN))
	if note != "":
		rows.append(_row(note, TT_RED))
	rows.append(_row("Цена продажи:", TT_WHITE, str(sell_price(item)), TT_WHITE, "money"))
	return rows

## Сравнение с надетым, как в WoW: «Если вы замените этот предмет…» — разница new − old по строкам
## характеристик, зелёным прибавка, красным потеря. Пустой массив — разницы нет.
static func compare_rows(new_item: Dictionary, old_item: Dictionary) -> Array:
	var a := stats(new_item)
	var b := stats(old_item)
	var rows := []
	var lines := [["armor", "к броне"], ["block_val", "к блоку"]] + TT_STAT_LINES
	for e in lines:
		var k: String = e[0]
		var dv := float(a.get(k, 0.0)) - float(b.get(k, 0.0))
		if absf(dv) < 0.05:
			continue
		var pct: bool = k in DB.PCT_STATS
		var t := UIK.fmt_pct(absf(dv)) if pct else "%d" % int(round(absf(dv)))
		if t == "0" or t == "0%":
			continue
		rows.append(_row("%s%s %s" % ["+" if dv > 0 else "−", t, e[1]], TT_GREEN if dv > 0 else TT_RED))
	if a.has("dmg_min") or b.has("dmg_min"):
		var dps_a := (float(a.get("dmg_min", 0)) + float(a.get("dmg_max", 0))) * 0.5 / float(a.get("interval", 1.0)) if a.has("dmg_min") else 0.0
		var dps_b := (float(b.get("dmg_min", 0)) + float(b.get("dmg_max", 0))) * 0.5 / float(b.get("interval", 1.0)) if b.has("dmg_min") else 0.0
		var dd := dps_a - dps_b
		if absf(dd) >= 0.05:
			rows.append(_row("%s%s ед. урона в секунду" % ["+" if dd > 0 else "−", _num(absf(dd))], TT_GREEN if dd > 0 else TT_RED))
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
