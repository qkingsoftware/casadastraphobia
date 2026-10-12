@tool
class_name ConveyorTread
extends StaticBody2D

enum OperatingMode {
	CONSTANT,
	SWITCH,
	INTERVAL
}

enum TreadDirection {
	RIGHT,
	LEFT
}

const ACTIVE_COLOR: Color = Color(1.0, 0.85, 0.2, 0.95)
const DISABLED_COLOR: Color = Color(0.4, 0.4, 0.4, 0.3)

@export_group("Operating Mode")
@export var mode: OperatingMode = OperatingMode.CONSTANT:
	set(val):
		mode = val
		_reset_mode_state()
		_update_appearance()

@export_group("Switch Settings")
@export var required_switch_meta: String = ""
@export var invert_switch: bool = false

@export_group("Interval Settings")
@export var interval_on_time: float = 2.0
@export var interval_off_time: float = 1.5
@export var start_active: bool = true

@export_group("Tread Configuration")
@export var tread_size: Vector2 = Vector2(96, 16):
	set(val):
		tread_size = val
		_update_appearance()

@export var direction: TreadDirection = TreadDirection.RIGHT:
	set(val):
		direction = val
		_update_appearance()

@export var tread_speed: float = 180.0:
	set(val):
		tread_speed = val
		_update_appearance()

@onready var nine_patch: NinePatchRect = get_node_or_null("NinePatchRect")
@onready var col_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var arrow: Node2D = get_node_or_null("Arrow")

var is_active: bool = true
var interval_timer: float = 0.0

func _ready() -> void:
	_ensure_unique_shape()
	_reset_mode_state()
	_update_appearance()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_update_mode_logic(delta)

func _update_mode_logic(delta: float) -> void:
	var prev_active = is_active

	match mode:
		OperatingMode.CONSTANT:
			is_active = true

		OperatingMode.SWITCH:
			if required_switch_meta.strip_edges() == "":
				is_active = true
			else:
				var raw_state = false
				if Engine.has_meta(required_switch_meta):
					raw_state = bool(Engine.get_meta(required_switch_meta))
				is_active = (not raw_state) if invert_switch else raw_state

		OperatingMode.INTERVAL:
			interval_timer -= delta
			if interval_timer <= 0.0:
				is_active = not is_active
				interval_timer = interval_on_time if is_active else interval_off_time

	if prev_active != is_active:
		_update_appearance()

func _reset_mode_state() -> void:
	match mode:
		OperatingMode.CONSTANT:
			is_active = true
		OperatingMode.SWITCH:
			if required_switch_meta.strip_edges() == "":
				is_active = true
			else:
				var raw = bool(Engine.get_meta(required_switch_meta)) if Engine.has_meta(required_switch_meta) else false
				is_active = (not raw) if invert_switch else raw
		OperatingMode.INTERVAL:
			is_active = start_active
			interval_timer = interval_on_time if is_active else interval_off_time

func _ensure_unique_shape() -> void:
	if col_shape == null:
		col_shape = get_node_or_null("CollisionShape2D")

	if col_shape:
		# If no shape exists, instantiate a fresh one
		if col_shape.shape == null:
			col_shape.shape = RectangleShape2D.new()
		# Duplicate resource so editing this instance never alters other conveyors
		elif not col_shape.shape.is_local_to_scene():
			col_shape.shape = col_shape.shape.duplicate()

func _update_appearance() -> void:
	if not is_inside_tree():
		return

	if nine_patch == null:
		nine_patch = get_node_or_null("NinePatchRect")
	if col_shape == null:
		col_shape = get_node_or_null("CollisionShape2D")
	if arrow == null:
		arrow = get_node_or_null("Arrow")

	_ensure_unique_shape()

	# Visual sizing
	if nine_patch:
		nine_patch.size = tread_size
		nine_patch.position = -tread_size * 0.5
		nine_patch.modulate = ACTIVE_COLOR if is_active else DISABLED_COLOR

	# Solid physics boundary - strictly centered
	if col_shape and col_shape.shape is RectangleShape2D:
		col_shape.shape.size = tread_size
		col_shape.position = Vector2.ZERO

	# Apply constant physics belt velocity
	if is_active:
		var dir_mult = 1.0 if direction == TreadDirection.RIGHT else -1.0
		constant_linear_velocity = Vector2(dir_mult * tread_speed, 0.0)
	else:
		constant_linear_velocity = Vector2.ZERO

	# Orient arrow
	if arrow:
		arrow.position = Vector2.ZERO
		arrow.modulate = Color(1, 1, 1, 0.9) if is_active else Color(1, 1, 1, 0.2)
		arrow.rotation_degrees = 0.0 if direction == TreadDirection.RIGHT else 180.0
