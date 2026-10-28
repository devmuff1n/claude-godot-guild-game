class_name ExpeditionTopBar
extends PanelContainer
## Верхняя панель похода (scenes/expedition/ExpeditionTopBar.tscn): название, кошелёк, тактика,
## маршрут, скорость боя, пауза и меню. Все элементы фиксированной ширины.

signal order_selected(order: String)
signal speed_selected(speed: float)
signal pause_pressed
signal menu_pressed

@onready var route: RouteBar = %Route
@onready var speed_btns := {0.5: %Speed05, 1.0: %Speed1, 1.5: %Speed15, 2.0: %Speed2}

func _ready() -> void:
	%AdvButton.pressed.connect(func(): order_selected.emit("advance"))
	%HoldButton.pressed.connect(func(): order_selected.emit("hold"))
	%PauseButton.pressed.connect(func(): pause_pressed.emit())
	%MenuButton.pressed.connect(func(): menu_pressed.emit())
	for k in speed_btns.keys():
		var sp: float = k
		speed_btns[k].pressed.connect(func(): speed_selected.emit(sp))

func set_title(t: String) -> void:
	%TitleLabel.text = t
	%TitleLabel.tooltip_text = t

func set_purse(v: int, visible_ := true) -> void:
	%Purse.visible = visible_
	%Purse.set_value(str(v))

const TIME_ICONS := {"morning": "dawn", "day": "sun", "evening": "dusk", "night": "moon"}
const TIME_TIPS := {
	"morning": "Утро",
	"day": "День",
	"evening": "Вечер",
	"night": "Ночь: враги дальше 360 шагов от героев скрыты во тьме",
}

## Время суток (DayTime): "morning" / "day" / "evening" / "night"; "" — скрыть (арена).
func set_time(t: String) -> void:
	%TimePill.visible = t != ""
	if t == "":
		return
	%TimePill.icon_kind = TIME_ICONS[t]
	%TimePill.set_value(DayTime.NAMES[t])
	%TimePill.tooltip_text = "%s\nКаждый пункт пути — часть суток. Привал — ночь: отряд спит, в путь — утром." % TIME_TIPS[t]

## order: "advance" / "hold"; enabled — есть ли бой
func set_order(order: String, enabled: bool) -> void:
	UIK.mark(%AdvButton, order == "advance")
	UIK.mark(%HoldButton, order == "hold")
	%AdvButton.disabled = not enabled
	%HoldButton.disabled = not enabled

func set_speed(s: float) -> void:
	for k in speed_btns.keys():
		UIK.mark(speed_btns[k], is_equal_approx(k, s))

func set_paused(p: bool) -> void:
	%PauseIcon.kind = "play" if p else "pause"
	UIK.mark(%PauseButton, p)
