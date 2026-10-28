extends Control
## Испытательная арена (scenes/village/ArenaView.tscn): бой без последствий, пробные перки.

const CHIP := preload("res://scenes/ui/ChipButton.tscn")
const PRESET_BTN := preload("res://scenes/ui/PresetButton.tscn")
const PERK_ROW := preload("res://scenes/ui/ArenaPerkRow.tscn")

const PRESETS := [
	{"name": "Волчья стая", "groups": [["wolf", "wolf", "wolf_alpha"]], "ambush": ["wolf"]},
	{"name": "Разбойники с лучником", "groups": [["bandit", "archer", "bandit"]]},
	{"name": "Громила и поджигатель", "groups": [["brute", "arsonist", "bandit"]]},
	{"name": "Налётчики у повозки", "groups": [["raider", "raider", "arsonist"]], "wagon": {"hp": 500.0, "max": 500.0}},
	{"name": "Ганс Рыжий", "groups": [["captain", "bandit", "archer"]]},
	{"name": "Чемпион: Меченый", "groups": [["bandit", "archer"]], "champion": {"type": "bandit", "affix": "stone", "name": "Меченый"}},
	{"name": "Ночной дозор", "groups": [["archer", "bandit", "archer"]], "ambush": ["wolf"], "night": true},
]

var village
var preset := 0
var level := 2
var perks := {}

func _ready() -> void:
	level = max(1, int(Game.hero("aiden")["level"]))
	for id in DB.HERO_IDS:
		perks[id] = Game.hero(id)["perks"].duplicate()
	%LevelSlider.value = level
	%Level.set_value(str(level))
	%LevelSlider.value_changed.connect(func(val):
		level = int(val)
		%Level.set_value(str(level)))
	%StartButton.pressed.connect(_go)
	refresh()

func _chip(parent: Control, text: String, on: bool, cb: Callable, tip := "") -> void:
	var b: Button = CHIP.instantiate()
	b.text = text
	b.tooltip_text = tip
	parent.add_child(b)
	UIK.mark(b, on)
	b.pressed.connect(cb)

func refresh() -> void:
	UIK.clear(%PresetRow)
	for i in PRESETS.size():
		var idx := i
		var pr: Dictionary = PRESETS[i]
		var b: Button = PRESET_BTN.instantiate()
		%PresetRow.add_child(b)
		b.get_node("%Name").text = pr["name"]
		var names := []
		for g in pr["groups"]:
			for t in g:
				names.append(DB.ENEMIES[Balance.etype(t)]["name"])
		for t in pr.get("ambush", []):
			names.append(DB.ENEMIES[Balance.etype(t)]["name"] + " (засада)")
		b.get_node("%Sub").text = ", ".join(names) + (" · повозка" if pr.has("wagon") else "")
		UIK.mark(b, preset == i)
		b.pressed.connect(func():
			preset = idx
			refresh())
	UIK.clear(%PerkRows)
	for id in DB.HERO_IDS:
		var row: PanelContainer = PERK_ROW.instantiate()
		%PerkRows.add_child(row)
		row.get_node("%Portrait").texture = UIK.portrait(id)
		row.get_node("%Name").text = DB.hero_name(id)
		for stage in DB.PERK_STAGES.keys():
			var box: HBoxContainer = row.get_node("%Stage" + str(stage))
			for opt in [{"id": "", "name": "—"}] + DB.PERKS[id][stage]:
				var pid: String = opt["id"]
				var st: int = stage
				var hid: String = id
				_chip(box, opt["name"], perks[id].get(stage, "") == pid, func():
					perks[hid][st] = pid
					refresh(), opt.get("desc", ""))

func _go() -> void:
	var pr: Dictionary = PRESETS[preset].duplicate(true)
	pr["level"] = level
	village.start_arena(Game.arena_config(pr, perks))
