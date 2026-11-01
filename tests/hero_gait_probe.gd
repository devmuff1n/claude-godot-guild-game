extends SceneTree
## Скорость шага клипов ходьбы/бега 3D-героев: как быстро опорная (нижняя) стопа едет назад в системе героя.
## Это скорость, с которой герой должен двигаться, чтобы ноги не скользили (м/с, с учётом масштаба сцены).
## godot --headless --path . -s res://tests/hero_gait_probe.gd

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
		var skel: Skeleton3D = h.find_children("*", "Skeleton3D", true, false)[0]
		var feet := []
		for b in skel.get_bone_count():
			var bn := skel.get_bone_name(b)
			if bn.ends_with("LeftToeBase") or bn.ends_with("RightToeBase") or bn.ends_with("LeftToes") or bn.ends_with("RightToes"):
				feet.append(b)
		var head := -1
		for b in skel.get_bone_count():
			if skel.get_bone_name(b).ends_with("Head"):
				head = b
		var out: Array = []
		for state in ["walk", "run"]:
			var clip: String = h.loops_mocap.get(state, "")
			if not h.anim.has_animation(clip):
				continue
			var a := h.anim.get_animation(clip)
			h.anim.play(clip, 0.0)
			h.anim.speed_scale = 1.0
			var n := 60
			var speeds: Array = []
			var prev := {}
			for i in n + 1:
				var t := a.length * i / n
				h.anim.seek(t, true)
				skel.force_update_all_bone_transforms()
				# опорная стопа — ниже всех; её смещение вдоль +Z (вперёд героя) между кадрами
				var low := -1
				var low_y := 1e9
				for f in feet:
					var p := (skel.global_transform * skel.get_bone_global_pose(f)).origin
					if p.y < low_y:
						low_y = p.y
						low = f
				var pz := (skel.global_transform * skel.get_bone_global_pose(low)).origin.z
				if prev.get("f", -2) == low and i > 0:
					speeds.append(-(pz - prev["z"]) / (a.length / n))
				prev = {"f": low, "z": pz}
			speeds.sort()
			var med: float = speeds[speeds.size() / 2] if not speeds.is_empty() else 0.0
			out.append("%s=%s len=%.2f stance_speed=%.2f m/s" % [state, clip, a.length, med])
		var hy := (skel.global_transform * skel.get_bone_global_pose(head)).origin.y
		print("GAIT %s scale=%.3f head_y=%.3f  %s" % [id, h.get_node("Model").scale.x, hy, "  ".join(out)])
		h.queue_free()
	quit()
