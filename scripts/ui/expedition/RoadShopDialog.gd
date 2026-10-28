class_name RoadShopDialog
extends Control
## Придорожная торговля (scenes/expedition/RoadShopDialog.tscn): покупки из походного кошелька.

signal buy_requested(id: String)
signal leave_pressed

const CONS_CARD := preload("res://scenes/ui/ConsCard.tscn")

func _ready() -> void:
	%LeaveButton.pressed.connect(func(): leave_pressed.emit())

func refresh(title: String, ids: Array) -> void:
	var e := Game.ex()
	%Title.text = title
	%Purse.set_value(str(int(e["purse"])))
	%Backpack.set_value("%d/%d" % [Game.backpack_count(), DB.BACKPACK_CAP])
	UIK.clear(%Grid)
	for id in ids:
		var cid: String = id
		var card: PanelContainer = CONS_CARD.instantiate()
		%Grid.add_child(card)
		var icon: ItemSlot = card.get_node("%Slot")
		icon.cons_id = id
		var owned := int(e["kits"]) if id == "kit" else (int(Game.state["potions"].get(id, 0)) if DB.CONSUMABLES.has(id) else int(Game.state["backpack"].get(id, 0)))
		icon.tip_bb = "[b]%s[/b]\n%s" % [DB.consumable_name(id), DB.CONSUMABLES[id]["desc"] if DB.CONSUMABLES.has(id) else DB.GIFTS[id]["desc"]]
		card.get_node("%Name").text = DB.consumable_name(id)
		card.get_node("%Owned").text = ("есть: %d" % owned) if owned > 0 else ""
		card.get_node("%Owned").visible = owned > 0
		var price := Game.cons_price(id, true)
		var b: Button = card.get_node("%BuyButton")
		b.text = "%d мон." % price
		b.tooltip_text = "Купить: %s" % DB.consumable_name(id)
		b.disabled = int(e["purse"]) < price
		b.pressed.connect(func(): buy_requested.emit(cid))
