extends Control
## Дом гильдии (scenes/village/HomeView.tscn): хроника, следующее поручение, отряд, награда на выбор, запасы.

const HERO_TILE := preload("res://scenes/ui/HeroTile.tscn")
const REWARD_CARD := preload("res://scenes/ui/RewardCard.tscn")
const PILL := preload("res://scenes/ui/ResourcePill.tscn")

var village

func _ready() -> void:
	%BoardButton.pressed.connect(func(): village.show_tab("board"))
	%TakeQueueButton.pressed.connect(func():
		Game.notify("Забрано предметов: %d" % Game.take_queue())
		refresh())
	refresh()

func refresh() -> void:
	var st: int = int(Game.state["story_stage"])
	%ChronicleCaption.text = "ХРОНИКА · ГЛАВА %d/%d" % [st, DB.STORY_ORDER.size()]
	%Chronicle.text = village.STORY_TEXT[clamp(st, 0, village.STORY_TEXT.size() - 1)]
	%ChapterDone.visible = Game.state.get("chapter_done", false)
	_fill_next()
	# Отряд
	UIK.clear(%Squad)
	for id in DB.HERO_IDS:
		var tile: HeroTile = HERO_TILE.instantiate()
		%Squad.add_child(tile)
		tile.setup(id)
		var hid: String = id
		tile.pressed.connect(func(): village.show_hero(hid))
	# Награда на выбор
	var pc: Array = Game.state["pending_choice"]
	%RewardPanel.visible = pc.size() > 0
	UIK.clear(%PendingCards)
	for i in pc.size():
		var card: PanelContainer = REWARD_CARD.instantiate()
		%PendingCards.add_child(card)
		var it: Dictionary = pc[i]
		card.get_node("%Slot").item = it
		card.get_node("%Name").text = Items.display_name(it)
		card.get_node("%Name").add_theme_color_override("font_color", Items.rarity_color(it))
		card.get_node("%Type").text = "%s · ур. %d" % [Items.type_label(it), int(it["ilvl"])]
		# Название, уровень и тип уже в шапке карточки — в описании только характеристики
		card.get_node("%Info").text = Items.tooltip_bb(it, "", 1, "", 3)
		var idx := i
		card.get_node("%ChooseButton").pressed.connect(func():
			Game.choose_pending(idx)
			refresh())
	# Запасы
	UIK.clear(%Supplies)
	for id in ["potion_hp", "potion_mp", "kit"]:
		_pill("cons", id, str(int(Game.state["potions"].get(id, 0))), DB.consumable_name(id))
	_pill("storage", "", "%d/%d" % [Game.storage_count(), DB.STORAGE_SIZE], "Кладовая")
	_pill("backpack", "", "%d/%d" % [Game.backpack_count(), DB.BACKPACK_CAP], "Походный рюкзак: подарки для вечера на привале")
	for g in Game.state["backpack"].keys():
		_pill("cons", g, "×%d" % int(Game.state["backpack"][g]), DB.consumable_name(g))
	var q: Array = Game.state["queue"]
	%QueueBox.visible = q.size() > 0
	%QueueLabel.text = "Очередь выдачи: %d" % q.size()

func _pill(kind: String, cons: String, val: String, tip: String) -> void:
	var p: ResourcePill = PILL.instantiate()
	p.icon_kind = kind
	p.cons_id = cons
	p.value_width = 0.0
	p.tooltip_text = tip
	%Supplies.add_child(p)
	p.set_value(val)

func _fill_next() -> void:
	var next := ""
	for cid in DB.STORY_ORDER:
		if Game.contract_available(cid) and Game.contract_done_count(cid) == 0:
			next = cid
			break
	if next == "" and Game.contract_available("s1") and Game.contract_done_count("s1") == 0:
		next = "s1"
	if next == "":
		%NextCaption.text = "ДОСКА ПОРУЧЕНИЙ"
		%NextName.text = "Все поручения выполнены"
		%NextInfo.text = "Можно браться за повторы"
		return
	var c: Dictionary = DB.CONTRACTS[next]
	%NextCaption.text = "СЛЕДУЮЩЕЕ ПОРУЧЕНИЕ"
	%NextName.text = c["name"]
	%NextInfo.text = "Уровень %d · оплата %d мон." % [int(c["level"]), int(c["pay"])]
