extends Node
func _ready() -> void:
	for d in ["res://scripts/ui", "res://scripts/ui/village", "res://scripts/ui/expedition"]:
		var dir := DirAccess.open(d)
		for f in dir.get_files():
			if f.ends_with(".gd"):
				var s = load(d + "/" + f)
				if s == null or not s.can_instantiate():
					print("FAIL ", f)
	for d in ["res://scenes", "res://scenes/screens", "res://scenes/village", "res://scenes/ui", "res://scenes/expedition"]:
		var dir2 := DirAccess.open(d)
		if dir2 == null:
			continue
		for f in dir2.get_files():
			if f.ends_with(".tscn"):
				var ps: PackedScene = load(d + "/" + f)
				if ps == null:
					print("FAIL scene ", f)
					continue
				var n = ps.instantiate()
				if n == null:
					print("FAIL inst ", f)
				else:
					n.free()
	print("CHECK DONE")
	get_tree().quit()
