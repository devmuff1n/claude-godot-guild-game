class_name VillageTopBar
extends PanelContainer
## Верхняя панель деревни (scenes/village/VillageTopBar.tscn): гильдия, вкладки, ресурсы, меню.

signal tab_selected(id: String)
signal menu_pressed

@onready var tabs := {"town": %NavTown, "home": %NavHome, "board": %NavBoard, "shop": %NavShop, "party": %NavParty, "arena": %NavArena}

func _ready() -> void:
	for k in tabs.keys():
		var id: String = k
		tabs[k].pressed.connect(func(): tab_selected.emit(id))
	%MenuButton.pressed.connect(func(): menu_pressed.emit())
	Game.changed.connect(refresh)
	refresh()

func set_tab(id: String) -> void:
	for k in tabs.keys():
		UIK.mark(tabs[k], k == id)

func refresh() -> void:
	if not is_inside_tree() or Game.state.is_empty():
		return
	var tr := int(Game.state["treasury"])
	%Treasury.set_value(str(tr))
	var disc := int(round(Game.discount() * 100.0))
	%Trust.set_value(str(int(Game.state["trust"])))
	%Trust.tooltip_text = "Доверие деревни" + ("\nСкидка в лавке: %d%%" % disc if disc > 0 else "")
	%Chapter.set_value("%d/%d" % [int(Game.state["story_stage"]), DB.STORY_ORDER.size()])
	# Метки «есть что сделать» на вкладках
	%HomeBadge.visible = Game.state["pending_choice"].size() > 0 or Game.state["queue"].size() > 0
	var pts := 0
	for id in DB.HERO_IDS:
		pts += Game.perk_points(id)
	%PartyBadge.visible = pts > 0
