class_name Settings
extends RefCounted
## Настройки игрока, общие для всех сохранений (user://settings.cfg).

const PATH := "user://settings.cfg"
## Вид героев на поле боя и в пути: simple — фигурки из примитивов (Art), 2d — покадровые спрайты,
## 3d — 3D-модели. Герой без своих ассетов для выбранного вида рисуется фигуркой.
const HERO_LOOKS := ["simple", "2d", "3d"]

## Режим окна: windowed — окно выбранного размера, fullscreen — во весь экран без рамки,
## exclusive — исключительный полноэкранный. Во весь экран размер окна равен экрану.
const WINDOW_MODES := ["windowed", "fullscreen", "exclusive"]
## Размеры окна (16:9 — как макет 1600×900; интерфейс масштабируется целиком, canvas_items/keep)
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080),
	Vector2i(2560, 1440), Vector2i(3200, 1800), Vector2i(3840, 2160)]

static var _loaded := false
static var _hero_look := "simple"
static var _window_mode := "windowed"
static var _resolution := Vector2i(1600, 900)
static var _display_saved := false   # в settings.cfg есть секция display — иначе окно как в project.godot
static var _force_res := false       # размер задан GUILD_RES — не проверять, влезает ли в экран


static func hero_look() -> String:
	_load()
	return _hero_look


static func set_hero_look(v: String) -> void:
	if v not in HERO_LOOKS:
		return
	_load()
	_hero_look = v
	var cf := ConfigFile.new()
	cf.load(PATH)
	cf.set_value("view", "hero_look", v)
	cf.save(PATH)


static func window_mode() -> String:
	_load()
	return _window_mode


static func resolution() -> Vector2i:
	_load()
	return _resolution


static func set_window_mode(v: String) -> void:
	if v not in WINDOW_MODES:
		return
	_load()
	_window_mode = v
	_save_display()
	apply_display()


static func set_resolution(v: Vector2i) -> void:
	if v not in RESOLUTIONS:
		return
	_load()
	_resolution = v
	_save_display()
	apply_display()


## Самый большой размер 16:9, который помещается в рабочую область экрана scr (с рамкой окна)
static func window_fit(v: Vector2i, scr: int) -> Vector2i:
	var area := DisplayServer.screen_get_usable_rect(scr).size - Vector2i(0, 40)
	var k := minf(1.0, minf(float(area.x) / v.x, float(area.y) / v.y))
	return Vector2i(int(v.x * k), int(v.y * k))


## Во сколько раз 3D-виды (HiResView) рисуются крупнее макета 1600×900: разрешение / 900
static func render_scale() -> float:
	_load()
	return _resolution.y / 900.0


## Применить режим окна и разрешение (при запуске и при смене в меню).
## Интерфейс — макет 1600×900, растянутый на окно целиком (canvas_items/keep): он всегда чёткий
## в родных пикселях окна. Разрешение задаёт, в каком размере рисуется 3D (HiResView), и размер
## окна в оконном режиме (если не влезает в экран — наибольший влезающий 16:9).
static func apply_display() -> void:
	_load()
	if not _display_saved or DisplayServer.get_name() == "headless":
		return
	var win := (Engine.get_main_loop() as SceneTree).root
	var res := _resolution
	(Engine.get_main_loop() as SceneTree).call_group(HiResView.GROUP, "refresh")
	match _window_mode:
		"fullscreen":
			win.mode = Window.MODE_FULLSCREEN
		"exclusive":
			win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		_:
			win.mode = Window.MODE_WINDOWED
			var scr := DisplayServer.window_get_current_screen()
			var sz := res if _force_res else window_fit(res, scr)
			var area := DisplayServer.screen_get_usable_rect(scr)
			win.size = sz
			# по центру рабочей области, но заголовок окна не уходит за верх экрана
			var pos := area.position + (area.size - sz) / 2
			win.position = Vector2i(max(pos.x, area.position.x), max(pos.y, area.position.y))


static func _save_display() -> void:
	_display_saved = true
	var cf := ConfigFile.new()
	cf.load(PATH)
	cf.set_value("display", "window_mode", _window_mode)
	cf.set_value("display", "resolution", "%dx%d" % [_resolution.x, _resolution.y])
	cf.save(PATH)


static func _parse_res(t: String) -> Vector2i:
	var p := t.to_lower().split("x")
	if p.size() != 2 or not p[0].is_valid_int() or not p[1].is_valid_int():
		return Vector2i.ZERO
	return Vector2i(int(p[0]), int(p[1]))


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var env := OS.get_environment("GUILD_HERO_LOOK")
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		_hero_look = str(cf.get_value("view", "hero_look", _hero_look))
		if cf.has_section("display"):
			_display_saved = true
			_window_mode = str(cf.get_value("display", "window_mode", _window_mode))
			var r := _parse_res(str(cf.get_value("display", "resolution", "")))
			if r in RESOLUTIONS:
				_resolution = r
	if _window_mode not in WINDOW_MODES:
		_window_mode = "windowed"
	# GUILD_RES=1920x1080 / GUILD_WINDOW=fullscreen — для проверок (в файл не пишутся)
	var env_res := _parse_res(OS.get_environment("GUILD_RES"))
	if env_res != Vector2i.ZERO:
		_resolution = env_res
		_force_res = true
		_display_saved = true
	if OS.get_environment("GUILD_WINDOW") in WINDOW_MODES:
		_window_mode = OS.get_environment("GUILD_WINDOW")
		_display_saved = true
	if env in HERO_LOOKS:
		_hero_look = env
	if _hero_look not in HERO_LOOKS:
		_hero_look = "simple"
