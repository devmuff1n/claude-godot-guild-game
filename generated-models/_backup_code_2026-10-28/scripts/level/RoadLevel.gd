class_name RoadLevel
extends Node3D
## Трёхмерный уровень похода: дорога вдоль оси X, камера сбоку едет вместе с отрядом.
## Масштаб совпадает с BattleView: 100 px экрана = 1 м на линии дороги (z = 0),
## центр дороги проецируется на линию земли y = 600 при окне 1600×900.

const PX_PER_M := 100.0
const SCREEN_W_PX := 1600.0

## Камера: высота, отступ к зрителю и наклон подобраны так, чтобы дорога легла под фигурки.
@export var cam_height := 7.34
@export var cam_back := 12.8

var _flicker: Array[OmniLight3D] = []
var _base_energy: Array[float] = []
var _t := 0.0
var _gate_overlay: StandardMaterial3D = null
var _fire_mult := 1.0
var _env: Environment = null
var _sun: DirectionalLight3D = null

@onready var cam: Camera3D = $Camera3D


func _ready() -> void:
	var lights := get_node_or_null("FireLights")
	if lights:
		for n in lights.get_children():
			if n is OmniLight3D:
				_flicker.append(n)
				_base_energy.append((n as OmniLight3D).light_energy)
	var we := find_children("*", "WorldEnvironment", false, false)
	if not we.is_empty():
		_env = (we[0] as WorldEnvironment).environment
	var suns := find_children("*", "DirectionalLight3D", false, false)
	if not suns.is_empty():
		_sun = suns[0]
	set_scroll(0.0)


func _process(delta: float) -> void:
	if _flicker.is_empty():
		return
	_t += delta
	for i in _flicker.size():
		var k := 0.82 + 0.12 * sin(_t * 11.0 + i * 1.7) + 0.06 * sin(_t * 23.0 + i)
		_flicker[i].light_energy = _base_energy[i] * k * _fire_mult


## Левый край экрана в пикселях пройденного пути (то же, что BattleView.scroll).
func set_scroll(px: float) -> void:
	cam.position = Vector3((px + SCREEN_W_PX * 0.5) / PX_PER_M, cam_height, cam_back)


## Затемнение створки ворот по урону (0 — целы, 1 — разбиты).
func set_gate_damage(dmg: float) -> void:
	var gate := get_node_or_null("SetPieces/Gate")
	if gate == null:
		return
	if _gate_overlay == null:
		_gate_overlay = StandardMaterial3D.new()
		_gate_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_gate_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_gate_overlay.albedo_color = Color(0.05, 0.03, 0.02, 0.0)
		var leaf := gate.find_child("forest_defense_gate_gate_leaf", true, false)
		if leaf:
			var meshes: Array = leaf.find_children("*", "MeshInstance3D", true, false)
			meshes.append(leaf)
			for m in meshes:
				if m is MeshInstance3D:
					(m as MeshInstance3D).material_overlay = _gate_overlay
	_gate_overlay.albedo_color.a = clampf(dmg, 0.0, 1.0) * 0.65


## Свет по времени суток (DayTime.PRESETS / DayTime.mix): небо, рассеянный свет, дымка, солнце или луна, костры.
func set_daylight(p: Dictionary) -> void:
	if _env != null:
		_env.background_color = p["bg"]
		_env.ambient_light_color = p["amb"]
		_env.ambient_light_energy = p["amb_e"]
		_env.fog_light_color = p["fog"]
		_env.fog_density = p["fog_d"]
	if _sun != null:
		_sun.light_color = p["sun"]
		_sun.light_energy = p["sun_e"]
		_sun.rotation_degrees = p["sun_rot"]
	_fire_mult = p["fire"]
	if not _flicker.is_empty() and _t == 0.0:
		for i in _flicker.size():
			_flicker[i].light_energy = _base_energy[i] * _fire_mult
