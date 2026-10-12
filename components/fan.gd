@tool
class_name Fan
extends Area2D

enum ControlMode {
	CONSTANT,
	SWITCH_POWER,
	SWITCH_DIRECTION,
	INTERVAL
}

@export_group("Control Modes")
@export var control_mode: ControlMode = ControlMode.CONSTANT:
	set(val):
		control_mode = val
		_reset_mode_state()
		_apply_state_change()

## Name of the global variable from the Switch (e.g. "fan_switch_1")
@export var global_var_name: String = "":
	set(val):
		global_var_name = val.strip_edges()
		_apply_state_change()

@export_group("Interval Settings")
@export var interval_on_time: float = 2.0
@export var interval_off_time: float = 1.5
@export var start_active: bool = true

@export_group("Fan Settings")
## Default state when switch is OFF or mode is CONSTANT (1 = Push, -1 = Pull)
@export_enum("Push:1", "Pull:-1") var default_direction: int = 1:
	set(val):
		default_direction = 1 if val == null else val
		_apply_state_change()

@export var force: float = 1600.0:
	set(val):
		force = 1600.0 if val == null else val
		_rebuild_stream()

@export var distance: float = 100.0:
	set(val):
		var target_dist = 100.0 if val == null else val
		distance = max(target_dist, 16.0)
		_rebuild_stream()

@export var width: float = 16.0:
	set(val):
		var target_width = 16.0 if val == null else val
		width = max(target_width, 4.0)
		_rebuild_stream()

var is_fan_on: bool = true
var current_direction: int = 1
var interval_timer: float = 0.0

@onready var col_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var particles: GPUParticles2D = get_node_or_null("WindParticles")

func _ready() -> void:
	current_direction = default_direction
	_ensure_unique_collision()
	_setup_particles()
	_reset_mode_state()
	_apply_state_change()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# State evaluation
	match control_mode:
		ControlMode.CONSTANT:
			if not is_fan_on:
				_set_power(true)
			if current_direction != default_direction:
				_set_direction(default_direction)

		ControlMode.SWITCH_POWER:
			var switch_val = _read_global_bool()
			if is_fan_on != switch_val:
				_set_power(switch_val)
			if current_direction != default_direction:
				_set_direction(default_direction)

		ControlMode.SWITCH_DIRECTION:
			if not is_fan_on:
				_set_power(true)
			var switch_is_on = _read_global_bool()
			var target_dir = -default_direction if switch_is_on else default_direction
			if current_direction != target_dir:
				_set_direction(target_dir)

		ControlMode.INTERVAL:
			interval_timer -= delta
			if interval_timer <= 0.0:
				_set_power(not is_fan_on)
				interval_timer = interval_on_time if is_fan_on else interval_off_time

	if not is_fan_on:
		return

	# Apply wind force
	var direction_vec = -global_transform.y.normalized() * float(current_direction)
	for body in get_overlapping_bodies():
		if body is CharacterBody2D:
			body.velocity += direction_vec * force * delta

func _read_global_bool() -> bool:
	if not global_var_name.is_empty() and Engine.has_meta(global_var_name):
		return bool(Engine.get_meta(global_var_name))
	return false

func _set_direction(new_dir: int) -> void:
	if current_direction == new_dir and particles != null:
		return
	current_direction = new_dir
	_rebuild_stream()

func _set_power(power_state: bool) -> void:
	is_fan_on = power_state
	if particles:
		particles.emitting = is_fan_on
	if col_shape:
		col_shape.set_deferred("disabled", not is_fan_on)

func _reset_mode_state() -> void:
	match control_mode:
		ControlMode.CONSTANT:
			is_fan_on = true
			current_direction = default_direction
		ControlMode.SWITCH_POWER:
			is_fan_on = _read_global_bool()
			current_direction = default_direction
		ControlMode.SWITCH_DIRECTION:
			is_fan_on = true
			var switch_is_on = _read_global_bool()
			current_direction = -default_direction if switch_is_on else default_direction
		ControlMode.INTERVAL:
			is_fan_on = start_active
			current_direction = default_direction
			interval_timer = interval_on_time if is_fan_on else interval_off_time

func _apply_state_change() -> void:
	match control_mode:
		ControlMode.CONSTANT:
			_set_power(true)
			_set_direction(default_direction)
		ControlMode.SWITCH_POWER:
			_set_power(_read_global_bool())
			_set_direction(default_direction)
		ControlMode.SWITCH_DIRECTION:
			_set_power(true)
			var switch_is_on = _read_global_bool()
			_set_direction(-default_direction if switch_is_on else default_direction)
		ControlMode.INTERVAL:
			_set_power(start_active)
			_set_direction(default_direction)

func _ensure_unique_collision() -> void:
	if col_shape == null:
		col_shape = get_node_or_null("CollisionShape2D")

	if not col_shape:
		col_shape = CollisionShape2D.new()
		col_shape.name = "CollisionShape2D"
		add_child(col_shape)
		if Engine.is_editor_hint():
			col_shape.owner = get_tree().edited_scene_root

	if col_shape.shape == null:
		col_shape.shape = RectangleShape2D.new()
	elif not col_shape.shape.is_local_to_scene():
		col_shape.shape = col_shape.shape.duplicate()

func _update_collision_dimensions() -> void:
	_ensure_unique_collision()
	if not col_shape or not (col_shape.shape is RectangleShape2D):
		return

	var safe_dist = distance if distance > 0.0 else 100.0
	var safe_width = width if width > 0.0 else 16.0
	col_shape.shape.size = Vector2(safe_width, safe_dist)
	col_shape.position = Vector2(0, -safe_dist * 0.5)

func _setup_particles() -> void:
	if particles == null:
		particles = get_node_or_null("WindParticles")

	if not particles:
		particles = GPUParticles2D.new()
		particles.name = "WindParticles"
		particles.z_index = 5
		particles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		particles.local_coords = true
		add_child(particles)
		if Engine.is_editor_hint():
			particles.owner = get_tree().edited_scene_root

	particles.texture = _generate_streak_texture()
	_rebuild_stream()

func _rebuild_stream() -> void:
	if not is_inside_tree():
		return

	_update_collision_dimensions()
	if not particles:
		return

	var safe_force = force if force > 0.0 else 1600.0
	var safe_dist = distance if distance > 0.0 else 100.0
	var safe_width = width if width > 0.0 else 16.0
	var speed = clamp(safe_force * 0.3, 100.0, 350.0)
	var lifetime = safe_dist / speed

	particles.lifetime = lifetime
	particles.amount = int(clamp(safe_dist * 0.2, 4, 30))

	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(safe_width * 0.35, 1.0, 0.0)
	mat.gravity = Vector3.ZERO
	mat.spread = 0.0
	mat.initial_velocity_min = speed
	mat.initial_velocity_max = speed

	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.0))
	gradient.add_point(0.1, Color(1, 1, 1, 0.6))
	gradient.add_point(0.8, Color(1, 1, 1, 0.4))
	gradient.set_color(1, Color(1, 1, 1, 0.0))

	var grad_tex = GradientTexture1D.new()
	grad_tex.gradient = gradient
	mat.color_ramp = grad_tex

	if current_direction == 1:
		mat.direction = Vector3(0, -1, 0)
		particles.position = Vector2.ZERO
	else:
		mat.direction = Vector3(0, 1, 0)
		particles.position = Vector2(0, -safe_dist)

	particles.process_material = mat
	particles.restart()
	particles.emitting = is_fan_on

func _generate_streak_texture() -> ImageTexture:
	var img = Image.create(3, 7, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	var solid = Color(1, 1, 1, 0.75)
	var fade = Color(1, 1, 1, 0.3)
	
	img.set_pixel(1, 0, fade)
	img.set_pixel(1, 1, solid)
	img.set_pixel(1, 2, solid)
	img.set_pixel(1, 3, solid)
	img.set_pixel(1, 4, solid)
	img.set_pixel(1, 5, solid)
	img.set_pixel(1, 6, fade)

	return ImageTexture.create_from_image(img)
