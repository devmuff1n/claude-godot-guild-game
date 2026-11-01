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
	# режим окна и размер (Settings.window_mode/resolution) тоже применяются сразу
	var modes := {"windowed": %WinWindowed, "fullscreen": %WinFullscreen, "exclusive": %WinExclusive}
	for v in modes:
		modes[v].pressed.connect(func():
			Settings.set_window_mode(v)
			_mark_display(modes))
	for r: Vector2i in Settings.RESOLUTIONS:
		%Resolution.add_item("%d × %d" % [r.x, r.y])
	# выбор размера во весь экран переключает в окно этого размера
	%Resolution.item_selected.connect(func(i: int):
		Settings.set_resolution(Settings.RESOLUTIONS[i])
		if Settings.window_mode() != "windowed":
			Settings.set_window_mode("windowed")
		_mark_display(modes))
	_mark_display(modes)


func _mark_display(modes: Dictionary) -> void:
	for v in modes:
		UIK.mark(modes[v], v == Settings.window_mode())
	var opt: OptionButton = %Resolution
	var windowed := Settings.window_mode() == "windowed"
	for i in Settings.RESOLUTIONS.size():
		var fits := Settings.fits_screen(Settings.RESOLUTIONS[i])
		opt.set_item_disabled(i, not fits)
		opt.set_item_tooltip(i, "" if fits else "Больше экрана")
	opt.select(Settings.RESOLUTIONS.find(Settings.resolution()))
	opt.tooltip_text = "" if windowed else "Во весь экран — разрешение монитора; выбор размера переключит в окно"


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
