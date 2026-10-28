class_name ConfirmDialog
extends Control
## Короткое окно с вопросом и кнопками (scenes/ui/ConfirmDialog.tscn): прервать поход, поражение, итог арены.
## Кнопки задаются списком; выбранная приходит сигналом chosen(index).

signal chosen(index: int)

const CHOICE := preload("res://scenes/ui/ChoiceButton.tscn")
const LEDGER := preload("res://scenes/ui/LedgerRow.tscn")

## bullets — строки «Название: значение» или просто текст; buttons — [[текст, главная?], ...]
func setup(caption: String, title: String, text: String, bullets: Array, buttons: Array, dim := true) -> ConfirmDialog:
	%Dim.visible = dim
	%Caption.text = caption
	%Caption.visible = caption != ""
	%Title.text = title
	%Body.text = text
	%Body.visible = text != ""
	UIK.clear(%Bullets)
	%Bullets.visible = not bullets.is_empty()
	for b in bullets:
		var row: HBoxContainer = LEDGER.instantiate()
		%Bullets.add_child(row)
		var line: String = b
		var cut := line.rfind(": ")
		row.get_node("%Name").text = line.substr(0, cut) if cut > 0 else line
		row.get_node("%Value").text = line.substr(cut + 2) if cut > 0 else ""
	UIK.clear(%Footer)
	for i in buttons.size():
		var btn: Button = CHOICE.instantiate()
		btn.text = buttons[i][0]
		btn.custom_minimum_size = Vector2(170, 44)
		if buttons[i].size() > 1 and buttons[i][1]:
			btn.theme_type_variation = &"ButtonPrimary"
			btn.add_theme_font_size_override("font_size", 16)
		if buttons[i].size() > 2:
			btn.tooltip_text = buttons[i][2]
		var idx := i
		btn.pressed.connect(func(): chosen.emit(idx))
		%Footer.add_child(btn)
	return self
