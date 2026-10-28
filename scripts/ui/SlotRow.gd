class_name SlotRow
extends PanelContainer
## Карточка слота сохранения (scenes/ui/SlotRow.tscn).

func setup(i: int, info: Dictionary, screen) -> void:
	var empty: bool = info.is_empty() or info.get("broken", false)
	%Caption.text = "СЛОТ %d" % (i + 1)
	if info.is_empty():
		%Title.text = "Пусто"
		%Sub.text = ""
		%Date.text = ""
	elif info.get("broken", false):
		%Title.text = "Сохранение повреждено"
		%Sub.text = ""
		%Date.text = ""
	else:
		var lv := []
		for x in info["levels"]:
			lv.append(str(x))
		%Title.text = ("В походе: «%s»" % info.get("exp_name", "")) if info["exp"] else ("Глава %d из 7" % int(info["story"]))
		%Sub.text = "Казна %d мон. · уровни %s" % [int(info["treasury"]), "/".join(lv)]
		%Date.text = str(info["saved"]).replace("T", " ").substr(0, 16)
	%Title.add_theme_color_override("font_color", UIK.MUTED if empty else UIK.INK)
	theme_type_variation = &"PanelInsetLocked" if empty else &"PanelInset"
	%NewButton.visible = empty
	%ContinueButton.visible = not empty
	%DeleteButton.visible = not empty
	%DeleteButton.text = "Точно?" if screen.confirm_del == i else "✕"
	%DeleteButton.tooltip_text = "Удалить сохранение"
	%NewButton.pressed.connect(func(): screen.new_game(i))
	%ContinueButton.pressed.connect(func(): screen.load_game(i))
	%DeleteButton.pressed.connect(func(): screen.ask_delete(i))
