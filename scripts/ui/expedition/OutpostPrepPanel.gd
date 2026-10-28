class_name OutpostPrepPanel
extends PanelContainer
## Передышка между волнами на заставе (scenes/expedition/OutpostPrepPanel.tscn).

signal repair_pressed
signal extinguish_pressed
signal save_pressed
signal next_pressed

func _ready() -> void:
	%PrepRepair.pressed.connect(func(): repair_pressed.emit())
	%PrepExtinguish.pressed.connect(func(): extinguish_pressed.emit())
	%PrepSave.pressed.connect(func(): save_pressed.emit())
	%PrepNext.pressed.connect(func(): next_pressed.emit())

func update(wave: int, waves: int, gate: Dictionary, materials: int, scout: Array, can_repair: bool) -> void:
	%PrepTitle.text = "Волна %d из %d" % [wave, waves]
	%Gate.set_value("%d%%" % int(round(gate["hp"] / gate["max"] * 100.0)), UIK.RED if gate["burning"] > 0.0 else Color(0, 0, 0, 0))
	%Gate.tooltip_text = "Ворота" + (" — горят!" if gate["burning"] > 0.0 else "")
	%Materials.set_value(str(materials))
	%PrepScout.text = ", ".join(scout)
	%PrepRepair.disabled = not can_repair
	%PrepExtinguish.disabled = gate["burning"] <= 0.0
