class_name Player
extends CharacterBody2D

# =========================================================
# 【Agent Context】 节点结构说明
# =========================================================
# 本脚本挂载于 Player (CharacterBody2D) 根节点上。
# 场景包含以下子节点，便于后续迭代获取上下文：
# - Player (CharacterBody2D) [Root]
#   ├── CollisionShape2D (CollisionShape2D) : 碰撞体
#   ├── Sprite2D (Sprite2D)                 : 玩家贴图/动画
#   ├── ShootTimer (Timer)                  : 控制射击频率的计时器
#   └── Camera2D (Camera2D)                 : 玩家跟随相机
# =========================================================

# =========================================================
# 节点引用 (Nodes)
# =========================================================
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var shoot_timer: Timer = $ShootTimer
@onready var camera: Camera2D = $Camera2D

# =========================================================
# 属性定义
# =========================================================
var hp: int = 0
var stamina: int = 0

const BASE_SPEED: float = 500.0
const DASH_MULTIPLIER: float = 3.0
const DASH_DURATION: float = 0.15
const DASH_COST: int = 1

var _is_dashing: bool = false
var _dash_timer: float = 0.0

# =========================================================
# 生命周期
# =========================================================
func _ready() -> void:
	# 初始同步属性
	_sync_stats()
	# 连接 GameManager 信号以实时更新属性
	if GameManager.has_signal("stats_updated"):
		GameManager.stats_updated.connect(_on_stats_updated)

func _physics_process(delta: float) -> void:
	_handle_dash(delta)
	_handle_movement()
	move_and_slide() # 自动处理边界和障碍物碰撞

# =========================================================
# 属性同步逻辑
# =========================================================
func _on_stats_updated() -> void:
	_sync_stats()

func _sync_stats() -> void:
	hp = GameManager.stats.get("hp", 0) as int
	stamina = GameManager.stats.get("stamina", 0) as int

# =========================================================
# 移动与冲刺逻辑
# =========================================================
func _handle_dash(delta: float) -> void:
	# 处理冲刺计时
	if _is_dashing:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_is_dashing = false
			
	# 检测冲刺输入：按下 'ui_select'，当前未冲刺，且体力充足
	if Input.is_action_just_pressed("ui_select") and not _is_dashing and stamina >= DASH_COST:
		_is_dashing = true
		_dash_timer = DASH_DURATION
		stamina -= DASH_COST
		# 注意：此处仅扣除本地 stamina。如果后续设计需要全局保存消耗的体力，应该在此处反向调用 GameManager 更新状态。

func _handle_movement() -> void:
	# 获取方向键输入 (ui_*)
	var ui_input: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# 获取 WASD 物理按键输入
	var wasd_x: float = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var wasd_y: float = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	var wasd_input: Vector2 = Vector2(wasd_x, wasd_y)
	
	# 合并两种输入，并限制向量长度最大为 1.0，防止斜向或叠加移动过快
	var input_vector: Vector2 = (ui_input + wasd_input).limit_length(1.0)
	
	var current_speed: float = BASE_SPEED
	if _is_dashing:
		current_speed *= DASH_MULTIPLIER
		
	velocity = input_vector * current_speed

# =========================================================
# 自动瞄准辅助
# =========================================================
func get_closest_enemy() -> Node2D:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemy")
	var closest_enemy: Node2D = null
	var min_distance: float = INF
	
	for enemy: Node in enemies:
		if enemy is Node2D:
			var distance: float = global_position.distance_to(enemy.global_position)
			if distance < min_distance:
				min_distance = distance
				closest_enemy = enemy as Node2D
				
	return closest_enemy
