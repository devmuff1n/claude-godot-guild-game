extends Node3D
## Отдельная тестовая сцена городского набора (generated-models/_tools/build_town_kit.py). В игре не используется.
## Проверяет каждый GLB: загрузку, габариты против арт-спецификации, коллизии, подвижные части;
## собирает городскую площадь и холл гильдии с мебелью. Двери, крышки, вывески и ворот покачиваются.
## TOWN_CAM=interior — камера в холле; TOWN_SHOT=<png> — снимок и выход.

const KIT := "res://assets/models/town/"
## Целевые габариты в осях Godot: x — ширина, y — высота, z — глубина.
const SPEC := {
	"village_cottage": ["buildings", Vector3(4.5, 4.6, 4)],
	"party_inn": ["buildings", Vector3(6.3, 6.7, 5.7)],
	"guild_hall_exterior": ["buildings", Vector3(7.2, 8.1, 6)],
	"blacksmith_exterior": ["buildings", Vector3(6.5, 6.2, 5)],
	"alchemy_workshop_exterior": ["buildings", Vector3(6.2, 6, 4.8)],
	"leather_workshop_exterior": ["buildings", Vector3(6, 4.8, 4.8)],
	"guild_hall_interior_shell": ["buildings", Vector3(10.5, 6, 8)],
	"wooden_barrel": ["props", Vector3(0.6, 0.8, 0.6)],
	"wooden_crate": ["props", Vector3(0.7, 0.65, 0.6)],
	"burlap_sack": ["props", Vector3(0.45, 0.6, 0.4)],
	"wicker_basket": ["props", Vector3(0.6, 0.4, 0.6)],
	"small_wooden_chest": ["props", Vector3(0.65, 0.4, 0.42)],
	"wooden_planter": ["props", Vector3(1.1, 0.8, 0.75)],
	"street_lamp": ["props", Vector3(1, 3, 0.55)],
	"portable_lantern": ["props", Vector3(0.3, 0.46, 0.3)],
	"stone_well": ["props", Vector3(2.4, 2.7, 2.2)],
	"market_stall": ["props", Vector3(2.8, 2.5, 2)],
	"quest_noticeboard": ["props", Vector3(2.3, 1.8, 0.16)],
	"guild_banner": ["props", Vector3(0.95, 1.7, 0.12)],
	"ledger_book": ["props", Vector3(0.32, 0.08, 0.24)],
	"parchment_scroll": ["props", Vector3(0.35, 0.06, 0.2)],
	"wooden_tankard": ["props", Vector3(0.17, 0.22, 0.13)],
	"metal_pitcher": ["props", Vector3(0.23, 0.32, 0.19)],
	"market_handcart": ["props", Vector3(2.5, 0.8, 1)],
	"guild_table": ["furniture", Vector3(2, 0.75, 0.9)],
	"guild_backless_bench": ["furniture", Vector3(1.8, 0.42, 0.4)],
	"village_bench": ["furniture", Vector3(1.8, 1.1, 0.65)],
	"guild_reception_counter": ["furniture", Vector3(3.4, 1, 0.9)],
	"wooden_bookshelf": ["furniture", Vector3(1.7, 2.5, 0.45)],
	"anvil": ["crafts", Vector3(1, 0.9, 0.5)],
	"forge_hearth": ["crafts", Vector3(1.5, 1, 1)],
	"tanning_vat": ["crafts", Vector3(1, 0.7, 1)],
	"hide_stretching_rack": ["crafts", Vector3(1.8, 2.4, 0.25)],
	"leather_roll": ["crafts", Vector3(1.2, 0.3, 0.3)],
	"hanging_herb_bundle": ["crafts", Vector3(0.35, 0.6, 0.28)],
	"weapon_rack": ["crafts", Vector3(1.5, 1.6, 0.6)],
}
## id, x и y из Blender (в Godot: x, высота, -y), поворот вокруг вертикали (град.), высота над землёй.
const SQUARE := [
	["guild_hall_exterior", 0.0, 9.0, 0.0, 0.0],
	["party_inn", -8.5, 8.2, 0.0, 0.0],
	["alchemy_workshop_exterior", 8.5, 8.4, 0.0, 0.0],
	["blacksmith_exterior", -13.0, 0.5, 90.0, 0.0],
	["village_cottage", -12.5, -7.5, 90.0, 0.0],
	["leather_workshop_exterior", 13.0, 0.5, -90.0, 0.0],
	["village_cottage", 12.5, -7.5, -90.0, 0.0],
	["stone_well", 0.0, 0.5, 15.0, 0.0],
	["market_stall", -5.0, 1.5, 10.0, 0.0],
	["market_stall", 5.0, 1.5, -10.0, 0.0],
	["wicker_basket", -5.6, 1.15, 0.0, 0.88],
	["wicker_basket", 4.4, 1.15, 0.0, 0.88],
	["quest_noticeboard", 3.6, 5.2, 0.0, 0.0],
	["street_lamp", -2.6, 5.4, 0.0, 0.0],
	["street_lamp", 2.0, -4.5, 180.0, 0.0],
	["street_lamp", -7.5, -3.5, 90.0, 0.0],
	["village_bench", -2.4, -3.0, 180.0, 0.0],
	["village_bench", 4.0, -2.0, 150.0, 0.0],
	["wooden_planter", -6.3, 5.6, 0.0, 0.0],
	["wooden_planter", 6.0, 5.8, 0.0, 0.0],
	["weapon_rack", -10.6, 5.9, 0.0, 0.0],
	["anvil", -9.4, 2.4, 70.0, 0.0],
	["wooden_barrel", -9.6, -1.6, 0.0, 0.0],
	["wooden_barrel", -9.0, -2.2, 40.0, 0.0],
	["wooden_crate", -8.3, 5.4, 15.0, 0.0],
	["burlap_sack", -7.5, 5.2, 0.0, 0.0],
	["tanning_vat", 9.6, -1.8, 0.0, 0.0],
	["hide_stretching_rack", 10.0, 2.6, -90.0, 0.0],
	["leather_roll", 9.4, -3.4, 30.0, 0.0],
	["market_handcart", -5.8, -5.5, 25.0, 0.0],
	["wooden_crate", -4.3, -5.0, 0.0, 0.0],
	["burlap_sack", 6.4, 0.4, 0.0, 0.0],
	["burlap_sack", 6.6, 1.0, 50.0, 0.0],
	["small_wooden_chest", 6.8, -0.4, -20.0, 0.0],
	["portable_lantern", -3.1, -3.2, 0.0, 0.47],
]
## Холл гильдии (оболочка в стороне от площади) и его мебель.
const HALL_ORIGIN := Vector3(0.0, 0.0, 40.0)
const HALL := [
	["guild_hall_interior_shell", 0.0, 0.0, 0.0, 0.0],
	["guild_reception_counter", -1.0, 2.0, 0.0, 0.12],
	["guild_banner", 1.4, 3.6, 0.0, 1.9],
	["guild_table", -2.5, -1.2, 0.0, 0.12],
	["guild_backless_bench", -2.5, -1.95, 0.0, 0.12],
	["guild_backless_bench", -2.5, -0.45, 180.0, 0.12],
	["guild_table", 1.5, -1.6, 90.0, 0.12],
	["wooden_bookshelf", -4.75, 1.0, 90.0, 0.12],
	["wooden_bookshelf", -4.75, -1.0, 90.0, 0.12],
	["ledger_book", -1.4, 2.0, 15.0, 1.07],
	["parchment_scroll", -0.5, 1.9, -10.0, 1.07],
	["wooden_tankard", -2.9, -1.1, 0.0, 0.87],
	["wooden_tankard", -2.2, -1.35, 0.0, 0.87],
	["metal_pitcher", -2.55, -1.0, 0.0, 0.87],
	["portable_lantern", 1.5, -1.4, 0.0, 0.87],
	["small_wooden_chest", 3.6, 2.2, 180.0, 0.12],
	["hanging_herb_bundle", -4.4, -2.8, 0.0, 2.6],
	["wooden_barrel", 4.3, -3.2, 0.0, 0.12],
]
## Подвижные узлы: суффикс имени, ось в локальных координатах, угол от/до (град.).
const MOVING := {
	"door_leaf": [Vector3(0, 1, 0), 0.0, 70.0],
	"side_door_left": [Vector3(0, 1, 0), 0.0, 70.0],
	"side_door_back": [Vector3(0, 1, 0), 0.0, 70.0],
	"hanging_sign": [Vector3(1, 0, 0), -12.0, 12.0],
	"anvil_sign": [Vector3(1, 0, 0), -12.0, 12.0],
	"flask_sign": [Vector3(1, 0, 0), -12.0, 12.0],
	"hide_sign": [Vector3(1, 0, 0), -12.0, 12.0],
	"windlass": [Vector3(1, 0, 0), 0.0, 360.0],
	"crate_lid": [Vector3(1, 0, 0), 0.0, -60.0],
	"hinged_lid": [Vector3(1, 0, 0), 0.0, -70.0],
}

var _movers: Array = []
var _t := 0.0


func _ready() -> void:
	_check_assets()
	_place(SQUARE, Vector3.ZERO)
	_place(HALL, HALL_ORIGIN)
	var cam: Camera3D = $Camera3D
	if OS.get_environment("TOWN_CAM") == "interior":
		cam.position = HALL_ORIGIN + Vector3(0.5, 4.2, 9.5)
		cam.look_at(HALL_ORIGIN + Vector3(0.0, 1.4, -0.5), Vector3.UP)
	else:
		cam.look_at(Vector3(0.0, 1.5, -1.5), Vector3.UP)
	var shot := OS.get_environment("TOWN_SHOT")
	if shot != "":
		await get_tree().create_timer(1.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot)
		print("[townkit] снимок ", shot)
		get_tree().quit()


func _process(delta: float) -> void:
	_t += delta
	var k := 0.5 - 0.5 * cos(_t * 1.2)
	for m in _movers:
		var node: Node3D = m[0]
		node.basis = m[1] * Basis(m[2], deg_to_rad(lerpf(m[3], m[4], k)))


func _scene_path(id: String) -> String:
	return KIT + SPEC[id][0] + "/" + id + ".glb"


func _check_assets() -> void:
	var ok := 0
	var tris := 0
	for id in SPEC.keys():
		var ps := load(_scene_path(id)) as PackedScene
		if ps == null:
			push_error("[townkit] не загружается %s" % id)
			continue
		var inst := ps.instantiate() as Node3D
		add_child(inst)
		var box := _merged_aabb(inst)
		var size := box.size
		var spec: Vector3 = SPEC[id][1]
		var shapes := inst.find_children("*", "CollisionShape3D", true, false).size()
		var t := _triangles(inst)
		tris += t
		var dev := Vector3(size.x / spec.x - 1.0, size.y / spec.y - 1.0, size.z / spec.z - 1.0)
		var worst := maxf(absf(dev.x), maxf(absf(dev.y), absf(dev.z)))
		var status := "OK" if worst <= 0.15 else "CHECK"
		if status == "OK":
			ok += 1
		print("[townkit] %-26s size=(%.2f, %.2f, %.2f) spec=(%.2f, %.2f, %.2f) base_y=%.2f tris=%d shapes=%d %s" % [
			id, size.x, size.y, size.z, spec.x, spec.y, spec.z, box.position.y, t, shapes, status])
		remove_child(inst)
		inst.free()
	print("[townkit] %d/%d в пределах 15%% от целевых габаритов, всего %d треугольников" % [ok, SPEC.size(), tris])


func _triangles(root: Node) -> int:
	var n := 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			var idx = arr[Mesh.ARRAY_INDEX]
			n += (idx.size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return n


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


func _place(rows: Array, origin: Vector3) -> void:
	var kit: Node3D = $Kit
	for row in rows:
		var id: String = row[0]
		var ps := load(_scene_path(id)) as PackedScene
		if ps == null:
			continue
		var inst := ps.instantiate() as Node3D
		inst.position = origin + Vector3(row[1], row[4], -float(row[2]))
		inst.rotation_degrees = Vector3(0.0, row[3], 0.0)
		kit.add_child(inst)
		for n in inst.find_children("*", "Node3D", true, false):
			for key in MOVING.keys():
				if String(n.name).ends_with(key) and not (n is CollisionShape3D):
					var cfg: Array = MOVING[key]
					_movers.append([n, (n as Node3D).basis, cfg[0], cfg[1], cfg[2]])
					break
