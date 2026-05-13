class_name EnemyBase
extends CharacterBody2D

# =========================================================
# 【Agent Context】 节点结构说明
# =========================================================
# 本脚本挂载于 EnemyBase (CharacterBody2D) 根节点上。
# 场景包含以下子节点，便于后续迭代获取上下文：
# - EnemyBase (CharacterBody2D) [Root]
#   ├── CollisionPolygon2D (CollisionPolygon2D) : 碰撞体，用于碰撞检测，敌人互挤，环境碰撞
#   ├── Sprite2D (Sprite2D)                     : 敌人贴图/动画
#   └── Hitbox (Area2D)                         : 用于碰撞玩家扣玩家血
#       └── CollisionPolygon2D (CollisionPolygon2D) : 用于上述hit的碰撞体
# =========================================================

# =========================================================
# Node References
# =========================================================
@onready var collision_polygon: CollisionPolygon2D = $CollisionPolygon2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox: Area2D = $Hitbox

# =========================================================
# Exported Base Attributes
# =========================================================
@export var base_hp: float = 20.0
@export var base_speed: float = 100.0
@export var base_damage: float = 10.0

# =========================================================
# Runtime Attributes
# =========================================================
var current_hp: float
var current_speed: float
var current_damage: float

func _ready() -> void:
	# Initialize current HP
	current_hp = base_hp
	
	# Calculate attributes based on GameManager stats
	_sync_stats()
	
	# Connect to GameManager signal for real-time updates
	if GameManager.has_signal("stats_updated"):
		GameManager.stats_updated.connect(_sync_stats)
		
	# Connect Hitbox signal for dealing damage
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)

func _sync_stats() -> void:
	# Retrieve stats safely, defaulting to 0.0 if not found
	var slow_debuff: float = GameManager.stats.get("enemy_slow", 0.0) as float
	var atk_debuff: float = GameManager.stats.get("enemy_atk_debuff", 0.0) as float
	
	# Calculate speed with slow debuff
	current_speed = base_speed * (1.0 - (slow_debuff / 100.0))
	
	# Calculate damage with attack debuff
	current_damage = base_damage * (1.0 - (atk_debuff / 100.0))

func _physics_process(_delta: float) -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
		
	var player: Node2D = players[0] as Node2D
		
	if player:
		# Calculate direction towards the player
		var direction: Vector2 = global_position.direction_to(player.global_position)
		
		# Set velocity and move
		velocity = direction * current_speed
		move_and_slide()

func take_damage(amount: float) -> void:
	# Calculate vulnerability debuff (every 1 point increases final damage by 2%)
	var def_debuff: float = GameManager.stats.get("enemy_def_debuff", 0.0) as float
	var final_damage: float = amount * (1.0 + def_debuff * 0.02)
	
	# Apply damage
	current_hp -= final_damage
	
	# Destroy if HP drops to 0 or below
	if current_hp <= 0:
		queue_free()

func _on_hitbox_body_entered(body: Node2D) -> void:
	# Check if the body is a player and can take damage
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(current_damage)
