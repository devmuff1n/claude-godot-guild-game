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
var _scroll_px := 0.0
## Наезд камеры на событие: 0 — обычная камера, 1 — камера у события (сдвиг _cine_off).
var cine := 0.0
var _cine_off := Vector3.ZERO
const FOCUS_MAX_X := 900.0   # точка события при наезде не правее этого (дальше — окно выбора)
const HERO_MIN_X := 330.0    # середина отряда при наезде не левее этого
## Меши-декорации диорамы: не обязаны целиком помещаться в кадр
const ZOOM_MIN := 0.7
const DRESSING := ["plants", "ground_details", "bushes", "tree_crown", "tree_trunk", "pine_needles", "crows"]

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
	_scroll_px = px
	_apply_cam()


func _base_pos() -> Vector3:
	return Vector3((_scroll_px + SCREEN_W_PX * 0.5) / PX_PER_M, cam_height, cam_back)


func _apply_cam() -> void:
	cam.position = _base_pos() + _cine_off * smoothstep(0.0, 1.0, cine)


func set_cine(t: float) -> void:
	cine = clampf(t, 0.0, 1.0)
	_apply_cam()


## Точка, на которую смотрит наезд: пустышка cam_focus в диораме SetPieces/Event_<id>.
func event_focus(event_id: String) -> Vector3:
	var n := get_node_or_null("SetPieces/Event_" + event_id) as Node3D
	if n == null:
		return Vector3((_scroll_px + 1200.0) / PX_PER_M, 0.8, -4.5)
	var f := n.find_child("cam_focus", true, false) as Node3D
	return f.global_position if f != null else n.global_position + Vector3(0, 0.8, -2.0)


## Экранная точка (в пикселях макета 1600×900) при сдвиге камеры off.
## Проекция считается вручную: unproject_position камеры отстаёт от только что изменённой позиции.
func _screen(p: Vector3, off: Vector3) -> Vector2:
	var xf := Transform3D(cam.transform.basis, _base_pos() + off)
	if cam.get_parent() is Node3D:
		xf = (cam.get_parent() as Node3D).global_transform * xf
	var q := xf.affine_inverse() * p
	var clip := cam.get_camera_projection() * Vector4(q.x, q.y, q.z, 1.0)
	if absf(clip.w) < 0.0001:
		return Vector2.ZERO
	return Vector2((clip.x / clip.w * 0.5 + 0.5) * SCREEN_W_PX, (0.5 - clip.y / clip.w * 0.5) * 900.0)


## Подобрать сдвиг камеры (наклон прежний): камера подъезжает так, что отряд на дороге
## становится крупнее в zoom раз, и сдвигается, чтобы точка между отрядом и событием
## (mix — доля пути к событию) встала в экранную точку aim_px (пиксели макета 1600×900).
func plan_cine(hero: Vector3, focus: Vector3, zoom: float, mix: float, aim_px: Vector2, shift := true) -> void:
	var fwd := -cam.transform.basis.z
	var right := cam.transform.basis.x
	var up := cam.transform.basis.y
	var d0 := (hero - _base_pos()).dot(fwd)
	var dolly := fwd * d0 * (1.0 - 1.0 / maxf(zoom, 0.6))
	var m := hero.lerp(focus, mix)
	var pan := Vector2.ZERO
	for it in 6:
		var off := dolly + right * pan.x + up * pan.y
		var r := _screen(m, off) - aim_px
		var rx := _screen(m, off + right * 0.05) - aim_px
		var ry := _screen(m, off + up * 0.05) - aim_px
		var jx := (rx - r) / 0.05
		var jy := (ry - r) / 0.05
		var det := jx.x * jy.y - jy.x * jx.y
		if absf(det) < 0.0001:
			break
		pan -= Vector2((r.x * jy.y - jy.x * r.y) / det, (jx.x * r.y - r.x * jx.y) / det)
	# диорама далеко справа уходит под окно выбора: сдвинуть кадр, пока отряд не упрётся в левый край
	var o0 := dolly + right * pan.x + up * pan.y
	var fx := _screen(focus, o0).x
	var hx := _screen(hero, o0).x
	var px_per_m := absf(_screen(hero, o0 + right).x - hx)
	if shift and fx > FOCUS_MAX_X and px_per_m > 1.0:
		pan.x += minf(fx - FOCUS_MAX_X, maxf(0.0, hx - HERO_MIN_X)) / px_per_m
	pan = pan.clamp(Vector2(-6, -4), Vector2(8, 3))
	_cine_off = dolly + right * pan.x + up * pan.y
	# всё ещё под окном выбора: наезжаем слабее
	if shift and zoom > 1.15 and _screen(focus, _cine_off).x > FOCUS_MAX_X + 60.0:
		plan_cine(hero, focus, zoom - 0.1, mix, aim_px)


## Углы рамок всех заметных мешей диорамы SetPieces/Event_<id> (плоская земля и декали не в счёт).
## Пусто, если диорамы нет.
func event_bounds(event_id: String) -> Array:
	var n := get_node_or_null("SetPieces/Event_" + event_id) as Node3D
	if n == null:
		return []
	var key := []
	var dressing := []
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		if b.size.y < 0.25:
			continue
		var nm := String(mi.name)
		var deco := false
		for w in DRESSING:
			if nm.contains(w):
				deco = true
		(dressing if deco else key).append(b)
	# по рамке считаем главное (будку, повозку, людей); деревья и кусты — только если больше ничего нет
	var boxes := key if not key.is_empty() else dressing
	var out := []
	for b in boxes:
		for i in 8:
			out.append(b.get_endpoint(i))
	return out


func _rect(pts: Array, off: Vector3) -> Rect2:
	var r := Rect2(_screen(pts[0], off), Vector2.ZERO)
	for p in pts:
		r = r.expand(_screen(p, off))
	return r


## Наезд так, чтобы вся диорама стояла левее окна выбора (правый край не дальше right_px),
## а отряд (party_l..party_r — края отряда на дороге, в метрах по x) не уходил за левый край.
## Если не помещается — наезжаем слабее, а то и отъезжаем (до ZOOM_MIN).
func plan_event_cine(party_l: float, party_r: float, corners: Array, zoom: float, right_px: float) -> void:
	var hero := Vector3((party_l + party_r) * 0.5, 0, 0)
	var box_c := Vector3.ZERO
	for c in corners:
		box_c += c
	box_c /= corners.size()
	var right := cam.transform.basis.x
	var pl := Vector3(party_l, 0, 0)
	var z := zoom
	while true:
		plan_cine(hero, box_c, z, 0.5, Vector2(680, 440), false)
		var off := _cine_off
		# сдвиг вбок: правый край диорамы ровно на right_px (не правее)
		for it in 5:
			var r0 := _rect(corners, off).end.x
			var r1 := _rect(corners, off + right * 0.1).end.x
			var slope := (r1 - r0) / 0.1
			if absf(slope) < 1.0:
				break
			off += right * ((r0 - right_px) / -slope)
		var fit := _screen(pl, off).x - 45.0 * z >= 16.0 and _rect(corners, off).position.y >= -60.0
		if fit or z <= ZOOM_MIN:
			if not fit:
				# совсем не влезает: отряд важнее, держим его в кадре
				var h0 := _screen(pl, off).x
				var h1 := _screen(pl, off + right * 0.1).x
				var need := 16.0 + 45.0 * z - h0
				if need > 0.0 and absf(h1 - h0) > 0.1:
					off += right * (need / ((h1 - h0) / 0.1))
			_cine_off = off
			if OS.has_environment("CINE_DEBUG"):
				print("CINE zoom=%.1f fit=%s box=%s party_l=%.0f" % [z, fit, _rect(corners, off), _screen(pl, off).x])
			return
		z = maxf(ZOOM_MIN, z - 0.1)


## Как 2D-слою (BattleView) повторить наезд: масштаб k и сдвиг для фигур на дороге (z = 0).
## Возвращает Vector3(k, сдвиг x, сдвиг y).
func view_xform() -> Vector3:
	if cine <= 0.0:
		return Vector3(1, 0, 0)
	var cur := _cine_off * smoothstep(0.0, 1.0, cine)
	var pa := Vector3((_scroll_px + 400.0) / PX_PER_M, 0, 0)
	var pb := Vector3((_scroll_px + 1200.0) / PX_PER_M, 0, 0)
	var a0 := _screen(pa, Vector3.ZERO)
	var b0 := _screen(pb, Vector3.ZERO)
	var a1 := _screen(pa, cur)
	var b1 := _screen(pb, cur)
	var k := (b1.x - a1.x) / maxf(1.0, b0.x - a0.x)
	var o := a1 - a0 * k
	return Vector3(k, o.x, o.y)


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
