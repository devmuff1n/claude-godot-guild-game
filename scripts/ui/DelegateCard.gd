class_name DelegateCard
extends PanelContainer
## Участник дипломатической миссии (scenes/ui/DelegateCard.tscn): портрет, имя, роль и шесть социальных черт.
## Герой отряда — портрет и черты с очками; сюжетный спутник (DB.STORY_NPCS) — буква вместо портрета, черты фиксированы.

func setup(id: String) -> DelegateCard:
	var npc: bool = DB.STORY_NPCS.has(id)
	var tex: Texture2D = null if npc else UIK.portrait(id)
	%Portrait.texture = tex
	%Initial.text = Game.dip_name(id).substr(0, 1) if tex == null else ""
	%Name.text = DB.STORY_NPCS[id]["full"] if npc else DB.HEROES[id]["full"]
	%Name.tooltip_text = DB.STORY_NPCS[id]["bio"] if npc else DB.HEROES[id]["bio"]
	%Role.text = DB.STORY_NPCS[id]["title"] if npc else DB.HEROES[id]["cls"]
	var rows := %Stats.get_children()
	for k in DB.SOCIAL_STATS.size():
		var st: String = DB.SOCIAL_STATS[k]
		var row: Control = rows[k]
		row.get_node("%Name").text = DB.SOCIAL_NAMES[st]
		row.get_node("%Value").text = str(Game.social_value(id, st))
		row.tooltip_text = DB.SOCIAL_DESC[st]
	return self
