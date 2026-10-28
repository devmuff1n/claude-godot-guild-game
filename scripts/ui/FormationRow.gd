class_name FormationRow
extends VBoxContainer
## Расстановка строя (scenes/ui/FormationRow.tscn и FormationPicker.tscn). Слева — тыл, справа — фронт.
## Нажмите двух героев, чтобы поменять местами.

signal changed(formation: Array)

@export var show_slot_names := false
var _sel := -1

func _ready() -> void:
	for i in 4:
		var b: Button = get_node("%Slot" + str(i))
		var vis_idx := i
		b.pressed.connect(func(): _press(vis_idx))
	refresh()

## Позиция на экране i (0 — крайний левый) соответствует formation[3 - i]
func refresh() -> void:
	var f: Array = Game.state["formation"]
	for i in 4:
		var b: Button = get_node("%Slot" + str(i))
		var idx := 3 - i
		var id: String = f[idx]
		b.icon = UIK.portrait(id)
		var slot_name := "Передний" if idx == 0 else ("Задний" if idx == 3 else "Средний")
		b.text = ("%s\n%s" % [DB.hero_name(id), slot_name]) if show_slot_names else DB.hero_name(id)
		UIK.mark(b, _sel == idx)

func _press(vis_idx: int) -> void:
	var idx := 3 - vis_idx
	if _sel < 0:
		_sel = idx
	else:
		var ff: Array = Game.state["formation"].duplicate()
		var t = ff[_sel]
		ff[_sel] = ff[idx]
		ff[idx] = t
		Game.set_formation(ff)
		_sel = -1
		changed.emit(ff)
	refresh()
