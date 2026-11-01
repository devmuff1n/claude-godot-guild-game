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
	# Награда занимает место отряда, пока не выбрана: колонка не растёт и не вылезает за экран
	%RewardPanel.visible = pc.size() > 0
	$Columns/Right/SquadPanel.visible = pc.is_empty()
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
		card.get_node("%Info").text = Items.tooltip_bb(it, "", 1, "", 3) + _context_bb(it, card.get_node("%Slot"))
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
	# Строка очереди всегда занимает место (иначе панель запасов меняет высоту)
	%QueueBox.modulate.a = 1.0 if q.size() > 0 else 0.0
	%TakeQueueButton.disabled = q.is_empty()
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
	if next == "":
		%NextCaption.text = "ДОСКА ПОРУЧЕНИЙ"
		%NextName.text = "Все поручения выполнены"
		%NextInfo.text = "Можно браться за повторы"
		return
	var c: Dictionary = DB.CONTRACTS[next]
	%NextCaption.text = "СЛЕДУЮЩЕЕ ПОРУЧЕНИЕ"
	%NextName.text = c["name"]
	%NextInfo.text = "Уровень %d · оплата %d мон." % [int(c["level"]), int(c["pay"])]

## Кому поможет награда (как в Hades): герой, которому вещь даёт больший прирост, и что изменится против надетого.
## Слоту карточки назначается этот герой — подсказка покажет сравнение с надетым.
func _context_bb(it: Dictionary, slot: ItemSlot) -> String:
	var best_h := ""
	var best := {"slot": "", "gain": -INF}
	for h in DB.HERO_IDS:
		if not Items.hero_can_use_type(h, it):
			continue
		var g := Game.upgrade_gain(h, it)
		if g["slot"] != "" and float(g["gain"]) > float(best["gain"]):
			best = g
			best_h = h
	if best_h == "":
		return ""
	slot.tip_hero = best_h
	var old = Game.hero(best_h)["equip"].get(best["slot"])
	var head := "\n\n[color=#%s]%s[/color] · %s" % [UIK.GOLD_HI.to_html(false), DB.hero_name(best_h), ("вместо «%s»" % Items.display_name(old)) if old != null else "пустой слот"]
	var rows: Array = Items.compare_rows(it, old) if old != null else []
	var out := [head]
	for i in mini(rows.size(), 4):
		out.append(Items._bb_row(rows[i]))
	return "\n".join(out)
