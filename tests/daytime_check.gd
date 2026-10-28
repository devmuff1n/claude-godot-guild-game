extends Node
## Время суток по пунктам каждого поручения: правила DayTime и бои ночью.
## godot --headless --path . res://tests/DayTimeCheck.tscn
func _ready() -> void:
	var bad := 0
	for cid in DB.CONTRACTS.keys():
		var c: Dictionary = DB.CONTRACTS[cid]
		var times := DayTime.contract_times(cid)
		var route: Array = c.get("route", [{"type": "outpost", "name": "Застава"}])
		var line := []
		for i in route.size():
			line.append("%s=%s" % [route[i]["name"], DayTime.NAMES[times[i]]])
			if route[i]["type"] == "camp" and times[i] != "night":
				bad += 1
				print("  ! привал не ночью: ", cid, " ", route[i]["name"])
			if route[i]["type"] == "battle" and (times[i] == "night") != c.get("night", false):
				bad += 1
				print("  ! ночной бой не совпадает с флагом night: ", cid, " ", route[i]["name"])
		print(cid, ": ", ", ".join(line))
	print("DAYTIME ", "OK" if bad == 0 else "FAIL %d" % bad)
	get_tree().quit()
