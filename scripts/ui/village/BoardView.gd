extends Control
## Доска поручений (scenes/village/BoardView.tscn): список поручений, описание и награды,
## подготовка к походу (доп. поручения, кошелёк, строй).

const LIST_ITEM := preload("res://scenes/ui/ContractListItem.tscn")
const CHIP := preload("res://scenes/ui/ChipButton.tscn")
const PILL := preload("res://scenes/ui/ResourcePill.tscn")
const UNLOCK_CHIP := preload("res://scenes/ui/UnlockChip.tscn")

var village
var sel := ""
var general := ""
var pers_hero := "marek"
var pers_obj := ""
var purse := -1

func _ready() -> void:
	for cid in DB.STORY_ORDER:
		if Game.contract_available(cid) and Game.contract_done_count(cid) == 0:
			sel = cid
			break
	if sel == "":
		sel = "c1"
	purse = Game.default_purse()
	%PurseSlider.value_changed.connect(func(val):
		purse = int(val)
		_update_purse_label())
	%DepartButton.pressed.connect(_depart)
	refresh()

func refresh() -> void:
	_fill_list()
	_fill_details()

func _fill_list() -> void:
	UIK.clear(%StoryList)
	UIK.clear(%SideList)
	for cid in DB.STORY_ORDER + DB.SIDE_ORDER:
		if not DB.CONTRACTS.has(cid):
			continue
		var b: ContractListItem = LIST_ITEM.instantiate()
		(%SideList if DB.CONTRACTS[cid].get("side", false) else %StoryList).add_child(b)
		b.setup(cid)
		var id: String = cid
		b.pressed.connect(func():
			sel = id
			general = ""
			pers_obj = ""
			refresh())
		UIK.mark(b, cid == sel)

func _chip(parent: Control, text: String, on: bool, cb: Callable, tip := "") -> Button:
	var b: Button = CHIP.instantiate()
	b.text = text
	b.tooltip_text = tip
	parent.add_child(b)
	UIK.mark(b, on)
	b.pressed.connect(cb)
	return b

func _pill(parent: Control, kind: String, cons: String, val: String, tip: String) -> ResourcePill:
	var p: ResourcePill = PILL.instantiate()
	p.icon_kind = kind
	p.cons_id = cons
	p.value_width = 0.0
	p.tooltip_text = tip
	parent.add_child(p)
	p.set_value(val)
	return p

func _fill_details() -> void:
	var c: Dictionary = DB.CONTRACTS[sel]
	var avail := Game.contract_available(sel)
	var n := Game.contract_done_count(sel)
	var first := n == 0
	%Kind.text = ("ГЛАВА %d" % int(c["story"])) if int(c["story"]) > 0 else "ПОБОЧНОЕ ПОРУЧЕНИЕ"
	%CName.text = c["name"]
	%Level.set_value(str(int(c["level"])))
	# Готовность отряда рядом с угрозой (Darkest Dungeon): зелёный — не ниже уровня, жёлтый — на 1 ниже, красный — ещё ниже
	var pl := int(Game.party_level())
	var gap := pl - int(c["level"])
	%PartyLevel.set_value(str(pl), UIK.GREEN if gap >= 0 else (UIK.GOLD_HI if gap == -1 else UIK.RED))
	%PartyLevel.tooltip_text = "Уровень отряда: %d (поручение: %d)" % [pl, int(c["level"])] + \
		("\nОтряд ниже уровня: у героев меньше здоровья и урона, а броня хуже держит удары врагов." if gap < 0 else ("\nОтряд выше уровня: опыта за врагов меньше." if gap > 0 else "\nОтряд в уровне поручения."))
	%Threat.set_rank(Game.contract_threat(sel)["rank"])
	%Threat.tooltip_text = Game.threat_tip(sel)
	%CDesc.text = c["desc"]
	%CIntro.text = "«%s»" % c["intro"]
	%CDesc.tooltip_text = %CIntro.text
	# Особые условия поручения: ночь, опасные враги, повозка… (подробности — в подсказке)
	UIK.clear(%Twists)
	for t in Game.contract_twists(sel):
		var chip: PanelContainer = UNLOCK_CHIP.instantiate()
		%Twists.add_child(chip)
		chip.get_node("%Icon").kind = t.get("icon", "event")
		chip.get_node("%Text").text = t["title"]
		chip.tooltip_text = t["tip"]
	# Строка остаётся на месте и без условий — описание и награды ниже не прыгают
	var diplo: bool = c.has("diplomacy")
	%Mission.visible = diplo and avail
	%Threat.visible = true
	# Награды
	UIK.clear(%Rewards)
	var pay: int = int(c["pay"]) if first else int(c["repeat_pay"])
	_pill(%Rewards, "coin", "", str(pay), ("Оплата за первое выполнение\nПовтор: %d мон." % c["repeat_pay"]) if first else "Оплата повтора (первое выполнение уже оплачено)")
	if first:
		_pill(%Rewards, "job", "", "+%d" % int(c["jxp"]), "Освоение: +%d JXP всем героям за первое выполнение" % c["jxp"])
	if diplo:
		_pill(%Rewards, "gift", "", "выбор", "Награда двора: 1 вещь на выбор из 3")
	else:
		_pill(%Rewards, "gift", "", "2 + выбор" if first else "2", "Добыча: 2 случайные вещи за победу" + (" и 1 вещь на выбор из 3 за первое выполнение" if first else ""))
	if c.get("escort", false):
		_pill(%Rewards, "cons", "kit", "%d + %d" % [c["kits"], int(Game.state["potions"].get("kit", 0))], "Сопровождение: повозка в бою, налётчики бьют по ней.\nРемкомплекты: %d от возчика + %d из запасов гильдии. Ремонт выводит героя из боя." % [c["kits"], int(Game.state["potions"].get("kit", 0))])
	var prem: Dictionary = c["premium"]
	var claimed: bool = Game.state["premium_claimed"].has(sel)
	%PremiumName.text = "Премия: «%s»" % prem["name"]
	%PremiumValue.text = "получена" if claimed else "+%d" % prem["coins"]
	%Premium.tooltip_text = "Одноразовая премия за особое условие. Её потеря не отменяет победу." + ("\nУже получена." if claimed else "")
	%Premium.modulate = Color(1, 1, 1, 0.55) if claimed else Color(1, 1, 1, 1)
	# Маршрут
	var route: Array = c.get("route", [])
	if c.get("outpost", false):
		route = [{"type": "outpost", "name": "Застава"}]
	%Route.set_route(route, -1, 0.0)
	if c.get("outpost", false):
		%Route.tooltip_text = "Оборона заставы: %d волн налётчиков.\nМежду волнами — ремонт ворот (материалы: %d) и тушение пожаров." % [c["waves"].size(), c["materials"]]
	%Locked.visible = not avail
	%Prep.visible = avail and not diplo
	%DepartButton.disabled = not avail
	%DepartButton.text = "В путь" if diplo else "Выступить"
	if diplo and avail:
		var party: Array = Game.dip_scenario(sel)["party"]
		%DelCard0.setup(party[0])
		%DelCard1.setup(party[1])
		if not first:
			%DepartButton.disabled = true
			%DepartButton.tooltip_text = "Миссия завершена"
		return
	if not avail:
		var req := []
		for r in c["requires"]:
			req.append("«%s»" % DB.CONTRACTS[r]["name"])
		%LockedText.text = "Откроется после: " + ", ".join(req)
		return
	# Общее поручение
	UIK.clear(%GeneralRow)
	for g in [""] + c["general"]:
		var gid: String = g
		var tip := ""
		if g != "":
			var gd: Dictionary = DB.GENERAL_OBJECTIVES[g]
			var got: bool = Game.state["jxp_claimed"].has("%s:gen:%s" % [sel, g])
			tip = "%s\nНаграда: +%d мон.%s" % [gd["desc"], gd["coins"], (" (JXP уже получен)" if got else ", +%d JXP всем" % gd["jxp"])]
		_chip(%GeneralRow, "Нет" if g == "" else DB.GENERAL_OBJECTIVES[g]["name"], general == g, func():
			general = gid
			refresh(), tip)
	# Личное поручение
	UIK.clear(%PersHeroRow)
	for hid in DB.HERO_IDS:
		var h: String = hid
		_chip(%PersHeroRow, DB.hero_name(hid), pers_hero == hid, func():
			pers_hero = h
			pers_obj = ""
			refresh())
	UIK.clear(%PersObjRow)
	_chip(%PersObjRow, "Нет", pers_obj == "", func():
		pers_obj = ""
		refresh())
	for od in DB.PERSONAL_OBJECTIVES[pers_hero]:
		var oid: String = od["id"]
		var got2: bool = Game.state["jxp_claimed"].has("%s:pers:%s:%s" % [sel, pers_hero, oid])
		_chip(%PersObjRow, od["name"], pers_obj == oid, func():
			pers_obj = oid
			refresh(), "%s\nНаграда: +20 мон.%s, дружба с Эйденом ↑" % [od["desc"], " (JXP уже получен)" if got2 else ", +60 JXP герою"])
	# Кошелёк
	var tr := int(Game.state["treasury"])
	purse = clamp(purse, 0, tr)
	%PurseSlider.max_value = tr
	%PurseSlider.set_value_no_signal(purse)
	_update_purse_label()
	# Запасы
	UIK.clear(%Supplies)
	for id in ["potion_hp", "potion_mp", "kit"]:
		_pill(%Supplies, "cons", id, str(int(Game.state["potions"].get(id, 0))), DB.consumable_name(id))
	_pill(%Supplies, "backpack", "", "%d/%d" % [Game.backpack_count(), DB.BACKPACK_CAP], "Походный рюкзак: подарки для вечера на привале")
	%Formation.refresh()

func _update_purse_label() -> void:
	%PurseValue.set_value(str(purse))
	%PurseValue.tooltip_text = "Берёте из казны: %d из %d мон." % [purse, int(Game.state["treasury"])]

func _depart() -> void:
	if DB.CONTRACTS[sel].has("diplomacy"):
		var e := Game.start_diplomacy(sel)
		if e != "":
			Game.notify(e)
			return
		village.main.goto("diplomacy")
		return
	var opts := {"purse": purse, "general": general, "formation": Game.state["formation"]}
	if pers_obj != "":
		opts["personal"] = {"hero": pers_hero, "obj": pers_obj}
	var err := Game.start_expedition(sel, opts)
	if err != "":
		Game.notify(err)
		return
	village.start_expedition_screen()
