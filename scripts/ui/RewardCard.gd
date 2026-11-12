class_name RewardCard
extends PanelContainer
## Карточка награды на выбор (scenes/ui/RewardCard.tscn): вещь, её свойства и кому она поможет больше всего.

signal chosen

var recommended_hero := ""

func _ready() -> void:
	%ChooseButton.pressed.connect(func(): chosen.emit())

func setup(it: Dictionary) -> RewardCard:
	%Slot.item = it
	%Name.text = Items.display_name(it)
	%Name.add_theme_color_override("font_color", Items.rarity_color(it))
	%Type.text = "%s · ур. %d" % [Items.type_label(it), int(it["ilvl"])]
	# Название, уровень и тип уже в шапке карточки — в описании только характеристики
	%Info.text = Items.tooltip_bb(it, "", 1, "", 3) + _context_bb(it)
	return self

## Отметить выбор: выбранная карточка остаётся яркой, остальные гаснут
func mark(picked: bool) -> void:
	%ChooseButton.disabled = true
	%ChooseButton.text = "Взято" if picked else "—"
	modulate = Color(1, 1, 1, 1) if picked else Color(1, 1, 1, 0.4)
	UIK.mark(%ChooseButton, picked)

## Кому поможет награда (как в Hades): герой, которому вещь даёт больший прирост, и что изменится против надетого.
## Слоту карточки назначается этот герой — подсказка покажет сравнение с надетым.
func _context_bb(it: Dictionary) -> String:
	var best_h := ""
	var best := {"slot": "", "gain": -INF}
	for h in DB.HERO_IDS:
		if not Items.hero_can_use_type(h, it):
			continue
		var g := Game.upgrade_gain(h, it)
		if g["slot"] != "" and float(g["gain"]) > float(best["gain"]):
			best = g
			best_h = h
	recommended_hero = best_h
	(%Slot as ItemSlot).tip_hero = best_h
	if best_h == "":
		return ""
	var old = Game.hero(best_h)["equip"].get(best["slot"])
	var head := "\n\n[color=#%s]%s[/color] · %s" % [UIK.GOLD_HI.to_html(false), DB.hero_name(best_h), ("вместо «%s»" % Items.display_name(old)) if old != null else "пустой слот"]
	var rows: Array = Items.compare_rows(it, old) if old != null else []
	var out := [head]
	for i in mini(rows.size(), 4):
		out.append(Items._bb_row(rows[i]))
	return "\n".join(out)
