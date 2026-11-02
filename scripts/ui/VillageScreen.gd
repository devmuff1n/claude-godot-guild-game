extends Control
## Деревня Ольховый Брод (scenes/screens/VillageScreen.tscn): верхняя панель, вкладки-сцены и окна поверх.

const TABS := {
	"town": "res://scenes/village/TownView.tscn",
	"home": "res://scenes/village/HomeView.tscn",
	"board": "res://scenes/village/BoardView.tscn",
	"shop": "res://scenes/village/ShopView.tscn",
	"party": "res://scenes/village/PartyView.tscn",
	"arena": "res://scenes/village/ArenaView.tscn",
}
## Фон под вкладкой (остальные — деревня)
const BACKGROUNDS := {
	"board": "res://assets/bg/board.png",
	"shop": "res://assets/bg/shop.png",
	"party": "res://assets/bg/party.png",
}
const SYSTEM_MENU := preload("res://scenes/ui/SystemMenu.tscn")
const RESULT := preload("res://scenes/ui/ResultDialog.tscn")
const STORY := preload("res://scenes/ui/StoryDialog.tscn")

const STORY_TEXT := [
	"Гильдия «Последний грош» — три комнаты, протекающая крыша и долги. Отец Тибальд умер зимой, оставив Эйдену ключи и расписки. Гильдию кормят лесные хутора, но этой осенью лес стал другим: звери выходят к дорогам, а хутора замолкают.",
	"Тропа в лес расчищена. Звери с красными глазами после гибели рассыпаются пеплом: это не звери, а чьи-то тени.",
	"Отряд дошёл до хутора Тимофея. Духи зверей кружат вокруг, а к воротам приходили люди с рогатыми амулетами.",
	"Хутор отбит у бандитов. Звери их не трогают, а сами бандиты зовут гильдию «тёмными» и обещают вернуться.",
	"Тимофей с дочерью Асей и обозом в доме гильдии. Но чужой разведчик видел, куда ушёл обоз.",
	"Штурм ворот гильдии отбит. Пленный рассказал, где посёлок бандитов и кому там молятся.",
	"Отряд дошёл до посёлка. Простые люди там голодают, а вожаки-фанатики отдают последнее рогатому идолу.",
	"Ганс Рыжий пал. Над пепелищем явился друид Морвен, хозяин лесной живности, и исчез, пообещав не оставить гильдию до скончания веков.",
	"О друиде узнали в столице. Пролог окончен: лес всё ещё в его руке, но гильдия больше не одна — а её люди стали друг другу больше, чем наёмниками.",
]

var main
var params: Dictionary = {}
var tab := "home"

@onready var content: Control = %Content
@onready var overlay: Control = %Overlay
@onready var top_bar: VillageTopBar = %TopBar

func _ready() -> void:
	top_bar.tab_selected.connect(show_tab)
	top_bar.menu_pressed.connect(show_menu)
	show_tab(params.get("tab", "town"))
	if params.has("result"):
		show_result(params["result"])
	elif not Game.state.get("intro_seen", false):
		_show_intro()
	elif not Game.state["pending_choice"].is_empty():
		show_pending_choice()

func show_tab(id: String, opts := {}) -> void:
	if not Game.feature_open(id):
		id = "town"
	Game.mark_feature_seen(id)
	if id == "shop":
		Game.mark_feature_seen("forge")
	tab = id
	top_bar.set_tab(id)
	var bg_path: String = BACKGROUNDS.get(id, "res://assets/bg/village.png")
	if ResourceLoader.exists(bg_path):
		$Background.texture = load(bg_path)
	UIK.clear(content)
	var v: Control = load(TABS[id]).instantiate()
	v.set("village", self)
	for k in opts.keys():
		v.set(k, opts[k])
	content.add_child(v)

## Открыть вкладку отряда на нужном герое
func show_hero(hid: String) -> void:
	show_tab("party", {"hero_id": hid})

func start_expedition_screen() -> void:
	main.goto("expedition")

func start_arena(cfg: Dictionary) -> void:
	main.goto("expedition", {"arena": cfg})

func go_title() -> void:
	Game.save()
	main.goto("title")

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_ESCAPE and overlay.get_child_count() == 0:
		get_viewport().set_input_as_handled()
		show_menu()

# ================================================================ Окна поверх
func _open(c: Control) -> Control:
	close_modal()
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(c)
	return c

func close_modal() -> void:
	UIK.clear(overlay)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_menu() -> void:
	var m: SystemMenu = _open(SYSTEM_MENU.instantiate())
	var acts := ["resume", "save", "main_menu"]
	if not Game.state.get("last_result", {}).is_empty():
		acts.insert(2, "last_result")
	m.setup("Меню", acts)
	m.chosen.connect(_on_menu)

func _on_menu(a: String) -> void:
	match a:
		"resume":
			close_modal()
		"save":
			Game.save()
			Game.notify("Игра сохранена.")
			close_modal()
		"last_result":
			show_result(Game.state["last_result"])
		"main_menu":
			go_title()

## Вступительная кат-сцена (если её ещё не видели) — отдельный экран в 3D-поселении
func _show_intro() -> void:
	main.goto.call_deferred("intro")

func show_result(res: Dictionary) -> void:
	var d: ResultDialog = _open(RESULT.instantiate())
	d.setup(res)
	d.closed.connect(func():
		close_modal()
		_after_result(res))

## Награда на выбор, которую не успели взять (игру закрыли на шаге выбора)
func show_pending_choice() -> void:
	var d: ResultDialog = _open(RESULT.instantiate())
	d.setup_choice()
	d.closed.connect(close_modal)

func _after_result(res: Dictionary) -> void:
	if res.get("chapter_end", false) and not Game.state.get("ending_seen", false):
		_show_ending()
	else:
		show_tab("town")

func _show_ending() -> void:
	var lines := [STORY_TEXT[STORY_TEXT.size() - 1]]
	# Итог дипломатической миссии финала (если она была)
	for cid in DB.STORY_ORDER:
		var oid: String = Game.state["flags"].get("%s_outcome" % cid, "")
		if oid != "":
			for o in Game.dip_scenario(cid)["outcomes"]:
				if o["id"] == oid:
					lines.insert(0, o["text"])
	for hid in DB.COMPANIONS:
		var r := Game.rel("aiden", hid)
		var f := int(r["friend"])
		var ro := int(r["romance"])
		var t := ""
		match hid:
			"marek":
				t = "Марек вешает щит над очагом гильдии. " + ("«Это мой дом», — говорит он и смотрит на тебя дольше, чем нужно." if ro >= 18 else ("«Здесь мои люди», — коротко говорит он." if f >= 25 else "Он остаётся — пока платят."))
			"elira":
				t = "Элира отмечает на коре последнюю зарубку. " + ("Вечером она берёт тебя за руку и ведёт на Вересковую поляну." if ro >= 18 else ("«Лес снова дышит. И мы тоже»." if f >= 25 else "Она уходит в лес на неделю, но обещает вернуться."))
			"neris":
				t = "Нэрис отсылает в приют Святой Ивы первое жалованье от короны. " + ("Нэрис целует тебя у всех на виду: «Пусть крестятся»." if ro >= 18 else ("Нэрис впервые смеётся при деревенских — и никто не крестится." if f >= 25 else "Нэрис кивает и молча забирает своё жалованье."))
		lines.append(t)
	var d: StoryDialog = _open(STORY.instantiate())
	d.setup("КОНЕЦ ПРОЛОГА", "«Проклятый лес»", lines, "Спасибо за игру! Поручения можно повторять, а арена открыта для экспериментов.", "В деревню", DB.HERO_IDS)
	d.closed.connect(func():
		Game.state["ending_seen"] = true
		Game.save()
		close_modal()
		show_tab("town"))
