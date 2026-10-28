class_name ItemTooltip
extends PanelContainer
## Подсказка предмета в духе WoW Classic (scenes/ui/ItemTooltip.tscn): название цветом качества,
## слот и тип в одну строку по краям, белые характеристики, зелёные «Если на персонаже», красные запреты.
## Строки берутся из Items.tooltip_lines, каждая — из шаблона ItemTooltipLine.tscn.

const LINE := preload("res://scenes/ui/ItemTooltipLine.tscn")
const WRAP_W := 300.0

func _enter_tree() -> void:
	# Всплывающее окно подсказки рисует свою рамку из темы — у предмета рамка своя, поэтому прячем внешнюю
	var p := get_parent()
	if p is PopupPanel:
		p.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

func show_item(item: Dictionary, hero_id: String = "", level: int = 1, note: String = "") -> Control:
	UIK.clear(%Lines)
	for r in Items.tooltip_lines(item, hero_id, level, note):
		var row: HBoxContainer = LINE.instantiate()
		%Lines.add_child(row)
		var l: Label = row.get_node("%Left")
		var rt: Label = row.get_node("%Right")
		l.text = r["l"]
		l.add_theme_color_override("font_color", r["lc"])
		rt.text = r["r"]
		rt.visible = r["r"] != ""
		rt.add_theme_color_override("font_color", r["rc"])
		# Длинные строки («Если на персонаже: …») переносятся по ширине подсказки, как в WoW
		if r["r"] == "" and l.get_theme_font("font").get_string_size(r["l"], HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x > WRAP_W:
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size.x = WRAP_W
		match r["kind"]:
			"title":
				l.theme_type_variation = &"TooltipTitle"
			"money":
				# «Цена продажи: 12 ●» — сумма с монеткой сразу за подписью, как в WoW
				l.size_flags_horizontal = Control.SIZE_FILL
				row.get_node("%Coin").visible = true
	return self
