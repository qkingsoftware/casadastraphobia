extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -300.0
const NORMAL_GRAVITY = 980.0

# Dynamic Sky Pull Variables
var is_sky_pull_active: bool = true
var min_sky_pull: float = -200.0   # Weak pull near the ground
var max_sky_pull: float = -2000.0  # Strong pull high in the sky
var pull_start_y: float = 200.0    # Y-coordinate where pull is weakest (ground level)
var pull_max_y: float = -1000.0    # Y-coordinate where pull is strongest (high up)

@onready var roof_checker = $RoofChecker

func _physics_process(delta):
	# 1. Jumping
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# 2. Gravity and Sky Pull
	if roof_checker.is_colliding():
		# Under a roof: Normal Gravity
		if not is_on_floor():
			velocity.y += NORMAL_GRAVITY * delta
	else:
		# Exposed to the sky
		if is_sky_pull_active:
			# Clamp current height so it doesn't exceed our boundaries
			var current_y = clamp(global_position.y, pull_max_y, pull_start_y)
			
			# Calculate ratio (0.0 at ground level, 1.0 at max height)
			var height_ratio = (pull_start_y - current_y) / (pull_start_y - pull_max_y)
			
			# Smoothly blend between min and max pull based on height ratio
			var current_pull_force = lerp(min_sky_pull, max_sky_pull, height_ratio)
			
			velocity.y += current_pull_force * delta
			
			# Terminal velocity for falling up
			if velocity.y < -2500:
				velocity.y = -2500
		else:
			# If pull is disabled for this level, fall normally
			velocity.y += NORMAL_GRAVITY * delta

# 3. Horizontal Movement
	var direction = Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * SPEED
		
		# Face Right
		if direction > 0:
			$Sprite2D.flip_h = false
			
			# Force hitbox to stay on the right side
			# (Using abs() ensures it always stays a positive offset)
			$CollisionShape2D.position.x = abs($CollisionShape2D.position.x)
			
			# Optional: If your RoofChecker is also off-center, do the same for it
			# $RoofChecker.position.x = abs($RoofChecker.position.x)
			
		# Face Left
		elif direction < 0:
			$Sprite2D.flip_h = true
			
			# Mirror hitbox to the left side by making the offset negative
			$CollisionShape2D.position.x = -abs($CollisionShape2D.position.x)
			
			# $RoofChecker.position.x = -abs($RoofChecker.position.x)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# 4. Death barrier (Adjusted slightly past max pull height)
	if global_position.y < (pull_max_y - 200):
		die_in_the_sky()
		return

	move_and_slide()

func die_in_the_sky()
		return:
	get_tree().reload_current_scene()
