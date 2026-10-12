@tool
extends StaticBody2D

enum FireMode {
	CONSTANT,
	INTERVAL,
	GLOBAL_BOOL
}

@export_group("Power")
## Master switch. If false, cannon remains off.
@export var enabled: bool = true:
	set(val):
		enabled = val
		_reset_mode_state()
		queue_redraw()

@export_group("Shooting Modes")
@export var mode: FireMode = FireMode.GLOBAL_BOOL:
	set(val):
		mode = val
		_reset_mode_state()

@export var active_time: float = 2.0
@export var inactive_time: float = 2.0

## Must match the exact global_var_name in Switch.gd
@export var global_var_name: String = "cannon_switch_1":
	set(val):
		global_var_name = val.strip_edges()

@export_group("Bubble Settings")
## Drag and drop bubble.tscn here!
@export var bubble_scene: PackedScene

@export var fire_rate: float = 0.4
@export var bubble_speed: float = 180.0
@export var range_distance: float = 200.0:
	set(val):
		range_distance = max(val, 16.0)
		queue_redraw()

@export var muzzle_offset: Vector2 = Vector2(24.0, 0.0):
	set(val):
		muzzle_offset = val
		queue_redraw()

@export_group("Editor Gizmo")
@export var show_range_gizmo: bool = true:
	set(val):
		show_range_gizmo = val
		queue_redraw()

@export var gizmo_color: Color = Color(0.2, 0.7, 1.0, 0.5):
	set(val):
		gizmo_color = val
		queue_redraw()

var is_active: bool = false
var anim_sprite: AnimatedSprite2D
var _fire_timer: float = 0.0
var _interval_timer: float = 0.0
var _is_in_interval_burst: bool = true
var _active_bubbles: Array[Area2D] = []

func _ready() -> void:
	_setup_animated_sprite()
	_update_animation_state()

	if Engine.is_editor_hint():
		queue_redraw()
		return

	# Warning to help catch missing setup
	if not bubble_scene:
		push_error("[BubbleCannon] NO BUBBLE SCENE ASSIGNED in the Inspector!")

	_reset_mode_state()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_cleanup_dead_bubbles()

	# 1. Determine active state
	var target_active = false
	if enabled:
		match mode:
			FireMode.CONSTANT:
				target_active = true

			FireMode.INTERVAL:
				_interval_timer -= delta
				if _interval_timer <= 0.0:
					_is_in_interval_burst = !_is_in_interval_burst
					_interval_timer = active_time if _is_in_interval_burst else inactive_time
				target_active = _is_in_interval_burst

			FireMode.GLOBAL_BOOL:
				if not global_var_name.is_empty() and Engine.has_meta(global_var_name):
					target_active = bool(Engine.get_meta(global_var_name))

	# 2. State transition check (explicit function call)
	if target_active != is_active:
		set_active(target_active)

	# 3. Fire logic
	if is_active:
		_fire_timer -= delta
		if _fire_timer <= 0.0:
			_spawn_bubble()
			_fire_timer = max(fire_rate, 0.05)

func set_active(val: bool) -> void:
	is_active = val
	_update_animation_state()

	if is_active:
		# Fire first shot immediately on turning on
		_fire_timer = 0.0
	else:
		_fire_timer = 0.0
		_clear_active_bubbles()

func _spawn_bubble() -> void:
	if not bubble_scene:
		return

	var travel_time: float = range_distance / max(bubble_speed, 1.0)
	var max_capacity: int = int(ceil(travel_time / max(fire_rate, 0.01)))

	# Pop the oldest bubble if stream is full
	if _active_bubbles.size() >= max_capacity:
		var oldest = _active_bubbles.pop_front()
		if is_instance_valid(oldest) and oldest.has_method("pop"):
			oldest.pop()

	var bubble = bubble_scene.instantiate()

	# Facing direction (+X right, rotated with cannon transform)
	var fire_dir = global_transform.x.normalized()
	var spawn_pos = global_position + (fire_dir * muzzle_offset.x) + (global_transform.y.normalized() * muzzle_offset.y)

	if bubble.has_method("setup"):
		bubble.setup(fire_dir * bubble_speed, travel_time, self)

	# Spawn in the level root, not inside cannon
	get_parent().add_child(bubble)
	bubble.global_position = spawn_pos

	_active_bubbles.append(bubble)

func _clear_active_bubbles() -> void:
	for bubble in _active_bubbles:
		if is_instance_valid(bubble) and not bubble.is_queued_for_deletion():
			if bubble.has_method("pop"):
				bubble.pop()
			else:
				bubble.queue_free()
	_active_bubbles.clear()

func _cleanup_dead_bubbles() -> void:
	_active_bubbles = _active_bubbles.filter(func(b): return is_instance_valid(b) and not b.is_queued_for_deletion())

func _setup_animated_sprite() -> void:
	anim_sprite = get_node_or_null("AnimatedSprite2D")
	if not anim_sprite:
		anim_sprite = AnimatedSprite2D.new()
		anim_sprite.name = "AnimatedSprite2D"
		add_child(anim_sprite)

func _update_animation_state() -> void:
	if not anim_sprite:
		anim_sprite = get_node_or_null("AnimatedSprite2D")
	if not anim_sprite or not anim_sprite.sprite_frames:
		return

	var target_anim = "on" if is_active else "off"
	if anim_sprite.sprite_frames.has_animation(target_anim):
		if anim_sprite.animation != target_anim or not anim_sprite.is_playing():
			anim_sprite.play(target_anim)

func _reset_mode_state() -> void:
	_fire_timer = 0.0
	_is_in_interval_burst = true
	_interval_timer = active_time

func _draw() -> void:
	if not Engine.is_editor_hint() or not show_range_gizmo:
		return

	var start_pt = muzzle_offset
	var end_pt = muzzle_offset + Vector2(range_distance, 0.0)
	var draw_col = gizmo_color if enabled else Color(gizmo_color.r, gizmo_color.g, gizmo_color.b, gizmo_color.a * 0.25)

	draw_line(start_pt, end_pt, draw_col, 2.0)
	draw_circle(start_pt, 3.0, draw_col)
	draw_arc(end_pt, 12.0, 0.0, TAU, 24, draw_col, 1.5)
