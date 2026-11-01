class_name Settings
extends RefCounted
## Настройки игрока, общие для всех сохранений (user://settings.cfg).

const PATH := "user://settings.cfg"
## Вид героев на поле боя и в пути: simple — фигурки из примитивов (Art), 2d — покадровые спрайты,
## 3d — 3D-модели. Герой без своих ассетов для выбранного вида рисуется фигуркой.
const HERO_LOOKS := ["simple", "2d", "3d"]

static var _loaded := false
static var _hero_look := "simple"


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


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var env := OS.get_environment("GUILD_HERO_LOOK")
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		_hero_look = str(cf.get_value("view", "hero_look", _hero_look))
	if env in HERO_LOOKS:
		_hero_look = env
	if _hero_look not in HERO_LOOKS:
		_hero_look = "simple"
