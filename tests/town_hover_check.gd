extends Node
## Проверка поселения: наведение на здание подсвечивает его и показывает название, клик открывает вкладку.
## TOWN_SHOT=<png> — снимок с наведением на дом гильдии.

const CHECKS := [["GuildHall", "home"], ["Noticeboard", "board"], ["PartyInn", "party"], ["Market", "shop"], ["TrainingYard", "arena"]]

func _ready() -> void:
	Game.slot = -1
	Game.state = Game._fresh_state()
	Game.state["intro_seen"] = true
	var vs = load("res://scenes/screens/VillageScreen.tscn").instantiate()
	add_child(vs)
	print("[town] экран деревни создан")
	await get_tree().create_timer(1.0).timeout
	var ok := 0
	var shot := OS.get_environment("TOWN_SHOT")
	for c in CHECKS:
		if vs.tab != "town":
			vs.show_tab("town")
		await get_tree().process_frame
		await get_tree().process_frame
		var tv: Control = vs.content.get_child(0)
		var cont: SubViewportContainer = tv.get_node("%TownView")
		var cam: Camera3D = tv.cam
		var h: TownHotspot = tv.view.get_node("Town3D/Hotspots/" + c[0])
		var shape: CollisionShape3D = h.get_node("Shape")
		var p := cont.global_position + cam.unproject_position(shape.global_position) * cont.size / Vector2(tv.view.size)
		var mv := InputEventMouseMotion.new()
		mv.position = p
		mv.global_position = p
		get_viewport().push_input(mv)
		await get_tree().create_timer(0.3).timeout
		var hovered: bool = tv.hover.visible and tv.hover_label.text == h.title
		if shot != "" and c[0] == "GuildHall":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(shot)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = p
		click.global_position = p
		get_viewport().push_input(click)
		var up := click.duplicate()
		up.pressed = false
		get_viewport().push_input(up)
		await get_tree().create_timer(0.2).timeout
		var opened: bool = vs.tab == c[1]
		if hovered and opened:
			ok += 1
		print("[town] %-13s экран=(%d, %d) наведение=%s вкладка=%s %s" % [c[0], p.x, p.y, hovered, vs.tab, "OK" if hovered and opened else "FAIL"])
	print("[town] %d/%d зданий работают" % [ok, CHECKS.size()])
	get_tree().quit()
