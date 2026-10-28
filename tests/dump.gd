extends Node
## Печать размеров контролов, выходящих за экран
func _ready() -> void:
	await get_tree().create_timer(1.5).timeout
	_walk(get_tree().root, 0)
	get_tree().quit()
func _walk(n: Node, d: int) -> void:
	if n is Control and n.is_visible_in_tree():
		var r: Rect2 = n.get_global_rect()
		if r.end.x > 1605 and d < 14:
			print("  ".repeat(d), n.get_class(), " ", n.name, " ", r, " min=", n.get_combined_minimum_size(), (" '" + str(n.text).substr(0, 40) + "'") if "text" in n else "")
	for c in n.get_children():
		_walk(c, d + 1)
