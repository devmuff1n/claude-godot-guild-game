class_name JournalView
extends HBoxContainer
## Журнал и отношения (scenes/ui/JournalView.tscn): досье спутников, факты (предположение/подтверждено),
## предпочтения, отношения пар и история.

const LIST_BTN := preload("res://scenes/ui/JournalListButton.tscn")
const REL_BLOCK := preload("res://scenes/ui/RelBlock.tscn")
const TEXT_LINE := preload("res://scenes/ui/TextLine.tscn")

var sel := "marek"

func _ready() -> void:
	refresh()

func _line(parent: Control, t: String, variation: String, col = null) -> Label:
	var l: Label = TEXT_LINE.instantiate()
	l.text = t
	l.theme_type_variation = StringName(variation)
	if col != null:
		l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l

func _rel(parent: Control, a: String, b: String, romance: bool, history := 0) -> void:
	var rb: RelBlock = REL_BLOCK.instantiate()
	parent.add_child(rb)
	rb.setup(a, b, romance, history)

func refresh() -> void:
	UIK.clear(%List)
	for id in DB.COMPANIONS + ["aiden", "pairs"]:
		var b: Button = LIST_BTN.instantiate()
		b.text = "Все пары и история" if id == "pairs" else (DB.HEROES[id]["full"] + ("" if id != "aiden" else " (вы)"))
		if id != "pairs":
			b.icon = UIK.portrait(id)
		UIK.mark(b, sel == id)
		var hid: String = id
		b.pressed.connect(func():
			sel = hid
			refresh())
		%List.add_child(b)
	%Dossier.visible = sel != "pairs"
	%Pairs.visible = sel == "pairs"
	if sel == "pairs":
		UIK.clear(%PairList)
		for pk in DB.all_pairs():
			var a: PackedStringArray = pk.split("|")
			_rel(%PairList, a[0], a[1], a[0] == "aiden", 4)
		return
	var id := sel
	var hd: Dictionary = DB.HEROES[id]
	%Portrait.texture = UIK.portrait(id)
	%Name.text = "%s · %s" % [hd["full"], hd["cls"]]
	%Role.text = String(hd["role"]).to_upper()
	%Bio.text = hd["bio"]
	var companion := id != "aiden"
	%CompanionBox.visible = companion
	%AidenBox.visible = not companion
	if not companion:
		UIK.clear(%AidenRels)
		for o in DB.COMPANIONS:
			_rel(%AidenRels, "aiden", o, true)
		return
	UIK.clear(%RelAiden)
	_rel(%RelAiden, "aiden", id, true)
	UIK.clear(%Prefs)
	var prefs: Dictionary = Game.state["knowledge"]["prefs"].get(id, {})
	if prefs.is_empty():
		_line(%Prefs, "Пока неизвестно.", "MutedLabel")
	for g in prefs.keys():
		var st: String = prefs[g]
		var txt: String = {"confirmed": "♥ %s — любимое (подтверждено)", "assumed": "? %s — кажется, любит (предположение)", "no": "✕ %s — не понравилось", "ok": "~ %s — неплохо"}.get(st, "%s") % DB.consumable_name(g)
		_line(%Prefs, txt, "SmallLabel", UIK.GREEN if st == "confirmed" else (UIK.GOLD if st == "assumed" else UIK.INK))
	UIK.clear(%Facts)
	var any := false
	for fid in DB.FACTS.keys():
		if DB.FACTS[fid]["hero"] != id:
			continue
		var st2: String = Game.state["knowledge"]["facts"].get(fid, "")
		if st2 == "":
			continue
		any = true
		var conf := st2 == "confirmed"
		_line(%Facts, ("✔ " if conf else "? ") + Game.fact_text(fid) + ("" if conf else "  [предположение]"), "SmallLabel", UIK.INK if conf else UIK.GOLD)
	if not any:
		_line(%Facts, "Записей пока нет.", "MutedLabel")
	UIK.clear(%Others)
	for o in DB.COMPANIONS:
		if o != id:
			_rel(%Others, id, o, false)
