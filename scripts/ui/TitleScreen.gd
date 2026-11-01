extends Control
## Титульный экран (scenes/screens/TitleScreen.tscn): логотип, главное меню и три слота сохранения.

const SLOT_ROW := preload("res://scenes/ui/SlotRow.tscn")
const SYSTEM_MENU := preload("res://scenes/ui/SystemMenu.tscn")

var main
var params: Dictionary = {}
var confirm_del := -1

@onready var slot_list: VBoxContainer = %SlotList

func _ready() -> void:
	%QuitButton.pressed.connect(func(): get_tree().quit())
	%SettingsButton.pressed.connect(show_settings)
	%ContinueLatest.pressed.connect(func():
		var i := _latest_slot()
		if i >= 0:
			load_game(i))
	refresh()

func refresh() -> void:
	UIK.clear(slot_list)
	for i in Game.SLOT_COUNT:
		var row: SlotRow = SLOT_ROW.instantiate()
		slot_list.add_child(row)
		row.setup(i, Game.slot_info(i), self)
	var latest := _latest_slot()
	%ContinueLatest.visible = latest >= 0
	if latest >= 0:
		var info := Game.slot_info(latest)
		%ContinueLatest.tooltip_text = "Слот %d · %s" % [latest + 1, str(info.get("saved", "")).replace("T", " ").substr(0, 16)]

## Слот с самым свежим сохранением (или -1)
func _latest_slot() -> int:
	var best := -1
	var best_t := ""
	for i in Game.SLOT_COUNT:
		var info := Game.slot_info(i)
		if info.is_empty() or info.get("broken", false):
			continue
		var t := str(info.get("saved", ""))
		if best < 0 or t > best_t:
			best = i
			best_t = t
	return best

## Настройки (вид героев, экран) — то же системное меню, без кнопок действий
func show_settings() -> void:
	var m: SystemMenu = SYSTEM_MENU.instantiate()
	add_child(m)
	m.setup("Настройки", [])
	m.chosen.connect(func(_a): m.queue_free())

func new_game(i: int) -> void:
	Game.new_game(i)
	main.goto("village")

func load_game(i: int) -> void:
	if not Game.load_slot(i):
		Game.notify("Не удалось загрузить сохранение.")
		return
	if Game.state.get("diplomacy") != null:
		main.goto("diplomacy")
		return
	main.goto("expedition" if Game.state["expedition"] != null else "village")

func ask_delete(i: int) -> void:
	if confirm_del == i:
		Game.delete_slot(i)
		confirm_del = -1
	else:
		confirm_del = i
	refresh()
