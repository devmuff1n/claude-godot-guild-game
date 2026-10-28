class_name Hero3DSprite
extends SubViewport
## 3D-модель героя для 2D-поля боя: свой маленький 3D-мир с прозрачным фоном.
## BattleView каждый кадр передаёт сюда состояние юнита (drive) и рисует get_texture() на месте фигурки.

const PX_PER_M := 128.0      # масштаб под нарисованных героев: Нэрис по росту как остальные в отряде
const FRAME := 384           # сторона кадра в пикселях
const FOOT_PAD_M := 0.3      # запас под ногами внутри кадра, м
const TURN := 0.7           # насколько герой довёрнут к зрителю, рад (в профиль видны только волосы)
const RUN_FROM := 1.2        # с какой скорости (м/с) вместо шага включается бег

var hero: HeroModel3D
var _facing := 1
var _yaw := 0.0
var _was_cast := false
var _was_dead := false
var _prev_x := NAN
var _prev_ms := 0
var _speed := 0.0
var _flash := 0.0
var _moving := ""
var used := false            # рисовался ли в этом кадре (BattleView гасит неиспользуемые)
var unused_t := 0.0
var _last_shot := ""
var _last_shot_ms := 0


func _init(scene: PackedScene = null) -> void:
	size = Vector2i(FRAME, FRAME)
	transparent_bg = true
	own_world_3d = true
	msaa_3d = Viewport.MSAA_4X
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.78, 0.72, 0.8)
	e.ambient_light_energy = 0.95
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 1.45
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, -140, 0)
	fill.light_energy = 0.35
	add_child(fill)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = FRAME / PX_PER_M
	cam.position = Vector3(0, cam.size * 0.5 - FOOT_PAD_M, 6.0)
	add_child(cam)
	cam.current = true
	if scene:
		hero = scene.instantiate()
		add_child(hero)


## Где в кадре стоят ноги: эту точку BattleView совмещает с позицией юнита.
func anchor() -> Vector2:
	return Vector2(FRAME * 0.5, FRAME - FOOT_PAD_M * PX_PER_M)


## Перевести состояние 2D-юнита в состояние 3D-модели.
## st: moving, dead, cast, flash, x (позиция в пикселях); facing: 1 вправо, -1 влево.
func drive(st: Dictionary, facing: int) -> void:
	used = true
	if hero == null or hero.anim == null:
		return
	var now := Time.get_ticks_msec()
	var x: float = st.get("x", 0.0)
	if not is_nan(_prev_x) and now > _prev_ms:
		var v: float = abs(x - _prev_x) / ((now - _prev_ms) / 1000.0) / PX_PER_M
		_speed = lerpf(_speed, v, 0.3)
	_prev_x = x
	_prev_ms = now
	if st.has("speed_mps"):
		_speed = st["speed_mps"]
	_facing = facing
	var dead: bool = st.get("dead", false)
	if dead:
		if not _was_dead:
			hero.play_state("death")
		_was_dead = true
		_was_cast = false
		return
	if _was_dead:
		_was_dead = false
		_moving = ""
		hero.play_state("idle")
	var cast: bool = st.get("cast", false)
	if cast and not _was_cast:
		hero.play_state("cast")
	elif not cast and _was_cast:
		hero.play_state("idle")
		one_shot("cast_release")
	_was_cast = cast
	if not cast:
		var mv := ""
		if st.get("moving", false):
			mv = "run" if _speed > RUN_FROM else "walk"
		if mv != _moving:
			_moving = mv
			hero.play_state(mv if mv != "" else "idle")
		if mv == "walk":
			hero.set_walk_speed(_speed)
	var fl: float = st.get("flash", 0.0)
	if fl > _flash + 0.3 and not cast:
		hero.play_state("hit")
	_flash = fl


## Разовое действие поверх текущего состояния: "attack", "cast_release", "hit"…
func one_shot(state: String) -> void:
	if hero == null or _was_dead:
		return
	var now := Time.get_ticks_msec()
	if state == _last_shot and now - _last_shot_ms < 300:
		return  # конец каста приходит и событием, и снятием флага каста
	_last_shot = state
	_last_shot_ms = now
	hero.play_state(state)


func _process(delta: float) -> void:
	if hero == null:
		return
	var target := _facing * (PI * 0.5 - TURN)
	_yaw = lerp_angle(_yaw, target, clampf(delta * 10.0, 0.0, 1.0)) if _yaw != 0.0 else target
	hero.rotation.y = _yaw
