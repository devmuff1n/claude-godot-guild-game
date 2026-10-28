class_name RelBlock
extends VBoxContainer
## Отношения пары (scenes/ui/RelBlock.tscn): дружба и, отдельно, симпатия; по желанию — последние записи истории.

const TEXT_LINE := preload("res://scenes/ui/TextLine.tscn")

func setup(a: String, b: String, show_romance: bool, history := 0) -> RelBlock:
	var r := Game.rel(a, b)
	var f := int(r["friend"])
	%Title.text = "%s и %s" % [DB.hero_name(a), DB.hero_name(b)]
	%Friend.set_val(clamp(f + 50, 0, 150), 150, "%d · %s" % [f, DB.friend_stage(f)])
	%RomanceRow.visible = show_romance
	if show_romance:
		%Romance.set_val(int(r["romance"]), 40, "%d · %s" % [int(r["romance"]), DB.romance_stage(int(r["romance"]))])
	UIK.clear(%History)
	var n := 0
	for hh in r["history"]:
		if n >= history:
			break
		var d := ""
		if int(hh["friend"]) != 0:
			d += " дружба %s%d" % ["+" if int(hh["friend"]) > 0 else "", int(hh["friend"])]
		if int(hh["romance"]) != 0:
			d += " симпатия +%d" % int(hh["romance"])
		var l: Label = TEXT_LINE.instantiate()
		l.theme_type_variation = &"TinyLabel"
		l.text = "   • %s (%s)" % [hh["text"], d.strip_edges()]
		%History.add_child(l)
		n += 1
	return self
