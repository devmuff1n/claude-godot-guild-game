class_name SystemMenu
extends Control
## Системное меню (scenes/ui/SystemMenu.tscn): пауза в походе и меню деревни.
## Набор кнопок задаётся через setup(); выбранное действие приходит сигналом chosen(action).

signal chosen(action: String)

const ACTIONS := ["resume", "save", "last_result", "abandon", "main_menu"]

func _ready() -> void:
	%Resume.pressed.connect(func(): chosen.emit("resume"))
	%Save.pressed.connect(func(): chosen.emit("save"))
	%LastResult.pressed.connect(func(): chosen.emit("last_result"))
	%Abandon.pressed.connect(func(): chosen.emit("abandon"))
	%MainMenu.pressed.connect(func(): chosen.emit("main_menu"))
	# вид героев (Settings.hero_look) меняется сразу, без закрытия меню
	var looks := {"simple": %LookSimple, "2d": %Look2D, "3d": %Look3D}
	for v in looks:
		looks[v].pressed.connect(func():
			Settings.set_hero_look(v)
			_mark_look(looks))
	_mark_look(looks)


func _mark_look(looks: Dictionary) -> void:
	for v in looks:
		UIK.mark(looks[v], v == Settings.hero_look())

## title — заголовок окна; actions — какие кнопки показать (из ACTIONS)
func setup(title: String, actions: Array, show_controls := false) -> SystemMenu:
	%Title.text = title
	%Resume.visible = "resume" in actions
	%Save.visible = "save" in actions
	%LastResult.visible = "last_result" in actions
	%Abandon.visible = "abandon" in actions
	%MainMenu.visible = "main_menu" in actions
	%Controls.visible = show_controls
	return self

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		chosen.emit("resume")
