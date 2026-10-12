How to Deal Damage from Hazards / Enemies
Any hazard, projectile, or spike pit can damage the player in one line of code:

1. Spikes or Environmental Hazards (Area2D)
Attach an Area2D to your spikes, set its shape, and connect its body_entered signal:

GDScript
extends Area2D

@export var damage_amount: int = 1

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage_amount)
2. Instant-Kill Hazards (Lava, bottomless pits, crushing walls)
For hazards that should kill instantly regardless of remaining health, either pass max_health or call die():

GDScript
func _on_body_entered(body: Node2D) -> void:
	if body.has_method("die"):
		body.die()
3. Continuous Contact Damage (Staying inside fire or electricity)
Use body_entered and _physics_process (or a Timer) to hit the player again once invulnerability runs out:

GDScript
extends Area2D

func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(1)


INTERACT
