extends SceneTree
## Marek (Mixamo clips) in the battle 3D frame: plays each state and saves one frame per state.
## godot --path . -s res://tests/marek_mx_check.gd   → user://marek_mx/<state>.png

const STATES := [["idle", 1.0], ["walk", 0.6], ["run", 0.4], ["cast", 0.9], ["cast_release", 1.0], ["attack", 0.4], ["attack", 0.7], ["skill_bash", 0.5], ["skill_cleave", 0.6], ["skill_taunt", 1.2], ["skill_wall", 0.5], ["skill_banner", 1.0], ["combo", 1.6], ["hit", 0.4], ["block_hit", 0.3], ["dodge", 0.5], ["victory", 2.0], ["death", 0.6], ["death", 1.2], ["death", 2.4]]

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := load("res://scenes/characters/MarekMX3D.tscn") as PackedScene
	var spr := Hero3DSprite.new(scene)
	root.add_child(spr)
	var tr := TextureRect.new()
	root.add_child(tr)
	await process_frame
	var hero: HeroModel3D = spr.hero
	print("MAREK clips=", hero.anim.get_animation_list().size())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://marek_mx"))
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
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < s[1] * 1000.0:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := spr.get_texture().get_image()
		img.save_png("user://marek_mx/%s_%d.png" % [s[0], int(s[1] * 10)])
		print("STATE ", s[0], " clip=", hero.anim.current_animation, " t=", hero.anim.current_animation_position, " playing=", hero.anim.is_playing())
	print("SAVED ", ProjectSettings.globalize_path("user://marek_mx"))
	quit()
