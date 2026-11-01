extends SceneTree
## Замер 3D-героев: рост (AABB сетки в позе idle), список клипов (длина, цикл, смещение бёдер за клип).
## godot --headless --path . -s res://tests/hero_mx_probe.gd

const HEROES := {
	"elira": "res://scenes/characters/EliraMX3D.tscn",
	"marek": "res://scenes/characters/MarekMX3D.tscn",
	"neris": "res://scenes/characters/NerisMX3D.tscn",
	"aiden": "res://scenes/characters/AidenMX3D.tscn",
}


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for id in HEROES:
		var h: HeroModel3D = load(HEROES[id]).instantiate()
		root.add_child(h)
		await process_frame
		await process_frame
		var aabb := AABB()
		var first := true
		for mi in h.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = mi.global_transform * mi.get_aabb()
			aabb = b if first else aabb.merge(b)
			first = false
		var skel: Skeleton3D = h.find_children("*", "Skeleton3D", true, false)[0]
		var head := -1
		var top := -1
		for b in skel.get_bone_count():
			var bn := skel.get_bone_name(b)
			if bn.ends_with("Head"):
				head = b
			if bn.ends_with("HeadTop_End"):
				top = b
		var head_y := (skel.global_transform * skel.get_bone_global_pose(head)).origin.y if head >= 0 else -1.0
		var top_y := (skel.global_transform * skel.get_bone_global_pose(top)).origin.y if top >= 0 else -1.0
		var top_rest := (skel.global_transform * skel.get_bone_global_rest(top)).origin.y if top >= 0 else -1.0
		# верх сетки тела (без оружия): самая высокая вершина среди сеток без Sword/Shield/Bow/Staff в имени
		var body_top := -1.0
		for mi in h.find_children("*", "MeshInstance3D", true, false):
			var nm := String(mi.name).to_lower()
			print("   mesh ", mi.name, " top=", (mi.global_transform * mi.get_aabb()).end.y)
		print("   head bone=%s y=%.3f  top=%s y=%.3f rest=%.3f" % [skel.get_bone_name(head) if head >= 0 else "-", head_y, skel.get_bone_name(top) if top >= 0 else "-", top_y, top_rest])
		print("HERO %s scale=%s aabb_y=[%.3f..%.3f] h=%.3f head_y=%.3f skel_scale=%s anim=%s" % [id, h.scale, aabb.position.y, aabb.end.y, aabb.size.y, head_y, skel.global_transform.basis.get_scale(), h.anim.current_animation])
		var lines: Array = []
		for clip in h.anim.get_animation_list():
			if String(clip).contains("/"):
				continue
			var a := h.anim.get_animation(clip)
			var dz := 0.0
			var dx := 0.0
			for t in a.get_track_count():
				if a.track_get_type(t) == Animation.TYPE_POSITION_3D and String(a.track_get_path(t)).ends_with(":Hips"):
					var p0: Vector3 = a.position_track_interpolate(t, 0.0)
					var p1: Vector3 = a.position_track_interpolate(t, a.length)
					dz = p1.z - p0.z
					dx = p1.x - p0.x
			lines.append("%s %.2fs loop=%d dHips=(%.2f,%.2f)" % [clip, a.length, a.loop_mode, dx, dz])
		print("  CLIPS ", ", ".join(lines))
		h.queue_free()
	quit()
