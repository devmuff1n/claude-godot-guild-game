class_name BalanceStepper
extends HBoxContainer
## Число с кнопками − / + (scenes/ui/balance/BalanceStepper.tscn). Shift+клик — шаг ×5.

signal changed(value: float)

@export var step := 1.0
@export var min_value := 0.0
@export var max_value := 100.0
## Формат подписи: "%d", "%d%%", "×%.2f" … zero_text — подпись для нуля (например «авто»)
@export var fmt := "%d"
@export var zero_text := ""

var value := 0.0

func _ready() -> void:
	%Minus.pressed.connect(func(): _bump(-1))
	%Plus.pressed.connect(func(): _bump(1))
	_show()

func set_value(v: float) -> BalanceStepper:
	value = clamp(v, min_value, max_value)
	if is_node_ready():
		_show()
	return self

func _bump(dir: int) -> void:
	var k := 5.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	var v: float = clamp(snappedf(value + dir * step * k, step), min_value, max_value)
	if is_equal_approx(v, value):
		return
	value = v
	_show()
	changed.emit(value)

func _show() -> void:
	var t: String = fmt % value
	if "f" in fmt:
		t = t.replace(".", ",")
	%Value.text = zero_text if (zero_text != "" and is_zero_approx(value)) else t
	%Minus.disabled = value <= min_value
	%Plus.disabled = value >= max_value
