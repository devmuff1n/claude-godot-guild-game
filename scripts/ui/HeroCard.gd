class_name HeroCard
extends PanelContainer
## Карточка героя в походе (scenes/ui/HeroCard.tscn): портрет с номером и состоянием, ОЗ, МП, два заряда ATB.
## Все подписи фиксированной ширины — карточка не меняет размер, что бы ни происходило в бою.

signal pressed(hero_id: String)

@export var hero_id := "aiden"
var active := false
var alive := true

func _ready() -> void:
	%Portrait.texture = UIK.portrait(hero_id)
	%Name.text = DB.hero_name(hero_id)

func set_num(n: int) -> void:
	%Num.text = str(n)
	tooltip_text = "Команды героя — клик или клавиша %d" % n

func set_active(a: bool) -> void:
	if a == active:
		return
	active = a
	_update_style()

func _update_style() -> void:
	if active:
		theme_type_variation = &"PanelCardActive"
	else:
		theme_type_variation = &"PanelCard" if alive else &"PanelCardDown"

func update_from(hp: float, mhp: float, mp: float, mmp: float, atb: float, is_alive: bool, st: String) -> void:
	%HP.text = "%d/%d" % [int(ceil(hp)), int(mhp)]
	%HpBar.set_val(hp, mhp)
	var mp_t := "%d/%d" % [int(mp), int(mmp)]
	if %MP.text != mp_t:
		%MP.text = mp_t
		%MpBar.tooltip_text = "МП " + mp_t
	%MpBar.set_val(mp, mmp)
	%AtbBar.set_val(atb, 2.0)
	%State.text = st
	%StateBand.visible = st != ""
	if is_alive != alive:
		alive = is_alive
		_update_style()
		%Portrait.modulate = Color(1, 1, 1) if alive else Color(0.45, 0.3, 0.3)
		%Stats.modulate = Color(1, 1, 1) if alive else Color(0.6, 0.55, 0.55)

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(hero_id)
		accept_event()
