extends Node
## Кат-сцена c1 «Красноглазый волк»: GUILD_UITEST=cutscene godot --path .
## Проверяет: отряд останавливается посреди пути, сцена продолжается после «загрузки» посреди разговора
## и посреди боя, волк-проекция не оставляет тела, после сцены отряд идёт дальше, повторно сцена не играет.
## GUILD_SHOT_DIR=папка — скриншоты каждой реплики и боя (нужно окно, не --headless).
var main
var shots := ""
var n_shot := 0
var fails := 0

func p(t: String) -> void:
	print("[CUT] ", t)

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
	p(("ok   " if ok else "FAIL ") + what)

func wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func shot(tag: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	n_shot += 1
	get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [shots, n_shot, tag])

func es():
	return main.current

func _ready() -> void:
	main = get_parent()
	shots = OS.get_environment("GUILD_SHOT_DIR")
	await wait(0.5)
	main._debug_start("battle")
	var t := 0.0
	while Game.story().is_empty() and t < 20.0:
		await wait(0.1)
		t += 0.1
	check(not Game.story().is_empty(), "сцена началась на пути к первому пункту")
	check(int(Game.ex()["node"]) == 0 and Game.ex()["phase"] == "walk", "отряд стоит посреди отрезка, пункт 0")
	var wt: float = Game.ex()["walk_t"]
	# Первая реплика, затем «загрузка» посреди разговора
	await _until_click()
	await _click_n(2)
	main.goto("expedition")
	await wait(0.6)
	check(es().cutscene.active and es().cutscene.i <= 2, "после загрузки сцена идёт с начала")
	check(is_equal_approx(float(Game.ex()["walk_t"]), wt), "отряд не сдвинулся с места")
	# Разговор до боя
	while es().cutscene.waiting != "fight":
		await _until_click()
		if es().cutscene.waiting == "fight":
			break
		await shot("say")
		await _click_n(1)
	await wait(0.5)
	check(es().sim != null and Game.ex()["battle_ctx"]["source"] == "story", "бой из сцены начался")
	var wolf = null
	for u in es().sim.s["units"]:
		if u["side"] == "enemy":
			wolf = u
	check(wolf != null and wolf["key"] == "red_wolf" and wolf["x"] < 1300.0, "волк стал врагом там, где стоял (x=%s)" % (wolf["x"] if wolf else "?"))
	await wait(1.5)
	await shot("fight")
	# «Загрузка» посреди боя
	main.goto("expedition")
	await wait(0.5)
	check(es().sim != null, "бой восстановлен после загрузки")
	es().paused = false
	es().speed = 3.0
	t = 0.0
	while es().sim != null and es().sim.s["phase"] == "fight" and t < 60.0:
		await wait(0.1)
		t += 0.1
	await wait(0.4)
	await shot("ash")
	check(es().view.ash.size() > 0, "волк рассыпался пеплом")
	t = 0.0
	while not es().cutscene.active and t < 5.0:
		await wait(0.1)
		t += 0.1
	check(es().cutscene.active, "после боя сцена продолжилась")
	var corpse_wolf := false
	for c in es().view.corpses:
		if c["look"] == "wolf_shade":
			corpse_wolf = true
	check(not corpse_wolf, "тела волка на дороге нет")
	while es().cutscene.active:
		await _until_click()
		if not es().cutscene.active:
			break
		await shot("after")
		await _click_n(1)
	await wait(0.5)
	check(Game.story().is_empty() and Game.state["cutscenes_seen"].has("c1_red_eyes"), "сцена отмечена увиденной")
	var w0: float = Game.ex()["walk_t"]
	await wait(0.6)
	check(float(Game.ex()["walk_t"]) > w0, "отряд пошёл дальше")
	check(Game.cutscene_due() == "", "повторно сцена не играет")
	p("готово, ошибок: %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _until_click() -> void:
	var t := 0.0
	while es().cutscene.active and es().cutscene.waiting != "click" and t < 15.0:
		await wait(0.1)
		t += 0.1
	await wait(0.5)

func _click_n(k: int) -> void:
	for j in k:
		es().cutscene._advance()
		await wait(0.4)
