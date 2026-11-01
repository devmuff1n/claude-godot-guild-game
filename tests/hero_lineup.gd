extends SceneTree
## Четыре 3D-героя рядом в кадре боя (Hero3DSprite): рост и клипы состояний на одной картинке.
## godot --path . -s res://tests/hero_lineup.gd -- <out.png> <state> [кадров] [шаг, с] [скорость м/с]
## state: idle | walk | run | <разовое состояние, например attack>. Строки — моменты времени, столбцы — герои.

const HEROES := ["marek", "aiden", "elira", "neris"]
const SCENES := {
	"elira": "res://scenes/characters/EliraMX3D.tscn",
	"marek": "res://scenes/characters/MarekMX3D.tscn",
	"neris": "res://scenes/characters/NerisMX3D.tscn",
	"aiden": "res://scenes/characters/AidenMX3D.tscn",
}


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://lineup.png"
	var state: String = args[1] if args.size() > 1 else "idle"
	var rows := int(args[2]) if args.size() > 2 else 1
	var step := float(args[3]) if args.size() > 3 else 0.15
	var mps := float(args[4]) if args.size() > 4 else 1.0
	var sprites: Array = []
	for id in HEROES:
		var spr := Hero3DSprite.new(load(SCENES[id]))
		root.add_child(spr)
		sprites.append(spr)
	await process_frame
	for spr in sprites:
		_drive(spr, state, mps)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 600:
		for spr in sprites:
			_drive(spr, state, mps)
		await process_frame
	if state not in ["idle", "walk", "run"]:
		for spr in sprites:
			spr.one_shot(state)
	var f := Hero3DSprite.FRAME
	var sheet := Image.create(f * HEROES.size(), f * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.42, 0.36, 0.3))
	for r in rows:
		var t1 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < step * 1000.0:
			for spr in sprites:
				_drive(spr, state, mps)
			await process_frame
		await RenderingServer.frame_post_draw
		for i in sprites.size():
			var img: Image = sprites[i].get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			sheet.blend_rect(img, Rect2i(0, 0, f, f), Vector2i(i * f, r * f))
	# линии роста: 1,6 / 1,7 / 1,8 м над точкой опоры
	var foot_y := int(Hero3DSprite.FRAME - Hero3DSprite.FOOT_PAD_M * Hero3DSprite.PX_PER_M)
	for m in [1.6, 1.7, 1.8]:
		var y := foot_y - int(m * Hero3DSprite.PX_PER_M)
		for x in sheet.get_width():
			if x % 6 < 3:
				sheet.set_pixel(x, y, Color(1, 1, 1, 0.6))
	for x in sheet.get_width():
		sheet.set_pixel(x, foot_y, Color(0, 0, 0))
	sheet.save_png(out)
	print("SAVED ", out)
	quit()


func _drive(spr: Hero3DSprite, state: String, mps: float) -> void:
	var st := {"x": 0.0}
	if state in ["walk", "run"]:
		st = {"moving": true, "x": 0.0, "speed_mps": mps}
	spr.drive(st, 1)
