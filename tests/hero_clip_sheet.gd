extends SceneTree
## Один 3D-герой в кадре боя: несколько клипов рядом (столбцы), моменты времени (строки).
## godot --path . -s res://tests/hero_clip_sheet.gd -- <out.png> <герой> <клип1,клип2,...> [строк] [шаг, с]

const SCENES := {
	"elira": "res://scenes/characters/EliraMX3D.tscn",
	"marek": "res://scenes/characters/MarekMX3D.tscn",
	"neris": "res://scenes/characters/NerisMX3D.tscn",
	"aiden": "res://scenes/characters/AidenMX3D.tscn",
}


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var clips: PackedStringArray = a[2].split(",")
	var rows := int(a[3]) if a.size() > 3 else 1
	var step := float(a[4]) if a.size() > 4 else 0.2
	var sprites: Array = []
	for c in clips:
		var spr := Hero3DSprite.new(load(SCENES[a[1]]))
		root.add_child(spr)
		sprites.append(spr)
	await process_frame
	for i in clips.size():
		var h: HeroModel3D = sprites[i].hero
		sprites[i].drive({"x": 0.0}, 1)
		if not h.anim.has_animation(clips[i]):
			print("NO CLIP ", clips[i])
			continue
		h.anim.play(clips[i], 0.0)
	var f := Hero3DSprite.FRAME
	var sheet := Image.create(f * clips.size(), f * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.42, 0.36, 0.3))
	for r in rows:
		var t1 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < step * 1000.0:
			for spr in sprites:
				spr.used = true
			await process_frame
		await RenderingServer.frame_post_draw
		for i in sprites.size():
			var img: Image = sprites[i].get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			sheet.blend_rect(img, Rect2i(0, 0, f, f), Vector2i(i * f, r * f))
	var foot_y := int(f - Hero3DSprite.FOOT_PAD_M * Hero3DSprite.PX_PER_M)
	for x in sheet.get_width():
		for r in rows:
			sheet.set_pixel(x, r * f + foot_y, Color(0, 0, 0))
	sheet.save_png(out)
	print("SAVED ", out)
	quit()
