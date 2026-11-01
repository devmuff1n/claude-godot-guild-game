extends Control
## Отдельная проверочная сцена: проходит 3D-уровни поручений, ставит камеру на каждый узел маршрута,
## рисует поверх настоящий BattleView с отрядом и сохраняет кадры в generated-models/_demo/levels/.

const LEVELS := ["c1", "c2", "c3", "c4", "c5", "c6", "c7"]
const NIGHT := ["c5"]
const SEG_PX := 260.0 * 2.6
const OUT := "res://generated-models/_demo/levels/"
const PARTY := ["marek", "aiden", "elira", "neris"]

@onready var vp: SubViewport = %LevelViewport
@onready var view: BattleView = %View


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	view.bg_3d = true
	view.walk_units = []
	for i in PARTY.size():
		view.walk_units.append({"look": PARTY[i], "x": BattleSim.FORMATION_X[i]})
	await _run()


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	for cid in LEVELS:
		var lvl := (load("res://scenes/levels/%s.tscn" % cid) as PackedScene).instantiate() as RoadLevel
		vp.add_child(lvl)
		view.night = cid in NIGHT
		var nodes: PackedStringArray = lvl.get_meta("nodes", PackedStringArray())
		for k in range(-1, nodes.size()):
			lvl.set_scroll((k + 1) * SEG_PX)
			for i in 4:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var label := "start" if k < 0 else "n%d" % k
			img.save_png(OUT + "%s_%s.png" % [cid, label])
			print("[levels] %s %s %s" % [cid, label, "" if k < 0 else nodes[k]])
		lvl.queue_free()
		await get_tree().process_frame
	print("[levels] done in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
