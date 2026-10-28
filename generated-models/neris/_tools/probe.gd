extends SceneTree
func _init():
	print("VER ", Engine.get_version_info().string)
	print("HAS ", ClassDB.class_exists("SpringBoneSimulator3D"))
	var names := []
	for m in ClassDB.class_get_method_list("SpringBoneSimulator3D", true):
		names.append(m.name)
	print("M ", ",".join(names))
	quit()
