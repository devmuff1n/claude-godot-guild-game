class_name ObjectivePanel
extends PanelContainer
## Объект боя (scenes/expedition/ObjectivePanel.tscn): повозка, ворота или сундук — прочность,
## запас ремкомплектов/материалов, кто чинит или тушит.

signal task_requested(kind: String, hero: String)
signal cancel_requested(hero: String)

func _ready() -> void:
	for id in DB.HERO_IDS:
		%RepairHero.add_item(DB.hero_name(id))
	%ExtButton.pressed.connect(func(): task_requested.emit("extinguish", selected_hero()))
	%RepButton.pressed.connect(func(): task_requested.emit("repair", selected_hero()))
	%CancelButton.pressed.connect(func(): cancel_requested.emit(selected_hero()))

func selected_hero() -> String:
	return DB.HERO_IDS[%RepairHero.selected]

func select_hero(hid: String) -> void:
	%RepairHero.select(DB.HERO_IDS.find(hid))

func setup(kind: String) -> void:
	%ObjName.text = BattleSim.OBJ_NAMES[kind]
	%ObjBar.color = Color(0.45, 0.82, 0.38) if kind == "wagon" else Color(0.95, 0.7, 0.25)
	select_hero("aiden" if kind == "wagon" else "elira")
	%RepButton.visible = kind != "chest"
	%Res.visible = kind != "chest"
	%Res.icon_kind = "cons" if kind == "wagon" else "material"
	%Res.cons_id = "kit" if kind == "wagon" else ""
	%Res.tooltip_text = "Ремкомплекты" if kind == "wagon" else "Материалы для ремонта ворот"
	%RepButton.tooltip_text = "+20%% за 4 с · тратит %s · герой выходит из боя" % ("ремкомплект" if kind == "wagon" else "материал")

## task_hero — юнит выбранного героя (или пустой словарь); any_burning — горит ли что-нибудь
func update(o: Dictionary, res_count: int, task_hero: Dictionary, any_burning: bool) -> void:
	%ObjPct.text = "%d%%" % int(round(o["hp"] / o["max"] * 100.0))
	%Fire.visible = o["burning"] > 0.0
	%ObjBar.set_val(o["hp"], o["max"])
	%Res.set_value(str(res_count))
	%ExtButton.disabled = not any_burning
	var busy: bool = not task_hero.is_empty() and task_hero["task"] != null
	# Полоса работы всегда занимает место — панель не меняет высоту
	%Progress.modulate.a = 1.0 if busy else 0.0
	%CancelButton.disabled = not busy
	if busy:
		var t: Dictionary = task_hero["task"]
		%Progress.set_val(t["t"], t["total"], "%s: %s" % [task_hero["name"], "ремонт" if t["type"] == "repair" else "тушение"])
