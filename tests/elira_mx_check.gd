extends SceneTree
## Elira (Mixamo clips) in the battle 3D frame: plays each state and saves one frame per state.
## godot --path . -s res://tests/elira_mx_check.gd   → user://elira_mx/<state>.png

const STATES := [["idle", 1.0], ["walk", 0.6], ["run", 0.4], ["cast", 0.9], ["cast_release", 0.25], ["attack", 1.1], ["hit", 0.4], ["dodge", 0.5], ["death", 0.6], ["death", 1.2], ["death", 2.0], ["death", 3.2]]

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := load("res://scenes/characters/EliraMX3D.tscn") as PackedScene
	var spr := Hero3DSprite.new(scene)
	root.add_child(spr)
	var tr := TextureRect.new()
	root.add_child(tr)
	await process_frame
	var hero: HeroModel3D = spr.hero
	print("ELIRA clips=", hero.anim.get_animation_list().size(), " has MX_Shot=", hero.anim.has_animation("MX_Shot"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://elira_mx"))
	for s in STATES:
		if s[0] in ["walk", "run"]:
			spr.drive({"moving": true, "speed_mps": 0.9 if s[0] == "walk" else 1.7, "x": 0.0}, 1)
		elif s[0] == "cast":
			spr.drive({"cast": true, "x": 0.0}, 1)
		elif s[0] == "cast_release":
			spr.drive({"cast": false, "x": 0.0}, 1)
		elif s[0] == "death":
			spr.drive({"dead": true, "x": 0.0}, 1)
		else:
			spr.drive({"x": 0.0}, 1)
			if s[0] != "idle":
				spr.one_shot(s[0])
		var t := 0.0
		while t < s[1]:
			await process_frame
			t += 1.0 / 60.0
		await RenderingServer.frame_post_draw
		var img := spr.get_texture().get_image()
		img.save_png("user://elira_mx/%s_%d.png" % [s[0], int(s[1] * 10)])
		print("STATE ", s[0], " clip=", hero.anim.current_animation, " t=", hero.anim.current_animation_position, " playing=", hero.anim.is_playing())
	print("SAVED ", ProjectSettings.globalize_path("user://elira_mx"))
	quit()
