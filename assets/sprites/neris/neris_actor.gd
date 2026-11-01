extends SpriteHero
## Нэрис: переходы между клипами из пакета анимаций (ожидание, ходьба, атака, каст, выпуск,
## получение урона, смерть). В бою действия начинаются сразу, без возврата к общей позе ожидания,
## как в демо пакета: иначе удар запаздывал бы до двух секунд.

## Реакция на урон не чаще раза за это время и только из ожидания или ходьбы,
## чтобы частые попадания не перебивали атаки и касты.
@export var hurt_cooldown := 2.5

var _pending: StringName = &""
var _walk_start_exit := false
var _cast_exit := false
var _hurt_cd := 0.0


#region Public methods
func play_idle() -> void:
	_request(&"idle")


func play_walk() -> void:
	_request(&"walk")


func play_attack() -> void:
	_request(&"attack")


func play_cast() -> void:
	_request(&"cast")


func play_release_now() -> void:
	if sprite.animation == &"death":
		return
	_clear()
	_play(&"cast_release")


func play_hurt() -> void:
	if _hurt_cd > 0.0 or not sprite.animation in [&"idle", &"walk", &"walk_start", &"hurt"]:
		return
	_hurt_cd = hurt_cooldown
	_clear()
	_play(&"hurt")


func play_death() -> void:
	_clear()
	_play(&"death")


func revive() -> void:
	_clear()
	_play(&"idle")
#endregion


#region Private methods
func _ready() -> void:
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_frame_changed)


func _process(delta: float) -> void:
	_hurt_cd = maxf(0.0, _hurt_cd - delta)


func _clear() -> void:
	_pending = &""
	_walk_start_exit = false
	_cast_exit = false


func _play(anim: StringName, custom_speed := 1.0, from_end := false) -> void:
	sprite.play(anim, custom_speed, from_end)
	if not from_end:
		sprite.set_frame_and_progress(0, 0.0)


## Сменить направление уже идущего клипа, не теряя текущий кадр.
func _reverse(anim: StringName, custom_speed: float) -> void:
	var frame: int = sprite.frame
	var progress: float = sprite.frame_progress
	sprite.play(anim, custom_speed, custom_speed < 0.0)
	sprite.set_frame_and_progress(frame, progress)


func _request(target: StringName) -> void:
	var anim: StringName = sprite.animation
	if anim == &"death":
		return
	if target == &"attack":
		_clear()
		_play(&"attack")
		return
	if anim in [&"attack", &"cast_release"] and sprite.is_playing():
		_pending = target
		return
	if anim == &"hurt" and sprite.is_playing() and target != &"cast":
		_pending = target
		return
	if anim == &"walk_start":
		_pending = target
		var exit := target != &"walk"
		if exit != _walk_start_exit:
			_walk_start_exit = exit
			_reverse(&"walk_start", -1.0 if exit else 1.0)
		return
	if anim == &"walk":
		if target == &"walk":
			_pending = &""
			return
		# Остановка: дождаться начала шага (кадр 0) и проиграть начало ходьбы назад.
		_pending = target
		if sprite.frame == 0:
			_start_walk_exit()
		return
	if anim == &"cast":
		if target == &"cast":
			_pending = &""
			return
		_pending = target
		_cast_exit = true
		_play(&"cast_start", -1.0, true)
		return
	if anim == &"cast_start":
		_pending = target
		var exit := target != &"cast"
		if exit != _cast_exit:
			_cast_exit = exit
			_reverse(&"cast_start", -1.0 if exit else 1.0)
		return
	_clear()
	match target:
		&"walk":
			_play(&"walk_start")
		&"cast":
			_play(&"cast_start")
		&"idle":
			if anim != &"idle":
				_play(&"idle")


func _start_walk_exit() -> void:
	_walk_start_exit = true
	sprite.play(&"walk_start", -1.0, true)


func _on_frame_changed() -> void:
	if sprite.animation == &"walk" and sprite.frame == 0 and _pending != &"" and _pending != &"walk":
		_start_walk_exit()


func _back_to_idle() -> void:
	var target: StringName = _pending if _pending != &"" else &"idle"
	_clear()
	_play(&"idle")
	_request(target)


func _on_animation_finished() -> void:
	match sprite.animation:
		&"attack", &"cast_release", &"hurt":
			_back_to_idle()
		&"walk_start":
			if _walk_start_exit:
				_back_to_idle()
			else:
				_play(&"walk")
		&"cast_start":
			if _cast_exit:
				_back_to_idle()
			else:
				_play(&"cast")
#endregion
