extends Node3D
## Проверка модели Нэрис после импорта: оси, масштаб, скелет, клипы, деформация, кадры.
## Запуск: godot --path . res://tests/NerisModelTest.tscn  (NERIS_SHOTS=папка — куда сохранить кадры)

const MODEL := "res://assets/models/characters/neris/neris.glb"
const PROFILE_BONES := ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head", "LeftShoulder", "LeftUpperArm",
	"LeftLowerArm", "LeftHand", "RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes", "RightUpperLeg", "RightLowerLeg", "RightFoot", "RightToes"]

var report := {}
var errors: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	var ps: PackedScene = load(MODEL)
	if ps == null:
		_fail("не загрузился " + MODEL)
		_finish()
		return
	var model: Node3D = ps.instantiate()
	add_child(model)
	var sk := model.find_children("*", "Skeleton3D", true, false)
	var aps := model.find_children("*", "AnimationPlayer", true, false)
	var skel: Skeleton3D = sk[0] if sk.size() > 0 else null
	var ap: AnimationPlayer = aps[0] if aps.size() > 0 else null
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	if skel == null or ap == null or meshes.is_empty():
		_fail("нет Skeleton3D / AnimationPlayer / MeshInstance3D")
		_finish()
		return
	var mi: MeshInstance3D = meshes[0]
	report["skeleton_path"] = str(model.get_path_to(skel))
	report["bone_count"] = skel.get_bone_count()
	var names := []
	for i in skel.get_bone_count():
		names.append(skel.get_bone_name(i))
	report["bones"] = names
	var missing := []
	for b in PROFILE_BONES:
		if skel.find_bone(b) < 0:
			missing.append(b)
	report["missing_profile_bones"] = missing
	report["mesh_surfaces"] = mi.mesh.get_surface_count()
	var tris := 0
	for s in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(s)
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		tris += idx.size() / 3 if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	report["triangles"] = tris
	report["material"] = str(mi.get_active_material(0).get_class()) if mi.get_active_material(0) else "none"
	var mat := mi.get_active_material(0) as BaseMaterial3D
	if mat:
		report["albedo_tex"] = mat.albedo_texture != null
		report["normal_tex"] = mat.normal_enabled and mat.normal_texture != null
		report["rough_tex"] = mat.roughness_texture != null
	report["skin_bind_count"] = mi.skin.get_bind_count() if mi.skin else 0
	# --- оси и масштаб в позе покоя
	skel.reset_bone_poses()
	await get_tree().process_frame
	var rest := _skinned_aabb(mi)
	report["rest_aabb_pos"] = _v(rest.position)
	report["rest_aabb_size"] = _v(rest.size)
	var hips := _bone_pos(skel, "Hips"); var head := _bone_pos(skel, "Head")
	var lh := _bone_pos(skel, "LeftHand"); var rh := _bone_pos(skel, "RightHand")
	var lt := _bone_pos(skel, "LeftToes")
	report["hips"] = _v(hips); report["head"] = _v(head); report["left_hand"] = _v(lh); report["right_hand"] = _v(rh); report["left_toes"] = _v(lt)
	report["up_is_y"] = head.y > hips.y + 0.2
	report["left_is_plus_x"] = lh.x > 0.0 and rh.x < 0.0
	report["faces_plus_z"] = lt.z > _bone_pos(skel, "LeftFoot").z
	report["feet_on_ground"] = absf(rest.position.y) < 0.02
	if not report["up_is_y"]: _fail("ось Y не вверх")
	if not report["left_is_plus_x"]: _fail("левая рука не на +X")
	if not report["faces_plus_z"]: _fail("модель не смотрит на +Z")
	if not missing.is_empty(): _fail("нет костей профиля: " + str(missing))
	# --- клипы: позы костей по ходу клипа (размах движения, высота таза, ступни над землёй)
	var anims := {}
	var bi_hips := skel.find_bone("Hips")
	var rest_pos := []
	for i in skel.get_bone_count():
		rest_pos.append(skel.get_bone_global_pose(i).origin)
	for an in ap.get_animation_list():
		if an == "RESET":
			continue
		var a := ap.get_animation(an)
		var w := {"max_bone_move": 0.0, "hips_min_y": 99.0, "min_bone_y": 99.0}
		for k in 9:
			ap.play(an)
			ap.seek(a.length * k / 8.0, true)
			ap.advance(0.0)
			skel.force_update_all_bone_transforms()
			for i in skel.get_bone_count():
				var p := skel.get_bone_global_pose(i).origin
				w["max_bone_move"] = maxf(w["max_bone_move"], p.distance_to(rest_pos[i]))
				w["min_bone_y"] = minf(w["min_bone_y"], p.y)
			w["hips_min_y"] = minf(w["hips_min_y"], skel.get_bone_global_pose(bi_hips).origin.y)
		ap.stop()
		anims[an] = {"length": snappedf(a.length, 0.01), "loop": a.loop_mode != Animation.LOOP_NONE, "tracks": a.get_track_count(),
			"max_bone_move_m": snappedf(w["max_bone_move"], 0.01), "hips_min_y": snappedf(w["hips_min_y"], 0.01), "min_bone_y": snappedf(w["min_bone_y"], 0.01)}
		if w["max_bone_move"] < 0.005: _fail("клип %s не двигает кости" % an)
		if w["max_bone_move"] > 1.5: _fail("клип %s: кости разлетаются" % an)
	report["animations"] = anims
	for need in ["Idle", "Walk", "Attack", "Cast", "Cast_Release", "Hit", "Dodge", "Death"]:
		if not anims.has(need): _fail("нет клипа " + need)
	for need in ["Idle", "Walk", "Cast"]:
		if anims.has(need) and not anims[need]["loop"]: _fail("клип %s не зациклен" % need)
	# --- кадры
	var shots := OS.get_environment("NERIS_SHOTS")
	if shots != "" and DisplayServer.get_name() != "headless":
		await _shots(model, ap, skel, shots)
	_finish()


func _shots(model: Node3D, ap: AnimationPlayer, skel: Skeleton3D, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.32, 0.33, 0.36)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.75, 0.75, 0.8); env.environment.ambient_light_energy = 0.6
	add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, 35, 0); sun.light_energy = 1.3; add_child(sun)
	var ground := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(4, 4); ground.mesh = pm; add_child(ground)
	var cam := Camera3D.new(); add_child(cam); cam.current = true
	var views := {"front": Vector3(0, 0.75, 3.2), "q": Vector3(2.2, 1.0, 2.3), "side": Vector3(3.2, 0.8, 0.0), "game": Vector3(0, 7.34, 12.8)}
	for an in ["Idle", "Walk", "Attack", "Cast", "Cast_Release", "Hit", "Dodge", "Death"]:
		if not ap.has_animation(an):
			continue
		var a := ap.get_animation(an)
		for k in 3:
			ap.play(an); ap.seek(a.length * (0.15 + 0.35 * k), true); ap.pause()
			for vn in ["q", "side"]:
				cam.fov = 30.0
				cam.position = views[vn]
				cam.look_at(Vector3(0, 0.7, 0))
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%s/godot_%s_%d_%s.png" % [dir, an, k, vn])
	ap.play("Idle"); ap.seek(0.0, true); ap.pause()
	cam.position = views["front"]; cam.look_at(Vector3(0, 0.75, 0)); cam.fov = 35.0
	await RenderingServer.frame_post_draw; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/godot_rest_front.png")
	cam.position = views["game"]; cam.look_at(Vector3(0, 0.6, 0)); cam.fov = 40.0
	await RenderingServer.frame_post_draw; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/godot_game_camera.png")


func _skinned_aabb(mi: MeshInstance3D) -> AABB:
	if mi.has_method("bake_mesh_from_current_skeleton_pose"):
		var m: ArrayMesh = mi.bake_mesh_from_current_skeleton_pose()
		if m:
			return mi.global_transform * m.get_aabb()
	return mi.global_transform * mi.get_aabb()


func _bone_pos(skel: Skeleton3D, n: String) -> Vector3:
	var i := skel.find_bone(n)
	return (skel.global_transform * skel.get_bone_global_pose(i)).origin if i >= 0 else Vector3.ZERO


func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]


func _fail(msg: String) -> void:
	errors.append(msg)
	push_error("NERIS: " + msg)


func _finish() -> void:
	report["errors"] = errors
	report["ok"] = errors.is_empty()
	var out := OS.get_environment("NERIS_REPORT")
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(JSON.stringify(report, "\t"))
		f.close()
	print("NERIS_REPORT ", JSON.stringify(report))
	get_tree().quit(0 if errors.is_empty() else 1)
