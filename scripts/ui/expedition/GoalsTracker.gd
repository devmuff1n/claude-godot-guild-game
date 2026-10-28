class_name GoalsTracker
extends PanelContainer
## Трекер целей похода (scenes/expedition/GoalsTracker.tscn): премия, общее и личное поручения.
## Строки создаются один раз и потом только обновляются — панель не перестраивается и не дёргается.

const GOAL_ROW := preload("res://scenes/expedition/GoalRow.tscn")

var _sig := ""

## rows: [[текст, состояние(1/0/-1), подсказка], ...]
func set_rows(rows: Array) -> void:
	var sig := str(rows)
	if sig == _sig:
		return
	_sig = sig
	var box: VBoxContainer = %Rows
	while box.get_child_count() < rows.size():
		box.add_child(GOAL_ROW.instantiate())
	while box.get_child_count() > rows.size():
		var c := box.get_child(box.get_child_count() - 1)
		box.remove_child(c)
		c.queue_free()
	for i in rows.size():
		var row: HBoxContainer = box.get_child(i)
		var r: Array = rows[i]
		var lbl: Label = row.get_node("%Text")
		var mark: UiIcon = row.get_node("%Mark")
		lbl.text = r[0]
		row.tooltip_text = r[2]
		match int(r[1]):
			1:
				mark.kind = "check"
				lbl.add_theme_color_override("font_color", UIK.GREEN)
			-1:
				mark.kind = "cross"
				lbl.add_theme_color_override("font_color", UIK.RED)
			_:
				mark.kind = "dot"
				lbl.remove_theme_color_override("font_color")
