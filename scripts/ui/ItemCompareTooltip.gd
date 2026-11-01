class_name ItemCompareTooltip
extends HBoxContainer
## Подсказка предмета со сравнением, как в WoW (scenes/ui/ItemCompareTooltip.tscn): слева наведённая вещь,
## справа — то, что сейчас надето в этот слот (у колец оба), с блоком «Если вы замените этот предмет…».

const ITEM_TOOLTIP := preload("res://scenes/ui/ItemTooltip.tscn")

func _enter_tree() -> void:
	var p := get_parent()
	if p is PopupPanel:
		p.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

## equipped — надетые вещи для сравнения
func show_compare(item: Dictionary, hero_id: String, level: int, note: String, equipped: Array) -> Control:
	UIK.clear(self)
	var main: ItemTooltip = ITEM_TOOLTIP.instantiate()
	add_child(main)
	main.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	main.show_item(item, hero_id, level, note)
	for old in equipped:
		var t: ItemTooltip = ITEM_TOOLTIP.instantiate()
		add_child(t)
		t.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		t.show_item(old, hero_id, level, "", "Сейчас надето", Items.compare_rows(item, old))
	return self
