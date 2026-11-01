class_name SpriteHero
extends Node2D
## Покадровый рисованный герой для 2D-поля боя (спрайт-листы вместо фигурки Art).
## Узел скрыт: AnimatedSprite2D только ведёт анимацию, а текущий кадр рисует BattleView (draw_on),
## чтобы герой стоял в общем порядке отрисовки — под всплывающими числами, эффектами и ночной тьмой.
## Переходы между клипами — в скрипте конкретного героя (play_idle, play_walk, play_attack…).

@export var sprite: AnimatedSprite2D
## Точка под ступнями внутри кадра и масштаб кадра на поле боя.
@export var pivot := Vector2(160, 297)
@export var draw_scale := 0.6
## Автоатака и выпуск заклинания в бою быстрее исходного ролика и начинаются ближе к удару.
@export var attack_from := 0
@export var attack_speed := 1.0
@export var release_from := 0
@export var release_speed := 1.0
@export var cast_start_speed := 1.0
## Скорость клипов получения урона и смерти (если они есть у героя).
@export var hurt_speed := 1.0
@export var death_speed := 1.0

var used := false            # рисовался ли в этом кадре (BattleView убирает неиспользуемые)
var unused_t := 0.0
var _dead := false
var _seen := false
var _last_flash := 0.0


func play_idle() -> void:
	pass


func play_walk() -> void:
	pass


func play_attack() -> void:
	pass


func play_cast() -> void:
	pass


## Выпуск заклинания сразу, без подготовки (мгновенные умения); из подготовки — как обычно.
func play_release_now() -> void:
	pass


## Реакция на попадание, смерть и возврат после воскрешения — у героев с такими клипами.
func play_hurt() -> void:
	pass


func play_death() -> void:
	pass


func revive() -> void:
	pass


## Состояние юнита: moving, cast, dead. Вызывается каждый кадр перед draw_on.
func drive(st: Dictionary) -> void:
	used = true
	var dead: bool = st.get("dead", false)
	if dead and not _dead:
		play_death()
		if not _seen and sprite.animation == &"death":
			# уже павший к первому показу: сразу последний кадр
			sprite.set_frame_and_progress(sprite.sprite_frames.get_frame_count(&"death") - 1, 0.99)
	elif _dead and not dead:
		revive()
	_dead = dead
	_seen = true
	var fl := float(st.get("flash", 0.0))
	var hit := fl > _last_flash + 0.05
	_last_flash = fl
	if _dead:
		_tune()
		return
	if hit:
		play_hurt()
	if st.get("cast", false):
		play_cast()
	elif st.get("moving", false):
		play_walk()
	else:
		play_idle()
	_tune()


## Разовое действие: "attack" или "cast_release".
func one_shot(kind: String) -> void:
	if _dead:
		return
	match kind:
		"attack":
			play_attack()
		"cast_release":
			play_release_now()
	_tune()


func _tune() -> void:
	match sprite.animation:
		&"attack":
			sprite.speed_scale = attack_speed
			if sprite.frame < attack_from:
				sprite.set_frame_and_progress(attack_from, 0.0)
		&"cast_release":
			sprite.speed_scale = release_speed
			if sprite.frame < release_from:
				sprite.set_frame_and_progress(release_from, 0.0)
		&"cast_start":
			sprite.speed_scale = cast_start_speed
		&"hurt":
			sprite.speed_scale = hurt_speed
		&"death":
			sprite.speed_scale = death_speed
		_:
			sprite.speed_scale = 1.0


## Нарисовать текущий кадр: pos — точка под ногами, facing 1 вправо, -1 влево.
## Павший герой без клипа смерти лежит на боку (поворот кадра ожидания), ранение — красная вспышка.
func draw_on(ci: CanvasItem, pos: Vector2, facing: int, st: Dictionary) -> void:
	var frames := sprite.sprite_frames
	var death_clip := _dead and sprite.animation == &"death"
	var tex: Texture2D = frames.get_frame_texture(&"idle", 0) if _dead and not death_clip else frames.get_frame_texture(sprite.animation, sprite.frame)
	if tex == null:
		return
	var fl: float = clampf(float(st.get("flash", 0.0)), 0.0, 1.0)
	var col := Color(1.0, 1.0 - 0.45 * fl, 1.0 - 0.5 * fl, float(st.get("alpha", 1.0)))
	if _dead:
		col = Color(1, 1, 1, 0.85 if death_clip else 0.55)
	var rot := 0.0
	var off := Vector2.ZERO
	if _dead and not death_clip:
		rot = -PI * 0.5 * float(facing)
		off = Vector2(-facing * 10, -14)
	ci.draw_set_transform(pos + off, rot, Vector2(float(facing) * draw_scale, draw_scale))
	ci.draw_texture(tex, -pivot, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
