class_name Town3D
extends Node3D
## Поселение гильдии (scenes/village/Town3D.tscn): здания, дорожки и декор.
## Что уже построено — DB.BUILDINGS / Game.building_built(): узлы Hotspots/<Здание> и узлы с metadata/building.

## Показать всё поселение (для тестов и редактора)
@export var show_all := false

func _ready() -> void:
	apply_buildings()

## Спрятать здания, которые ещё не построены (вместе с их дорожками и пристройками)
func apply_buildings() -> void:
	for h in $Hotspots.get_children():
		_set_built(h, _built(h.name))
	for group in [$Paths, $Decor]:
		for n in group.get_children():
			if n.has_meta("building"):
				_set_built(n, _built(String(n.get_meta("building"))))

func _built(id: String) -> bool:
	return show_all or Game.state.is_empty() or Game.building_built(id)

func _set_built(n: Node3D, on: bool) -> void:
	n.visible = on
	# Невидимая зона здания не должна ловить курсор
	n.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
