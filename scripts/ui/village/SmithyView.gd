extends Control
## Кузница (scenes/village/SmithyView.tscn): заточка надетых вещей и вещей из кладовой, разборка на реагенты.
## Открывается постройкой Кузницы (DB.FEATURES["forge"]).

const ITEM_SLOT := preload("res://scenes/ui/ItemSlot.tscn")
const CHIP := preload("res://scenes/ui/ChipButton.tscn")
const PILL := preload("res://scenes/ui/ResourcePill.tscn")

var village
var hero_id := "marek"
## Выбранная вещь: {"kind": "storage", "index": i} или {"kind": "equip", "hero": id, "slot": s}
var sel := {}

func _ready() -> void:
	%SharpenButton.pressed.connect(func():
		_msg(Game.sharpen(_sel_item())))
	%SalvageButton.pressed.connect(func():
		if sel.get("kind", "") == "storage":
			var i: int = sel["index"]
			sel = {}
			_msg(Game.salvage_storage(i)))
	Game.changed.connect(_on_changed)
	refresh()

func _on_changed() -> void:
	if is_inside_tree():
		refresh()

func _msg(m: String) -> void:
	if m != "":
		Game.notify(m)

func _sel_item():
	match sel.get("kind", ""):
		"storage":
			return Game.storage()[int(sel["index"])]
		"equip":
			return Game.hero(sel["hero"])["equip"].get(sel["slot"])
	return null

func _pill(parent: Control, kind: String, val: String, tip: String, bad := false) -> void:
	var p: ResourcePill = PILL.instantiate()
	p.icon_kind = kind
	p.value_width = 28.0
	p.tooltip_text = tip
	parent.add_child(p)
	p.set_value(val, UIK.RED if bad else Color(0, 0, 0, 0))

func _slot(parent: Control, it, ctx: Dictionary) -> void:
	var sl: ItemSlot = ITEM_SLOT.instantiate()
	sl.custom_minimum_size = Vector2(54, 54)
	sl.can_drag = false
	sl.setup(it, ctx)
	if ctx["kind"] == "equip":
		sl.tip_hero = ctx["hero"]
	sl.selected = it != null and ctx == sel
	sl.clicked.connect(func(_x):
		sel = ctx if it != null else {}
		refresh())
	parent.add_child(sl)

func refresh() -> void:
	if _sel_item() == null:
		sel = {}
	# Запас реагентов
	UIK.clear(%Reagents)
	for k in DB.REAGENT_ORDER:
		var r: Dictionary = DB.REAGENTS[k]
		_pill(%Reagents, r["icon"], str(Game.reagent_count(k)), "[%s]\n%s" % [r["name"], r["desc"]])
	# Надетое выбранного героя
	UIK.clear(%HeroRow)
	for h in DB.HERO_IDS:
		var hid: String = h
		var b: Button = CHIP.instantiate()
		b.text = DB.hero_name(h)
		%HeroRow.add_child(b)
		UIK.mark(b, h == hero_id)
		b.pressed.connect(func():
			hero_id = hid
			refresh())
	UIK.clear(%EquipGrid)
	var eq: Dictionary = Game.hero(hero_id)["equip"]
	for s in DB.SLOTS:
		_slot(%EquipGrid, eq.get(s), {"kind": "equip", "hero": hero_id, "slot": s})
	# Кладовая
	%StorageCaption.text = "КЛАДОВАЯ  %d/%d" % [Game.storage_count(), DB.STORAGE_SIZE]
	UIK.clear(%StorageGrid)
	var st := Game.storage()
	for i in st.size():
		_slot(%StorageGrid, st[i], {"kind": "storage", "index": i})
	_fill_work()

func _fill_work() -> void:
	var it = _sel_item()
	%Slot.setup(it, {})
	%Slot.can_drag = false
	UIK.clear(%SharpenCost)
	UIK.clear(%SalvageYield)
	%SharpenButton.disabled = true
	%SalvageButton.disabled = true
	%SharpenButton.tooltip_text = ""
	%SalvageButton.tooltip_text = ""
	if it == null:
		%ItemName.text = "—"
		%ItemName.add_theme_color_override("font_color", UIK.MUTED)
		%ItemType.text = ""
		%Level.set_value("—")
		%Bonus.set_value("—")
		return
	%ItemName.text = Items.display_name(it)
	%ItemName.add_theme_color_override("font_color", Items.rarity_color(it))
	%ItemType.text = "%s · ур. %d" % [Items.type_label(it), int(it.get("ilvl", 1))]
	var plus := int(it.get("plus", 0))
	var step := int(round(DB.SHARPEN_STEP * 100.0))
	%Level.set_value("+%d / +%d" % [plus, DB.SHARPEN_MAX])
	var cost := Game.sharpen_cost(it)
	if cost.is_empty():
		%Bonus.set_value("+%d%%" % (plus * step))
	else:
		%Bonus.set_value("+%d%% → +%d%%" % [plus * step, (plus + 1) * step])
		_pill(%SharpenCost, "coin", str(int(cost["coins"])), "Монеты из казны", int(Game.state["treasury"]) < int(cost["coins"]))
		for k in DB.REAGENT_ORDER:
			if cost["reagents"].has(k):
				var need := int(cost["reagents"][k])
				_pill(%SharpenCost, DB.REAGENTS[k]["icon"], str(need), "%s: есть %d" % [DB.REAGENTS[k]["name"], Game.reagent_count(k)], Game.reagent_count(k) < need)
	var why := Game.sharpen_problem(it)
	%SharpenButton.disabled = why != ""
	%SharpenButton.tooltip_text = why
	# Разборка — только из кладовой
	var y := Game.salvage_yield(it)
	for k in DB.REAGENT_ORDER:
		if y.has(k):
			_pill(%SalvageYield, DB.REAGENTS[k]["icon"], "+%d" % int(y[k]), DB.REAGENTS[k]["name"])
	%SalvageYield.modulate.a = 1.0 if sel.get("kind", "") == "storage" else 0.35
	%SalvageButton.disabled = sel.get("kind", "") != "storage"
	%SalvageButton.tooltip_text = "" if sel.get("kind", "") == "storage" else "Сначала снимите вещь в кладовую."
