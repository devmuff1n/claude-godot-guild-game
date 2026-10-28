extends Control
## Проверка событий в походе: для каждого узла-события открывает настоящий экран похода,
## ждёт наезд камеры и сохраняет кадры (до и после наезда) в generated-models/_demo/events/.

const OUT := "res://generated-models/_demo/events/"
const EXP := "res://scenes/screens/ExpeditionScreen.tscn"
const CIDS := ["c1", "c2", "c3", "c4", "c5", "c6", "c7"]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await get_tree().process_frame
	var only := OS.get_environment("EV_ONLY")
	for cid in CIDS:
		var route: Array = DB.CONTRACTS[cid]["route"]
		for k in route.size():
			if route[k]["type"] != "event":
				continue
			if only != "" and only != route[k]["event"]:
				continue
			await _shot(cid, k, route[k]["event"])
	print("[events] done")
	get_tree().quit()


func _shot(cid: String, k: int, ev: String) -> void:
	Game.slot = -1
	Game.state = Game._fresh_state()
	for c in DB.CONTRACTS:
		Game.state["completed"][c] = 1
	Game.state["treasury"] = 200
	var err := Game.start_expedition(cid, {"purse": 60})
	if err != "":
		print("[events] ERROR %s: %s" % [cid, err])
		return
	var e := Game.ex()
	for i in k:
		e["route"][i]["done"] = true
	e["node"] = k
	e["phase"] = "event"
	var scr: Control = (load(EXP) as PackedScene).instantiate()
	scr.set("params", {})
	add_child(scr)
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + "%s_n%d_a.png" % [cid, k])
	await get_tree().create_timer(2.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + "%s_n%d_b.png" % [cid, k])
	var lv = scr.get("level")
	var vw = scr.get("view")
	print("[events] %s n%d %s  cine=%s off=%s k=%s o=%s" % [cid, k, ev, lv.cine if lv else -1, lv._cine_off if lv else "", vw.scale, vw.position])
	scr.queue_free()
	Game.state["expedition"] = null
	await get_tree().process_frame
	await get_tree().process_frame
