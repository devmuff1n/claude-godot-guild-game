class_name ResultDialog
extends Control
## Итоги похода по шагам (scenes/ui/ResultDialog.tscn):
## 1) герои — рост уровней, значения «щёлкают» вверх; 2) добыча — деньги и вещи по одной;
## 3) награда на выбор — одна вещь из трёх прямо здесь; 4) итоги — что открылось, ведомость, урон по героям.
## Пустые шаги пропускаются. «Далее» во время анимации сначала досматривает её.

signal closed

const LEDGER_ROW := preload("res://scenes/ui/LedgerRow.tscn")
const LOOT_CARD := preload("res://scenes/ui/LootCard.tscn")
const GROWTH_CHIP := preload("res://scenes/ui/GrowthChip.tscn")
const SUMMARY_ROW := preload("res://scenes/ui/HeroSummaryRow.tscn")
const UNLOCK_CHIP := preload("res://scenes/ui/UnlockChip.tscn")
const LEVEL_CARD := preload("res://scenes/ui/LevelUpCard.tscn")
const LEVEL_ROW := preload("res://scenes/ui/LevelUpRow.tscn")
const REWARD_CARD := preload("res://scenes/ui/RewardCard.tscn")
const UNLOCK_ICON := {"perks": "perk", "skills": "sword", "contract": "board", "social": "friend"}
const KIND_CAPTION := {"victory": "ПОРУЧЕНИЕ ВЫПОЛНЕНО", "defeat": "ПОРАЖЕНИЕ", "abandon": "ПОХОД ПРЕРВАН", "choice": "НАГРАДА"}
## [ключ, подпись, подсказка] — строки карточки роста уровня
const LEVEL_ROWS := [
	["max_hp", "ОЗ", "Здоровье"], ["max_mp", "МП", "Мана"], ["dmg", "Урон", "Урон автоатаки"],
	["armor", "Броня", "Броня"], ["sp", "Сила закл.", "Сила заклинаний"],
	["sta", "Выносл.", "Выносливость"], ["str", "Сила", ""], ["agi", "Ловкость", ""], ["int", "Интеллект", ""],
]
const TICK := 0.09

var res: Dictionary = {}
var pages: Array[String] = []
var page := -1
var picked := -1
var _tween: Tween

@onready var _page_nodes := {"heroes": %PageHeroes, "loot": %PageLoot, "choice": %PageChoice, "summary": %PageSummary}
@onready var _step_labels := {"heroes": %Steps.get_node("StepHeroes"), "loot": %Steps.get_node("StepLoot"),
	"choice": %Steps.get_node("StepChoice"), "summary": %Steps.get_node("StepSummary")}

func _ready() -> void:
	%ContinueButton.pressed.connect(_on_continue)

func setup(r: Dictionary) -> ResultDialog:
	res = r
	var kind: String = res.get("kind", "victory")
	%Kind.text = KIND_CAPTION.get(kind, "")
	%Kind.add_theme_color_override("font_color", UIK.GOLD if kind in ["victory", "choice"] else UIK.RED)
	%Title.text = res.get("name", "")
	pages = []
	if kind != "abandon" and kind != "choice" and (not res.get("levels", []).is_empty() or not res.get("jobs", []).is_empty() or kind == "victory"):
		pages.append("heroes")
	if res.get("items", []).size() > 0 or int(res.get("coins", 0)) + int(res.get("purse_return", 0)) > 0:
		pages.append("loot")
	if not Game.state["pending_choice"].is_empty() and (res.get("choice", false) or kind == "choice"):
		pages.append("choice")
	if kind != "choice":
		pages.append("summary")
	for k in _step_labels.keys():
		_step_labels[k].visible = k in pages
	var n := 1
	for k in ["heroes", "loot", "choice", "summary"]:
		if k in pages:
			_step_labels[k].text = "%d · %s" % [n, {"heroes": "ГЕРОИ", "loot": "ДОБЫЧА", "choice": "НАГРАДА НА ВЫБОР", "summary": "ИТОГИ"}[k]]
			n += 1
	%Steps.visible = pages.size() > 1
	_goto(0)
	return self

## Только выбор награды (если игру закрыли до выбора — при входе в деревню)
func setup_choice() -> ResultDialog:
	return setup({"kind": "choice", "name": "Награда на выбор", "choice": true})

func _goto(i: int) -> void:
	page = i
	var id: String = pages[i]
	for k in _page_nodes.keys():
		_page_nodes[k].visible = k == id
	for k in _step_labels.keys():
		var l: Label = _step_labels[k]
		var cur: bool = k == id
		var done: bool = pages.find(k) < i
		l.add_theme_color_override("font_color", UIK.GOLD_HI if cur else (UIK.GOLD if done else UIK.MUTED))
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(0.05)
	match id:
		"heroes":
			_fill_heroes()
		"loot":
			_fill_loot()
		"choice":
			_fill_choice()
		"summary":
			_fill_summary()
	# Страница плавно проявляется
	var pn: Control = _page_nodes[id]
	pn.modulate.a = 0.0
	create_tween().tween_property(pn, "modulate:a", 1.0, 0.25)
	_update_button()

func _update_button() -> void:
	var last := page >= pages.size() - 1
	%ContinueButton.text = "Готово" if last else "Далее"
	var need_pick: bool = pages[page] == "choice" and picked < 0
	%ContinueButton.disabled = need_pick
	%ContinueButton.tooltip_text = "Сначала выберите одну вещь" if need_pick else ""

func _on_continue() -> void:
	if _tween != null and _tween.is_running():
		_tween.custom_step(999.0)
		return
	if pages[page] == "choice" and picked < 0:
		return
	if page < pages.size() - 1:
		_goto(page + 1)
	else:
		closed.emit()

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		get_viewport().set_input_as_handled()
		if not %ContinueButton.disabled:
			_on_continue()

# ================================================================ 1. Герои
func _fill_heroes() -> void:
	UIK.clear(%Cards)
	UIK.clear(%Growth)
	var ups: Array = res.get("levels", []).filter(func(lu): return lu.has("before"))
	%Caption.text = "Новый уровень!" if not ups.is_empty() else "Опыт отряда"
	var delay := 0.3
	for lu in ups:
		delay = _level_card(lu, delay) + 0.15
	var jobs := {}
	for j in res.get("jobs", []):
		jobs[j[0]] = j[1]
	for hid in DB.HERO_IDS:
		var h := Game.hero(hid)
		var chip: PanelContainer = GROWTH_CHIP.instantiate()
		%Growth.add_child(chip)
		chip.get_node("%Portrait").texture = UIK.portrait(hid)
		chip.get_node("%Name").text = DB.hero_name(hid)
		var lv: Label = chip.get_node("%Level")
		var lvl := int(h["level"])
		lv.text = "Ур. %d · опыт %d/%d" % [lvl, int(h["xp"]), DB.xp_to_next(lvl)] if lvl < DB.MAX_LEVEL else "Ур. %d · максимум" % lvl
		var jb: Label = chip.get_node("%Job")
		jb.visible = jobs.has(hid)
		if jobs.has(hid):
			jb.text = "Job %d · очко перка" % int(jobs[hid])
	if ups.is_empty():
		%Cards.visible = false
	else:
		%Cards.visible = true

## Карточка героя с новым уровнем: строки «было → стало», выросшие значения по очереди «щёлкают».
## Возвращает задержку, на которой закончилась анимация карточки.
func _level_card(lu: Dictionary, delay: float) -> float:
	var card: PanelContainer = LEVEL_CARD.instantiate()
	%Cards.add_child(card)
	var hid: String = lu["hero"]
	card.get_node("%Portrait").texture = UIK.portrait(hid)
	card.get_node("%Name").text = DB.hero_name(hid)
	card.get_node("%Level").text = "Уровень %d → %d" % [int(lu["from"]), int(lu["to"])]
	var sk: Label = card.get_node("%Skills")
	sk.visible = lu["abilities"].size() > 0
	sk.text = "Новое умение: " + ", ".join(lu["abilities"])
	var b: Dictionary = lu["before"]
	var a: Dictionary = lu["after"]
	for r in LEVEL_ROWS:
		var row: HBoxContainer = LEVEL_ROW.instantiate()
		card.get_node("%Rows").add_child(row)
		row.get_node("%Name").text = r[1]
		row.tooltip_text = r[2]
		var old := _val(b, r[0])
		var new := _val(a, r[0])
		row.get_node("%Old").text = _fmt(b, r[0])
		var nl: Label = row.get_node("%New")
		var dl: Label = row.get_node("%Delta")
		nl.text = _fmt(b, r[0])
		dl.text = "+%d" % int(round(new - old))
		dl.modulate.a = 0.0
		if new <= old:
			row.modulate = Color(1, 1, 1, 0.5)
			dl.text = ""
			continue
		var key: String = r[0]
		_tween.parallel().tween_callback(func():
			nl.text = _fmt(a, key)
			nl.add_theme_color_override("font_color", UIK.GOLD_HI)
			dl.modulate.a = 1.0
			nl.pivot_offset = nl.size * 0.5
			var tw := nl.create_tween()
			tw.tween_property(nl, "scale", Vector2(1.25, 1.25), 0.06)
			tw.tween_property(nl, "scale", Vector2.ONE, 0.1)).set_delay(delay)
		delay += TICK
	return delay

func _val(d: Dictionary, k: String) -> float:
	if k == "dmg":
		return (float(d["dmg_min"]) + float(d["dmg_max"])) * 0.5
	return float(d.get(k, 0))

func _fmt(d: Dictionary, k: String) -> String:
	if k == "dmg":
		return "%d–%d" % [int(d["dmg_min"]), int(d["dmg_max"])]
	return "%d" % int(d.get(k, 0))

# ================================================================ 2. Добыча
func _fill_loot() -> void:
	var kind: String = res.get("kind", "victory")
	var coins := int(res.get("coins", 0))
	var purse := int(res.get("purse_return", 0))
	%MoneyBox.visible = coins + purse > 0
	%TotalNote.text = "награды %d · кошелёк %d" % [coins, purse] if kind == "victory" else "возврат кошелька"
	# Сумма набегает от нуля
	%Total.text = "+0"
	var total := coins + purse
	_tween.parallel().tween_method(func(v: float): %Total.text = "+%d" % int(v), 0.0, float(total), 0.6).set_delay(0.1)
	%LootCaption.text = "УТЕШИТЕЛЬНЫЙ ПРИЗ" if res.get("consolation", false) else "ДОБЫЧА"
	%LootCaption.visible = res.get("items", []).size() > 0
	UIK.clear(%Loot)
	var delay := 0.5
	for it in res.get("items", []):
		var card: PanelContainer = LOOT_CARD.instantiate()
		%Loot.add_child(card)
		card.get_node("%Slot").item = it
		var nm: Label = card.get_node("%Name")
		nm.text = Items.display_name(it)
		nm.add_theme_color_override("font_color", Items.rarity_color(it))
		# Вещи выкладываются по одной
		card.modulate.a = 0.0
		_tween.parallel().tween_property(card, "modulate:a", 1.0, 0.2).set_delay(delay)
		delay += 0.35

# ================================================================ 3. Награда на выбор
func _fill_choice() -> void:
	UIK.clear(%ChoiceCards)
	picked = -1
	var pc: Array = Game.state["pending_choice"]
	var delay := 0.1
	for i in pc.size():
		var card: RewardCard = REWARD_CARD.instantiate()
		%ChoiceCards.add_child(card)
		card.custom_minimum_size = Vector2(360, 0)
		card.setup(pc[i])
		var idx := i
		card.chosen.connect(func(): _pick(idx))
		card.modulate.a = 0.0
		_tween.parallel().tween_property(card, "modulate:a", 1.0, 0.25).set_delay(delay)
		delay += 0.2

func _pick(idx: int) -> void:
	if picked >= 0:
		return
	picked = idx
	var cards := %ChoiceCards.get_children()
	for i in cards.size():
		(cards[i] as RewardCard).mark(i == idx)
	Game.choose_pending(idx)
	_update_button()

# ================================================================ 4. Итоги
func _fill_summary() -> void:
	%Outro.visible = res.get("outro", "") != ""
	%Outro.text = "«%s»" % res.get("outro", "")
	UIK.clear(%Ledger)
	for l in res.get("lines", []):
		_ledger(str(l))
	# Итоги по героям (как в Details!): урон, лечение, поглощено, прерывания; лучший в столбце — золотом
	UIK.clear(%SummaryRows)
	var bh: Dictionary = res.get("by_hero", {})
	%SummaryBox.visible = not bh.is_empty()
	if not bh.is_empty():
		var head: HBoxContainer = SUMMARY_ROW.instantiate()
		%SummaryRows.add_child(head)
		head.get_node("%Name").text = ""
		for f in [["Dmg", "Урон"], ["Heal", "Лечение"], ["Absorbed", "Поглощено"], ["Int", "Прервано"]]:
			var l: Label = head.get_node("%" + f[0])
			l.text = f[1]
			l.theme_type_variation = &"CaptionLabel"
		var best := {}
		for f in ["dmg", "heal", "absorbed", "int"]:
			var m := 0
			for hid in bh.keys():
				m = maxi(m, int(bh[hid].get(f, 0)))
			best[f] = m
		for hid in DB.HERO_IDS:
			var v: Dictionary = bh.get(hid, {})
			var row: HBoxContainer = SUMMARY_ROW.instantiate()
			%SummaryRows.add_child(row)
			row.get_node("%Portrait").texture = UIK.portrait(hid)
			row.get_node("%Name").text = DB.hero_name(hid)
			for f in [["Dmg", "dmg"], ["Heal", "heal"], ["Absorbed", "absorbed"], ["Int", "int"]]:
				var l2: Label = row.get_node("%" + f[0])
				var val := int(v.get(f[1], 0))
				l2.text = str(val) if val > 0 else "—"
				if val > 0 and val == int(best[f[1]]):
					l2.add_theme_color_override("font_color", UIK.GOLD_HI)
	# Новинки: что открылось после поручения и что ждёт в следующем
	UIK.clear(%Unlocks)
	UIK.clear(%Next)
	var delay := 0.2
	for u in res.get("unlocks", []):
		var chip := _news_chip(%Unlocks, u.get("icon", UNLOCK_ICON.get(u["kind"], "diamond")), u["title"], u["tip"], true)
		chip.modulate.a = 0.0
		_tween.parallel().tween_property(chip, "modulate:a", 1.0, 0.2).set_delay(delay)
		delay += 0.15
	for t in res.get("next", []):
		_news_chip(%Next, t.get("icon", "event"), t["title"], t["tip"], false)
	%UnlockRow.visible = %Unlocks.get_child_count() > 0
	%NextRow.visible = %Next.get_child_count() > 0
	%NewsBox.visible = %UnlockRow.visible or %NextRow.visible

func _news_chip(parent: Control, icon: String, text: String, tip: String, gold: bool) -> PanelContainer:
	var chip: PanelContainer = UNLOCK_CHIP.instantiate()
	parent.add_child(chip)
	chip.get_node("%Icon").kind = icon
	var l: Label = chip.get_node("%Text")
	l.text = text
	if not gold:
		l.theme_type_variation = &"ValueLabel"
	chip.tooltip_text = tip
	return chip

## Строка ведомости: «Название: значение» → значение выравнивается вправо
func _ledger(line: String) -> void:
	var row: HBoxContainer = LEDGER_ROW.instantiate()
	%Ledger.add_child(row)
	var name_l: Label = row.get_node("%Name")
	var val_l: Label = row.get_node("%Value")
	var cut := line.rfind(": ")
	var right := line.substr(cut + 2) if cut > 0 else ""
	if right.ends_with(".") and not right.ends_with("мон."):
		right = right.trim_suffix(".")
	if cut > 0 and right.length() <= 28:
		name_l.text = line.substr(0, cut)
		val_l.text = right
	else:
		name_l.text = line
		val_l.text = ""
	var lost := "урезан" in line or "упущена" in line or "не выполнено" in line or "не возвращается" in line or "Наград за победу нет" in line
	if lost:
		name_l.add_theme_color_override("font_color", UIK.MUTED)
	if right.begins_with("+"):
		val_l.add_theme_color_override("font_color", UIK.GOLD_HI)
