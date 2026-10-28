class_name RankBadge
extends Control
## Значок ранга угрозы (scenes/ui/RankBadge.tscn): эмблема assets/ui/ranks/rank_<R>.png и буква ранга поверх.
## Пока картинки нет — только цветная буква.

const DIR := "res://assets/ui/ranks/rank_%s.png"
const ON_IMG := Color(1.0, 0.96, 0.88)

func set_rank(rank: String, dim := false) -> void:
	var path := DIR % rank
	var has_img := ResourceLoader.exists(path)
	%Img.visible = has_img
	if has_img:
		%Img.texture = load(path)
	%Letter.text = rank
	# Буква на эмблеме светлая, без эмблемы — цвет ранга; длинные ранги (SS, SSS) мельче
	var col: Color = ON_IMG if has_img else Game.THREAT_COLORS.get(rank, Color.WHITE)
	%Letter.add_theme_color_override("font_color", UIK.DIM if dim and not has_img else col)
	var k: float = [0.52, 0.42, 0.32][clamp(rank.length() - 1, 0, 2)] * (0.85 if has_img else 1.0)
	%Letter.add_theme_font_size_override("font_size", int(custom_minimum_size.y * k))
	modulate = Color(1, 1, 1, 0.5) if dim and has_img else Color(1, 1, 1, 1)
