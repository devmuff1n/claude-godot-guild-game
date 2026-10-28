extends Node
## Отладочный запуск похода по 3D-уровню без записи сохранений (как GUILD_START, но из редактора, F6).
## Поручение выбирается свойством cid в инспекторе.

@export var cid := "c1"


func _ready() -> void:
	var main: Control = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	Game.slot = -1
	Game.state = Game._fresh_state()
	Game.state["intro_seen"] = true
	for c in DB.STORY_ORDER:
		if c != cid:
			Game.state["completed"][c] = 1
	Game.start_expedition(cid, {"purse": 50, "general": "no_ko", "personal": {"hero": "elira", "obj": "kills"}})
	main.goto("expedition")
