class_name HiResView
extends SubViewportContainer
## 3D-вид, который рисуется в выбранном разрешении (Settings.resolution), а не в размере
## макета 1600×900. Контейнер (stretch = true) делается в render_scale раз больше своего места
## и уменьшается обратно через scale, поэтому SubViewport получает размер в пикселях разрешения.
## Место задаётся в сцене якорями на весь родитель и отступами (offset_*); ввод и координаты
## внутри контейнера идут в пикселях разрешения (size тоже), их отношение сохраняется.

const GROUP := "hires_view"

var _margins := Rect2()   # offset_left/top и offset_right/bottom из сцены


func _ready() -> void:
	add_to_group(GROUP)
	_margins = Rect2(offset_left, offset_top, offset_right, offset_bottom)
	set_anchors_preset(PRESET_TOP_LEFT, false)
	get_parent_control().resized.connect(refresh)
	refresh()


func refresh() -> void:
	var p := get_parent_control()
	if p == null:
		return
	var k := Settings.render_scale()
	var place := Rect2(_margins.position, p.size - _margins.position + _margins.size)
	scale = Vector2.ONE / k
	position = place.position
	size = place.size * k
