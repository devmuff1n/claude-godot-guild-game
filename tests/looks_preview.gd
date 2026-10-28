extends Node2D
## Витрина обликов врагов по ступеням I/II/III (для скриншота).
const ROWS := [["wolf", "wolf_alpha", "boar", "lynx"], ["spider", "bear", "bandit", "raider"], ["archer", "brute", "healer", "arsonist"]]
var t := 0.0

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.32, 0.42, 0.3))
	await get_tree().create_timer(0.6).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(OS.get_environment("SHOT") if OS.get_environment("SHOT") != "" else "user://looks.png")
	get_tree().quit()

func _process(d: float) -> void:
	t += d
	queue_redraw()

func _draw() -> void:
	var y0 := 200.0
	for r in ROWS.size():
		for col in ROWS[r].size():
			var look: String = ROWS[r][col]
			for tier in 3:
				var x: float = 80.0 + col * 400.0 + tier * 125.0
				var y: float = y0 + r * 280.0
				var sc: float = [1.0, 1.06, 1.12][tier] * 0.95
				var sw := 0.5 if (look == "raider" and tier == 0) else 0.0
				Art.draw_unit(self, Vector2(x, y), look, -1, {"t": 0.3, "tier": tier + 1, "swing": sw, "cast": look == "bear" and tier == 2}, sc)
				draw_string(ThemeDB.fallback_font, Vector2(x - 60, y + 30), "%s %s" % [DB.enemy_name(look, [1, 3, 5][tier]), ["I", "II", "III"][tier]], HORIZONTAL_ALIGNMENT_CENTER, 120, 13)
		draw_line(Vector2(0, y0 + r * 280 + 4), Vector2(1920, y0 + r * 300 + 4), Color(0, 0, 0, 0.2), 2)
	Art.draw_unit(self, Vector2(1540, 860), "spiderling", -1, {"t": 0.3}, 1.0)
