extends Node
## Записать текущий баланс (DB.gd + data/balance.json) в data/balance.json.
## godot --headless --path . res://tests/BalanceExport.tscn

func _ready() -> void:
	print("balance -> ", Balance.save_file(Balance.export_doc()))
	get_tree().quit()
