@tool
class_name LaserEmitter
extends Area2D

enum OperatingMode {
	CONSTANT,
	SWITCH,
	INTERVAL
}

enum BeamDirection {
	RIGHT,
	LEFT,
	UP,
	DOWN
}

const BEAM_COLOR_ACTIVE: Color = Color(1.0, 0.15, 0.15, 0.9)
const BEAM_COLOR_WARN: Color = Color(1.0, 0.45, 0.1, 0.25)
const BEAM_COLOR_OFF: Color = Color(0.0, 0.0, 0.0, 0.0)

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
@export var warning_duration: float = 0.5
@export var start_active: bool = true

@export_group("Beam Configuration")
@export var direction: BeamDirection = BeamDirection.RIGHT:
	set(val):
		direction = val
		_update_appearance()

@export var max_beam_distance: float = 640.0:
	set(val):
		max_beam_distance = val
		_update_appearance()

@export var damage_amount: int = 1

var anim_sprite: AnimatedSprite2D
var ray_cast: RayCast2D
var line_2d: Line2D
var col_shape: CollisionShape2D

var is_active: bool = true
var is_warning: bool = false
var interval_timer: float = 0.0

func _enter_tree() -> void:
	_resolve_nodes()
	_isolate_resources()

func _ready() -> void:
	monitoring = true
	_resolve_nodes()
	_isolate_resources()
	_configure_raycast()
	_reset_mode_state()
	_update_appearance()

	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if not Engine.is_editor_hint():
		_update_mode_logic(delta)

	_update_beam_geometry()

	if not Engine.is_editor_hint() and is_active and not is_warning:
		for body in get_overlapping_bodies():
			if body.has_method("take_damage"):
				body.take_damage(damage_amount)

func _resolve_nodes() -> void:
	if anim_sprite == null:
		anim_sprite = get_node_or_null("AnimatedSprite2D")
	if ray_cast == null:
		ray_cast = get_node_or_null("RayCast2D")
	if line_2d == null:
		line_2d = get_node_or_null("Line2D")
	if col_shape == null:
		col_shape = get_node_or_null("CollisionShape2D")

func _isolate_resources() -> void:
	_resolve_nodes()

	if col_shape:
		if col_shape.shape == null:
			col_shape.shape = RectangleShape2D.new()
		elif not col_shape.shape.is_local_to_scene():
			col_shape.shape = col_shape.shape.duplicate()

	if anim_sprite and anim_sprite.sprite_frames:
		if not anim_sprite.sprite_frames.is_local_to_scene():
			anim_sprite.sprite_frames = anim_sprite.sprite_frames.duplicate()

func _configure_raycast() -> void:
	if ray_cast:
		ray_cast.collide_with_areas = false
		ray_cast.collide_with_bodies = true
		ray_cast.add_exception(self)

func _update_mode_logic(delta: float) -> void:
	var prev_active = is_active
	var prev_warning = is_warning

	match mode:
		OperatingMode.CONSTANT:
			is_active = true
			is_warning = false

		OperatingMode.SWITCH:
			is_warning = false
			if required_switch_meta.strip_edges() == "":
				is_active = true
			else:
				var raw_state = false
				if Engine.has_meta(required_switch_meta):
					raw_state = bool(Engine.get_meta(required_switch_meta))
				is_active = (not raw_state) if invert_switch else raw_state

		OperatingMode.INTERVAL:
			interval_timer -= delta
			if is_active:
				if interval_timer <= 0.0:
					is_active = false
					interval_timer = interval_off_time
			else:
				if interval_timer <= warning_duration:
					is_warning = true
				if interval_timer <= 0.0:
					is_active = true
					is_warning = false
					interval_timer = interval_on_time

	if prev_active != is_active or prev_warning != is_warning:
		monitoring = is_active and not is_warning
		_update_appearance()

func _reset_mode_state() -> void:
	match mode:
		OperatingMode.CONSTANT:
			is_active = true
			is_warning = false
		OperatingMode.SWITCH:
			is_warning = false
			if required_switch_meta.strip_edges() == "":
				is_active = true
			else:
				var raw = bool(Engine.get_meta(required_switch_meta)) if Engine.has_meta(required_switch_meta) else false
				is_active = (not raw) if invert_switch else raw
		OperatingMode.INTERVAL:
			is_active = start_active
			is_warning = false
			interval_timer = interval_on_time if is_active else interval_off_time

func _update_beam_geometry() -> void:
	if not is_inside_tree():
		return

	_resolve_nodes()

	var dir_vec = get_direction_vector()
	var beam_origin = dir_vec * 8.0 # Emitter face offset
	var target_endpoint = dir_vec * max_beam_distance

	if ray_cast:
		_configure_raycast()
		ray_cast.position = beam_origin
		ray_cast.target_position = target_endpoint - beam_origin
		ray_cast.force_raycast_update()

		if ray_cast.is_colliding():
			var hit_pt = to_local(ray_cast.get_collision_point())
			# Ensure we didn't hit internal origin or an invalid point behind the origin
			if (hit_pt - beam_origin).dot(dir_vec) > 1.0:
				target_endpoint = hit_pt

	var beam_len: float = max(0.0, (target_endpoint - beam_origin).length())

	if line_2d:
		line_2d.clear_points()
		if is_active or is_warning or Engine.is_editor_hint():
			line_2d.add_point(beam_origin)
			line_2d.add_point(target_endpoint)

	if col_shape and col_shape.shape is RectangleShape2D:
		match direction:
			BeamDirection.RIGHT: col_shape.rotation_degrees = 0.0
			BeamDirection.LEFT:  col_shape.rotation_degrees = 180.0
			BeamDirection.UP:    col_shape.rotation_degrees = -90.0
			BeamDirection.DOWN:  col_shape.rotation_degrees = 90.0

		col_shape.shape.size = Vector2(beam_len, 4.0)
		col_shape.position = beam_origin + (dir_vec * (beam_len * 0.5))

		if not Engine.is_editor_hint():
			col_shape.disabled = not (is_active and not is_warning)
		else:
			col_shape.disabled = false

func _on_body_entered(body: Node2D) -> void:
	if is_active and not is_warning:
		if body.has_method("take_damage"):
			body.take_damage(damage_amount)

func get_direction_vector() -> Vector2:
	match direction:
		BeamDirection.RIGHT: return Vector2.RIGHT
		BeamDirection.LEFT:  return Vector2.LEFT
		BeamDirection.UP:    return Vector2.UP
		BeamDirection.DOWN:  return Vector2.DOWN
	return Vector2.RIGHT

func _update_appearance() -> void:
	if not is_inside_tree():
		return

	_resolve_nodes()

	if anim_sprite:
		anim_sprite.position = Vector2.ZERO
		match direction:
			BeamDirection.RIGHT: anim_sprite.rotation_degrees = 0.0
			BeamDirection.LEFT:  anim_sprite.rotation_degrees = 180.0
			BeamDirection.UP:    anim_sprite.rotation_degrees = -90.0
			BeamDirection.DOWN:  anim_sprite.rotation_degrees = 90.0

		if is_active or is_warning or Engine.is_editor_hint():
			if anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("on"):
				anim_sprite.play("on")
		else:
			if anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("off"):
				anim_sprite.play("off")

	if line_2d:
		line_2d.width = 4.0
		if not is_active and not Engine.is_editor_hint():
			line_2d.default_color = BEAM_COLOR_OFF
		elif is_warning:
			line_2d.default_color = BEAM_COLOR_WARN
		else:
			line_2d.default_color = BEAM_COLOR_ACTIVE

	_update_beam_geometry()
