extends Control
## Лавка Ольги (scenes/village/ShopView.tscn): покупка за казну, продажа, перековка свойств, выкуп проданного.

const SHOP_CARD := preload("res://scenes/ui/ShopItemCard.tscn")
const CONS_CARD := preload("res://scenes/ui/ConsCard.tscn")
const BUYBACK_ROW := preload("res://scenes/ui/BuybackRow.tscn")
const ITEM_SLOT := preload("res://scenes/ui/ItemSlot.tscn")
const CHIP := preload("res://scenes/ui/ChipButton.tscn")
const CONS_IDS := ["potion_hp", "potion_mp", "kit", "apple", "berries", "wine", "bread", "tea", "book"]

var village
var sel_sell := -1

func _ready() -> void:
	%SellButton.pressed.connect(func():
		Game.sell_storage(sel_sell)
		sel_sell = -1)
	%RerollButton.pressed.connect(func(): _msg(Game.reroll_storage(sel_sell)))
	Game.changed.connect(_on_changed)
	refresh()

func _on_changed() -> void:
	if is_inside_tree():
		refresh()

func _msg(m: String) -> void:
	if m != "":
		Game.notify(m)

func refresh() -> void:
	var disc := int(Game.discount() * 100)
	%ShopTitle.tooltip_text = "Платят из казны. Товар обновляется после победного похода и улучшается с числом разных выполненных поручений.%s" % (" Скидка за доверие деревни: %d%%." % disc if disc > 0 else "")
	# Снаряжение
	UIK.clear(%StockGrid)
	var stock: Array = Game.state["shop"]["stock"]
	%SoldOut.visible = stock.is_empty()
	for i in stock.size():
		var it: Dictionary = stock[i]
		var row: PanelContainer = SHOP_CARD.instantiate()
		%StockGrid.add_child(row)
		var s: ItemSlot = row.get_node("%Slot")
		s.item = it
		var nm: Label = row.get_node("%Name")
		nm.text = Items.display_name(it)
		nm.add_theme_color_override("font_color", Items.rarity_color(it))
		row.get_node("%Type").text = "%s · ур. %d" % [Items.type_label(it), int(it["ilvl"])]
		var price := Game.shop_price(it)
		var b: Button = row.get_node("%BuyButton")
		b.text = "Купить · %d мон." % price
		b.disabled = int(Game.state["treasury"]) < price
		var idx := i
		b.pressed.connect(func(): _msg(Game.buy_item(idx)))
	# Припасы
	UIK.clear(%ConsGrid)
	for id in CONS_IDS:
		var card: PanelContainer = CONS_CARD.instantiate()
		%ConsGrid.add_child(card)
		var s2: ItemSlot = card.get_node("%Slot")
		s2.cons_id = id
		var owned := int(Game.state["potions"].get(id, 0)) if DB.CONSUMABLES.has(id) else int(Game.state["backpack"].get(id, 0))
		var desc: String = DB.CONSUMABLES[id]["desc"] if DB.CONSUMABLES.has(id) else DB.GIFTS[id]["desc"] + "\nПодарок для вечера на привале (походный рюкзак, %d мест)." % DB.BACKPACK_CAP
		s2.tip_bb = "[b]%s[/b]\n%s" % [DB.consumable_name(id), desc]
		card.get_node("%Name").text = DB.consumable_name(id)
		card.get_node("%Owned").text = ("есть: %d" % owned) if owned > 0 else ""
		card.get_node("%Owned").visible = owned > 0
		var b2: Button = card.get_node("%BuyButton")
		b2.text = "%d мон." % Game.cons_price(id)
		b2.tooltip_text = "Купить: %s" % DB.consumable_name(id)
		b2.disabled = int(Game.state["treasury"]) < Game.cons_price(id)
		var cid: String = id
		b2.pressed.connect(func(): _msg(Game.buy_cons(cid)))
	# Продажа
	%SellNote.text = "КЛАДОВАЯ  %d/%d" % [Game.storage_count(), DB.STORAGE_SIZE]
	UIK.clear(%SellGrid)
	var st := Game.storage()
	for i in st.size():
		var sl: ItemSlot = ITEM_SLOT.instantiate()
		sl.custom_minimum_size = Vector2(54, 54)
		sl.can_drag = false
		var it3 = st[i]
		sl.setup(it3, {})
		sl.selected = i == sel_sell
		var idx3 := i
		sl.clicked.connect(func(_x):
			sel_sell = idx3 if st[idx3] != null else -1
			refresh())
		%SellGrid.add_child(sl)
	var has_sel := sel_sell >= 0 and st[sel_sell] != null
	# Строка продажи всегда на месте, чтобы список ниже не прыгал
	%SellButton.disabled = not has_sel
	%SellButton.text = "Продать"
	%RerollButton.disabled = true
	%RerollButton.text = "Перековать"
	%RerollButton.tooltip_text = "Новые случайные свойства для необычной и лучшей вещи. Каждая следующая перековка той же вещи дороже."
	%SellName.text = "—"
	%SellName.add_theme_color_override("font_color", UIK.MUTED)
	if has_sel:
		var it4: Dictionary = st[sel_sell]
		%SellName.text = Items.display_name(it4)
		%SellName.add_theme_color_override("font_color", Items.rarity_color(it4))
		%SellButton.text = "Продать · %d мон." % Items.sell_price(it4)
		if Items.can_reroll(it4):
			var rp := Items.reroll_price(it4)
			%RerollButton.text = "Перековать · %d мон." % rp
			%RerollButton.disabled = int(Game.state["treasury"]) < rp
			var n := int(it4.get("rerolls", 0))
			if n > 0:
				%RerollButton.tooltip_text += "\nУже перекована: %d раз(а)." % n
	UIK.clear(%ConsSell)
	for id in ["potion_hp", "potion_mp", "kit"]:
		if int(Game.state["potions"].get(id, 0)) > 0:
			_chip_sell(id, int(Game.state["potions"][id]))
	for g in Game.state["backpack"].keys():
		_chip_sell(g, int(Game.state["backpack"][g]))
	# Выкуп
	UIK.clear(%BuybackList)
	var bb: Array = Game.state["shop"]["buyback"]
	%BuybackEmpty.visible = bb.is_empty()
	for i in bb.size():
		var e: Dictionary = bb[i]
		var row3: HBoxContainer = BUYBACK_ROW.instantiate()
		%BuybackList.add_child(row3)
		row3.get_node("%Slot").item = e["item"]
		var nm3: Label = row3.get_node("%Name")
		nm3.text = Items.display_name(e["item"])
		nm3.add_theme_color_override("font_color", Items.rarity_color(e["item"]))
		var b3: Button = row3.get_node("%BuyButton")
		b3.text = "Выкупить — %d" % int(e["price"])
		var idx2 := i
		b3.pressed.connect(func(): _msg(Game.buyback(idx2)))

func _chip_sell(id: String, n: int) -> void:
	var b: Button = CHIP.instantiate()
	b.text = "%s ×%d" % [DB.consumable_name(id), n]
	b.pressed.connect(func(): _msg(Game.sell_cons(id)))
	%ConsSell.add_child(b)
