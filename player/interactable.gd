# res://player/interactable.gd
class_name Interactable
extends Area2D

@export var speaker_name: String = "Survivor"
@export_multiline var lines: Array[String] = [
	"The gravity stabilizer failed...",
	"Be careful up ahead, the fans are still running."
]

func interact() -> void:
	if Engine.has_meta("HUD"):
		var hud = Engine.get_meta("HUD")
		hud.start_dialogue(speaker_name, lines)
