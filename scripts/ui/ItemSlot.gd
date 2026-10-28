class_name ItemSlot
extends Control
## Ячейка предмета: кладовая, экипировка, лавка. Поддерживает перетаскивание и подсказку.

signal clicked(slot: ItemSlot)
signal right_clicked(slot: ItemSlot)

const ITEM_TOOLTIP := preload("res://scenes/ui/ItemTooltip.tscn")

var item = null:            # Dictionary или null
	set(v):
		item = v
		queue_redraw()
var cons_id: String = "":  # для расходников
	set(v):
		cons_id = v
		queue_redraw()
var count: int = 0:
	set(v):
		count = v
		queue_redraw()
var ctx: Dictionary = {}   # {"kind": "storage", "index": i} / {"kind": "equip", "hero": id, "slot": s}
@export var placeholder: String = "":
	set(v):
		placeholder = v
		queue_redraw()
var selected := false:
	set(v):
		selected = v
		queue_redraw()
var tip_bb: String = ""     # подсказка для расходников и пустых слотов (BBCode)
var tip_hero: String = ""   # для предмета: чьими глазами смотреть (красный тип брони, требования)
var tip_note: String = ""   # для предмета: красная строка-причина внизу подсказки
var drop_cb: Callable      # func(from_ctx, to_ctx)
var can_drag := true
var dim := false:
	set(v):
		dim = v
		queue_redraw()

func _init(sz: float = 58.0) -> void:
	# Размер из сцены задаётся раньше скрипта — не перезаписываем его
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(sz, sz)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = " "

func setup(it, c: Dictionary, tip: String = "") -> ItemSlot:
	item = it
	ctx = c
	tip_bb = tip
	queue_redraw()
	return self

static var _sb := StyleBoxFlat.new()

func _box(r: Rect2, bg: Color, border: Color, bw: int) -> void:
	_sb.bg_color = bg
	_sb.border_color = border
	_sb.set_border_width_all(bw)
	_sb.set_corner_radius_all(4)
	_sb.anti_aliasing = true
	draw_style_box(_sb, r)

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var empty := item == null and cons_id == ""
	if empty:
		# пустая ячейка — утопленная и почти незаметная, чтобы сетка не рябила
		_box(r, Color(0.045, 0.038, 0.03, 0.75), Color(0.42, 0.33, 0.2, 0.28) if not selected else UIK.GOLD, 2 if selected else 1)
		draw_rect(Rect2(r.position + Vector2(3, 1), Vector2(r.size.x - 6, 2)), Color(0, 0, 0, 0.35))
		if placeholder != "":
			var f := UIK.f()
			var fs := 11
			var ts := f.get_string_size(placeholder, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs)
			draw_string(f, Vector2(0, (size.y + ts.y * 0.5) * 0.5), placeholder, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color(0.5, 0.45, 0.36, 0.55))
	else:
		var rc := Items.rarity_color(item) if item != null else Color(0.55, 0.45, 0.3)
		var border := UIK.GOLD if selected else rc.darkened(0.1)
		_box(r, Color(0.1, 0.082, 0.062), border, 2 if selected else 1)
		# мягкое свечение цвета редкости от центра
		_box(r.grow(-3), Color(rc, 0.1), Color(0, 0, 0, 0), 0)
		draw_circle(r.get_center(), size.x * 0.3, Color(rc, 0.07))
		draw_rect(Rect2(r.position + Vector2(3, 2), Vector2(r.size.x - 6, 1)), Color(1, 1, 1, 0.08))
		if item != null:
			Art.draw_item_icon(self, r.grow(-6), item)
		else:
			Art.draw_cons_icon(self, r.grow(-6), cons_id)
	if count > 0 and cons_id != "":
		var f2 := UIK.fb()
		var p := Vector2(size.x - 22, size.y - 5)
		draw_string_outline(f2, p, "×%d" % count, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, Color(0, 0, 0, 0.9))
		draw_string(f2, p, "×%d" % count, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.95, 0.8))
	if dim:
		_box(r, Color(0, 0, 0, 0.55), Color(0, 0, 0, 0), 0)

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(self)
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			right_clicked.emit(self)

func _make_custom_tooltip(_for_text: String) -> Object:
	if item != null:
		var lvl := int(Game.hero(tip_hero)["level"]) if tip_hero != "" else 1
		var tt = ITEM_TOOLTIP.instantiate()
		return tt.show_item(item, tip_hero, lvl, tip_note)
	var bb := tip_bb
	if bb == "":
		if placeholder != "":
			bb = "[color=#9d927c]%s: пусто[/color]" % placeholder
		else:
			return null
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.custom_minimum_size = Vector2(300, 10)
	r.text = bb
	r.add_theme_font_size_override("normal_font_size", 15)
	r.add_theme_font_size_override("bold_font_size", 16)
	return r

func _get_drag_data(_pos: Vector2) -> Variant:
	if item == null or not can_drag or ctx.is_empty():
		return null
	var prev := ItemSlot.new(52)
	prev.item = item
	prev.modulate = Color(1, 1, 1, 0.8)
	set_drag_preview(prev)
	return {"ctx": ctx, "item_uid": item.get("uid", 0)}

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("ctx") and drop_cb.is_valid() and not ctx.is_empty()

func _drop_data(_pos: Vector2, data: Variant) -> void:
	if drop_cb.is_valid():
		drop_cb.call(data["ctx"], ctx)
