extends CanvasLayer

@onready var health_container: HBoxContainer = $HealthContainer
@onready var dialogue_box: Control = $DialogueBox
@onready var speaker_label: Label = $DialogueBox/Panel/SpeakerLabel
@onready var message_label: RichTextLabel = $DialogueBox/Panel/MessageLabel

var is_dialogue_active: bool = false
var text_tween: Tween
var current_lines: Array[String] = []
var line_index: int = 0

func _ready() -> void:
	dialogue_box.visible = false
	Engine.set_meta("HUD", self)

func update_health(current: int, max_hp: int) -> void:
	for i in range(health_container.get_child_count()):
		var heart = health_container.get_child(i)
		heart.visible = (i < max_hp)
		heart.modulate = Color.WHITE if (i < current) else Color(0.3, 0.3, 0.3, 0.5)

func start_dialogue(speaker: String, lines: Array[String]) -> void:
	if lines.is_empty():
		return
	
	speaker_label.text = speaker
	current_lines = lines
	line_index = 0
	is_dialogue_active = true
	dialogue_box.visible = true
	Engine.set_meta("in_dialogue", true)
	_show_current_line()

func _input(event: InputEvent) -> void:
	if not is_dialogue_active:
		return
	
	# Corrected: Use is_action_pressed() on event, and ignore echo/held key repeats
	if event.is_action_pressed("ui_accept") and not event.is_echo():
		if text_tween and text_tween.is_running():
			text_tween.kill()
			message_label.visible_ratio = 1.0
		else:
			line_index += 1
			if line_index < current_lines.size():
				_show_current_line()
			else:
				_close_dialogue()

func _show_current_line() -> void:
	message_label.text = current_lines[line_index]
	message_label.visible_ratio = 0.0
	
	if text_tween:
		text_tween.kill()
	text_tween = create_tween()
	text_tween.tween_property(message_label, "visible_ratio", 1.0, 0.5)

func _close_dialogue() -> void:
	is_dialogue_active = false
	dialogue_box.visible = false
	Engine.set_meta("in_dialogue", false)
