extends Node
## Ранги угрозы поручений: godot --headless --path . res://tests/ThreatCheck.tscn
func _ready() -> void:
	for cid in DB.STORY_ORDER + DB.SIDE_ORDER:
		var t := Game.contract_threat(cid)
		var fs := []
		for f in t["fights"]:
			fs.append("%.2f" % f)
		print("%s  %-26s ур.%d  ранг %-3s очки %.1f  для уровня %.2f  бои: %s" % [cid, DB.CONTRACTS[cid]["name"], int(DB.CONTRACTS[cid]["level"]), t["rank"], t["points"], t["score"], " ".join(fs)])
	get_tree().quit()
