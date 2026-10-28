class_name ModalDialog
extends Control
## Модальное окно (scenes/ui/ModalDialog.tscn): затемнение, панель по центру, заголовок и тело.
## Содержимое собирается из шаблонов TextLine.tscn и ChoiceButton.tscn.

const TEXT_LINE := preload("res://scenes/ui/TextLine.tscn")
const CHOICE := preload("res://scenes/ui/ChoiceButton.tscn")

@onready var body: VBoxContainer = %Body
@onready var footer: HBoxContainer = %Footer

## scroll_h > 0 — тело прокручивается в пределах этой высоты
func setup(title: String, width := 620, dim := true, scroll_h := 0) -> ModalDialog:
	%Title.text = title
	%Panel.custom_minimum_size.x = width
	%Dim.visible = dim
	if scroll_h > 0:
		%Scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		%Scroll.custom_minimum_size.y = scroll_h
	return self

## Абзац текста. variation — вариация темы (BodyLabel, MutedLabel, GoldLabel, GoodLabel, BadLabel...)
func text(t: String, variation := "BodyLabel", parent: Control = null) -> Label:
	var l: Label = TEXT_LINE.instantiate()
	l.text = t
	l.theme_type_variation = StringName(variation)
	(parent if parent != null else body).add_child(l)
	return l

func button(t: String, cb: Callable, parent: Control = null, left := false) -> Button:
	var b: Button = CHOICE.instantiate()
	b.text = t
	if left:
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if cb.is_valid():
		b.pressed.connect(cb)
	(parent if parent != null else body).add_child(b)
	return b

func row() -> HBoxContainer:
	var h := HBoxContainer.new()
	body.add_child(h)
	return h

func add(c: Control) -> Control:
	body.add_child(c)
	return c

func separator() -> void:
	body.add_child(HSeparator.new())
