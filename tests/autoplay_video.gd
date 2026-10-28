extends "res://tests/ui_smoke.gd"
## Запись прохождения поручения с новым сохранением (бот жмёт настоящие кнопки и способности).
## CID=c1 AFK=1 (без команд в бою) SLOW=6 (кадров на шаг) VSPEED=2 (скорость боя)
## xvfb-run godot --path . --rendering-driver opengl3 --write-movie out.avi --fixed-fps 30 -- с GUILD_UITEST=video

var helper = preload("res://tests/balance_test.gd").new()
var slow := 6
var afk := false

func wait(n := 2) -> void:
	for i in n * slow:
		await get_tree().process_frame

func bot(sim: BattleSim) -> void:
	if not afk:
		helper.bot(sim)

func _ready() -> void:
	main = get_parent()
	var cid := OS.get_environment("CID") if OS.get_environment("CID") != "" else "c1"
	afk = OS.get_environment("AFK") != ""
	if OS.get_environment("SLOW") != "":
		slow = int(OS.get_environment("SLOW"))
	var vspeed := float(OS.get_environment("VSPEED")) if OS.get_environment("VSPEED") != "" else 2.0
	await wait(2)
	Game.slot = -1
	Game.state = Game._fresh_state()
	Game.state["intro_seen"] = true
	main.goto("village")
	await wait(4)
	press("За работу")
	await wait(4)
	var v = main.current
	v.show_tab("board")
	await wait(4)
	var board = v.content.get_child(0)
	board.sel = cid
	board.general = DB.CONTRACTS[cid]["general"][0]
	board.pers_hero = "aiden"
	board.pers_obj = "healing"
	board.refresh()
	await wait(8)
	press("Выступить")
	await wait(4)
	var guard := 0
	var last_phase := ""
	while main.current.get_script().resource_path.ends_with("ExpeditionScreen.gd") and guard < 6000:
		guard += 1
		var es = main.current
		var e := Game.ex()
		if e.is_empty():
			await wait(1)
			continue
		if e["phase"] != last_phase:
			last_phase = e["phase"]
			p("phase %s node=%s" % [last_phase, str(e.get("node", ""))])
		match e["phase"]:
			"prebattle":
				await wait(6)
				press("В бой")
			"battle":
				es.speed = vspeed
				if es.sim != null:
					bot(es.sim)
				if es.sim != null and es.sim.s["phase"] == "prep":
					await wait(4)
					press("Следующая волна")
				if find_buttons(main, "Вернуться в деревню").size() > 0:
					p("battle over: " + str(es.sim.s.get("result", "")) if es.sim != null else "battle over")
					await wait(12)
					press("Вернуться в деревню")
			"event":
				await wait(10)
				if not press("В бой") and not press("Дальше"):
					for b in get_tree().get_nodes_in_group("event_choice"):
						if b.is_visible_in_tree() and not b.disabled:
							b.pressed.emit()
							break
			"camp":
				await camp_flow(es)
			"shop":
				await wait(6)
				press_tip("Купить: Лечебное зелье")
				await wait(6)
				press("Дальше в путь")
		await wait(1)
	p("finished guard=%d screen=%s completed=%s" % [guard, main.current.get_script().resource_path, str(Game.state["completed"])])
	await wait(25)
	get_tree().quit()
