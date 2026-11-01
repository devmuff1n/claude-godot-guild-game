class_name LevelUpDialog
extends Control
## Экран повышения уровня в духе Fire Emblem (scenes/ui/LevelUpDialog.tscn): у каждого героя строки
## «было → стало», выросшие значения по очереди «щёлкают» вверх. Клик по кнопке во время анимации — показать всё сразу.

signal closed

const CARD := preload("res://scenes/ui/LevelUpCard.tscn")
const ROW := preload("res://scenes/ui/LevelUpRow.tscn")
## [ключ, подпись, подсказка]
const ROWS := [
	["max_hp", "ОЗ", "Здоровье"], ["max_mp", "МП", "Мана"], ["dmg", "Урон", "Урон автоатаки"],
	["armor", "Броня", "Броня"], ["sp", "Сила закл.", "Сила заклинаний"],
	["sta", "Выносл.", "Выносливость"], ["str", "Сила", ""], ["agi", "Ловкость", ""], ["int", "Интеллект", ""],
]
const TICK := 0.09

var _tween: Tween

func _ready() -> void:
	%ContinueButton.pressed.connect(_on_continue)

## levels — res["levels"] из Game.finish_expedition: [{hero, from, to, abilities, before, after}]
func setup(levels: Array) -> LevelUpDialog:
	UIK.clear(%Cards)
	_tween = create_tween()
	_tween.tween_interval(0.05)
	var delay := 0.25
	for lu in levels:
		if not lu.has("before"):
			continue
		var card: PanelContainer = CARD.instantiate()
		%Cards.add_child(card)
		var hid: String = lu["hero"]
		card.get_node("%Portrait").texture = UIK.portrait(hid)
		card.get_node("%Name").text = DB.hero_name(hid)
		card.get_node("%Level").text = "Уровень %d → %d" % [int(lu["from"]), int(lu["to"])]
		var sk: Label = card.get_node("%Skills")
		sk.visible = lu["abilities"].size() > 0
		sk.text = "Новое умение: " + ", ".join(lu["abilities"])
		var b: Dictionary = lu["before"]
		var a: Dictionary = lu["after"]
		for r in ROWS:
			var row: HBoxContainer = ROW.instantiate()
			card.get_node("%Rows").add_child(row)
			row.get_node("%Name").text = r[1]
			row.tooltip_text = r[2]
			var old := _val(b, r[0])
			var new := _val(a, r[0])
			row.get_node("%Old").text = _fmt(b, r[0])
			var nl: Label = row.get_node("%New")
			var dl: Label = row.get_node("%Delta")
			nl.text = _fmt(b, r[0])
			dl.text = "+%d" % int(round(new - old))
			dl.modulate.a = 0.0
			if new <= old:
				row.modulate = Color(1, 1, 1, 0.5)
				dl.text = ""
				continue
			# Щелчок: значение пересчитывается до нового, дельта вспыхивает
			var key: String = r[0]
			_tween.parallel().tween_callback(func():
				nl.text = _fmt(a, key)
				nl.add_theme_color_override("font_color", UIK.GOLD_HI)
				dl.modulate.a = 1.0
				nl.pivot_offset = nl.size * 0.5
				var tw := nl.create_tween()
				tw.tween_property(nl, "scale", Vector2(1.25, 1.25), 0.06)
				tw.tween_property(nl, "scale", Vector2.ONE, 0.1)).set_delay(delay)
			delay += TICK
	%ContinueButton.text = "Продолжить"
	return self

func _val(d: Dictionary, k: String) -> float:
	if k == "dmg":
		return (float(d["dmg_min"]) + float(d["dmg_max"])) * 0.5
	return float(d.get(k, 0))

func _fmt(d: Dictionary, k: String) -> String:
	if k == "dmg":
		return "%d–%d" % [int(d["dmg_min"]), int(d["dmg_max"])]
	return "%d" % int(d.get(k, 0))

func _on_continue() -> void:
	if _tween != null and _tween.is_running():
		_tween.custom_step(999.0)
		return
	closed.emit()
