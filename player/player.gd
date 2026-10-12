extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -300.0
const NORMAL_GRAVITY = 980.0

@export_group("Health")
@export var max_health: int = 3
@export var invulnerability_duration: float = 1.0

var current_health: int = 3
var is_invulnerable: bool = false

# Dynamic Sky Pull Variables
var is_sky_pull_active: bool = true
var min_sky_pull: float = -200.0   # Weak pull near the ground
var max_sky_pull: float = -2000.0  # Strong pull high in the sky
var pull_start_y: float = 200.0    # Y-coordinate where pull is weakest (ground level)
var pull_max_y: float = -1000.0    # Y-coordinate where pull is strongest (high up)

@onready var roof_checker: RayCast2D = get_node_or_null("RoofChecker")
@onready var sprite: Sprite2D = $Sprite2D
@onready var col_shape: CollisionShape2D = $CollisionShape2D

var in_gravity_zone: bool = false
var nearby_interactable: Area2D = null

func _ready() -> void:
	current_health = max_health
	_update_hud_health()

	# Create interaction detector area dynamically
	var interact_area = Area2D.new()
	interact_area.name = "InteractionDetector"
	
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 32.0
	shape.shape = circle
	interact_area.add_child(shape)
	
	# Detect interactables on Area layers
	interact_area.area_entered.connect(_on_interact_area_entered)
	interact_area.area_exited.connect(_on_interact_area_exited)
	add_child(interact_area)

func _physics_process(delta: float) -> void:
	# 0. Dialogue freeze
	if Engine.has_meta("in_dialogue") and bool(Engine.get_meta("in_dialogue")):
		velocity.x = move_toward(velocity.x, 0.0, SPEED * 8.0 * delta)
		move_and_slide()
		return

	# 1. Direct query: Check if we are inside an active GravityZone
	_check_gravity_zones()

	# 2. Update vertical orientation & disable floor snapping when inverted
	if in_gravity_zone:
		up_direction = Vector2.DOWN
		floor_snap_length = 0.0          # Stop Godot from gluing player to ground
		sprite.flip_v = true
	else:
		up_direction = Vector2.UP
		floor_snap_length = 8.0          # Normal ground snap
		sprite.flip_v = false

	# 3. Jumping (Action: "jump")
	if Input.is_action_just_pressed("jump"):
		if in_gravity_zone:
			# Standing upside-down on ceiling: jump pushes downward
			if is_on_floor() or is_on_ceiling():
				velocity.y = abs(JUMP_VELOCITY)
		else:
			# Normal jump: pushes upward
			if is_on_floor():
				velocity.y = JUMP_VELOCITY

	# 4. Interaction (Action: "interact")
	if Input.is_action_just_pressed("interact"):
		if nearby_interactable and nearby_interactable.has_method("interact"):
			nearby_interactable.interact()

	# 5. Gravity & Sky Pull
	if in_gravity_zone:
		# Pull UP towards the ceiling
		if not is_on_floor():
			velocity.y -= NORMAL_GRAVITY * delta
		else:
			if velocity.y < 0.0:
				velocity.y = 0.0
	elif roof_checker and roof_checker.is_colliding():
		# Under a roof: normal downward gravity
		if not is_on_floor():
			velocity.y += NORMAL_GRAVITY * delta
	else:
		# Exposed to the sky pull
		if is_sky_pull_active:
			var current_y = clamp(global_position.y, pull_max_y, pull_start_y)
			var height_ratio = (pull_start_y - current_y) / (pull_start_y - pull_max_y)
			var current_pull_force = lerp(min_sky_pull, max_sky_pull, height_ratio)
			
			velocity.y += current_pull_force * delta
			if velocity.y < -2500.0:
				velocity.y = -2500.0
		else:
			if not is_on_floor():
				velocity.y += NORMAL_GRAVITY * delta

	# 6. Horizontal Movement
	var direction = Input.get_axis("left", "right")
	var target_speed = direction * SPEED

	if direction:
		velocity.x = move_toward(velocity.x, target_speed, SPEED * 8.0 * delta)
		if direction > 0:
			sprite.flip_h = false
			col_shape.position.x = abs(col_shape.position.x)
		elif direction < 0:
			sprite.flip_h = true
			col_shape.position.x = -abs(col_shape.position.x)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED * 4.0 * delta)

	# 7. Death barrier
	if global_position.y < (pull_max_y - 200.0):
		die()
		return

	move_and_slide()

# --- Health, Damage, and Death ---

func take_damage(amount: int = 1) -> void:
	if is_invulnerable or current_health <= 0:
		return

	current_health = max(0, current_health - amount)
	_update_hud_health()

	if current_health <= 0:
		die()
		return

	# Temporary invulnerability with sprite flicker
	is_invulnerable = true
	var flicker_tween = create_tween().set_loops(int(invulnerability_duration / 0.2))
	flicker_tween.tween_property(sprite, "modulate:a", 0.2, 0.1)
	flicker_tween.tween_property(sprite, "modulate:a", 1.0, 0.1)
	
	get_tree().create_timer(invulnerability_duration).timeout.connect(func():
		is_invulnerable = false
		sprite.modulate.a = 1.0
	)

func heal(amount: int = 1) -> void:
	current_health = min(max_health, current_health + amount)
	_update_hud_health()

func die() -> void:
	# Reset dialogue metadata before reloading so inputs aren't locked
	Engine.set_meta("in_dialogue", false)
	get_tree().reload_current_scene()

func _update_hud_health() -> void:
	if Engine.has_meta("HUD"):
		var hud = Engine.get_meta("HUD")
		if hud.has_method("update_health"):
			hud.update_health(current_health, max_health)

# --- Area / Zone Checkers ---

func _check_gravity_zones() -> void:
	in_gravity_zone = false
	var zones = get_tree().get_nodes_in_group("gravityzone")
	for zone in zones:
		if zone is Area2D and zone.has_method("is_point_inside"):
			if zone.is_point_inside(global_position):
				in_gravity_zone = true
				break

func _on_interact_area_entered(area: Area2D) -> void:
	if area.has_method("interact"):
		nearby_interactable = area

func _on_interact_area_exited(area: Area2D) -> void:
	if area == nearby_interactable:
		nearby_interactable = null
