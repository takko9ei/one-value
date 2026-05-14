class_name EnemyBase
extends CharacterBody2D

# Declare death signal, used to notify the level controller
signal died

# =========================================================
# [Agent Context] Node Structure Explanation
# =========================================================
# This script is attached to the EnemyBase (CharacterBody2D) root node.
# The scene contains the following child nodes for context:
# - EnemyBase (CharacterBody2D) [Root]
#   ├── CollisionPolygon2D (CollisionPolygon2D) : Collider for physics detection, enemy pushing, environment collision
#   ├── Sprite2D (Sprite2D)                     : Enemy texture/animation
#   └── Hitbox (Area2D)                         : Used to detect collision with player to deal damage
#       └── CollisionPolygon2D (CollisionPolygon2D) : Collider for the hitbox
# =========================================================

# =========================================================
# Node References
# =========================================================
@onready var collision_polygon: CollisionPolygon2D = $CollisionPolygon2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var hp_bar: ProgressBar = $ProgressBar

# =========================================================
# Exported Base Attributes
# =========================================================
@export var base_hp: float = 50.0
@export var base_def: float = 30.0
@export var base_atk: float = 20.0
@export var base_speed: float = 120.0

# =========================================================
# Runtime Attributes
# =========================================================
var current_hp: float
var effective_def: float
var current_speed: float
var current_atk: float

func _ready() -> void:
	# Initialize current HP
	current_hp = base_hp
	
	# Calculate attributes based on GameManager stats
	_sync_stats()
	
	# Initialize health bar
	if hp_bar:
		hp_bar.max_value = base_hp
		hp_bar.value = current_hp
	
	# Connect to GameManager signal for real-time updates
	if GameManager.has_signal("stats_updated"):
		GameManager.stats_updated.connect(_sync_stats)
		
	# Connect Hitbox signal for dealing damage
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)

func _sync_stats() -> void:
	# Retrieve stats safely and cast to float
	var slow_debuff: float = float(GameManager.stats.get("enemy_slow", 0.0))
	var atk_debuff: float = float(GameManager.stats.get("enemy_atk_debuff", 0.0))
	var def_debuff: float = float(GameManager.stats.get("enemy_def_debuff", 0.0))
	
	# Speed debuff: cap the reduction ratio at 80% using minf(0.8, x)
	current_speed = base_speed * (1.0 - minf(0.8, slow_debuff / 100.0))
	
	# Attack debuff: similarly restrict maximum reduction to 80%
	current_atk = base_atk * (1.0 - minf(0.8, atk_debuff / 100.0))
	
	# Defense debuff: ensure armor can be stripped down to a minimum of 0
	effective_def = maxf(0.0, base_def - (def_debuff * 2.0))

func _physics_process(_delta: float) -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
		
	var player: Node2D = players[0] as Node2D
		
	if player and not player.is_queued_for_deletion():
		# Calculate direction towards the player
		var direction: Vector2 = global_position.direction_to(player.global_position)
		
		# Set velocity and move
		velocity = direction * current_speed
		move_and_slide()

func take_damage(incoming_damage: float) -> void:
	# Armor damage reduction formula: classic League of Legends/Dota armor model
	# When effective_def is 0: 100 / 100 = 1.0 (take 100% true damage)
	# When effective_def is 100: 100 / 200 = 0.5 (take 50% damage, half reduction)
	var dmg_multiplier: float = 100.0 / (100.0 + effective_def)
	
	# Actual damage taken = incoming bullet damage * armor multiplier
	current_hp -= (incoming_damage * dmg_multiplier)
	
	# Update floating health bar UI
	if hp_bar:
		hp_bar.value = current_hp
	
	# Destroy if HP drops to 0 or below
	if current_hp <= 0:
		died.emit()
		queue_free()

func _on_hitbox_body_entered(body: Node2D) -> void:
	# Check if the body is a player and can take damage
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(current_atk)
