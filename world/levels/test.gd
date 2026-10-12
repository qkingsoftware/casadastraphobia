extends Node2D

# Export variables allow you to change these in the Godot Inspector per-level
@export var sky_pull_enabled: bool = true
@export var level_min_pull: float = -150.0  # Gentle breeze near ground
@export var level_max_pull: float = -2500.0 # Violent pull in the sky
@export var level_ground_y: float = 300.0   # Where the pull starts (adjust to your floor's Y coordinate)
@export var level_sky_y: float = -1200.0    # Where the pull maxes out

func _ready():
	# Finds the Player node in the scene tree
	# Note: Adjust "Player" if your character node has a different name
	var player = get_node_or_null("Player") 
	
	if player:
		# Overwrite the player's default variables with this level's specific settings
		player.is_sky_pull_active = sky_pull_enabled
		player.min_sky_pull = level_min_pull
		player.max_sky_pull = level_max_pull
		player.pull_start_y = level_ground_y
		player.pull_max_y = level_sky_y
	else:
		push_warning("Level script could not find the Player node!")
