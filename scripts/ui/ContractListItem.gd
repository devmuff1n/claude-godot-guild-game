class_name ContractListItem
extends Button
## Строка списка поручений (scenes/ui/ContractListItem.tscn): номер, название, уровень, состояние.

func setup(cid: String) -> ContractListItem:
	var c: Dictionary = DB.CONTRACTS[cid]
	var avail := Game.contract_available(cid)
	var n := Game.contract_done_count(cid)
	%Num.text = str(int(c["story"])) if int(c["story"]) > 0 else "✦"
	%Name.text = c["name"]
	var xf := Game.contract_xp_factor(cid)
	%Sub.text = "Уровень %d" % int(c["level"]) + ((" · выполнено ×%d" % n) if n > 0 else "") + ((" · опыт %d%%" % int(round(xf * 100.0))) if xf < 1.0 and avail else "")
	%Rank.set_rank(Game.contract_threat(cid)["rank"], not avail)
	%State.kind = "lock" if not avail else ("check" if n > 0 else "xp")
	%State.tint = Color(1, 1, 1, 1) if avail else Color(1, 1, 1, 0.6)
	if not avail:
		%Name.add_theme_color_override("font_color", UIK.DIM)
		%Num.add_theme_color_override("font_color", UIK.DIM)
		var req := []
		for r in c["requires"]:
			req.append("«%s»" % DB.CONTRACTS[r]["name"])
		tooltip_text = "Откроется после: " + ", ".join(req)
	else:
		tooltip_text = ("Новое поручение\n" if n == 0 else "") + Game.threat_tip(cid)
		if xf < 1.0:
			tooltip_text += "\nОтряд выше уровнем: враги падают быстрее, опыта за них — %d%%." % int(round(xf * 100.0))
	return self
