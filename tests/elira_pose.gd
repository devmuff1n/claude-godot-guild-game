extends Node3D
## Отладка: Элира в одном клипе спереди и сбоку (ортокамеры), ELIRA_CLIP=имя клипа, ELIRA_T=время.
var hero: HeroModel3D
func _ready() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.3, 0.3, 0.33)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.8)
	add_child(env)
	hero = load("res://scenes/characters/Elira3D.tscn").instantiate()
	add_child(hero)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.7
	var side := OS.get_environment("ELIRA_VIEW") == "side"
	cam.position = Vector3(3, 0.8, 0) if side else Vector3(0, 0.8, 3)
	add_child(cam)
	cam.look_at(Vector3(0, 0.8, 0))
	cam.current = true
	await get_tree().process_frame
	var clip := OS.get_environment("ELIRA_CLIP")
	if clip != "":
		hero.anim.play(clip)
		hero.anim.seek(float(OS.get_environment("ELIRA_T")), true)
		hero.anim.pause()
