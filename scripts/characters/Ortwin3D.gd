class_name Ortwin3D
extends Node3D
## Ортвин Хейл, глава гильдии (scenes/characters/Ortwin3D.tscn): старик в кресле, фигура из примитивов.
## Подагра держит его в кресле, поэтому вся «анимация» — дыхание, поворот головы к собеседнику,
## кивки во время речи и жест тростью. Смотрит вдоль +Z, как и модели героев.

## Точка в мире, куда смотрит голова (null — прямо перед собой)
var look_target = null
var talking := false

var _t := 0.0
var _head_yaw := 0.0
var _head_pitch := 0.0
var _nod := 0.0
var _gesture: Tween

@onready var body: Node3D = $Body
@onready var head: Node3D = $Body/Head
@onready var arm_r: Node3D = $Body/ArmR
@onready var _body_base := body.transform
@onready var _arm_base := arm_r.transform


func _process(delta: float) -> void:
	_t += delta
	# Дыхание: грудь чуть поднимается
	var br := sin(_t * 1.7) * 0.012
	body.transform = _body_base.scaled_local(Vector3(1.0 + br * 0.5, 1.0 + br, 1.0 + br * 0.5))
	# Голова поворачивается к собеседнику, во время речи покачивается
	var yaw := 0.0
	var pitch := 0.0
	if look_target is Vector3:
		var local: Vector3 = global_transform.affine_inverse() * (look_target as Vector3)
		var hp: Vector3 = global_transform.affine_inverse() * head.global_position
		var d := local - hp
		yaw = clampf(atan2(d.x, d.z), -1.0, 1.0)
		pitch = clampf(-atan2(d.y, Vector2(d.x, d.z).length()), -0.4, 0.4)
	if talking:
		pitch += sin(_t * 7.0) * 0.05 + sin(_t * 2.3) * 0.03
		yaw += sin(_t * 1.9) * 0.05
	else:
		pitch += sin(_t * 0.9) * 0.015
	_head_yaw = lerpf(_head_yaw, yaw, minf(1.0, delta * 4.0))
	_head_pitch = lerpf(_head_pitch, pitch, minf(1.0, delta * 6.0))
	head.rotation = Vector3(_head_pitch + _nod, _head_yaw, 0.0)


## Жест: "cane" — приподнять трость и стукнуть ею, "nod" — кивнуть
func gesture(kind: String) -> void:
	if _gesture != null and _gesture.is_running():
		_gesture.kill()
	_gesture = create_tween()
	match kind:
		"cane":
			var up := _arm_base.rotated_local(Vector3.RIGHT, -0.55)
			_gesture.tween_property(arm_r, "transform", up, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_gesture.tween_interval(0.25)
			_gesture.tween_property(arm_r, "transform", _arm_base, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		"nod":
			_gesture.tween_property(self, "_nod", 0.3, 0.18)
			_gesture.tween_property(self, "_nod", 0.0, 0.25)
