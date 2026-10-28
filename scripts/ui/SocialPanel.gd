class_name SocialPanel
extends VBoxContainer
## Черты характера героя (scenes/ui/SocialPanel.tscn): шесть социальных черт, «+» за свободное очко, сброс.
## Строки — из scenes/ui/SocialRow.tscn; подробности — во всплывающих подсказках.

const ROW := preload("res://scenes/ui/SocialRow.tscn")

var hero_id := "aiden"

func _ready() -> void:
	%ResetButton.pressed.connect(func(): _toast(Game.reset_social(hero_id)))

func _toast(msg: String) -> void:
	if msg != "":
		Game.notify(msg)

func show_hero(id: String) -> void:
	hero_id = id
	var open := Game.social_unlocked()
	%Header.text = "ЧЕРТЫ ХАРАКТЕРА" + ("" if open else "  🔒")
	%Header.tooltip_text = "Проверки в дипломатии: d20 + черта против КС.\nОчко черты — за каждый Job Level. Предел черты — %d." % DB.SOCIAL_MAX
	if not open:
		%Header.tooltip_text += "\n\n" + Game.social_problem(id, DB.SOCIAL_STATS[0])
	UIK.clear(%Rows)
	var spent: Dictionary = Game.hero(id).get("social", {})
	for st in DB.SOCIAL_STATS:
		var row: HBoxContainer = ROW.instantiate()
		%Rows.add_child(row)
		var v := Game.social_value(id, st)
		var base := int(DB.SOCIAL_BASE[id].get(st, 0))
		row.get_node("%Name").text = DB.SOCIAL_NAMES[st]
		row.get_node("%Value").text = str(v)
		var pips: PipBar = row.get_node("%Pips")
		pips.count = DB.SOCIAL_MAX
		pips.value = v
		row.tooltip_text = "%s\n\nПрирода: %d · очки: %d" % [DB.SOCIAL_DESC[st], base, int(spent.get(st, 0))]
		var b: Button = row.get_node("%PlusButton")
		var prob := Game.social_problem(id, st)
		b.disabled = prob != ""
		b.tooltip_text = prob
		var stat: String = st
		b.pressed.connect(func(): _toast(Game.add_social(hero_id, stat)))
		row.modulate = Color(1, 1, 1) if open else Color(0.7, 0.67, 0.62)
	%ResetButton.disabled = not open or spent.is_empty() or Game.state["expedition"] != null
