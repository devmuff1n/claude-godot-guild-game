class_name HeroModel3D
extends Node3D
## Трёхмерная фигура героя: состояние боя/похода → клип AnimationPlayer с плавным переходом.
## Зацикленные состояния (idle/walk/cast) задают фон; разовые (attack, hit…) играют поверх и возвращают фон.
## Вторичные кости (волосы, коса, хвост, плащ, юбка) покачиваются от движения (SpringBoneSimulator3D поверх клипов).
## В руке оружие-проп: следует за костью кисти, в стойке и касте выпрямляется. Для лука ещё тетива и стрела.
## Значения по умолчанию — Нэрис (посох в правой руке); другие герои переопределяют их в своей сцене.

@export var blend_time := 0.2
@export var secondary_motion := true
## true — клипы из библиотеки мокапа Quaternius (CC0), false — пробные клипы, поставленные вручную в модели.
@export var use_mocap := true
## Мокап Quaternius снят на скелете с наклонённой вперёд шеей: взгляд уходил в пол на ~30°.
## Поворачиваем шею и голову вверх на столько градусов (делится между двумя костями).
@export var head_pitch_fix_deg := 26.0
## Скорость, на которую рассчитан клип ходьбы (м/с, в масштабе файла модели): под неё подстраивается темп шага.
## Масштаб узла модели в сцене учитывается сам (tests/hero_gait_probe.gd меряет обе скорости).
@export var walk_clip_mps := 0.6
## То же для бега; 0 — темп бега не подстраивается.
@export var run_clip_mps := 0.0
## Клип → момент удара/выпуска (с). Разовый клип по событию боя (урон уже нанесён) начинается
## за impact_lead секунд до этого момента, чтобы взмах на экране совпал с уроном (tests/hero_impact_probe.gd).
@export var impact_times := {}
@export var impact_lead := 0.3
## Клип → скорость проигрывания разового клипа (длинные клипы магии ускоряются, чтобы не стоять в позе после удара).
@export var clip_speeds := {}

@export_group("Клипы")
## Состояние → клип. Без префикса — клипы самой модели, «ual/», «ual2/» — библиотеки мокапа.
@export var loops_mocap := {"idle": "ual2/Idle_Lantern", "walk": "ual/Walk", "run": "ual/Jog_Fwd", "cast": "ual/Spell_Simple_Idle_R"}
## Готовых клипов «каст посохом» в бесплатных паках нет: каст — заклинание одной рукой, отзеркаленное
## на правую руку с посохом (*_R), удар — взмах мечом из второго пака, которым становится удар посохом.
## «quick_release» — выпуск без предшествующего каста (мгновенные умения); если нет, играет cast_release.
@export var one_shots_mocap := {
	"cast_start": "ual/Spell_Simple_Enter_R", "cast_release": "ual/Spell_Simple_Shoot_R",
	"attack": "ual2/Sword_Regular_A", "heavy_attack": "ual2/Sword_Heavy_Combo", "throw": "ual2/OverhandThrow",
	"hit": "ual/Hit_Chest", "dodge": "ual/Roll", "death": "ual/Death01",
}
## Клипы библиотеки ual, которые зеркалятся слева направо (появляются с суффиксом _R).
@export var mirrored_clips: PackedStringArray = ["Spell_Simple_Enter", "Spell_Simple_Idle", "Spell_Simple_Shoot", "Spell_Simple_Exit"]
## Цепочки вторичных костей: корень, конец, жёсткость, сопротивление, гравитация.
@export var spring_chains: Array = [
	["Hair_Back_C_01", "Hair_Back_C_04", 2.5, 0.6, 0.1],
	["Hair_Back_L_01", "Hair_Back_L_04", 2.5, 0.6, 0.1],
	["Hair_Back_R_01", "Hair_Back_R_04", 2.5, 0.6, 0.1],
	["Tail_01", "Tail_07", 2.5, 0.5, 0.0],
	["Skirt_L_01", "Skirt_L_03", 3.0, 0.7, 0.2],
	["Skirt_R_01", "Skirt_R_03", 3.0, 0.7, 0.2],
	["Skirt_F_01", "Skirt_F_02", 3.0, 0.7, 0.2],
	["Skirt_B_01", "Skirt_B_02", 3.0, 0.7, 0.2],
]

## Составные клипы: ноги и корпус из мокапа, руки — из позы модели (как держать оружие).
## Каждая запись: [имя, клип-основа, клип-поза, момент позы (с), начала имён костей, которые берутся из позы].
## Готовые клипы лежат в библиотеке «mix»: «mix/<имя>».
@export var composites: Array = []

@export_group("Оружие")
## Проп в руке; пустое значение — без оружия.
@export var prop_scene: PackedScene = preload("res://assets/models/props/neris_staff.glb")
@export var prop_bone := "RightHand"
@export var prop_scale := 1.0
## Хват в системе кости кисти: направление пропа (+Y модели пропа) и точка хвата в середине кулака.
@export var prop_grip_offset := Vector3(0.0, 0.045, 0.012)
@export var prop_axis := Vector3(-0.21, 0.0, -0.98)
## Куда смотрит «вертикальный» проп в системе героя.
@export var prop_upright_dir := Vector3(-0.32, 1.0, 0.06)
## Не ноль — проп выпрямляется целиком, а не только по оси: его +Z смотрит сюда (лук: спинкой к цели).
@export var prop_front_dir := Vector3.ZERO
## Насколько проп выпрямляется в каждом состоянии (1 — вертикально, 0 — строго по кисти).
@export var prop_upright := {
	"idle": 1.0, "walk": 0.9, "run": 0.7, "cast": 1.0, "cast_start": 1.0, "cast_release": 1.0,
	"hit": 0.8, "attack": 0.0, "heavy_attack": 0.0, "throw": 0.3, "dodge": 0.2, "death": 1.0,
}
## При смерти проп ложится на землю рядом (направление в системе героя).
@export var prop_fallen_dir := Vector3(-1.0, 0.0, 0.35)
## Хват по кулаку: проп лежит в кулаке вдоль линии костяшек (+Y пропа к указательному пальцу),
## его +Z смотрит туда же, куда пальцы. Считается по покою скелета; prop_grip_offset и prop_axis тогда не нужны.
@export var prop_grip_from_fist := false
@export var prop_grip_along := 0.045
## Клип, из которого берётся поза пальцев кулака (момент fist_time), и кисть, которую она держит поверх любых клипов.
@export var fist_clip := ""
@export var fist_time := 0.333
@export var fist_side := "Left"

@export_group("Лук")
## Стрела на тетиве; пустое значение — у оружия нет тетивы.
@export var arrow_scene: PackedScene
## Кисть, которая тянет тетиву, и точка в кулаке (система кости).
@export var draw_bone := "RightHand"
@export var draw_offset := Vector3(0.0, 0.045, 0.0)
## Клип → отрезок времени (с), когда тетива натянута и на ней лежит стрела.
@export var draw_windows := {}
@export var string_color := Color(0.92, 0.88, 0.78)

const LOOPS_TEST := {"idle": "Idle", "walk": "Walk", "cast": "Cast"}
const ONE_SHOTS_TEST := {"attack": "Attack", "cast_release": "Cast_Release", "hit": "Hit", "dodge": "Dodge", "death": "Death"}
const MOCAP_LIBRARY := "res://assets/animations/quaternius_ual/UAL1_Standard.glb"
const MOCAP_LIBRARY_2 := "res://assets/animations/quaternius_ual2/UAL2_Standard.glb"
## Разовый выпуск сразу после каста — продолжение каста, позже — мгновенное умение.
const CAST_TAIL_MS := 400
## Повторный удар по герою перезапускает вздрагивание не раньше, чем через столько секунд клипа.
const HIT_RETRIGGER_S := 0.45

var anim: AnimationPlayer
var springs: Node
var prop: Node3D
var _skel: Skeleton3D
var _hand := -1
var _draw_hand := -1
var _grip := Transform3D.IDENTITY
var _upright := 1.0
var _upright_target := 1.0
var _base_state := "idle"
var _fallen := false
var _fall := 0.0
var _base := "Idle"
var _loops: Dictionary = LOOPS_TEST
var _one_shots: Dictionary = ONE_SHOTS_TEST
var _death := "Death"
var _cast_end_ms := -100000
var _tips: Array[Node3D] = []
var _string: Array[MeshInstance3D] = []
var _arrow: Node3D


func _ready() -> void:
	var found := find_children("*", "AnimationPlayer", true, false)
	if found.is_empty():
		push_warning("HeroModel3D: нет AnimationPlayer в %s" % name)
		return
	anim = found[0]
	anim.animation_finished.connect(_on_finished)
	if use_mocap and ResourceLoader.exists(MOCAP_LIBRARY):
		# библиотеки Quaternius подключаются, только если сцена ссылается на их клипы (у героев Mixamo свои MX_*)
		var used_libs := {}
		for clip in loops_mocap.values() + one_shots_mocap.values():
			if String(clip).contains("/"):
				used_libs[String(clip).get_slice("/", 0)] = true
		for c in composites:
			for k in [1, 2]:
				if String(c[k]).contains("/"):
					used_libs[String(c[k]).get_slice("/", 0)] = true
		for pair in [[&"ual", MOCAP_LIBRARY], [&"ual2", MOCAP_LIBRARY_2]]:
			if not used_libs.has(String(pair[0])) or not ResourceLoader.exists(pair[1]) or anim.has_animation_library(pair[0]):
				continue
			var lib: AnimationLibrary = load(pair[1])
			if lib:
				_fix_head_pitch(lib)
				anim.add_animation_library(pair[0], lib)
		var ual := anim.get_animation_library(&"ual") if anim.has_animation_library(&"ual") else null
		for clip in (mirrored_clips if ual else PackedStringArray()):
			if ual.has_animation(clip) and not ual.has_animation(clip + "_R"):
				ual.add_animation(clip + "_R", _mirrored(ual.get_animation(clip)))
		_build_composites()
		_loops = loops_mocap
		_one_shots = one_shots_mocap
		_death = one_shots_mocap.get("death", "Death")
	# фоновые клипы самой модели крутятся по кругу, даже если при импорте им не задан цикл
	for clip in _loops.values():
		if anim.has_animation(clip) and anim.get_animation(clip).loop_mode == Animation.LOOP_NONE:
			anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	var skels := find_children("*", "Skeleton3D", true, false)
	_skel = skels[0] if not skels.is_empty() else null
	if secondary_motion:
		_setup_springs()
	if prop_scene:
		_attach_prop()
	if fist_clip != "":
		_setup_fist()
	play_state("idle")
	# поза первого кадра сразу, иначе свежая модель один кадр стоит в T-позе
	anim.advance(0.0)
	_upright = _upright_target


## Клип фонового состояния; если его нет — idle, если нет и его — любой клип модели (T-позы не бывает).
func _loop_clip(state: String) -> String:
	for st in [state, "idle"]:
		if _loops.has(st) and anim.has_animation(_loops[st]):
			return _loops[st]
	var list := anim.get_animation_list()
	return String(list[0]) if not list.is_empty() else ""


func play_state(state: String) -> void:
	if anim == null:
		return
	if _base_state == "cast" and state != "cast":
		_cast_end_ms = Time.get_ticks_msec()
	if not _loops.has(state) and not _has_clip(state) and state != "cast_release":
		# неизвестное состояние: ничего не меняем, но и не оставляем модель без клипа
		if not anim.is_playing() and not _fallen:
			anim.play(_base, blend_time)
		return
	if _loops.has(state):
		var entering_cast := state == "cast" and _base_state != "cast"
		_base = _loop_clip(state)
		_base_state = state
		# разовый клип (удар, выстрел) доигрывает до конца, фон включится после него
		if _one_shot_playing():
			return
		_upright_target = prop_upright.get(state, 1.0)
		_fallen = false
		if entering_cast and _has_clip("cast_start"):
			_play_one_shot("cast_start")
			return
		if anim.current_animation != _base:
			if state not in ["walk", "run"]:
				anim.speed_scale = 1.0
			anim.play(_base, blend_time)
		return
	if state == "cast_release" and Time.get_ticks_msec() - _cast_end_ms > CAST_TAIL_MS and _has_clip("quick_release"):
		state = "quick_release"
	if state in ["hit", "block_hit"] and not _hit_allowed():
		return
	_upright_target = prop_upright.get(state, 1.0)
	_fallen = state == "death"
	if _has_clip(state):
		_play_one_shot(state)


## Вздрагивание от удара не перебивает атаку или умение и не начинается заново на каждом ударе по герою.
func _hit_allowed() -> bool:
	if not anim.is_playing():
		return true
	var cur := String(anim.current_animation)
	if cur == _death:
		return false
	var hit_clips := [_one_shots.get("hit", ""), _one_shots.get("block_hit", "")]
	if cur in hit_clips:
		return anim.current_animation_position > HIT_RETRIGGER_S
	return not (cur in _one_shots.values())


## Есть ли у модели клип для этого состояния (например "skill_bash" у Марека).
func has_state(state: String) -> bool:
	return anim != null and (_loops.has(state) or _has_clip(state))


func _has_clip(state: String) -> bool:
	return _one_shots.has(state) and anim.has_animation(_one_shots[state])


func _play_one_shot(state: String) -> void:
	var clip: String = _one_shots[state]
	anim.speed_scale = 1.0
	anim.play(clip, blend_time, float(clip_speeds.get(clip, 1.0)))
	var from := 0.0
	if impact_times.has(clip) and state not in ["cast_start", "hit", "block_hit", "death", "dodge"]:
		# не дальше середины клипа: замах умения не должен пропасть целиком
		from = clampf(float(impact_times[clip]) - impact_lead, 0.0, anim.get_animation(clip).length * 0.5)
	anim.seek(from, true)


func _one_shot_playing() -> bool:
	return anim.is_playing() and anim.current_animation != _death and anim.current_animation in _one_shots.values()


## Темп шага под скорость движения (м/с): стопа стоит на земле, а не скользит.
func set_walk_speed(mps: float) -> void:
	if anim == null:
		return
	var k := _model_scale()
	var cur := String(anim.current_animation)
	if cur == _loops.get("walk", "") and walk_clip_mps > 0.0:
		anim.speed_scale = clampf(mps / (walk_clip_mps * k), 0.5, 2.0)
	elif cur == _loops.get("run", "") and run_clip_mps > 0.0:
		anim.speed_scale = clampf(mps / (run_clip_mps * k), 0.6, 1.6)
	else:
		anim.speed_scale = 1.0


## Во сколько раз модель в сцене больше файла модели (масштаб узла Model).
func _model_scale() -> float:
	if _skel == null or not is_inside_tree():
		return 1.0
	return _skel.global_basis.get_scale().x / maxf(0.001, global_basis.get_scale().x)


func _on_finished(clip: StringName) -> void:
	if String(clip) != _death:
		if _base_state not in ["walk", "run"]:
			anim.speed_scale = 1.0
		anim.play(_base, blend_time)
		_upright_target = prop_upright.get(_base_state, 1.0)


## Страховка: если клип почему-то остановился (не смерть), снова включается фоновый.
func _process(_delta: float) -> void:
	if anim != null and not anim.is_playing() and not _fallen and _base != "":
		anim.play(_base, blend_time)


func _setup_springs() -> void:
	if not ClassDB.class_exists("SpringBoneSimulator3D") or _skel == null:
		return
	var chains := spring_chains.filter(func(c): return _skel.find_bone(c[0]) >= 0 and _skel.find_bone(c[1]) >= 0)
	if chains.is_empty():
		return
	springs = ClassDB.instantiate("SpringBoneSimulator3D")
	springs.name = "SecondaryMotion"
	_skel.add_child(springs)
	springs.set_setting_count(chains.size())
	for i in chains.size():
		var c: Array = chains[i]
		springs.set_root_bone_name(i, c[0])
		springs.set_end_bone_name(i, c[1])
		springs.set_extend_end_bone(i, true)
		springs.set_end_bone_length(i, 0.06)
		springs.set_stiffness(i, c[2])
		springs.set_drag(i, c[3])
		springs.set_gravity(i, c[4])
		springs.set_radius(i, 0.02)


## Поднимает взгляд: ко всем ключам поворота шеи и головы добавляется наклон вверх.
## Библиотека общая для всех героев, поэтому правка делается один раз (метка на ресурсе).
func _fix_head_pitch(lib: AnimationLibrary) -> void:
	if is_zero_approx(head_pitch_fix_deg) or lib.has_meta(&"head_pitch_fixed"):
		return
	lib.set_meta(&"head_pitch_fixed", head_pitch_fix_deg)
	var share := {"Neck": 0.55, "Head": 0.45}
	for clip in lib.get_animation_list():
		var a := lib.get_animation(clip)
		for t in a.get_track_count():
			if a.track_get_type(t) != Animation.TYPE_ROTATION_3D:
				continue
			var bone := String(a.track_get_path(t).get_concatenated_subnames())
			if not share.has(bone):
				continue
			var fix := Quaternion(Vector3.RIGHT, -deg_to_rad(head_pitch_fix_deg) * share[bone])
			for k in a.track_get_key_count(t):
				a.track_set_key_value(t, k, fix * a.track_get_key_value(t, k))


## Зеркальная копия клипа: Left↔Right в именах костей, повороты и смещения отражаются по оси X.
## Работает, потому что после ретаргета покой скелета симметричен (профиль Godot Humanoid).
func _mirrored(src: Animation) -> Animation:
	var m: Animation = src.duplicate(true)
	for t in m.get_track_count():
		var p := String(m.track_get_path(t))
		var i := p.rfind(":")
		var bone := p.substr(i + 1).replace("Left", "#").replace("Right", "Left").replace("#", "Right")
		m.track_set_path(t, NodePath(p.substr(0, i + 1) + bone))
		var ty := m.track_get_type(t)
		for k in m.track_get_key_count(t):
			var v = m.track_get_key_value(t, k)
			if ty == Animation.TYPE_ROTATION_3D:
				m.track_set_key_value(t, k, Quaternion(v.x, -v.y, -v.z, v.w))
			elif ty == Animation.TYPE_POSITION_3D:
				m.track_set_key_value(t, k, Vector3(-v.x, v.y, v.z))
	return m


func _attach_prop() -> void:
	if _skel == null or _skel.find_bone(prop_bone) < 0:
		return
	_hand = _skel.find_bone(prop_bone)
	_draw_hand = _skel.find_bone(draw_bone)
	prop = prop_scene.instantiate()
	prop.name = "Prop"
	prop.top_level = true
	add_child(prop)
	var to := prop_axis.normalized()
	var b := Basis(Quaternion(Vector3.UP, to)) if not to.is_equal_approx(Vector3.DOWN) else Basis(Vector3.RIGHT, PI)
	_grip = Transform3D(b, prop_grip_offset)
	if prop_grip_from_fist:
		_grip = _fist_grip()
	if arrow_scene:
		_setup_bow()
	_skel.skeleton_updated.connect(_update_prop)


## Тетива — два тонких цилиндра от концов лука к точке натяжения; стрела лежит на тетиве в окнах натяжения.
func _setup_bow() -> void:
	for n in ["TipTop", "TipBottom"]:
		var tip := prop.find_child(n, true, false) as Node3D
		if tip == null:
			return
		_tips.append(tip)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = string_color
	mat.roughness = 0.8
	for i in 2:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.0022
		cyl.bottom_radius = 0.0022
		cyl.height = 1.0
		cyl.radial_segments = 5
		cyl.rings = 1
		cyl.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = cyl
		mi.top_level = true
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_string.append(mi)
	_arrow = arrow_scene.instantiate()
	_arrow.top_level = true
	_arrow.visible = false
	add_child(_arrow)


## Проп держится в кулаке, а его наклон смешивается между «как повернула кисть» и «стоит прямо».
func _update_prop() -> void:
	var dt := get_process_delta_time()
	_upright = move_toward(_upright, _upright_target, dt * 4.0)
	var hand := _skel.global_transform * _skel.get_bone_global_pose(_hand) * _grip
	var q_hand := hand.basis.orthonormalized().get_rotation_quaternion()
	_fall = move_toward(_fall, 1.0 if _fallen else 0.0, dt * 1.5)
	var up0 := (global_basis * prop_upright_dir).normalized()
	var up := (global_basis * prop_upright_dir.normalized().slerp(prop_fallen_dir.normalized(), _fall)).normalized()
	var q_up: Quaternion
	if prop_front_dir != Vector3.ZERO:
		var fwd := global_basis * prop_front_dir
		fwd = (fwd - up0 * fwd.dot(up0)).normalized()
		q_up = Quaternion(up0, up) * Basis(up0.cross(fwd), up0, fwd).get_rotation_quaternion()
	else:
		q_up = Quaternion(q_hand * Vector3.UP, up) * q_hand
	var q := q_hand.slerp(q_up, _upright)
	prop.global_transform = Transform3D(Basis(q).scaled(Vector3.ONE * prop_scale), hand.origin)
	if not _string.is_empty():
		_update_string()


func _drawn() -> bool:
	if anim == null or not draw_windows.has(anim.current_animation):
		return false
	var w: Vector2 = draw_windows[anim.current_animation]
	var t := anim.current_animation_position
	return t >= w.x and t <= w.y


func _update_string() -> void:
	var a := _tips[0].global_position
	var b := _tips[1].global_position
	var drawn := _drawn() and _draw_hand >= 0 and not _fallen
	var nock := (a + b) * 0.5
	if drawn:
		nock = _skel.global_transform * (_skel.get_bone_global_pose(_draw_hand) * draw_offset)
		_place_segment(_string[0], a, nock)
		_place_segment(_string[1], nock, b)
		var to_grip := prop.global_position - nock
		if to_grip.length() > 0.01:
			_arrow.global_transform = Transform3D(Basis(Quaternion(Vector3.BACK, to_grip.normalized())), nock)
	else:
		_place_segment(_string[0], a, b)
		_string[1].visible = false
	_arrow.visible = drawn


func _place_segment(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.001:
		mi.visible = false
		return
	mi.visible = true
	var basis := Basis(Quaternion(Vector3.UP, d / l))
	mi.global_transform = Transform3D(basis * Basis.from_scale(Vector3(1, l, 1)), (a + b) * 0.5)


## Хват в системе кости кисти, посчитанный по покою: середина кулака, ось пропа вдоль костяшек.
func _fist_grip() -> Transform3D:
	var side := "Left" if prop_bone.begins_with("Left") else "Right"
	var mid := _skel.find_bone(side + "MiddleProximal")
	var ind := _skel.find_bone(side + "IndexProximal")
	var lit := _skel.find_bone(side + "LittleProximal")
	if mid < 0 or ind < 0 or lit < 0:
		return _grip
	var hand_rest := _skel.get_bone_global_rest(_hand)
	var d := (_skel.get_bone_global_rest(mid).origin - hand_rest.origin).normalized()
	var k := _skel.get_bone_global_rest(ind).origin - _skel.get_bone_global_rest(lit).origin
	k = (k - d * k.dot(d)).normalized()
	var grip_rest := Transform3D(Basis(k.cross(d), k, d), hand_rest.origin + d * prop_grip_along)
	return hand_rest.affine_inverse() * grip_rest


## Пальцы одной кисти держат позу кулака из клипа fist_clip поверх любых клипов (мокап разжимает кисть).
func _setup_fist() -> void:
	if _skel == null or not anim.has_animation(fist_clip):
		return
	var a := anim.get_animation(fist_clip)
	var poses := {}
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var bone := String(a.track_get_path(t).get_concatenated_subnames())
		if not bone.begins_with(fist_side) or not (bone.contains("Thumb") or bone.contains("Index") or bone.contains("Middle") or bone.contains("Ring") or bone.contains("Little")):
			continue
		var i := _skel.find_bone(bone)
		if i >= 0:
			poses[i] = a.rotation_track_interpolate(t, fist_time)
	if poses.is_empty():
		return
	var mod := FingerPose3D.new()
	mod.name = "Fist"
	mod.poses = poses
	_skel.add_child(mod)


## Собирает составные клипы: копия клипа-основы, у выбранных костей повороты заменены неподвижной позой.
func _build_composites() -> void:
	if composites.is_empty():
		return
	var lib := AnimationLibrary.new()
	for c in composites:
		var base_name: String = c[0]
		if not anim.has_animation(c[1]) or not anim.has_animation(c[2]):
			push_warning("HeroModel3D: нет клипа для %s" % base_name)
			continue
		var base: Animation = anim.get_animation(c[1]).duplicate(true)
		var over: Animation = anim.get_animation(c[2])
		var at: float = c[3]
		var prefixes: Array = c[4]
		var by_bone := {}
		for t in base.get_track_count():
			if base.track_get_type(t) == Animation.TYPE_ROTATION_3D:
				by_bone[String(base.track_get_path(t).get_concatenated_subnames())] = t
		for t in over.get_track_count():
			if over.track_get_type(t) != Animation.TYPE_ROTATION_3D:
				continue
			var bone := String(over.track_get_path(t).get_concatenated_subnames())
			if not prefixes.any(func(p): return bone.begins_with(p)):
				continue
			var q: Quaternion = over.rotation_track_interpolate(t, at)
			var bt: int = by_bone.get(bone, -1)
			if bt < 0:
				bt = base.add_track(Animation.TYPE_ROTATION_3D)
				base.track_set_path(bt, over.track_get_path(t))
			while base.track_get_key_count(bt) > 0:
				base.track_remove_key(bt, 0)
			base.rotation_track_insert_key(bt, 0.0, q)
		lib.add_animation(base_name, base)
	anim.add_animation_library(&"mix", lib)
