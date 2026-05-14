class_name LevelController
extends Node2D

# =========================================================
# 【Agent Context】 节点结构说明
# =========================================================
# 挂载于 LevelController 节点
# 场景期望包含以下子节点：
# - LevelController (Node2D)
#   ├── SpawnTimer (Timer) : 控制刷怪间隔
#   └── SpawnPoints (Node2D) : 作为容器，其下挂载多个 Marker2D 作为生成点
# =========================================================

# =========================================================
# 关卡参数 (可暴露给各个 Stage 独立调整)
# =========================================================
@export var enemy_scene: PackedScene
@export var total_enemies_to_kill: int = 20
@export var spawn_interval: float = 1.0
@export var max_enemies_on_screen: int = 15

# =========================================================
# 内部状态变量
# =========================================================
var current_kills: int = 0
var _spawn_points: Array[Marker2D] = []

# =========================================================
# 节点引用
# =========================================================
@onready var spawn_timer: Timer = $SpawnTimer

func _ready() -> void:
	# 1. 初始化 SpawnTimer
	if spawn_timer:
		spawn_timer.wait_time = spawn_interval
		spawn_timer.timeout.connect(_on_spawn_timer_timeout)
		spawn_timer.start()
	else:
		push_error("LevelController: 找不到 SpawnTimer 节点！")
		
	# 2. 获取所有的生成点
	var points_container: Node = get_node_or_null("SpawnPoints")
	if points_container:
		for child: Node in points_container.get_children():
			if child is Marker2D:
				_spawn_points.append(child)
				
	if _spawn_points.is_empty():
		push_warning("LevelController: SpawnPoints 下没有找到任何 Marker2D 生成点！")

func _on_spawn_timer_timeout() -> void:
	# 安全校验
	if not enemy_scene or _spawn_points.is_empty():
		return
		
	# 检查当前同屏怪物数量，限制最大生成数
	var current_enemies: Array[Node] = get_tree().get_nodes_in_group("enemy")
	if current_enemies.size() >= max_enemies_on_screen:
		return # 屏幕上怪物太多了，本次跳过生成
		
	# 随机选择一个生成点
	var random_point: Marker2D = _spawn_points.pick_random()
	
	# 实例化敌人
	var enemy: EnemyBase = enemy_scene.instantiate() as EnemyBase
	if enemy:
		enemy.global_position = random_point.global_position
		
		# 关键：连接敌人的死亡信号到控制器的统计函数
		enemy.died.connect(_on_enemy_died)
		
		# 将敌人添加到当前场景树中
		var current_scene: Node = get_tree().current_scene
		if current_scene:
			current_scene.add_child(enemy)
		else:
			get_tree().root.add_child(enemy)

func _on_enemy_died() -> void:
	# 每次有敌人发出 died 信号，击杀数 + 1
	current_kills += 1
	
	# 检查通关条件
	if current_kills >= total_enemies_to_kill:
		# 通关条件达成，停止刷怪
		if spawn_timer:
			spawn_timer.stop()
			
		print("Level Cleared! 关卡通过！")
		
		# 进入下一关或跳转到加点 UI
		if GameManager.has_method("next_level"):
			GameManager.next_level()
		else:
			push_error("LevelController: GameManager 中未定义 next_level() 方法！")
