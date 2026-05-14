class_name PlayerProjectile
extends Area2D

# =========================================================
# [Agent Context] Node Structure Explanation
# =========================================================
# This script is attached to the PlayerProjectile (Area2D) root node.
# The scene contains the following statically configured child nodes for context:
# - PlayerProjectile (Area2D) [Root]
#   ├── Sprite2D (Sprite2D)                 : Projectile texture
#   └── CollisionShape2D (CollisionShape2D) : Collision detection shape
# =========================================================

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

@export var speed: float = 900.0
var direction: Vector2 = Vector2.ZERO
var damage: float = 10.0

func _ready() -> void:
	# Create a timer, call queue_free() automatically after surviving for 3 seconds to prevent memory leaks
	var timer := Timer.new()
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	
	# Connect collision signals
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	# Move in a straight line through global coordinates
	global_position += direction * speed * delta
	# Rotate the projectile texture to face the movement direction (optional)
	rotation = direction.angle()

func _on_body_entered(body: Node2D) -> void:
	# If the body touched is in the "enemy" group and has the take_damage method
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(damage)
		
	# Regardless of hitting an enemy or a wall (Layer 3), destroy itself immediately upon any collision
	queue_free()
