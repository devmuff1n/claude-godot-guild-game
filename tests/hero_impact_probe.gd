extends SceneTree
## Момент удара/выпуска в разовых клипах 3D-героев: когда кисть (или конец оружия) движется быстрее всего.
## По нему клип атаки запускается со сдвигом, чтобы удар на экране совпал с уроном в симуляции.
## godot --headless --path . -s res://tests/hero_impact_probe.gd

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
		var hands := []
		for b in skel.get_bone_count():
			var bn := skel.get_bone_name(b)
			if bn.ends_with("LeftHand") or bn.ends_with("RightHand") or bn in ["Sword", "Staff", "Bow"]:
				hands.append(b)
		var done := {}
		var out: Array = []
		for state in h.one_shots_mocap:
			var clip: String = h.one_shots_mocap[state]
			if done.has(clip) or not h.anim.has_animation(clip) or state in ["death", "hit", "dodge", "block_hit"]:
				continue
			done[clip] = true
			var a := h.anim.get_animation(clip)
			h.anim.play(clip, 0.0)
			var n := int(a.length * 30.0)
			var prev := {}
			var best_t := 0.0
			var best_v := 0.0
			for i in n + 1:
				var t := a.length * i / n
				h.anim.seek(t, true)
				skel.force_update_all_bone_transforms()
				for b in hands:
					var p := skel.get_bone_global_pose(b).origin
					if prev.has(b):
						var v: float = (p - prev[b]).length() * 30.0
						if v > best_v:
							best_v = v
							best_t = t
					prev[b] = p
			out.append("%s(%s) len=%.2f peak=%.2f v=%.1f" % [state, clip, a.length, best_t, best_v])
		print("IMPACT %s  %s" % [id, " | ".join(out)])
		h.queue_free()
	quit()
