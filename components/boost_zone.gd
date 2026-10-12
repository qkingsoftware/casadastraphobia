@tool
class_name BoostZone
extends Area2D

enum OperatingMode {
	CONSTANT,
	SWITCH,
	INTERVAL
}

enum BoostMultiplier {
	SPEED_0_5X, # Pale Yellow / Amber (Sluggish / Low boost)
	SPEED_2X,   # Lime Green
	SPEED_3X,   # Cyan
	SPEED_4X,   # Orange
	SPEED_5X    # Red
}

enum BoostDirection {
	RIGHT,
	LEFT,
	UP,
	DOWN
}

const MULTIPLIER_VALUES: Dictionary = {
	BoostMultiplier.SPEED_0_5X: 0.5,
	BoostMultiplier.SPEED_2X:   2.0,
	BoostMultiplier.SPEED_3X:   3.0,
	BoostMultiplier.SPEED_4X:   4.0,
	BoostMultiplier.SPEED_5X:   5.0
}

const TIER_COLORS: Dictionary = {
	BoostMultiplier.SPEED_0_5X: Color(1.0, 0.95, 0.4, 0.6), # Pale Yellow
	BoostMultiplier.SPEED_2X:   Color(0.3, 0.95, 0.3, 0.6), # Lime Green
	BoostMultiplier.SPEED_3X:   Color(0.2, 0.85, 1.0, 0.6), # Cyan
	BoostMultiplier.SPEED_4X:   Color(1.0, 0.55, 0.1, 0.7), # Orange
	BoostMultiplier.SPEED_5X:   Color(1.0, 0.15, 0.15, 0.75) # Red
}

const DISABLED_COLOR: Color = Color(0.4, 0.4, 0.4, 0.25)

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

@export_group("Zone Configuration")
@export var zone_size: Vector2 = Vector2(96, 48):
	set(val):
		zone_size = val
		_update_appearance()

@export var speed_tier: BoostMultiplier = BoostMultiplier.SPEED_2X:
	set(val):
		speed_tier = val
		_update_appearance()

@export var direction: BoostDirection = BoostDirection.RIGHT:
	set(val):
		direction = val
		_update_appearance()

@export var base_boost_speed: float = 300.0

@onready var nine_patch: NinePatchRect = get_node_or_null("NinePatchRect")
@onready var col_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var arrow: Node2D = get_node_or_null("Arrow")

var is_active: bool = true
var interval_timer: float = 0.0
var overlapping_players: Array[CharacterBody2D] = []

func _ready() -> void:
	monitoring = true
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
		overlapping_players.clear()
		return

	var launch_vector = get_launch_vector()
	var final_speed = base_boost_speed * MULTIPLIER_VALUES[speed_tier]

	for player in overlapping_players:
		if is_instance_valid(player):
			_apply_zone_acceleration(player, launch_vector, final_speed)

func _apply_zone_acceleration(player: CharacterBody2D, launch_vector: Vector2, final_speed: float) -> void:
	# Read active player inputs
	var input_h = Input.get_axis("left", "right")
	var input_jump = Input.is_action_pressed("jump") or Input.is_action_just_pressed("jump")

	# Horizontal boost: only triggers if player actively inputs in that direction or is moving along it
	if launch_vector.x != 0.0:
		var pressing_with_stream = (sign(input_h) == sign(launch_vector.x))
		var moving_with_stream = (sign(player.velocity.x) == sign(launch_vector.x) and abs(player.velocity.x) > 10.0)

		if pressing_with_stream or moving_with_stream:
			player.velocity.x = launch_vector.x * final_speed

	# Vertical boost: only triggers if player jumps/thrusts into the current
	if launch_vector.y != 0.0:
		var player_up = player.up_direction if "up_direction" in player else Vector2.UP
		var jumping_upward = (launch_vector.y < 0.0 and (input_jump or player.velocity.y < -10.0))
		var dropping_downward = (launch_vector.y > 0.0 and (player.velocity.y > 10.0 or (input_jump and player_up == Vector2.DOWN)))

		if jumping_upward or dropping_downward:
			player.velocity.y = launch_vector.y * final_speed

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
				var raw_state = false
				if Engine.has_meta(required_switch_meta):
					raw_state = bool(Engine.get_meta(required_switch_meta))
				is_active = (not raw_state) if invert_switch else raw_state
		OperatingMode.INTERVAL:
			is_active = start_active
			interval_timer = interval_on_time if is_active else interval_off_time

func _on_body_entered(body: Node2D) -> void:
	if is_active and body is CharacterBody2D:
		overlapping_players.append(body)

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		overlapping_players.erase(body)

		# Only shoot the player out if they were actively running/moving through it
		if is_active:
			var launch_vector = get_launch_vector()
			var final_speed = base_boost_speed * MULTIPLIER_VALUES[speed_tier]

			var was_moving_h = (launch_vector.x != 0.0 and sign(body.velocity.x) == sign(launch_vector.x) and abs(body.velocity.x) > 20.0)
			var was_moving_v = (launch_vector.y != 0.0 and sign(body.velocity.y) == sign(launch_vector.y) and abs(body.velocity.y) > 20.0)

			if was_moving_h:
				body.velocity.x = launch_vector.x * final_speed
			if was_moving_v:
				body.velocity.y = launch_vector.y * final_speed

func get_launch_vector() -> Vector2:
	match direction:
		BoostDirection.RIGHT: return Vector2.RIGHT
		BoostDirection.LEFT:  return Vector2.LEFT
		BoostDirection.UP:    return Vector2.UP
		BoostDirection.DOWN:  return Vector2.DOWN
	return Vector2.RIGHT

func _update_appearance() -> void:
	if not is_inside_tree():
		return

	if nine_patch == null:
		nine_patch = get_node_or_null("NinePatchRect")
	if col_shape == null:
		col_shape = get_node_or_null("CollisionShape2D")
	if arrow == null:
		arrow = get_node_or_null("Arrow")

	if nine_patch:
		nine_patch.size = zone_size
		nine_patch.position = -zone_size * 0.5
		nine_patch.modulate = TIER_COLORS[speed_tier] if is_active else DISABLED_COLOR

	if col_shape:
		if col_shape.shape is RectangleShape2D:
			col_shape.shape.size = zone_size
		col_shape.position = Vector2.ZERO

	if arrow:
		arrow.position = Vector2.ZERO
		arrow.modulate = Color(1, 1, 1, 1.0) if is_active else Color(1, 1, 1, 0.2)
		match direction:
			BoostDirection.RIGHT: arrow.rotation_degrees = 0.0
			BoostDirection.LEFT:  arrow.rotation_degrees = 180.0
			BoostDirection.UP:    arrow.rotation_degrees = -90.0
			BoostDirection.DOWN:  arrow.rotation_degrees = 90.0
