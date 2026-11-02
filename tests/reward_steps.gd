extends Node
## Снимки пошаговых итогов похода: GUILD_UITEST=reward CID=c1 GUILD_SHOT_DIR=папка godot --path .
## Первое выполнение поручения CID (уровни, добыча, выбор 1 из 3, итоги), щелчок «Далее» на каждом шаге.
## Потом — поселение с новыми зданиями. Ошибки — в stdout, код выхода 1.
var main

func _ready() -> void:
	main = get_parent()
	var cid := OS.get_environment("CID") if OS.get_environment("CID") != "" else "c1"
	var dir := OS.get_environment("GUILD_SHOT_DIR")
	Game.slot = -1
	Game.state = Game._fresh_state()
	Game.state["intro_seen"] = true
	var k := DB.STORY_ORDER.find(cid)
	for i in k:
		Game.state["completed"][DB.STORY_ORDER[i]] = 1
	Game.state["story_stage"] = k
	for id in DB.HERO_IDS:
		Game.hero(id)["level"] = k + 1
		Game.hero(id)["xp"] = DB.xp_to_next(k + 1)
	Game.start_expedition(cid, {"purse": 60, "general": DB.CONTRACTS[cid]["general"][0], "personal": {}})
	Game.ex()["counters"]["champions"] = 1
	var res := Game.finish_expedition("victory")
	main.goto("village", {"result": res})
	var fails := []
	var d: ResultDialog = null
	for c in main.current.overlay.get_children():
		if c is ResultDialog:
			d = c
	if d == null:
		print("FAIL: нет окна итогов")
		get_tree().quit(1)
		return
	print("pages: ", d.pages)
	if d.pages != ["heroes", "loot", "choice", "summary"]:
		fails.append("порядок шагов %s" % [d.pages])
	var n := 0
	while is_instance_valid(d) and d.is_inside_tree():
		await get_tree().create_timer(2.0).timeout
		var id: String = d.pages[d.page]
		await _shot(dir, "%d_%s" % [n, id])
		var sz: Vector2 = d.get_node("Center/Panel").size
		print("page %s panel %s" % [id, sz])
		if sz != Vector2(1300, 760):
			fails.append("окно %s: %s вместо 1300x760" % [id, sz])
		if id == "choice":
			if not d.get_node("%ContinueButton").disabled:
				fails.append("«Далее» доступна до выбора")
			var cards: Array = d.get_node("%ChoiceCards").get_children()
			if cards.size() != 3:
				fails.append("карточек выбора %d" % cards.size())
			d._pick(1)
			await get_tree().create_timer(0.4).timeout
			await _shot(dir, "%d_choice_picked" % n)
			if not Game.state["pending_choice"].is_empty():
				fails.append("выбор не записан")
		n += 1
		d._on_continue()
		if d.page < d.pages.size() and d.pages[d.page] == id and is_instance_valid(d):
			d._on_continue()
	await get_tree().create_timer(2.5).timeout
	await _shot(dir, "%d_town" % n)
	for f in fails:
		print("FAIL: ", f)
	print("OK" if fails.is_empty() else "FAILED")
	get_tree().quit(0 if fails.is_empty() else 1)

func _shot(dir: String, name: String) -> void:
	if dir == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
