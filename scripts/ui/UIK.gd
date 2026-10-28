class_name UIK
extends RefCounted
## Общие константы интерфейса и мелкие помощники. Вёрстка живёт в сценах (scenes/), оформление — в теме
## assets/theme/guild_theme.tres (вариации типов: PanelDark, TitleLabel, ButtonTab, ButtonChip и т.д.).

const GOLD := Color(0.84, 0.66, 0.29)
const GOLD_HI := Color(1.0, 0.86, 0.5)
const GOLD_DIM := Color(0.55, 0.43, 0.22)
const INK := Color(0.93, 0.89, 0.8)
const MUTED := Color(0.66, 0.61, 0.52)
const DIM := Color(0.48, 0.44, 0.38)
const RED := Color(0.88, 0.36, 0.32)
const GREEN := Color(0.5, 0.82, 0.45)
const BLUE := Color(0.45, 0.68, 0.95)
const HP_COL := Color(0.82, 0.27, 0.24)
const MP_COL := Color(0.3, 0.58, 0.95)
const ATB_COL := Color(0.95, 0.72, 0.25)
const THEME_PATH := "res://assets/theme/guild_theme.tres"

static var _font: Font
static var _font_bold: Font
static var portraits := {}

static func f() -> Font:
	_ensure_fonts()
	return _font

static func fb() -> Font:
	_ensure_fonts()
	return _font_bold

static func _ensure_fonts() -> void:
	if _font != null:
		return
	var th: Theme = load(THEME_PATH)
	_font = th.default_font
	_font_bold = th.get_font("bold_font", "RichTextLabel")

static func portrait(id: String) -> Texture2D:
	if portraits.has(id):
		return portraits[id]
	var path := "res://assets/portraits/%s.png" % id
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	portraits[id] = tex
	return tex

static func clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()

## Отметить кнопку как выбранную. Используется состояние «нажата» (toggle), а не смена вариации темы —
## поэтому размер шрифта и отступы кнопки не меняются и соседние элементы не сдвигаются.
static func mark(b: BaseButton, on: bool) -> void:
	b.toggle_mode = true
	b.set_pressed_no_signal(on)

static func fmt_pct(v: float) -> String:
	var t := "%.1f" % v
	if t.ends_with(".0"):
		t = t.substr(0, t.length() - 2)
	return t.replace(".", ",") + "%"

## Цвет текста по состоянию цели: 1 — выполнено, -1 — провалено
static func state_color(st: int) -> Color:
	match st:
		1: return GREEN
		-1: return RED
	return INK
