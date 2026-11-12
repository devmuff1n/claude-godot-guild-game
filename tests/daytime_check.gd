extends Node
## Время суток по пунктам каждого поручения: правила DayTime и бои ночью.
## godot --headless --path . res://tests/DayTimeCheck.tscn
func _ready() -> void:
	Game.slot = -1
	Game.state = Game._fresh_state()
	for cid in DB.STORY_ORDER:
		Game.state["completed"][cid] = 1

	var bad := 0
	for cid in DB.CONTRACTS.keys():
		var c: Dictionary = DB.CONTRACTS[cid]
		var times := DayTime.contract_times(cid)
		var route: Array = c.get("route", [{"type": "outpost", "name": "Застава"}])
		if not c.has("diplomacy"):
			Game.state["expedition"] = null
			var problem := Game.start_expedition(cid, {})
			if problem != "":
				bad += 1
				print("  ! не удалось начать поход: ", cid, " — ", problem)
				continue
		var line := []
		for i in route.size():
			var node: Dictionary = route[i]
			var time: String = times[i]
			var combat: bool = node["type"] in ["battle", "outpost"]
			var expected: String = node.get("time", c.get("start_time", "morning") if i == 0 else "")
			# Привалы проходят ночью, а в пещерах тьма действует во всех боях.
			if node["type"] == "camp" or (combat and c.get("cave", false)):
				expected = "night"
			line.append("%s=%s" % [node["name"], DayTime.NAMES[time]])
			if expected != "" and time != expected:
				bad += 1
				print("  ! неверное время: ", cid, " ", node["name"], ", ожидалось ", DayTime.NAMES[expected])
			if combat:
				Game.ex()["node"] = i
				var cfg := Game.battle_config([], [], false, false)
				if cfg["night"] != (time == "night"):
					bad += 1
					print("  ! тьма в бою не соответствует времени узла: ", cid, " ", node["name"])
		print(cid, ": ", ", ".join(line))
	print("DAYTIME ", "OK" if bad == 0 else "FAIL %d" % bad)
	get_tree().quit(1 if bad > 0 else 0)
