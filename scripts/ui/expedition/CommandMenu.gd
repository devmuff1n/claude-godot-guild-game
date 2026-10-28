class_name CommandMenu
extends PanelContainer
## Меню команд героя в бою (scenes/expedition/CommandMenu.tscn): умения или зелья.
## Ширина фиксирована, у строк — отдельные колонки цены и перезарядки: при тикающих секундах ничего не сдвигается.

signal ability_chosen(ab: String)
signal potion_chosen(kind: String)
signal attack_chosen
signal closed

const ROW := preload("res://scenes/expedition/CommandRow.tscn")

var hero := ""
var items_mode := false
var _rows := {}   # ключ → Button

func _ready() -> void:
	%Close.pressed.connect(func(): closed.emit())
	%ModeButton.pressed.connect(func():
		items_mode = not items_mode
		_build())

func open_for(sim: BattleSim, hid: String) -> void:
	hero = hid
	_sim = sim
	_build()

var _sim: BattleSim

func _build() -> void:
	UIK.clear(%List)
	_rows = {}
	var u = _sim.hero_unit(hero)
	if u == null:
		return
	%HeroName.text = u["name"]
	if items_mode:
		for kind in ["potion_hp", "potion_mp"]:
			var pk: String = kind
			_add_row("p_" + kind, func(): potion_chosen.emit(pk))
		%ModeButton.text = "← Умения"
	else:
		_add_row("attack", func(): attack_chosen.emit())
		for ab in DB.HERO_ABILITIES[hero]:
			if int(u["level"]) < int(DB.ABILITIES[ab]["lvl"]):
				continue
			var a2: String = ab
			_add_row(ab, func(): ability_chosen.emit(a2))
		%ModeButton.text = "Зелья ▸"
	refresh()

func _add_row(key: String, cb: Callable) -> void:
	var b: Button = ROW.instantiate()
	%List.add_child(b)
	b.pressed.connect(cb)
	_rows[key] = b

func refresh() -> void:
	var u = _sim.hero_unit(hero)
	if u == null:
		return
	%Atb.set_val(u["atb"], 2.0)
	%Mp.text = "%d МП" % int(u["mp"])
	for k in _rows.keys():
		var b: Button = _rows[k]
		var name_l: Label = b.get_node("%Name")
		var cost_l: Label = b.get_node("%Cost")
		var cd_l: Label = b.get_node("%Cooldown")
		if k == "attack":
			var f = _sim.hero_focus(u)
			name_l.text = "Автоатака" if f == null else "Автоатака → %s" % f["name"]
			cost_l.text = ""
			cd_l.text = ""
			UIK.mark(b, f != null)
			b.disabled = not u["alive"]
			b.tooltip_text = "Выбрать врага: герой идёт к нему и бьёт только его.
Повторный выбор той же цели — снять приказ."
			continue
		if k.begins_with("p_"):
			var kind: String = k.substr(2)
			var n: int = int(_sim.s["potions"].get(kind, 0))
			name_l.text = "%s ×%d" % [DB.CONSUMABLES[kind]["name"], n]
			cost_l.text = "1 ATB"
			cd_l.text = ""
			var prob := ""
			if u["atb"] < 0.999:
				prob = "Нужен 1 заряд ATB."
			elif n <= 0:
				prob = "Нет в запасе."
			elif _sim.hero_busy(u) or _sim.is_stunned(u):
				prob = "Герой занят."
			b.disabled = prob != ""
			b.tooltip_text = DB.CONSUMABLES[kind]["desc"] + ("\n[%s]" % prob if prob != "" else "")
			continue
		var a: Dictionary = DB.ABILITIES[k]
		var cd: float = u["cds"].get(k, 0.0)
		name_l.text = a["name"]
		cost_l.text = "%d ATB · %d МП" % [_sim.ability_cost(u, k), a["mp"]]
		cd_l.text = ("%dс" % int(ceil(cd))) if cd > 0.0 else ""
		var prob2 := _sim.ability_problem(u["uid"], k)
		b.disabled = prob2 != ""
		var ct := _sim.ability_cast_time(u, k)
		var tip: String = a["desc"]
		if ct > 0.0:
			tip += "\nПодготовка %.1f с." % ct
		if a["cd"] > 0.0:
			tip += " Перезарядка %.0f с." % a["cd"]
		if prob2 != "":
			tip += "\n[%s]" % prob2
		b.tooltip_text = tip
