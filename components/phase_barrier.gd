@tool
class_name PhaseBarrier
extends StaticBody2D

enum OperatingMode {
	CONSTANT,
	SWITCH,
	INTERVAL
}

enum PhasePolarity {
	CYAN,
	AMBER
}

const COLOR_CYAN_SOLID: Color = Color(0.2, 0.85, 1.0, 0.95)
const COLOR_CYAN_GHOST: Color = Color(0.2, 0.85, 1.0, 0.18)

const COLOR_AMBER_SOLID: Color = Color(1.0, 0.65, 0.15, 0.95)
const COLOR_AMBER_GHOST: Color = Color(1.0, 0.65, 0.15, 0.18)

@export_group("Operating Mode")
@export var mode: OperatingMode = OperatingMode.INTERVAL:
	set(val):
		mode = val
		_reset_mode_state()
		_update_appearance()

@export_group("Phase Polarity")
## Defines whether this block aligns with Cyan or Amber polarity
@export var polarity: PhasePolarity = PhasePolarity.CYAN:
	set(val):
		polarity = val
		_update_appearance()

@export_group("Switch Settings")
## Switch metadata key (e.g. "phase_switch"). Both Cyan & Amber can listen to the same key!
@export var required_switch_meta: String = ""
@export var invert_switch: bool = false

@export_group("Interval Settings")
@export var interval_duration: float = 2.0

@export_group("Geometry")
@export var block_size: Vector2 = Vector2(48, 48):
	set(val):
		block_size = val
		_update_appearance()

var nine_patch: NinePatchRect
var col_shape: CollisionShape2D

var is_solid: bool = true
var interval_timer: float = 0.0

func _enter_tree() -> void:
	_resolve_nodes()
	_isolate_shape()

func _ready() -> void:
	_resolve_nodes()
	_isolate_shape()
	_reset_mode_state()
	_update_appearance()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_update_mode_logic(delta)

func _resolve_nodes() -> void:
	if nine_patch == null:
		nine_patch = get_node_or_null("NinePatchRect")
	if col_shape == null:
		col_shape = get_node_or_null("CollisionShape2D")

func _isolate_shape() -> void:
	_resolve_nodes()
	if col_shape:
		if col_shape.shape == null:
			col_shape.shape = RectangleShape2D.new()
		elif not col_shape.shape.is_local_to_scene():
			col_shape.shape = col_shape.shape.duplicate()

func _update_mode_logic(delta: float) -> void:
	var prev_solid = is_solid

	match mode:
		OperatingMode.CONSTANT:
			is_solid = true

		OperatingMode.SWITCH:
			var raw_state = false
			if required_switch_meta.strip_edges() != "" and Engine.has_meta(required_switch_meta):
				raw_state = bool(Engine.get_meta(required_switch_meta))
			if invert_switch:
				raw_state = not raw_state

			# Cyan is active when switch is FALSE; Amber is active when switch is TRUE
			if polarity == PhasePolarity.CYAN:
				is_solid = not raw_state
			else:
				is_solid = raw_state

		OperatingMode.INTERVAL:
			interval_timer -= delta
			if interval_timer <= 0.0:
				interval_timer = interval_duration
				is_solid = not is_solid

	if prev_solid != is_solid:
		_update_appearance()

func _reset_mode_state() -> void:
	match mode:
		OperatingMode.CONSTANT:
			is_solid = true

		OperatingMode.SWITCH:
			var raw_state = false
			if required_switch_meta.strip_edges() != "" and Engine.has_meta(required_switch_meta):
				raw_state = bool(Engine.get_meta(required_switch_meta))
			if invert_switch:
				raw_state = not raw_state

			if polarity == PhasePolarity.CYAN:
				is_solid = not raw_state
			else:
				is_solid = raw_state

		OperatingMode.INTERVAL:
			# Cyan starts solid, Amber starts ghostly so they alternate cleanly out of the box
			is_solid = (polarity == PhasePolarity.CYAN)
			interval_timer = interval_duration

func _update_appearance() -> void:
	if not is_inside_tree():
		return

	_resolve_nodes()
	_isolate_shape()

	# Determine active tint based on polarity and current solidity
	var display_color: Color
	if polarity == PhasePolarity.CYAN:
		display_color = COLOR_CYAN_SOLID if is_solid else COLOR_CYAN_GHOST
	else:
		display_color = COLOR_AMBER_SOLID if is_solid else COLOR_AMBER_GHOST

	if nine_patch:
		nine_patch.size = block_size
		nine_patch.position = -block_size * 0.5
		nine_patch.modulate = display_color

	if col_shape:
		col_shape.position = Vector2.ZERO
		if col_shape.shape is RectangleShape2D:
			col_shape.shape.size = block_size
		
		if not Engine.is_editor_hint():
			col_shape.set_deferred("disabled", not is_solid)
		else:
			col_shape.disabled = false
