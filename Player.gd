class_name Player
extends CharacterBody2D

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
	# 使用 get_vector 获取 WASD 输入 (依赖项目设置中 ui_* 的按键映射)
	var input_vector: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
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
