extends Node
## Снимки вступительной кат-сцены: GUILD_UITEST=intro GUILD_SHOT_DIR=папка godot --path .
## Новая игра → сцена «intro»: снимок каждой реплики и раз в 1,5 с на проездах; в конце — поселение.
## Проверяет, что сцена доходит до деревни и отмечает intro_seen. Ошибки — в stdout, код выхода 1.
var main

func _ready() -> void:
	main = get_parent()
	var dir := OS.get_environment("GUILD_SHOT_DIR")
	var skip_at := int(OS.get_environment("INTRO_SKIP")) if OS.get_environment("INTRO_SKIP") != "" else -1
	Game.slot = -1
	Game.state = Game._fresh_state()
	main.goto("intro")
	var n := 0
	var t := 0.0
	var idle := 0.0
	var fails := []
	while t < 240.0:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
		var scr = main.current
		if not (scr is IntroScreen):
			break
		if skip_at >= 0 and n >= skip_at:
			scr.skip()
			skip_at = -1
			continue
		if scr.waiting == "click":
			scr.get_node("%Text").visible_ratio = 1.0
			await get_tree().create_timer(0.5).timeout
			await _shot(dir, "%02d_say_%s" % [n, scr.speaker if scr.speaker != "" else "narr"])
			n += 1
			scr._advance()
			idle = 0.0
		else:
			idle += 0.25
			if idle >= 1.5:
				idle = 0.0
				await _shot(dir, "%02d_%s" % [n, scr.waiting if scr.waiting != "" else "run"])
				n += 1
	await get_tree().create_timer(2.0).timeout
	await _shot(dir, "%02d_village" % n)
	if not Game.state.get("intro_seen", false):
		fails.append("intro_seen не отмечен")
	if not main.current.get_script().resource_path.ends_with("VillageScreen.gd"):
		fails.append("после сцены не деревня")
	print("intro: %.1f s, кадров %d" % [t, n])
	for f in fails:
		print("FAIL: ", f)
	print("OK" if fails.is_empty() else "FAILED")
	get_tree().quit(0 if fails.is_empty() else 1)

func _shot(dir: String, name: String) -> void:
	if dir == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
