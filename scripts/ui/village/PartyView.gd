extends Control
## Отряд (scenes/village/PartyView.tscn): список героев, «кукла» с экипировкой, характеристики,
## кладовая на 80 ячеек, умения и перки; вторая вкладка — отношения и журнал (JournalView.tscn).

const ROSTER_ITEM := preload("res://scenes/ui/HeroRosterItem.tscn")
const SKILL_CARD := preload("res://scenes/ui/SkillCard.tscn")
const PERK_CARD := preload("res://scenes/ui/PerkCard.tscn")
const TEXT_LINE := preload("res://scenes/ui/TextLine.tscn")
const ITEM_SLOT := preload("res://scenes/ui/ItemSlot.tscn")

var village
var hero_id := "marek"
var sub := "heroes"
var side_tab := "skills"
var sel_storage := -1

func _ready() -> void:
	%TabHeroes.pressed.connect(func():
		sub = "heroes"
		refresh())
	%TabJournal.pressed.connect(func():
		sub = "journal"
		refresh())
	%TabSkills.pressed.connect(func():
		side_tab = "skills"
		refresh())
	%TabPerks.pressed.connect(func():
		side_tab = "perks"
		refresh())
	%TabSocial.pressed.connect(func():
		side_tab = "social"
		refresh())
	%QueueButton.pressed.connect(func(): Game.take_queue())
	%BestButton.pressed.connect(func():
		var n := Game.equip_best(hero_id)
		sel_storage = -1
		Game.notify("Надето вещей: %d." % n if n > 0 else "В кладовой нет вещей лучше надетых."))
	%EquipButton.pressed.connect(func():
		_toast(Game.equip_from_storage(hero_id, sel_storage))
		sel_storage = -1)
	%SellButton.pressed.connect(func():
		Game.sell_storage(sel_storage)
		sel_storage = -1)
	%Doll.drop_cb = _on_drop
	%Doll.slot_right_clicked.connect(func(sl: String): _toast(Game.unequip(hero_id, sl)))
	for i in DB.STORAGE_SIZE:
		var s2: ItemSlot = ITEM_SLOT.instantiate()
		s2.custom_minimum_size = Vector2(50, 50)
		s2.drop_cb = _on_drop
		# Ячейки показывают только вещи выбранного героя, поэтому номер ячейки кладовой берём из ctx
		s2.clicked.connect(func(sl: ItemSlot):
			var idx: int = sl.ctx.get("index", -1)
			sel_storage = idx if sel_storage != idx and sl.item != null else -1
			refresh())
		s2.right_clicked.connect(func(sl: ItemSlot):
			var idx: int = sl.ctx.get("index", -1)
			if idx >= 0 and Game.storage()[idx] != null:
				_toast(Game.equip_from_storage(hero_id, idx)))
		%StorageGrid.add_child(s2)
	Game.changed.connect(_on_changed)
	refresh()

func _on_changed() -> void:
	if is_inside_tree():
		refresh()

func _toast(msg: String) -> void:
	if msg != "":
		Game.notify(msg)

func refresh() -> void:
	UIK.mark(%TabHeroes, sub == "heroes")
	UIK.mark(%TabJournal, sub == "journal")
	%HeroesPage.visible = sub == "heroes"
	%JournalPage.visible = sub == "journal"
	if sub == "journal":
		%Journal.refresh()
		return
	_fill_roster()
	_fill_center()
	_fill_side()

func _fill_roster() -> void:
	UIK.clear(%HeroList)
	for id in DB.HERO_IDS:
		var b: HeroRosterItem = ROSTER_ITEM.instantiate()
		%HeroList.add_child(b)
		b.setup(id)
		UIK.mark(b, id == hero_id)
		var hid: String = id
		b.pressed.connect(func():
			hero_id = hid
			sel_storage = -1
			refresh())

func _fill_center() -> void:
	var h := Game.hero(hero_id)
	var hd: Dictionary = DB.HEROES[hero_id]
	%Role.text = ("%s · %s" % [hd["cls"], hd["role"]]).to_upper()
	%HeroName.text = hd["full"]
	var wt := []
	for w in hd["weapons"]:
		wt.append(DB.WEAPON_TYPE_NAMES[w])
	var at := []
	for a in hd["armors"]:
		at.append(DB.ARMOR_TYPE_NAMES[a])
	%HeroName.tooltip_text = "%s\n\nОружие: %s\nБроня: %s" % [hd["bio"], ", ".join(wt), ", ".join(at)]
	%XpBar.set_val(int(h["xp"]), DB.xp_to_next(int(h["level"])), "Base %d · %d/%d XP" % [int(h["level"]), int(h["xp"]), DB.xp_to_next(int(h["level"]))])
	%JobBar.set_val(int(h["jxp"]), DB.jxp_to_next(int(h["job"])), "Job %d · %d/%d JXP" % [int(h["job"]), int(h["jxp"]), DB.jxp_to_next(int(h["job"]))])
	%Doll.show_hero(hero_id)
	%Stats.show_hero(hero_id)
	# Кладовая
	%StorageTitle.text = "КЛАДОВАЯ  %d/%d" % [Game.storage_count(), DB.STORAGE_SIZE]
	%QueueButton.visible = Game.state["queue"].size() > 0
	%QueueButton.text = "Забрать из очереди: %d" % Game.state["queue"].size()
	var st := Game.storage()
	var has_sel := sel_storage >= 0 and st[sel_storage] != null
	# Кнопки всегда на месте (чтобы заголовок не прыгал), без выбора — неактивны
	%EquipButton.disabled = not has_sel
	%SellButton.disabled = not has_sel
	%SelName.text = ""
	%EquipButton.tooltip_text = ""
	%SellButton.text = "Продать"
	if has_sel:
		var it2: Dictionary = st[sel_storage]
		%SelName.text = Items.display_name(it2)
		%SelName.add_theme_color_override("font_color", Items.rarity_color(it2))
		var prob := Game.equip_problem(hero_id, it2, Game.auto_slot(hero_id, it2))
		%EquipButton.disabled = prob != ""
		%EquipButton.tooltip_text = prob
		%SellButton.text = "Продать · %d" % Items.sell_price(it2)
	# Только то, что выбранный герой может носить: сначала его вещи, затем свободные ячейки.
	# Чужие вещи остаются в своих ячейках кладовой, просто не показываются.
	var shown := []
	var hidden := 0
	for i in st.size():
		if st[i] != null:
			if Items.hero_can_use_type(hero_id, st[i]):
				shown.append(i)
			else:
				hidden += 1
	for i in st.size():
		if st[i] == null:
			shown.append(i)
	%StorageTitle.mouse_filter = Control.MOUSE_FILTER_PASS
	%StorageTitle.tooltip_text = ("Скрыто вещей, которые %s не носит: %d" % [DB.hero_name(hero_id), hidden]) if hidden > 0 else ""
	var slots := %StorageGrid.get_children()
	var any_up := false
	for j in slots.size():
		var s2: ItemSlot = slots[j]
		s2.visible = j < shown.size()
		if not s2.visible:
			s2.setup(null, {})
			continue
		var i: int = shown[j]
		var it3 = st[i]
		s2.dim = false
		s2.upgrade = false
		s2.tip_hero = hero_id
		s2.tip_note = ""
		if it3 != null:
			var prob2 := Game.equip_problem(hero_id, it3, Game.auto_slot(hero_id, it3))
			s2.dim = prob2 != ""
			s2.upgrade = prob2 == "" and float(Game.upgrade_gain(hero_id, it3)["gain"]) > 0.01
			any_up = any_up or s2.upgrade
			# Нехватку уровня и так видно красным в подсказке; иная причина — отдельной красной строкой
			if prob2 != "" and Items.meets_requirements(hero_id, int(h["level"]), it3):
				s2.tip_note = prob2
		s2.setup(it3, {"kind": "storage", "index": i})
		s2.selected = i == sel_storage
	%BestButton.disabled = not any_up

func _on_drop(from: Dictionary, to: Dictionary) -> void:
	if from["kind"] == "storage" and to["kind"] == "storage":
		if from["index"] != to["index"]:
			Game.move_item(from["index"], to["index"])
	elif from["kind"] == "storage" and to["kind"] == "equip":
		_toast(Game.equip_from_storage(to["hero"], from["index"], to["slot"]))
	elif from["kind"] == "equip" and to["kind"] == "storage":
		_toast(Game.unequip_to(from["hero"], from["slot"], to["index"]))
	elif from["kind"] == "equip" and to["kind"] == "equip":
		_toast("Сначала снимите вещь в кладовую.")

func _line(parent: Control, t: String, variation: String) -> Label:
	var l: Label = TEXT_LINE.instantiate()
	l.text = t
	l.theme_type_variation = StringName(variation)
	parent.add_child(l)
	return l

func _fill_side() -> void:
	UIK.mark(%TabSkills, side_tab == "skills")
	UIK.mark(%TabPerks, side_tab == "perks")
	UIK.mark(%TabSocial, side_tab == "social")
	%Points.set_value(str(Game.perk_points(hero_id)))
	%Points.icon_kind = "perk"
	%Points.tooltip_text = "Свободные очки перков (Job Level)"
	var body: VBoxContainer = %SideBody
	UIK.clear(body)
	var h := Game.hero(hero_id)
	%SideScroll.visible = side_tab != "social"
	%Social.visible = side_tab == "social"
	if side_tab == "social":
		%Points.set_value(str(Game.social_points(hero_id)))
		%Points.icon_kind = "friend"
		%Points.tooltip_text = "Свободные очки черт: по одному за каждый Job Level"
		%Social.show_hero(hero_id)
	elif side_tab == "skills":
		for ab in DB.HERO_ABILITIES[hero_id]:
			var a: Dictionary = DB.ABILITIES[ab]
			var unlocked := Game.ability_unlocked(hero_id, ab)
			var card: PanelContainer = SKILL_CARD.instantiate()
			body.add_child(card)
			card.theme_type_variation = &"PanelInset" if unlocked else &"PanelInsetLocked"
			card.get_node("%Name").text = a["name"]
			card.get_node("%Lock").visible = not unlocked
			card.get_node("%LockLevel").text = "ур. %d" % a["lvl"]
			card.get_node("%Cost").text = "%d ATB · %d МП" % [a["cost"], a["mp"]]
			var meta := []
			if a["cast"] > 0:
				meta.append("подготовка %.1f с" % a["cast"])
			if a["cd"] > 0:
				meta.append("перезарядка %.0f с" % a["cd"])
			# подготовка и перезарядка — в подсказку
			card.get_node("%Meta").visible = false
			card.tooltip_text = "\n".join(meta)
			card.get_node("%Desc").text = a["desc"]
			card.modulate = Color(1, 1, 1) if unlocked else Color(0.7, 0.67, 0.62)
	else:
		for stage in DB.PERK_STAGES.keys():
			var prob := Game.perk_stage_problem(hero_id, stage)
			var head := _line(body, "ЭТАП %s" % DB.STAGE_NAMES[stage], "CaptionLabel")
			if prob != "":
				head.text += "  🔒"
				head.tooltip_text = prob
				head.mouse_filter = Control.MOUSE_FILTER_PASS
			var cur: String = h["perks"].get(stage, "")
			for pk in DB.PERKS[hero_id][stage]:
				var chosen: bool = cur == pk["id"]
				var card2: PanelContainer = PERK_CARD.instantiate()
				body.add_child(card2)
				card2.theme_type_variation = &"PanelChosen" if chosen else (&"PanelInset" if prob == "" else &"PanelInsetLocked")
				card2.get_node("%Name").text = pk["name"] + ("  ✔" if chosen else "")
				card2.get_node("%Desc").text = pk["desc"]
				var b2: Button = card2.get_node("%ChooseButton")
				b2.visible = not chosen
				if not chosen:
					var pid: String = pk["id"]
					var st2: int = stage
					b2.text = "Выбрать" if cur == "" else "Сменить"
					b2.pressed.connect(func(): _toast(Game.choose_perk(hero_id, st2, pid)))
					b2.disabled = prob != "" or (cur == "" and Game.perk_points(hero_id) <= 0)
					if b2.disabled:
						b2.tooltip_text = prob if prob != "" else "Нет свободных очков Job."
