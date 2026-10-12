@tool
class_name GelDampener
extends Area2D

enum OperatingMode {
	CONSTANT,
	SWITCH,
	INTERVAL
}

# Vibrant translucent gel styling
const ACTIVE_GEL_COLOR: Color = Color(0.15, 0.9, 0.75, 0.45)
const DISABLED_COLOR: Color = Color(0.3, 0.3, 0.3, 0.1)

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

@export_group("Gel Dynamics")
## Instant velocity cut factor applied upon entry (0.0 = total stop, 0.3 = retains 30% speed)
@export_range(0.0, 1.0, 0.05) var entry_velocity_retention: float = 0.15

## Maximum speed clamped in any direction while wading inside the gel
@export var max_wading_speed: float = 90.0

## Continuous drag multiplier applied per physics frame (higher = thicker fluid)
@export var continuous_drag: float = 12.0

@export_group("Geometry")
@export var zone_size: Vector2 = Vector2(96, 96):
	set(val):
		zone_size = val
		_update_appearance()

var nine_patch: NinePatchRect
var col_shape: CollisionShape2D

var is_active: bool = true
var interval_timer: float = 0.0
var overlapping_bodies: Array[CharacterBody2D] = []

func _enter_tree() -> void:
	_resolve_nodes()
	_isolate_shape()

func _ready() -> void:
	monitoring = true
	_resolve_nodes()
	_isolate_shape()
	_reset_mode_state()
	_update_appearance()

	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_update_mode_logic(delta)

	if not is_active:
		overlapping_bodies.clear()
		return

	# Continuously dampen velocity while swimming/wading through the gel
	for body in overlapping_bodies:
		if is_instance_valid(body):
			# Drag down current velocity toward maximum wading speed
			body.velocity = body.velocity.move_toward(
				body.velocity.clamp(Vector2(-max_wading_speed, -max_wading_speed), Vector2(max_wading_speed, max_wading_speed)),
				continuous_drag * 100.0 * delta
			)

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
	var prev_active = is_active

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
			interval_timer -= delta
			if interval_timer <= 0.0:
				is_active = not is_active
				interval_timer = interval_on_time if is_active else interval_off_time

	if prev_active != is_active:
		monitoring = is_active
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

func _on_body_entered(body: Node2D) -> void:
	if is_active and body is CharacterBody2D:
		if not overlapping_bodies.has(body):
			overlapping_bodies.append(body)

		# Immediate airbrake impact upon entering the gel
		body.velocity *= entry_velocity_retention

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		overlapping_bodies.erase(body)

func _update_appearance() -> void:
	if not is_inside_tree():
		return

	_resolve_nodes()
	_isolate_shape()

	if nine_patch:
		nine_patch.size = zone_size
		nine_patch.position = -zone_size * 0.5
		nine_patch.modulate = ACTIVE_GEL_COLOR if is_active else DISABLED_COLOR

	if col_shape:
		col_shape.position = Vector2.ZERO
		if col_shape.shape is RectangleShape2D:
			col_shape.shape.size = zone_size
