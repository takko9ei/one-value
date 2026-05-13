class_name PlayerProjectile
extends Area2D

# =========================================================
# 【Agent Context】 节点结构说明
# =========================================================
# 本脚本挂载于 PlayerProjectile (Area2D) 根节点上。
# 场景包含以下静态配置的子节点，便于后续迭代获取上下文：
# - PlayerProjectile (Area2D) [Root]
#   ├── Sprite2D (Sprite2D)                 : 子弹贴图
#   └── CollisionShape2D (CollisionShape2D) : 碰撞检测形状
# （注：内部还会通过代码动态生成 Timer 和 VisibleOnScreenNotifier2D）
# =========================================================

# =========================================================
# 节点引用 (Nodes)
# =========================================================
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

@export var speed: float = 800.0
@export var max_lifetime: float = 5.0

var direction: Vector2 = Vector2.ZERO
var damage: int = 1

func _ready() -> void:
	# 初始化伤害属性，同步自 GameManager.stats['atk']
	if GameManager.stats.has("atk"):
		damage = GameManager.stats["atk"] as int
	
	# 动态创建计时器：生存 5 秒后删除
	var lifetime_timer := Timer.new()
	lifetime_timer.wait_time = max_lifetime
	lifetime_timer.one_shot = true
	lifetime_timer.autostart = true
	lifetime_timer.timeout.connect(queue_free)
	add_child(lifetime_timer)
	
	# 动态创建屏幕可视通知器：离开屏幕后删除
	var notifier := VisibleOnScreenNotifier2D.new()
	notifier.screen_exited.connect(queue_free)
	add_child(notifier)
	
	# 连接碰撞事件
	body_entered.connect(_on_body_entered)

# 初始化函数，由玩家或武器脚本在实例化后调用
func setup(target_direction: Vector2) -> void:
	direction = target_direction.normalized()
	# 让子弹朝向运动方向
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	# 沿 direction 直线匀速飞行
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	# 检查是否命中敌人
	if body.is_in_group("enemy"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
	# 检查是否命中障碍物（假设非玩家、非敌人的碰撞体即为障碍物，例如墙壁）
	elif not body.is_in_group("player"):
		_spawn_spark_effect()
		queue_free()

# 可选的小火花特效生成
func _spawn_spark_effect() -> void:
	# TODO: 如果后续有特效预制体，可以在这里加载并实例化
	# var spark_scene = preload("res://path/to/spark.tscn")
	# var spark = spark_scene.instantiate()
	# get_tree().current_scene.add_child(spark)
	# spark.global_position = global_position
	pass
