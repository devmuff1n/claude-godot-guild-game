extends SceneTree
## Отладка: где оказываются кисти и плечи Элиры в кадре клипа (сравнение с Blender).
func _init() -> void:
	var h: Node3D = load("res://scenes/characters/Elira3D.tscn").instantiate()
	root.add_child(h)
	await process_frame
	var ap: AnimationPlayer = h.find_children("*", "AnimationPlayer", true, false)[0]
	var sk: Skeleton3D = h.find_children("*", "Skeleton3D", true, false)[0]
	for clip in ["Bow_Aim", "Idle"]:
		ap.play(clip)
		ap.seek(0.0, true)
		ap.advance(0)
		await process_frame
		for b in ["Hips", "Spine", "Chest", "UpperChest", "LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightLowerArm", "RightHand", "Head"]:
			var i := sk.find_bone(b)
			print(clip, " ", b, " ", (sk.global_transform * sk.get_bone_global_pose(i)).origin.snapped(Vector3.ONE * 0.001))
	quit()
