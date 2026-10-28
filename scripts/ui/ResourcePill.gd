@tool
class_name ResourcePill
extends PanelContainer
## Значок ресурса (scenes/ui/ResourcePill.tscn): иконка + число фиксированной ширины.
## Подробности — во всплывающей подсказке.

@export var icon_kind: String = "coin":
	set(v):
		icon_kind = v
		if is_node_ready():
			%Icon.kind = v
@export var cons_id: String = "":
	set(v):
		cons_id = v
		if is_node_ready():
			%Icon.cons_id = v
## Минимальная ширина числа — чтобы соседние элементы не сдвигались при смене значения
@export var value_width: float = 40.0:
	set(v):
		value_width = v
		if is_node_ready():
			%Value.custom_minimum_size.x = v

func _ready() -> void:
	%Icon.kind = icon_kind
	%Icon.cons_id = cons_id
	%Value.custom_minimum_size.x = value_width

func set_value(text: String, color := Color(0, 0, 0, 0)) -> void:
	%Value.text = text
	if color.a > 0.0:
		%Value.add_theme_color_override("font_color", color)
	else:
		%Value.remove_theme_color_override("font_color")
