extends "res://tests/ui_smoke.gd"
## Запись боя на дороге для проверки анимаций 3D-героев: бой (бот жмёт умения) → конец боя → ходьба.
## GUILD_UITEST=anim ANIM_START=fight_c5_2 ANIM_WALK=8 (секунд ходьбы после боя)
## Godot ... --write-movie out/f.png --fixed-fps 30   → кадры; лог состояний героев в stdout ([ANIM]).

var helper = preload("res://tests/balance_test.gd").new()
var frame := 0


func _ready() -> void:
	main = get_parent()
	# запись анимаций 3D-героев: вид «3d» (не сохраняется в настройках); ANIM_KEEP_LOOK=1 — вид из настроек
	if OS.get_environment("GUILD_HERO_LOOK") == "" and OS.get_environment("ANIM_KEEP_LOOK") == "":
		OS.set_environment("GUILD_HERO_LOOK", "3d")
	await get_tree().process_frame
	var start := OS.get_environment("ANIM_START") if OS.get_environment("ANIM_START") != "" else "fight_c5_2"
	var walk_s := float(OS.get_environment("ANIM_WALK")) if OS.get_environment("ANIM_WALK") != "" else 8.0
	main._debug_start(start)
	var es = main.current
	var guard := 0
	var won_at := -1
	while guard < 30 * 240:
		guard += 1
		frame += 1
		await get_tree().process_frame
		es = main.current
		var e := Game.ex()
		if es.get("sim") != null and es.sim != null and e.get("phase", "") == "battle":
			helper.bot(es.sim)
			if OS.get_environment("ANIM_SPEED") != "":
				es.speed = float(OS.get_environment("ANIM_SPEED"))
		if frame == 90 and OS.get_environment("ANIM_MENU_SHOT") != "":
			es._show_pause_menu()
			for i in 10:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(OS.get_environment("ANIM_MENU_SHOT"))
			p("SHOT menu")
			break
		if frame % 6 == 0:
			_log_models(es, String(e.get("phase", "")))
		if e.get("phase", "") == "walk" and won_at < 0:
			won_at = frame
			p("WON at frame %d" % frame)
		if won_at > 0 and frame - won_at == 75 and OS.get_environment("ANIM_SHOT_WALK") != "":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(OS.get_environment("ANIM_SHOT_WALK"))
			p("SHOT road")
			break
		if won_at > 0 and frame - won_at > walk_s * 30:
			break
		if e.get("phase", "") in ["event", "camp", "shop"]:
			break
	p("done frame=%d" % frame)
	get_tree().quit()


func _log_models(es, phase: String) -> void:
	var view = es.get("view")
	if view == null:
		return
	var parts: Array = []
	for k in view.models.keys():
		var m: Hero3DSprite = view.models[k]
		if m.unused_t > 0.5:
			continue
		var h: HeroModel3D = m.hero
		if h == null or h.anim == null:
			parts.append("%s:NOANIM" % k)
			continue
		parts.append("%s:%s@%.2f%s spd%.2f" % [k, h.anim.current_animation, h.anim.current_animation_position, "" if h.anim.is_playing() else "(STOP)", h.anim.speed_scale])
	print("[ANIM] f%d %s %s" % [frame, phase, " | ".join(parts)])
