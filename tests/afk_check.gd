extends "res://tests/balance_test.gd"
## Сравнение: поручение без команд (AFK) и с командами бота, N прогонов с нового сохранения.
## CID=c1 N=20 godot --headless --path . res://tests/AfkCheck.tscn

func _ready() -> void:
	var cid := OS.get_environment("CID") if OS.get_environment("CID") != "" else "c1"
	var n := int(OS.get_environment("N")) if OS.get_environment("N") != "" else 10
	Game.slot = -1
	for mode in ["afk", "bot"]:
		var wins := 0
		for i in n:
			Game.state = Game._fresh_state()
			var r := run_contract(cid, mode == "bot")
			if r["res"]["kind"] == "victory":
				wins += 1
		print("%s %s: побед %d из %d" % [cid, mode, wins, n])
	get_tree().quit()
