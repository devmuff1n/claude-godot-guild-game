extends Control
## Поселение гильдии (scenes/village/TownView.tscn): 3D-деревня, здания открывают вкладки.
## Здание под курсором ищется лучом из камеры по зонам TownHotspot (Area3D).

var village

@onready var container: SubViewportContainer = %TownView
@onready var view: SubViewport = %TownViewport
@onready var hover: Control = %Hover
@onready var hover_label: Label = %HoverLabel
@onready var cam: Camera3D = view.get_node("Town3D/Camera3D")

var _hot: TownHotspot = null
var _cam_base: Transform3D
var _mouse := Vector2(-1, -1)

func _ready() -> void:
	hover.visible = false
	_cam_base = cam.transform
	container.gui_input.connect(_on_gui_input)
	container.mouse_exited.connect(func(): _mouse = Vector2(-1, -1))
	Game.changed.connect(refresh)
	refresh()

func refresh() -> void:
	if not is_inside_tree() or Game.state.is_empty():
		return
	var pts := 0
	for id in DB.HERO_IDS:
		pts += Game.perk_points(id)
	var badges := {
		"home": Game.state["pending_choice"].size() > 0 or Game.state["queue"].size() > 0,
		"party": pts > 0,
	}
	for h in _hotspots():
		h.set_badge(badges.get(h.tab, false))

func _hotspots() -> Array[TownHotspot]:
	var out: Array[TownHotspot] = []
	for n in view.get_node("Town3D/Hotspots").get_children():
		if n is TownHotspot:
			out.append(n)
	return out

func _on_gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_mouse = ev.position
		var h := _pick()
		if h:
			village.show_tab(h.tab)

## Зона здания под точкой контейнера
func _pick() -> TownHotspot:
	if _mouse.x < 0:
		return null
	var p := _mouse * Vector2(view.size) / container.size
	var from := cam.project_ray_origin(p)
	var q := PhysicsRayQueryParameters3D.create(from, from + cam.project_ray_normal(p) * 200.0)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.get("collider") as TownHotspot if not hit.is_empty() else null

func _set_hot(h: TownHotspot) -> void:
	if h == _hot:
		return
	if _hot:
		_hot.set_highlight(false)
	_hot = h
	hover.visible = h != null
	container.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if h else Control.CURSOR_ARROW
	if h:
		h.set_highlight(true)
		hover_label.text = h.title

func _physics_process(_delta: float) -> void:
	_set_hot(_pick())

func _process(_delta: float) -> void:
	var m := get_local_mouse_position()
	if hover.visible:
		hover.position = (m + Vector2(18, 14)).clamp(Vector2.ZERO, (size - hover.size).max(Vector2.ZERO))
	# лёгкий параллакс камеры за курсором
	var k := (m / size - Vector2(0.5, 0.5)).clamp(Vector2(-0.5, -0.5), Vector2(0.5, 0.5))
	var target := _cam_base.translated(Vector3(k.x * 1.2, -k.y * 0.5, 0.0))
	cam.transform = cam.transform.interpolate_with(target, 0.06)
