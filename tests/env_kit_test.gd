extends Node3D
## Отдельная тестовая сцена набора окружения (generated-models). В игре не используется.
## Проверяет каждый GLB: загрузку, габариты против арт-спецификации, коллизии,
## и показывает участок пути, собранный из модулей. Подвижные детали покачиваются на своих осях.

const KIT := "res://assets/models/environment/"
## Целевые габариты в осях Godot: x — ширина, y — высота, z — глубина.
const SPEC := {
	"ground_road_tile": Vector3(6, 0.2, 6),
	"stream_channel": Vector3(6, 0.8, 4),
	"field_rock": Vector3(1.35, 0.9, 1.1),
	"fallen_tree_root": Vector3(3, 1, 1.3),
	"vegetable_garden_bed": Vector3(3.6, 0.35, 2.7),
	"oak_tree": Vector3(4, 5.4, 3.6),
	"pine_tree": Vector3(2.9, 6.5, 2.8),
	"roadside_bush": Vector3(1.4, 1, 1.2),
	"grass_tuft": Vector3(0.55, 0.65, 0.5),
	"flower_patch": Vector3(0.7, 0.5, 0.6),
	"potted_plant": Vector3(0.45, 0.75, 0.4),
	"low_stone_wall": Vector3(3, 1.2, 0.55),
	"wooden_garden_fence": Vector3(3, 1, 0.28),
	"wooden_barricade": Vector3(1.7, 0.9, 0.65),
	"checkpoint_barrier": Vector3(3.6, 1.2, 0.4),
	"forest_defense_gate": Vector3(2.3, 2.8, 0.45),
	"timber_footbridge": Vector3(4.2, 1.25, 2.2),
	"toll_sign": Vector3(0.7, 2.1, 0.3),
	"decorative_spear": Vector3(0.12, 1.65, 0.08),
	"round_watch_shield": Vector3(0.6, 0.6, 0.1),
}
const CATEGORY := {
	"ground_road_tile": "landscape",
	"stream_channel": "landscape",
	"field_rock": "landscape",
	"fallen_tree_root": "landscape",
	"vegetable_garden_bed": "landscape",
	"oak_tree": "vegetation",
	"pine_tree": "vegetation",
	"roadside_bush": "vegetation",
	"grass_tuft": "vegetation",
	"flower_patch": "vegetation",
	"potted_plant": "vegetation",
	"low_stone_wall": "road_defense",
	"wooden_garden_fence": "road_defense",
	"wooden_barricade": "road_defense",
	"checkpoint_barrier": "road_defense",
	"forest_defense_gate": "road_defense",
	"timber_footbridge": "road_defense",
	"toll_sign": "road_defense",
	"decorative_spear": "road_defense",
	"round_watch_shield": "road_defense",
}
## id, x и y из Blender (в Godot: x, 0, -y), поворот вокруг вертикали (град.), масштаб.
const LAYOUT := [
	["ground_road_tile", -9.0, 0.0, 0.0, 1.0],
	["ground_road_tile", -3.0, 0.0, 0.0, 1.0],
	["ground_road_tile", 7.0, 0.0, 0.0, 1.0],
	["ground_road_tile", 13.0, 0.0, 0.0, 1.0],
	["stream_channel", 2.0, 0.0, 90.0, 1.0],
	["stream_channel", 2.0, 6.0, 90.0, 1.0],
	["stream_channel", 2.0, -6.0, 90.0, 1.0],
	["timber_footbridge", 2.0, 0.0, 0.0, 1.0],
	["checkpoint_barrier", -6.0, 0.0, 90.0, 1.0],
	["toll_sign", -6.9, -2.45, 0.0, 1.0],
	["forest_defense_gate", 10.0, 0.0, 90.0, 1.0],
	["low_stone_wall", 10.0, 2.65, 90.0, 1.0],
	["low_stone_wall", 10.0, -2.65, -90.0, 1.0],
	["wooden_barricade", 12.3, 1.7, 90.0, 1.0],
	["wooden_barricade", 12.3, -1.7, 90.0, 1.0],
	["decorative_spear", 9.25, -1.5, 0.0, 1.0],
	["round_watch_shield", 10.32, 2.6, 90.0, 1.0],
	["potted_plant", 8.9, -3.4, 0.0, 1.0],
	["wooden_garden_fence", -10.5, 4.6, 0.0, 1.0],
	["wooden_garden_fence", -7.5, 4.6, 0.0, 1.0],
	["wooden_garden_fence", -4.5, 4.6, 0.0, 1.0],
	["vegetable_garden_bed", -7.5, 7.4, 0.0, 1.0],
	["oak_tree", -2.5, 7.0, 30.0, 1.0],
	["oak_tree", 15.5, -6.6, 120.0, 0.9],
	["pine_tree", -12.5, -5.6, 0.0, 1.0],
	["pine_tree", -9.5, -7.4, 60.0, 0.85],
	["pine_tree", 6.2, 6.6, 20.0, 1.1],
	["pine_tree", 16.5, 5.9, 80.0, 0.9],
	["pine_tree", -1.6, -7.6, 40.0, 0.9],
	["roadside_bush", -4.8, -3.9, 0.0, 1.0],
	["roadside_bush", 5.4, -4.2, 70.0, 1.0],
	["roadside_bush", 13.6, 3.9, 140.0, 1.0],
	["roadside_bush", -1.0, 4.1, 200.0, 0.9],
	["field_rock", -0.4, -4.5, 20.0, 1.0],
	["field_rock", 8.4, 4.5, 150.0, 0.8],
	["field_rock", -13.6, 2.2, 0.0, 1.2],
	["fallen_tree_root", -12.8, 6.4, 25.0, 1.0],
	["flower_patch", -3.6, -3.6, 0.0, 1.0],
	["flower_patch", -11.8, -3.6, 40.0, 1.0],
	["flower_patch", 7.8, 3.6, 90.0, 1.0],
	["flower_patch", 15.0, -3.7, 10.0, 1.0],
	["grass_tuft", -5.6, -3.4, 0.0, 1.0],
	["grass_tuft", -8.3, -3.8, 50.0, 1.1],
	["grass_tuft", -10.2, -3.3, 100.0, 0.9],
	["grass_tuft", -0.2, 3.5, 20.0, 1.0],
	["grass_tuft", 6.4, 3.5, 70.0, 1.0],
	["grass_tuft", 11.8, 4.2, 30.0, 1.2],
	["grass_tuft", 14.6, -4.4, 150.0, 1.0],
	["grass_tuft", 4.6, -3.4, 10.0, 0.9],
	["grass_tuft", -13.0, -3.9, 80.0, 1.0],
]
## Узел, ось вращения в его локальных координатах, угол от/до (град.).
const MOVING := {
	"checkpoint_barrier_crossbar": [Vector3(0, 0, 1), 0.0, 70.0],
	"forest_defense_gate_gate_leaf": [Vector3(0, 1, 0), 0.0, 80.0],
	"toll_sign_round_sign": [Vector3(1, 0, 0), -15.0, 15.0],
}

var _movers: Array = []
var _t := 0.0


func _ready() -> void:
	_check_assets()
	_build_layout()
	var cam: Camera3D = $Camera3D
	cam.look_at(Vector3(1.5, 0.0, 0.5), Vector3.UP)


func _process(delta: float) -> void:
	_t += delta
	var k := 0.5 - 0.5 * cos(_t * 1.2)
	for m in _movers:
		var node: Node3D = m[0]
		var rest: Basis = m[1]
		var angle := lerpf(m[3], m[4], k)
		node.basis = rest * Basis(m[2], deg_to_rad(angle))


func _scene_path(id: String) -> String:
	return KIT + CATEGORY[id] + "/" + id + ".glb"


func _check_assets() -> void:
	var ok := 0
	for id in SPEC.keys():
		var ps := load(_scene_path(id)) as PackedScene
		if ps == null:
			push_error("[envkit] не загружается %s" % id)
			continue
		var inst := ps.instantiate() as Node3D
		add_child(inst)
		var box := _merged_aabb(inst)
		var size := box.size
		var spec: Vector3 = SPEC[id]
		var shapes := inst.find_children("*", "CollisionShape3D", true, false).size()
		var dev := Vector3(size.x / spec.x - 1.0, size.y / spec.y - 1.0, size.z / spec.z - 1.0)
		var worst := maxf(absf(dev.x), maxf(absf(dev.y), absf(dev.z)))
		var status := "OK" if worst <= 0.1 else "CHECK"
		if status == "OK":
			ok += 1
		print("[envkit] %-22s size=(%.2f, %.2f, %.2f) spec=(%.2f, %.2f, %.2f) base_y=%.2f shapes=%d %s" % [
			id, size.x, size.y, size.z, spec.x, spec.y, spec.z, box.position.y, shapes, status])
		remove_child(inst)
		inst.free()
	print("[envkit] %d/%d в пределах 10%% от целевых габаритов" % [ok, SPEC.size()])


func _merged_aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for n in root.find_children("*", "VisualInstance3D", true, false):
		var vi := n as VisualInstance3D
		var b: AABB = vi.global_transform * vi.get_aabb()
		if first:
			out = b
			first = false
		else:
			out = out.merge(b)
	return out


func _build_layout() -> void:
	var kit: Node3D = $Kit
	for row in LAYOUT:
		var id: String = row[0]
		var ps := load(_scene_path(id)) as PackedScene
		if ps == null:
			continue
		var inst := ps.instantiate() as Node3D
		var lift := 0.7 if id == "round_watch_shield" else 0.0
		inst.position = Vector3(row[1], lift, -float(row[2]))
		inst.rotation_degrees = Vector3(0.0, row[3], 0.0)
		inst.scale = Vector3.ONE * float(row[4])
		kit.add_child(inst)
		for node_name in MOVING.keys():
			var node := inst.find_child(node_name, true, false) as Node3D
			if node:
				var cfg: Array = MOVING[node_name]
				_movers.append([node, node.basis, cfg[0], cfg[1], cfg[2]])
