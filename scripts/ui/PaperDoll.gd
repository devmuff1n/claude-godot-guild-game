class_name PaperDoll
extends Control
## «Кукла» героя (scenes/ui/PaperDoll.tscn): портрет и 10 слотов экипировки.
## Слева — броня, справа — украшения и оружие.

signal slot_right_clicked(slot_id: String)

var drop_cb: Callable:
	set(v):
		drop_cb = v
		if is_node_ready():
			for sl in DB.SLOTS:
				slot(sl).drop_cb = v

func _ready() -> void:
	for sl in DB.SLOTS:
		var s := slot(sl)
		var sid: String = sl
		s.drop_cb = drop_cb
		s.right_clicked.connect(func(_x): slot_right_clicked.emit(sid))

func slot(sl: String) -> ItemSlot:
	return get_node("%Slot_" + sl)

func show_hero(hid: String) -> void:
	var h := Game.hero(hid)
	%Portrait.texture = UIK.portrait(hid)
	var eq: Dictionary = h["equip"]
	for sl in DB.SLOTS:
		var s := slot(sl)
		s.placeholder = DB.SLOT_NAMES[sl]
		var it = eq[sl]
		var tip := ""
		s.tip_hero = hid
		s.tip_note = ""
		if it == null and sl == "off" and eq["main"] != null and int(Items.base_of(eq["main"]).get("hands", 1)) == 2:
			s.placeholder = "Занята"
			tip = "[color=#9d927c]Двуручное оружие занимает обе руки.[/color]"
		s.setup(it, {"kind": "equip", "hero": hid, "slot": sl}, tip)
