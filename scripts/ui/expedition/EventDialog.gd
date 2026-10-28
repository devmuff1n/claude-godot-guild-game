class_name EventDialog
extends Control
## Дорожная ситуация (scenes/expedition/EventDialog.tscn): описание, запасы, варианты с последствиями.

signal choice_picked(choice: Dictionary)
signal continue_pressed
signal fight_pressed

const CHOICE := preload("res://scenes/expedition/EventChoice.tscn")

func _ready() -> void:
	%NextButton.pressed.connect(func(): continue_pressed.emit())
	%FightButton.pressed.connect(func(): fight_pressed.emit())

func show_choices(ev: Dictionary, purse: int, hp_pots: int, mp_pots: int) -> void:
	%Title.text = ev["title"]
	%Text.text = ev["text"]
	%Purse.set_value(str(purse))
	%PotHp.set_value(str(hp_pots))
	%PotMp.set_value(str(mp_pots))
	%Resources.visible = true
	%Footer.visible = false
	UIK.clear(%Choices)
	%Choices.visible = true
	for ch in ev["choices"]:
		var choice: Dictionary = ch
		var b: Button = CHOICE.instantiate()
		%Choices.add_child(b)
		b.get_node("%Text").text = ch["text"]
		b.get_node("%Effect").text = Game.choice_text(ch)
		var prob := Game.event_choice_problem(ch)
		b.disabled = prob != ""
		b.tooltip_text = prob
		b.pressed.connect(func(): choice_picked.emit(choice))

func show_result(ev: Dictionary, text: String, battle: bool) -> void:
	%Title.text = ev["title"]
	%Text.text = text
	%Resources.visible = false
	%Choices.visible = false
	UIK.clear(%Choices)
	%Footer.visible = true
	%FightButton.visible = battle
	%NextButton.visible = not battle
