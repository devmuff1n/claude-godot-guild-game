extends Node
## Скриншоты одной кат-сцены: GUILD_UITEST=cutshots CUT=c7_druid GUILD_SHOT_DIR=папка godot --path .
## Открывает поход её поручения, ставит отряд на её место и снимает каждую реплику (бой сцены пропускается).
var main

func _ready() -> void:
	main = get_parent()
	var id := OS.get_environment("CUT")
	var dir := OS.get_environment("GUILD_SHOT_DIR")
	var cs: Dictionary = DB.CUTSCENES[id]
	var cid: String = cs["contract"]
	Game.slot = -1
	Game.state = Game._fresh_state()
	Game.state["intro_seen"] = true
	var k := DB.STORY_ORDER.find(cid)
	if k < 0:
		k = DB.STORY_ORDER.find(DB.CONTRACTS[cid]["requires"][0]) + 1
	for i in k:
		Game.state["completed"][DB.STORY_ORDER[i]] = 1
	Game.state["story_stage"] = k
	Game.start_expedition(cid, {"purse": 60, "general": DB.CONTRACTS[cid]["general"][0], "personal": {}})
	var end := typeof(cs["node"]) == TYPE_STRING
	if end:
		Game.ex()["node"] = DB.route_len(cid)
	for c in DB.CUTSCENES.keys():
		if c != id:
			Game.state["cutscenes_seen"][c] = 1
	main.goto("expedition")
	var n := 0
	var t := 0.0
	while t < 90.0:
		await get_tree().create_timer(0.3).timeout
		t += 0.3
		var es = main.current
		if not es.get_script().resource_path.ends_with("ExpeditionScreen.gd"):
			break
		var cut: Cutscene = es.cutscene
		if cut.waiting == "fight" and es.sim != null:
			for u in es.sim.s["units"]:
				if u["side"] == "enemy":
					u["hp"] = 1.0
			es.speed = 3.0
		if cut.active and cut.waiting == "click" and cut.since_show > 0.6:
			await RenderingServer.frame_post_draw
			n += 1
			get_viewport().get_texture().get_image().save_png("%s/%s_%02d.png" % [dir, id, n])
			cut._advance()
			if n >= int(OS.get_environment("MAXSHOTS") if OS.get_environment("MAXSHOTS") != "" else "99"):
				break
		if Game.state["cutscenes_seen"].has(id) and Game.story().is_empty():
			break
	print("[SHOTS] ", id, " ", n)
	get_tree().quit()
