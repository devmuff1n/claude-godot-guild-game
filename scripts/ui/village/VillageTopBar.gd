class_name VillageTopBar
extends PanelContainer
## Верхняя панель деревни (scenes/village/VillageTopBar.tscn): гильдия, вкладки, ресурсы, меню.

signal tab_selected(id: String)
signal menu_pressed

@onready var tabs := {"town": %NavTown, "home": %NavHome, "board": %NavBoard, "shop": %NavShop, "party": %NavParty, "arena": %NavArena, "build": %NavBuild, "forge": %NavForge}

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
	# Вкладки появляются по мере открытия возможностей (DB.FEATURES); «Поселение» и «Поручения» есть всегда
	for k in tabs.keys():
		tabs[k].visible = Game.feature_open(k)
	# Метки «есть что сделать» или «новое» на вкладках
	%HomeBadge.visible = Game.state["pending_choice"].size() > 0 or Game.state["queue"].size() > 0 or Game.feature_new("home")
	var pts := 0
	for id in DB.HERO_IDS:
		pts += Game.perk_points(id)
	%PartyBadge.visible = pts > 0 or Game.feature_new("party")
	%ShopBadge.visible = Game.feature_new("shop")
	%ForgeBadge.visible = Game.feature_new("forge")
	%ArenaBadge.visible = Game.feature_new("arena")
	%BuildBadge.visible = Game.feature_new("build") or Game.buildable_count() > 0
