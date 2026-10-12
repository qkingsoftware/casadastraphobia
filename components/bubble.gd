extends Area2D

@export var default_speed: float = 180.0
@export var default_lifetime: float = 2.0

@onready var anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var col: CollisionShape2D = get_node_or_null("CollisionShape2D")

var move_velocity: Vector2 = Vector2.ZERO
var lifetime: float = 0.0
var _is_popping: bool = false
var _spawner: Node = null
var _spawn_grace: float = 0.08

func setup(vel: Vector2, max_lifetime: float, spawner: Node = null) -> void:
	move_velocity = vel
	lifetime = max_lifetime
	_spawner = spawner

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	if lifetime <= 0.0:
		lifetime = default_lifetime

	if anim and anim.sprite_frames:
		if anim.sprite_frames.has_animation("spawn"):
			anim.play("spawn")
			if not anim.animation_finished.is_connected(_on_animation_finished):
				anim.animation_finished.connect(_on_animation_finished)
		elif anim.sprite_frames.has_animation("float"):
			anim.play("float")

func _physics_process(delta: float) -> void:
	if _is_popping:
		return

	if _spawn_grace > 0.0:
		_spawn_grace -= delta

	global_position += move_velocity * delta

	lifetime -= delta
	if lifetime <= 0.0:
		pop()

func _on_body_entered(body: Node2D) -> void:
	if body == _spawner:
		return
	if _spawn_grace > 0.0:
		return
	pop()

func _on_area_entered(area: Area2D) -> void:
	if area == _spawner or area.get_parent() == _spawner:
		return
	if _spawn_grace > 0.0:
		return
	pop()

func _on_animation_finished() -> void:
	if anim and anim.animation == "spawn":
		if anim.sprite_frames.has_animation("float"):
			anim.play("float")

func pop() -> void:
	if _is_popping:
		return
	_is_popping = true

	move_velocity = Vector2.ZERO
	if col:
		col.set_deferred("disabled", true)

	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("pop"):
		anim.play("pop")
		await anim.animation_finished

	queue_free()
