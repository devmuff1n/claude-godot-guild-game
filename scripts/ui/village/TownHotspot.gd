class_name TownHotspot
extends Area3D
## Кликабельное здание поселения (scenes/village/Town3D.tscn): открывает вкладку деревни.

const HIGHLIGHT := preload("res://scenes/village/town_highlight.tres")

## Вкладка VillageScreen, которую открывает клик
@export var tab := "home"
## Название под курсором
@export var title := ""

var _meshes: Array[MeshInstance3D] = []

func _ready() -> void:
	for n in find_children("*", "MeshInstance3D", true, false):
		_meshes.append(n as MeshInstance3D)

func set_highlight(on: bool) -> void:
	for m in _meshes:
		m.material_overlay = HIGHLIGHT if on else null

func set_badge(on: bool) -> void:
	var b := get_node_or_null("Badge") as Node3D
	if b:
		b.visible = on
