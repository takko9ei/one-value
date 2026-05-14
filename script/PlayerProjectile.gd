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
# =========================================================

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

@export var speed: float = 900.0
var direction: Vector2 = Vector2.ZERO
var damage: float = 10.0

func _ready() -> void:
	# 创建一个计时器，生存 3 秒后调用 queue_free() 自动销毁，防止内存泄漏
	var timer := Timer.new()
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	
	# 连接碰撞信号
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	# 通过全局坐标直线移动
	global_position += direction * speed * delta
	# 让子弹贴图朝向运动方向（可选）
	rotation = direction.angle()

func _on_body_entered(body: Node2D) -> void:
	# 如果碰到的 body 在 "enemy" 组，且拥有 take_damage 方法
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(damage)
		
	# 无论碰到的是敌人还是墙壁（Layer 3），只要发生碰撞，立刻销毁自身
	queue_free()
