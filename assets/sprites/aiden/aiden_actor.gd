extends SpriteHero
## Эйден: переходы между клипами (из пакета анимаций). Переходы используют кадры движения
## и отдельный мост ходьбы без наложения спрайтов.

@export var auto_cast_after_start: bool = false

var _pending_animation: StringName = &""
var _is_cast_exit: bool = false
var _is_walk_bridge_exit: bool = false
var _is_walk_start_exit: bool = false
var _awaiting_phase: StringName = &""


#region Public methods
func play_idle() -> void:
	_request_animation(&"idle")


func play_walk() -> void:
	_request_animation(&"walk")


func play_attack() -> void:
	_request_animation(&"attack")


func play_cast_start() -> void:
	_request_animation(&"cast_start")


func play_cast() -> void:
	_request_animation(&"cast")


func play_cast_release() -> void:
	_request_animation(&"cast_release")


func play_release_now() -> void:
	if sprite.animation == &"cast" or (sprite.animation == &"cast_start" and not _is_cast_exit):
		_request_animation(&"cast_release")
		return
	_pending_animation = &""
	_awaiting_phase = &""
	_is_cast_exit = false
	_is_walk_start_exit = false
	sprite.play(&"cast_release")
	sprite.set_frame_and_progress(0, 0.0)
#endregion


#region Private methods
func _ready() -> void:
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_frame_changed)


func _request_animation(target: StringName) -> void:
	if sprite.animation == &"cast_release" and sprite.is_playing():
		_pending_animation = &"" if target == &"cast_release" else target
		return
	if sprite.animation == &"attack" and sprite.is_playing() and target != &"attack":
		_pending_animation = target
		return
	if sprite.animation == &"walk_start":
		_pending_animation = target
		var exit_requested: bool = target != &"walk"
		if exit_requested != _is_walk_start_exit:
			var frame: int = sprite.frame
			var progress: float = sprite.frame_progress
			_is_walk_start_exit = exit_requested
			sprite.play(&"walk_start", -1.0 if exit_requested else 1.0, exit_requested)
			sprite.set_frame_and_progress(frame, progress)
		return
	if sprite.animation == &"walk_bridge":
		_pending_animation = target
		var exit_requested: bool = target != &"walk"
		if exit_requested != _is_walk_bridge_exit:
			var frame: int = sprite.frame
			var progress: float = sprite.frame_progress
			_is_walk_bridge_exit = exit_requested
			sprite.play(&"walk_bridge", -1.0 if exit_requested else 1.0, exit_requested)
			sprite.set_frame_and_progress(frame, progress)
		return
	if sprite.animation == &"walk":
		if target == &"walk":
			_pending_animation = &""
			_awaiting_phase = &""
			return
		_pending_animation = target
		if sprite.frame != 0:
			_awaiting_phase = &"walk"
			return
		_awaiting_phase = &""
		_is_walk_start_exit = true
		sprite.play(&"walk_start", -1.0, true)
		return
	if sprite.animation == &"idle" and target != &"idle" and sprite.frame >= 140 and sprite.frame <= 157:
		_pending_animation = target
		_awaiting_phase = &"idle"
		return
	if sprite.animation == &"idle" and target == &"idle":
		_pending_animation = &""
		_awaiting_phase = &""
		return
	_awaiting_phase = &""

	if sprite.animation == &"cast" and target in [&"idle", &"walk", &"attack", &"cast_start"]:
		_pending_animation = target
		_is_cast_exit = true
		sprite.play(&"cast_start", -3.0, true)
		return

	if sprite.animation == &"cast_start":
		if target in [&"idle", &"walk", &"attack"]:
			_pending_animation = target
			if not _is_cast_exit:
				var frame: int = sprite.frame
				var progress: float = sprite.frame_progress
				_is_cast_exit = true
				sprite.play(&"cast_start", -3.0, true)
				sprite.set_frame_and_progress(frame, progress)
			return
		if target in [&"cast", &"cast_release"] or (_is_cast_exit and target == &"cast_start"):
			_pending_animation = target if target in [&"cast", &"cast_release"] else &""
			var frame: int = sprite.frame
			var progress: float = sprite.frame_progress
			_is_cast_exit = false
			sprite.play(&"cast_start")
			sprite.set_frame_and_progress(frame, progress)
			return

	_is_cast_exit = false
	_pending_animation = &""
	if target == &"walk":
		_pending_animation = &"walk"
		_is_walk_start_exit = false
		sprite.play(&"walk_start")
		sprite.set_frame_and_progress(0, 0.0)
	elif target in [&"cast", &"cast_release"] and sprite.animation != &"cast":
		_pending_animation = target
		sprite.play(&"cast_start")
		sprite.set_frame_and_progress(0, 0.0)
	elif target == &"cast_release":
		sprite.play(&"cast_release")
		sprite.set_frame_and_progress(0, 0.0)
	elif target == &"attack" or target == &"cast_start":
		sprite.play(target)
		sprite.set_frame_and_progress(0, 0.0)
	elif sprite.animation != target:
		sprite.play(target)
		sprite.set_frame_and_progress(0, 0.0)


func _on_frame_changed() -> void:
	if (_awaiting_phase == &"walk" and sprite.animation == &"walk" and sprite.frame == 0) or (_awaiting_phase == &"idle" and sprite.animation == &"idle" and sprite.frame == 158):
		var target: StringName = _pending_animation
		_awaiting_phase = &""
		_request_animation(target)


func _on_animation_finished() -> void:
	if sprite.animation in [&"attack", &"cast_release"]:
		var target: StringName = _pending_animation if _pending_animation != &"" else &"idle"
		_pending_animation = &""
		_request_animation(target)
	elif sprite.animation == &"walk_start":
		var target: StringName = _pending_animation
		_pending_animation = &""
		if _is_walk_start_exit:
			_is_walk_start_exit = false
			sprite.play(&"idle")
			sprite.set_frame_and_progress(0, 0.0)
			_request_animation(target)
		else:
			sprite.play(&"walk")
			sprite.set_frame_and_progress(0, 0.0)
	elif sprite.animation == &"walk_bridge":
		var target: StringName = _pending_animation
		_pending_animation = &""
		if _is_walk_bridge_exit:
			_is_walk_bridge_exit = false
			sprite.play(&"idle")
			sprite.set_frame_and_progress(0, 0.0)
			_request_animation(target)
		else:
			sprite.play(&"walk")
			sprite.set_frame_and_progress(31, 0.0)
	elif sprite.animation == &"cast_start":
		if _is_cast_exit:
			var target: StringName = _pending_animation
			_is_cast_exit = false
			_pending_animation = &""
			sprite.play(&"idle")
			sprite.set_frame_and_progress(0, 0.0)
			_request_animation(target)
		elif _pending_animation in [&"cast", &"cast_release"] or auto_cast_after_start:
			var next: StringName = _pending_animation if _pending_animation != &"" else &"cast"
			_pending_animation = &""
			sprite.play(next)
#endregion
