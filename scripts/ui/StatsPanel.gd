class_name StatsPanel
extends VBoxContainer
## Характеристики героя (scenes/ui/StatsPanel.tscn): основные плитки, атрибуты, боевые параметры.
## Формулы и пояснения — во всплывающих подсказках.

const STAT_ROW := preload("res://scenes/ui/StatRow.tscn")

func show_hero(hid: String) -> void:
	var h := Game.hero(hid)
	var d := Game.derived(hid)
	var nat := Stats.natural(hid, int(h["level"]))
	_tile(%TileHp, "ОЗ", "%d" % d["max_hp"], UIK.HP_COL.lightened(0.25), "Выносливость × 8 + 40")
	_tile(%TileMp, "МП", "%d" % d["max_mp"], UIK.MP_COL.lightened(0.25), "Интеллект × 12 + 60")
	_tile(%TileAtk, "АТАКА", "%d–%d" % [d["dmg_min"], d["dmg_max"]], UIK.INK, "Урон автоатаки: оружие + бонус от %s" % ("силы" if d["melee"] else ("ловкости" if d["wtype"] == "bow" else "интеллекта")))
	_tile(%TileArmor, "БРОНЯ", "%d" % d["armor"], UIK.INK, "Снижает физический урон на %d%%.\nЛовкость добавляет броню." % int(Stats.armor_reduction(d["armor"], int(h["level"])) * 100))
	UIK.clear(%Attrs)
	_row(%Attrs, "Выносливость", d["sta"], nat["sta"], "Здоровье")
	_row(%Attrs, "Сила", d["str"], nat["str"], "Атаки оружием ближнего боя")
	_row(%Attrs, "Ловкость", d["agi"], nat["agi"], "Атаки из лука и броня")
	_row(%Attrs, "Интеллект", d["int"], nat["int"], "Мана и сила заклинаний, лечения и щитов")
	UIK.clear(%Combat)
	_line(%Combat, "Сила заклинаний", "%d" % int(d["sp"]), "")
	_line(%Combat, "Крит. шанс", UIK.fmt_pct(d["crit"]), "Крит — ×1,75 урона, ×1,5 лечения")
	_line(%Combat, "Меткость", UIK.fmt_pct(d["hit"]), "")
	_line(%Combat, "Уклонение", UIK.fmt_pct(d["dodge"]), "")
	_line(%Combat, "Парирование", UIK.fmt_pct(d["parry"]) if d["parry"] > 0 else "—", "Только с мечом, булавой или кинжалом")
	_line(%Combat, "Блок", ("%s · %d" % [UIK.fmt_pct(d["block"]), d["block_val"]]) if d["block"] > 0 else "—", "Только со щитом: снижает физический удар на силу блока")
	_line(%Combat, "Интервал атаки", "%.1f с" % d["interval"], "")
	_line(%Combat, "Дальность", "%d" % int(d["range"]), "")
	%Resists.get_node("%Value").text = "%d · %d · %d" % [int(d["res_fire"]), int(d["res_shadow"]), int(d["res_nature"])]
	%Resists.tooltip_text = "Сопротивления: огонь %d · тьма %d · природа %d\nСнижают урон своей школы магии." % [int(d["res_fire"]), int(d["res_shadow"]), int(d["res_nature"])]

func _tile(t: PanelContainer, name: String, val: String, col: Color, tip: String) -> void:
	t.get_node("%Name").text = name
	var v: Label = t.get_node("%Value")
	v.text = val
	v.add_theme_color_override("font_color", col)
	t.tooltip_text = tip

func _row(parent: Control, name: String, total, own, tip: String) -> void:
	var bonus := int(total) - int(own)
	_line(parent, name, ("%d" % int(total)) + (("  +%d" % bonus) if bonus > 0 else ""), "%s\nСобственное значение: %d (для требований вещей)" % [tip, int(own)])

func _line(parent: Control, name: String, val: String, tip: String) -> void:
	var r: HBoxContainer = STAT_ROW.instantiate()
	parent.add_child(r)
	r.get_node("%Name").text = name
	r.get_node("%Value").text = val
	r.tooltip_text = tip
