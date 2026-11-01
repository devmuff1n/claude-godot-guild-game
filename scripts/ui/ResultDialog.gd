class_name ResultDialog
extends Control
## Итоги похода (scenes/ui/ResultDialog.tscn): ведомость, деньги в казну, добыча, рост отряда.

signal closed

const LEDGER_ROW := preload("res://scenes/ui/LedgerRow.tscn")
const LOOT_CARD := preload("res://scenes/ui/LootCard.tscn")
const GROWTH_CHIP := preload("res://scenes/ui/GrowthChip.tscn")
const SUMMARY_ROW := preload("res://scenes/ui/HeroSummaryRow.tscn")
const UNLOCK_CHIP := preload("res://scenes/ui/UnlockChip.tscn")
const UNLOCK_ICON := {"perks": "perk", "skills": "sword", "contract": "board", "social": "friend"}
const KIND_CAPTION := {"victory": "ПОРУЧЕНИЕ ВЫПОЛНЕНО", "defeat": "ПОРАЖЕНИЕ", "abandon": "ПОХОД ПРЕРВАН"}

func _ready() -> void:
	%ContinueButton.pressed.connect(func(): closed.emit())

func setup(res: Dictionary) -> ResultDialog:
	var kind: String = res["kind"]
	%Kind.text = KIND_CAPTION.get(kind, "")
	%Kind.add_theme_color_override("font_color", UIK.GOLD if kind == "victory" else UIK.RED)
	%Title.text = res["name"]
	%Outro.visible = res.get("outro", "") != ""
	%Outro.text = "«%s»" % res.get("outro", "")
	# Ведомость
	UIK.clear(%Ledger)
	for l in res["lines"]:
		_ledger(str(l))
	# Деньги
	var coins := int(res.get("coins", 0))
	var purse := int(res.get("purse_return", 0))
	%Total.text = "+%d" % (coins + purse)
	%TotalNote.text = "награды %d · кошелёк %d" % [coins, purse] if kind == "victory" else "возврат кошелька"
	%MoneyBox.visible = coins + purse > 0
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
	# Добыча
	UIK.clear(%Loot)
	%LootBox.visible = res["items"].size() > 0
	%LootBox.get_node("Caption").text = "УТЕШИТЕЛЬНЫЙ ПРИЗ" if res.get("consolation", false) else "ДОБЫЧА"
	for it in res["items"]:
		var card: PanelContainer = LOOT_CARD.instantiate()
		%Loot.add_child(card)
		card.get_node("%Slot").item = it
		var nm: Label = card.get_node("%Name")
		nm.text = Items.display_name(it)
		nm.add_theme_color_override("font_color", Items.rarity_color(it))
	%ChoiceNote.visible = res.get("choice", false)
	# Рост отряда
	UIK.clear(%Growth)
	var by_hero := {}
	for lu in res["levels"]:
		by_hero[lu["hero"]] = {"lu": lu}
	for j in res["jobs"]:
		if not by_hero.has(j[0]):
			by_hero[j[0]] = {}
		by_hero[j[0]]["job"] = j[1]
	%GrowthBox.visible = not by_hero.is_empty()
	for hid in DB.HERO_IDS:
		if not by_hero.has(hid):
			continue
		var g: Dictionary = by_hero[hid]
		var chip: PanelContainer = GROWTH_CHIP.instantiate()
		%Growth.add_child(chip)
		chip.get_node("%Portrait").texture = UIK.portrait(hid)
		chip.get_node("%Name").text = DB.hero_name(hid)
		var lv: Label = chip.get_node("%Level")
		var jb: Label = chip.get_node("%Job")
		lv.visible = g.has("lu")
		if g.has("lu"):
			lv.text = "Уровень %d → %d" % [g["lu"]["from"], g["lu"]["to"]]
			if g["lu"]["abilities"].size() > 0:
				chip.tooltip_text = "Новые умения: " + ", ".join(g["lu"]["abilities"])
				lv.text += "  ✦"
		jb.visible = g.has("job")
		if g.has("job"):
			jb.text = "Job %d · очко перка" % int(g["job"])
	# Новинки: что открылось после поручения и что ждёт в следующем
	UIK.clear(%Unlocks)
	UIK.clear(%Next)
	for u in res.get("unlocks", []):
		_news_chip(%Unlocks, UNLOCK_ICON.get(u["kind"], "diamond"), u["title"], u["tip"], true)
	for t in res.get("next", []):
		_news_chip(%Next, t.get("icon", "event"), t["title"], t["tip"], false)
	%UnlockRow.visible = %Unlocks.get_child_count() > 0
	%NextRow.visible = %Next.get_child_count() > 0
	%NewsBox.visible = %UnlockRow.visible or %NextRow.visible
	return self

func _news_chip(parent: Control, icon: String, text: String, tip: String, gold: bool) -> void:
	var chip: PanelContainer = UNLOCK_CHIP.instantiate()
	parent.add_child(chip)
	chip.get_node("%Icon").kind = icon
	var l: Label = chip.get_node("%Text")
	l.text = text
	if not gold:
		l.theme_type_variation = &"ValueLabel"
	chip.tooltip_text = tip

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
