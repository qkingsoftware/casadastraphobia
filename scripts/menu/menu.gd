extends Control

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://world/levels/test.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _ready():
	print("Game Lauching!")
