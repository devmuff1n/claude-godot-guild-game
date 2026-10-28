class_name HeroRosterItem
extends Button
## Герой в списке отряда (scenes/ui/HeroRosterItem.tscn): портрет, имя, класс, уровни.

func setup(hid: String) -> HeroRosterItem:
	var h := Game.hero(hid)
	var hd: Dictionary = DB.HEROES[hid]
	%Portrait.texture = UIK.portrait(hid)
	%Name.text = hd["full"]
	%Sub.text = "%s · ур. %d · job %d" % [hd["cls"], int(h["level"]), int(h["job"])]
	var pts := Game.perk_points(hid)
	%Perk.visible = pts > 0
	%Perk.tooltip_text = "Свободные очки перков: %d" % pts
	return self
