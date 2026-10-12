@tool
extends Area2D

signal toggled(is_on: bool)

@export_group("Global Link")
## Name of the shared global boolean variable (e.g. "cannon_switch_1").
@export var global_var_name: String = "cannon_switch_1":
	set(val):
		global_var_name = val.strip_edges()
		_push_global_state()

@export_group("State & Behavior")
@export var is_on: bool = false:
	set(val):
		is_on = val
		_update_visuals()
		_push_global_state()
		toggled.emit(is_on)

@export var trigger_group: StringName = &"player"
@export var can_toggle_back: bool = true
@export var debounce_time: float = 0.35

@onready var anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
var _can_trigger: bool = true

func _ready() -> void:
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)
		area_entered.connect(_on_area_entered)
		
		if not global_var_name.is_empty() and Engine.has_meta(global_var_name):
			is_on = bool(Engine.get_meta(global_var_name))
		else:
			_push_global_state()

	_update_visuals()

func _on_body_entered(body: Node2D) -> void:
	if not _can_trigger:
		return
	if body.is_in_group(trigger_group) or body.name == "Player":
		_trigger_toggle()

func _on_area_entered(area: Area2D) -> void:
	if not _can_trigger:
		return
	if area.is_in_group(trigger_group):
		_trigger_toggle()

func _trigger_toggle() -> void:
	if is_on and not can_toggle_back:
		return

	_can_trigger = false
	is_on = !is_on

	if is_inside_tree():
		get_tree().create_timer(debounce_time).timeout.connect(func(): _can_trigger = true)
	else:
		_can_trigger = true

func _push_global_state() -> void:
	if global_var_name.is_empty():
		return
	Engine.set_meta(global_var_name, is_on)

func _update_visuals() -> void:
	if not anim:
		anim = get_node_or_null("AnimatedSprite2D")
	if not anim or not anim.sprite_frames:
		return

	var target = "on" if is_on else "off"
	if anim.sprite_frames.has_animation(target):
		anim.play(target)
