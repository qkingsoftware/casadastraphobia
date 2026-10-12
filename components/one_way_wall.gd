@tool
class_name OneWayWall
extends AnimatableBody2D

enum OperatingMode {
	CONSTANT,
	SWITCH,
	INTERVAL
}

enum PassDirection {
	PASS_UP,    # Pass upward, blocks falling down
	PASS_DOWN,  # Pass downward, blocks moving up
	PASS_RIGHT, # Pass left-to-right, blocks right-to-left
	PASS_LEFT   # Pass right-to-left, blocks left-to-right
}

const ACTIVE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.95)
const DISABLED_COLOR: Color = Color(0.3, 0.3, 0.3, 0.25)

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

@export_group("Wall Configuration")
@export var wall_size: Vector2 = Vector2(96, 16):
	set(val):
		wall_size = val
		_update_appearance()

@export var pass_direction: PassDirection = PassDirection.PASS_RIGHT:
	set(val):
		pass_direction = val
		_update_appearance()

@onready var nine_patch: NinePatchRect = get_node_or_null("NinePatchRect")
@onready var col_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var entry_sensor: Area2D = get_node_or_null("EntrySensor")
@onready var sensor_shape: CollisionShape2D = get_node_or_null("EntrySensor/SensorShape")
@onready var arrow: Node2D = get_node_or_null("Arrow")

var is_active: bool = true
var interval_timer: float = 0.0
var bodies_in_entry: Array[Node2D] = []

func _ready() -> void:
	_reset_mode_state()
	_update_appearance()

	if not Engine.is_editor_hint() and entry_sensor:
		entry_sensor.body_entered.connect(_on_sensor_body_entered)
		entry_sensor.body_exited.connect(_on_sensor_body_exited)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_update_mode_logic(delta)

	if not is_active:
		if col_shape:
			col_shape.disabled = true
		return

	# Evaluate whether overlapping players are approaching with valid direction
	var should_pass: bool = false
	var required_vec = get_pass_vector()

	for body in bodies_in_entry:
		if body is CharacterBody2D:
			# Verify movement matches arrow direction
			if required_vec.x != 0.0:
				if sign(body.velocity.x) == sign(required_vec.x) or sign(Input.get_axis("left", "right")) == sign(required_vec.x):
					should_pass = true
					break
			elif required_vec.y != 0.0:
				if sign(body.velocity.y) == sign(required_vec.y):
					should_pass = true
					break

	if col_shape:
		col_shape.disabled = should_pass

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
				var raw_state = false
				if Engine.has_meta(required_switch_meta):
					raw_state = bool(Engine.get_meta(required_switch_meta))
				is_active = (not raw_state) if invert_switch else raw_state
		OperatingMode.INTERVAL:
			is_active = start_active
			interval_timer = interval_on_time if is_active else interval_off_time

func _on_sensor_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and not bodies_in_entry.has(body):
		bodies_in_entry.append(body)

func _on_sensor_body_exited(body: Node2D) -> void:
	bodies_in_entry.erase(body)

func get_pass_vector() -> Vector2:
	match pass_direction:
		PassDirection.PASS_UP:    return Vector2.UP
		PassDirection.PASS_DOWN:  return Vector2.DOWN
		PassDirection.PASS_RIGHT: return Vector2.RIGHT
		PassDirection.PASS_LEFT:  return Vector2.LEFT
	return Vector2.RIGHT

func _update_appearance() -> void:
	if not is_inside_tree():
		return

	if nine_patch == null:
		nine_patch = get_node_or_null("NinePatchRect")
	if col_shape == null:
		col_shape = get_node_or_null("CollisionShape2D")
	if sensor_shape == null:
		sensor_shape = get_node_or_null("EntrySensor/SensorShape")
	if arrow == null:
		arrow = get_node_or_null("Arrow")

	# Visuals
	if nine_patch:
		nine_patch.size = wall_size
		nine_patch.position = -wall_size * 0.5
		nine_patch.modulate = ACTIVE_COLOR if is_active else DISABLED_COLOR

	# Solid Blocker Shape
	if col_shape:
		col_shape.rotation_degrees = 0.0
		col_shape.position = Vector2.ZERO
		col_shape.disabled = not is_active
		if col_shape.shape is RectangleShape2D:
			col_shape.shape.size = wall_size

	# Entry Sensor Placement (Slightly larger, offset to the incoming side)
	if sensor_shape:
		var pass_vec = get_pass_vector()
		if sensor_shape.shape is RectangleShape2D:
			sensor_shape.shape.size = wall_size + Vector2(16, 16)
		# Place entry zone slightly toward the side you enter from
		sensor_shape.position = -pass_vec * 8.0

	# Direction Arrow pointing where you ARE allowed to travel
	if arrow:
		arrow.position = Vector2.ZERO
		arrow.modulate = Color(1, 1, 1, 0.9) if is_active else Color(1, 1, 1, 0.2)
		match pass_direction:
			PassDirection.PASS_RIGHT: arrow.rotation_degrees = 0.0
			PassDirection.PASS_LEFT:  arrow.rotation_degrees = 180.0
			PassDirection.PASS_UP:    arrow.rotation_degrees = -90.0
			PassDirection.PASS_DOWN:  arrow.rotation_degrees = 90.0
