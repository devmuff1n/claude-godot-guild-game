class_name HeroTile
extends Button
## Плитка героя в доме гильдии (scenes/ui/HeroTile.tscn): портрет, уровни, выгорание, свободные очки перков.

var hero_id := ""

func setup(hid: String) -> HeroTile:
	hero_id = hid
	var h := Game.hero(hid)
	var hd: Dictionary = DB.HEROES[hid]
	%Portrait.texture = UIK.portrait(hid)
	%Name.text = hd["full"]
	%Cls.text = String(hd["cls"]).to_upper()
	%Level.set_value(str(int(h["level"])))
	%Job.set_value(str(int(h["job"])))
	var bo := int(h["burnout"])
	%Burnout.value = bo
	%Burnout.color = UIK.GREEN if bo < 3 else (UIK.GOLD if bo < 6 else UIK.RED)
	%BurnoutBox.tooltip_text = "Выгорание %d/10 — %s" % [bo, "спокоен(на)" if bo < 3 else ("устал(а)" if bo < 6 else "на пределе")]
	var pts := Game.perk_points(hid)
	%PerkBadge.visible = pts > 0
	%PerkBadge.tooltip_text = "Свободные очки перков: %d" % pts
	tooltip_text = "%s — %s" % [hd["full"], hd["role"]]
	return self
