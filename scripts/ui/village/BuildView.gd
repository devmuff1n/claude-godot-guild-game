extends Control
## Стройка (scenes/village/BuildView.tscn): здания поселения за монеты из казны (DB.BUILDINGS, DB.BUILD_ORDER).

const CARD := preload("res://scenes/ui/BuildingCard.tscn")

var village

func _ready() -> void:
	Game.changed.connect(_on_changed)
	refresh()

func _on_changed() -> void:
	if is_inside_tree():
		refresh()

func refresh() -> void:
	UIK.clear(%Grid)
	for id in DB.BUILD_ORDER:
		var card: BuildingCard = CARD.instantiate()
		%Grid.add_child(card)
		card.setup(id)
		var bid: String = id
		card.build_pressed.connect(func():
			var why := Game.build(bid)
			if why != "":
				Game.notify(why))
