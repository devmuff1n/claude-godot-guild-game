class_name BuildingCard
extends PanelContainer
## Карточка здания на вкладке «Стройка» (scenes/ui/BuildingCard.tscn): что даёт, цена, кнопка «Построить».

signal build_pressed

var building_id := ""

func _ready() -> void:
	%BuildButton.pressed.connect(func(): build_pressed.emit())

func setup(id: String) -> void:
	building_id = id
	var b: Dictionary = DB.BUILDINGS[id]
	%Name.text = Game.building_name(id)
	%Icon.kind = b.get("icon", "home")
	%Icon.queue_redraw()
	var gives: Array = b.get("gives", [])
	%Gives.text = "\n".join(gives)
	var price := int(b["price"])
	if Game.building_built(id):
		theme_type_variation = &"PanelChosen"
		%Status.text = "ПОСТРОЕНО"
		%BuildButton.text = "Построено"
		%BuildButton.disabled = true
		%BuildButton.tooltip_text = ""
	elif not Game.building_available(id):
		theme_type_variation = &"PanelInsetLocked"
		var af: String = b["after"]
		%Status.text = "ПОСЛЕ ОТПРАВКИ ДЕЛЕГАЦИИ" if af.begins_with("sent:") else "ПОСЛЕ «%s»" % DB.CONTRACTS[af]["name"].to_upper()
		%BuildButton.text = "%d мон." % price
		%BuildButton.disabled = true
		%BuildButton.tooltip_text = Game.build_problem(id)
	else:
		theme_type_variation = &"PanelInset"
		%Status.text = "МОЖНО ПОСТРОИТЬ"
		%BuildButton.text = "Построить · %d мон." % price
		var why := Game.build_problem(id)
		%BuildButton.disabled = why != ""
		%BuildButton.tooltip_text = why
