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
	# Retrieve stats safely, defaulting to 0.0 if not found
	var slow_debuff: float = GameManager.stats.get("enemy_slow", 0.0) as float
	var atk_debuff: float = GameManager.stats.get("enemy_atk_debuff", 0.0) as float
	var def_debuff: float = GameManager.stats.get("enemy_def_debuff", 0.0) as float
	
	# 速度减益：通过 mini(0.8, x) 确保减速比例最高只到 80%
	# 如果没有这个保护，当减速达到 100% 以上时，(1.0 - 1.1) 会变成负数，导致怪物倒着向后移动
	current_speed = base_speed * (1.0 - mini(0.8, slow_debuff / 100.0))
	
	# 攻击力减益：同样限制最高削减 80% 的攻击力
	# 防止攻击力变为负数，导致怪物打到玩家时反而给玩家加血
	current_atk = base_atk * (1.0 - mini(0.8, atk_debuff / 100.0))
	
	# 防御削减：通过 maxf(0.0, x) 确保护甲最低被扒光到 0 点
	# 如果护甲掉到负数（如 -10），在后续的护甲公式中 100 / (100 - 10) 会导致受击倍率异常变大甚至溢出
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
	# 护甲减伤公式：经典的英雄联盟/Dota护甲模型
	# 当有效护甲 (effective_def) 为 0 时，100 / 100 = 1.0 (承受 100% 真实伤害)
	# 当有效护甲为 100 时，100 / 200 = 0.5 (承受 50% 伤害，减伤一半)
	var dmg_multiplier: float = 100.0 / (100.0 + effective_def)
	
	# 实际扣血 = 子弹面板伤害 * 护甲乘区
	current_hp -= (incoming_damage * dmg_multiplier)
	
	# 更新悬浮血条 UI
	if hp_bar:
		hp_bar.value = current_hp
	
	# Destroy if HP drops to 0 or below
	if current_hp <= 0:
		queue_free()

func _on_hitbox_body_entered(body: Node2D) -> void:
	# Check if the body is a player and can take damage
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(current_atk)
