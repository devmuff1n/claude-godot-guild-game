class_name CampPanel
extends Control
## Привал (scenes/ui/CampPanel.tscn): разговоры, сцены у костра, личный вечер с подарком, отдых.

const CAMP_ROW := preload("res://scenes/ui/CampHeroRow.tscn")
const CHIP := preload("res://scenes/ui/ChipButton.tscn")
const CHOICE := preload("res://scenes/ui/ChoiceButton.tscn")
const TALK_BTN := preload("res://scenes/ui/TalkButton.tscn")

var screen   # ExpeditionScreen
var evening_pick := ""

@onready var dlg_box: VBoxContainer = %DialogBox

func _ready() -> void:
	%RestButton.pressed.connect(func(): screen.camp_leave())
	%JournalButton.pressed.connect(func():
		%Journal.refresh()
		%JournalPopup.visible = true)
	%CloseJournal.pressed.connect(func(): %JournalPopup.visible = false)
	%DlgOk.pressed.connect(func():
		camp().erase("dialog")
		Game.save()
		refresh())
	refresh()

func camp() -> Dictionary:
	return Game.ex()["camp"]

func refresh() -> void:
	_fill_left()
	_fill_dialog()

func _chip(parent: Control, text: String, cb: Callable, tip := "", on := false, disabled := false) -> Button:
	var b: Button = CHIP.instantiate()
	b.text = text
	b.tooltip_text = tip
	b.disabled = disabled
	UIK.mark(b, on)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _fill_left() -> void:
	var e := Game.ex()
	var busy: bool = camp().has("dialog") and camp()["dialog"].get("kind", "") != "result"
	UIK.clear(%PartyStatus)
	for id in DB.HERO_IDS:
		var d := Game.derived(id)
		var hs: Dictionary = e["hero_state"][id]
		var row: HBoxContainer = CAMP_ROW.instantiate()
		%PartyStatus.add_child(row)
		row.get_node("%Portrait").texture = UIK.portrait(id)
		row.get_node("%Name").text = DB.hero_name(id)
		row.get_node("%Hp").set_val(hs["hp"], d["max_hp"])
		row.get_node("%Mp").set_val(hs["mp"], d["max_mp"])
		row.tooltip_text = "ОЗ %d/%d · МП %d/%d" % [int(hs["hp"]), d["max_hp"], int(hs["mp"]), d["max_mp"]]
	%RestButton.disabled = busy
	# Разговоры
	UIK.clear(%TalkList)
	for hid in DB.COMPANIONS:
		var h: String = hid
		var r := Game.rel("aiden", hid)
		var t = Game.next_topic(hid)
		var txt := ""
		var dis := busy
		var tip := "Дружба %d (%s) · симпатия: %s" % [int(r["friend"]), DB.friend_stage(int(r["friend"])), DB.romance_stage(int(r["romance"]))]
		if camp().get("talked_" + hid, false):
			txt = "%s — поговорили ✔" % DB.hero_name(hid)
			dis = true
		elif t == null:
			txt = "%s — всё обсудили" % DB.hero_name(hid)
			dis = true
		elif t.get("locked", false):
			txt = "%s — «%s» (позже)" % [DB.hero_name(hid), t["title"]]
			dis = true
			var need := []
			if int(r["friend"]) < int(t["need_friend"]):
				need.append("дружба %d" % t["need_friend"])
			if int(Game.state["story_stage"]) < int(t["need_story"]):
				need.append("сюжетных поручений: %d" % t["need_story"])
			tip += "\nОткроется: " + ", ".join(need)
		else:
			txt = "%s — «%s»" % [DB.hero_name(hid), t["title"]]
		var b: Button = TALK_BTN.instantiate()
		b.text = txt
		b.icon = UIK.portrait(hid)
		b.disabled = dis
		b.tooltip_text = tip
		b.pressed.connect(func(): _open_topic(h))
		%TalkList.add_child(b)
	var ps = Game.next_pair_scene()
	%PairButton.visible = ps != null and not camp().get("pair", false)
	if %PairButton.visible:
		%PairButton.text = "У костра: %s" % ps["title"]
		%PairButton.disabled = busy
		for c in %PairButton.pressed.get_connections():
			%PairButton.pressed.disconnect(c["callable"])
		var scene: Dictionary = ps
		%PairButton.pressed.connect(func(): _open_pair(scene))
	# Личный вечер
	var done: bool = camp().get("evening", false)
	%EveningDone.visible = done
	%EveningPick.visible = not done
	if done:
		%EveningDone.text = "Вечер проведён: %s" % DB.hero_name(camp().get("evening_with", ""))
		return
	UIK.clear(%EveningHeroes)
	for hid in DB.COMPANIONS:
		var h2: String = hid
		var bo := int(Game.hero(hid)["burnout"])
		_chip(%EveningHeroes, DB.hero_name(hid), func():
			evening_pick = h2
			_fill_left(), "Выгорание: %d/10" % bo, evening_pick == hid, busy)
	UIK.clear(%GiftGrid)
	%GiftEmpty.visible = evening_pick != "" and Game.state["backpack"].is_empty()
	if evening_pick == "":
		return
	for g in Game.state["backpack"].keys():
		var gift: String = g
		var st := Game.pref_status(evening_pick, g)
		var mark: String = {"confirmed": " ♥", "assumed": " (?)", "no": " ✕", "ok": " ~"}.get(st, "")
		var tip2: String = {"confirmed": "Любимое.", "assumed": "Предположение из разговора.", "no": "Не понравилось.", "ok": "Неплохо, но не любимое."}.get(st, "")
		_chip(%GiftGrid, "%s ×%d%s" % [DB.consumable_name(g), int(Game.state["backpack"][g]), mark], func(): _evening(evening_pick, gift), tip2, false, busy)

func _open_topic(hid: String) -> void:
	var t = Game.next_topic(hid)
	if t == null or t.get("locked", false):
		return
	camp()["dialog"] = {"kind": "topic", "hero": hid, "topic": t["id"]}
	Game.save()
	refresh()

func _open_pair(ps: Dictionary) -> void:
	camp()["dialog"] = {"kind": "pair", "scene": ps["id"]}
	Game.save()
	refresh()

func _topic_by_id(hid: String, tid: String) -> Dictionary:
	for t in DB.TOPICS[hid]:
		if t["id"] == tid:
			return t
	return {}

func _scene_by_id(sid: String) -> Dictionary:
	for p in DB.PAIR_SCENES:
		if p["id"] == sid:
			return p
	return {}

func _fill_dialog() -> void:
	UIK.clear(%DlgChoices)
	var d: Dictionary = camp().get("dialog", {})
	var who: String = d.get("hero", "")
	%PortraitFrame.visible = who != ""
	if who != "":
		%DlgPortrait.texture = UIK.portrait(who)
	%DlgOk.visible = d.get("kind", "") == "result"
	%DlgOk.get_parent().visible = %DlgOk.visible
	if d.is_empty():
		%DialogPanel.visible = false
		%NamePlate.visible = false
		return
	%DialogPanel.visible = true
	%NamePlate.visible = who != ""
	%Speaker.text = DB.HEROES[who]["full"] if who != "" else ""
	match d["kind"]:
		"topic":
			var t := _topic_by_id(who, d["topic"])
			%DlgTitle.text = t["title"]
			%DlgText.text = "\n".join(t["lines"])
			var i := 0
			for ch in t["choices"]:
				var ci := i
				var b: Button = CHOICE.instantiate()
				b.text = ("«%s»" % ch["text"]) + ("  ♥" if ch.get("romance", 0) > 0 else "")
				b.alignment = HORIZONTAL_ALIGNMENT_LEFT
				b.theme_type_variation = &"ButtonCommand"
				if not Game.choice_allowed(who, ch):
					b.disabled = true
					b.tooltip_text = "Нужна взаимная симпатия."
				elif ch.get("romance", 0) > 0:
					b.tooltip_text = "Романтический ответ: меняет симпатию."
				b.pressed.connect(func(): _pick_topic(who, t, ci))
				%DlgChoices.add_child(b)
				i += 1
		"pair":
			var p := _scene_by_id(d["scene"])
			%DlgTitle.text = p["title"]
			%DlgText.text = "\n".join(p["lines"])
			var j := 0
			for ch in p["choices"]:
				var cj := j
				var b2: Button = CHOICE.instantiate()
				b2.text = ch["text"]
				b2.alignment = HORIZONTAL_ALIGNMENT_LEFT
				b2.theme_type_variation = &"ButtonCommand"
				b2.pressed.connect(func(): _pick_pair(p, cj))
				%DlgChoices.add_child(b2)
				j += 1
		"result":
			%DlgTitle.text = ""
			%DlgText.text = d.get("text", "")

func _pick_topic(hid: String, t: Dictionary, ci: int) -> void:
	camp()["dialog"] = {"kind": "result", "hero": hid, "text": Game.do_topic(hid, t, ci)}
	Game.save()
	refresh()

func _pick_pair(p: Dictionary, ci: int) -> void:
	camp()["dialog"] = {"kind": "result", "text": Game.do_pair_scene(p, ci)}
	Game.save()
	refresh()

func _evening(hid: String, gift: String) -> void:
	var out := Game.personal_evening(hid, gift)
	if out == "":
		return
	camp()["dialog"] = {"kind": "result", "hero": hid, "text": "%s\n\n%s" % [DB.consumable_name(gift), out]}
	evening_pick = ""
	Game.save()
	refresh()
