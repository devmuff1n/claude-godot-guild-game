class_name FingerPose3D
extends SkeletonModifier3D
## Держит пальцы в заданной позе поверх любого клипа (например, кулак на рукояти лука, пока мокап играет стойку).
## poses: индекс кости → поворот (локальная поза кости).

var poses := {}


func _process_modification_with_delta(_delta: float) -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	for bone in poses:
		skel.set_bone_pose_rotation(bone, skel.get_bone_pose_rotation(bone).slerp(poses[bone], influence))
