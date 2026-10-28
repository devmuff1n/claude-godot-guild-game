extends Node3D
## Запись ролика: Элира в Godot проигрывает все клипы, на ходьбе идёт по кругу, чтобы было видно вторичное движение.
## Запуск: godot --path . --write-movie out/frame.png --fixed-fps 30 res://tests/EliraShowreel.tscn

const STEPS := [
	["idle", 2.5, "Idle"],
	["walk", 5.0, "Walk"],
	["idle", 1.5, "Idle"],
	["run", 3.0, "Run"],
	["idle", 1.5, "Idle"],
	["cast", 2.6, "Cast"],
	["idle", 0.0, "Idle"],
	["cast_release", 1.6, "Cast_Release"],
	["attack", 1.8, "Attack"],
	["attack", 1.8, "Attack"],
	["hit", 1.0, "Hit"],
	["dodge", 1.4, "Dodge"],
	["death", 2.5, "Death"],
]

var hero: HeroModel3D
var cam: Camera3D
var label: Label
var t := 0.0
var step := -1
var step_t := 0.0
var angle := 0.0
const FACE_CAMERA := 0.44


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.17, 0.13, 0.19)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.68, 0.8)
	e.ambient_light_energy = 0.7
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 35, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8, 8)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.32, 0.27, 0.33)
	pm.material = fm
	floor_mesh.mesh = pm
	add_child(floor_mesh)
	hero = load("res://scenes/characters/Elira3D.tscn").instantiate()
	if OS.get_environment("ELIRA_SPRINGS") == "0":
		hero.secondary_motion = false
	if OS.get_environment("ELIRA_MOCAP") == "0":
		hero.use_mocap = false
	add_child(hero)
	hero.rotation.y = FACE_CAMERA
	cam = Camera3D.new()
	cam.fov = 32
	add_child(cam)
	cam.current = true
	label = Label.new()
	label.position = Vector2(24, 18)
	label.add_theme_font_size_override("font_size", 40)
	var layer := CanvasLayer.new()
	layer.add_child(label)
	add_child(layer)
	_next()


func _next() -> void:
	step += 1
	step_t = 0.0
	if step >= STEPS.size():
		get_tree().quit()
		return
	hero.play_state(STEPS[step][0])
	label.text = hero.anim.current_animation if hero.anim else STEPS[step][2]


func _process(delta: float) -> void:
	t += delta
	step_t += delta
	if STEPS[step][0] == "walk":
		# круг радиусом 1,2 м со скоростью клипа (≈0,6 м/с)
		angle += delta * 0.6 / 1.2
		hero.position = Vector3(sin(angle) * 1.2, 0, cos(angle) * 1.2 - 1.2)
		hero.rotation.y = lerp_angle(hero.rotation.y, angle + PI / 2, minf(1.0, delta * 6.0))
	else:
		# между клипами плавно разворачивается к камере (заодно видно, как качаются волосы)
		hero.rotation.y = lerp_angle(hero.rotation.y, FACE_CAMERA, minf(1.0, delta * 4.0))
	var focus := hero.position + Vector3(0, 0.72, 0)
	cam.position = focus + Vector3(1.6, 0.35, 3.4)
	cam.look_at(focus)
	if step_t >= STEPS[step][1]:
		_next()
