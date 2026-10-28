class_name StoryDialog
extends Control
## Сюжетное окно (scenes/ui/StoryDialog.tscn): вступление и концовка главы.

signal closed

func _ready() -> void:
	%OkButton.pressed.connect(func(): closed.emit())

func setup(caption: String, title: String, paragraphs: Array, accent := "", button := "Продолжить", portraits := []) -> StoryDialog:
	%Caption.text = caption
	%Title.text = title
	%Body.text = "\n\n".join(paragraphs)
	%Accent.visible = accent != ""
	%Accent.text = accent
	%OkButton.text = button
	%Portraits.visible = not portraits.is_empty()
	for i in %Portraits.get_child_count():
		var tr: TextureRect = %Portraits.get_child(i).get_child(0)
		%Portraits.get_child(i).visible = i < portraits.size()
		if i < portraits.size():
			tr.texture = UIK.portrait(portraits[i])
			%Portraits.get_child(i).tooltip_text = DB.HEROES[portraits[i]]["full"] + " · " + DB.HEROES[portraits[i]]["cls"]
	return self
