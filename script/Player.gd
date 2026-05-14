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
#   ├── Camera2D (Camera2D)                 : 玩家跟随相机
#   └── Muzzle (Marker2D)                   : 子弹发射位置 (请在编辑器中确保存在)
# =========================================================

# =========================================================
# 节点引用 (Nodes)
# =========================================================
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var shoot_timer: Timer = $ShootTimer
@onready var camera: Camera2D = $Camera2D
@onready var muzzle: Marker2D = $Muzzle

# 悬浮 UI 引用
@onready var health_bar: ProgressBar = $HealthBar
@onready var stamina_bar: ProgressBar = $StaminaBar

# 暴露给编辑器的子弹预制体引用
@export var projectile_scene: PackedScene

# 暴露给编辑器的游戏结束 UI 引用
@export var game_over_ui: CanvasLayer

# =========================================================
# 属性定义 (Stats)
# =========================================================
# 血量系统
var max_hp: float = 100.0
var current_hp: float = 100.0

# 耐力系统
var max_stamina: int = 2
var current_stamina: int = 2
var stamina_regen_timer: float = 0.0

# 动态射击属性
var current_atk: float = 10.0
var current_projectile_count: int = 1

# 移动配置
const BASE_SPEED: float = 500.0
const DASH_MULTIPLIER: float = 2.5
const DASH_DURATION: float = 0.15
const DASH_COST: int = 1

var _is_dashing: bool = false
var _dash_timer: float = 0.0

# 记录玩家最后面朝方向，用于没有敌人时默认发射方向
var _last_facing_direction: Vector2 = Vector2.RIGHT

# =========================================================
# 生命周期
# =========================================================
func _ready() -> void:
	# 1. 初始同步 GameManager 属性，计算出真实的 max_hp 和 max_stamina
	_sync_stats()
	
	# 2. 初始化时将当前血量和耐力拉满
	current_hp = max_hp
	current_stamina = max_stamina
	
	if health_bar:
		health_bar.value = current_hp
	if stamina_bar:
		stamina_bar.value = current_stamina
	
	# 3. 连接 GameManager 信号以实时更新属性上限和攻击力
	if GameManager.has_signal("stats_updated"):
		GameManager.stats_updated.connect(_on_stats_updated)
		
	# 4. 连接射击计时器信号
	if shoot_timer:
		shoot_timer.timeout.connect(_on_shoot_timer_timeout)

func _physics_process(delta: float) -> void:
	# 每帧按顺序处理：回耐、冲刺消耗计算、常规移动
	_handle_stamina_regen(delta)
	_handle_dash(delta)
	_handle_movement()
	move_and_slide() # 自动处理边界和障碍物碰撞

# =========================================================
# 属性同步逻辑
# =========================================================
func _on_stats_updated() -> void:
	_sync_stats()

func _sync_stats() -> void:
	# 同步最大血量：基础 100 + 每点 hp 提供 20
	var hp_points: float = GameManager.stats.get("hp", 0.0) as float
	max_hp = 100.0 + (hp_points * 20.0)
	# 确保当失去点数导致上限降低时，当前血量不会溢出
	current_hp = minf(current_hp, max_hp)
	
	# 同步 UI
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current_hp
	
	# 同步最大耐力：基础 2 + 每 5 点 stamina 提供 1
	var stamina_points: float = GameManager.stats.get("stamina", 0.0) as float
	max_stamina = 2 + floori(stamina_points / 5.0)
	current_stamina = mini(current_stamina, max_stamina)
	
	# 同步 UI
	if stamina_bar:
		stamina_bar.max_value = max_stamina
		stamina_bar.value = current_stamina
	
	# 同步射击属性：基础 10 + 每点 atk 提供 2
	var atk_points: float = GameManager.stats.get("atk", 0.0) as float
	current_atk = 10.0 + (atk_points * 2.0)
	
	# 同步多重投射物
	var proj_points: float = GameManager.stats.get("projectiles", 0.0) as float
	current_projectile_count = 1 + floori(proj_points / 5.0)

# =========================================================
# 耐力与冲刺逻辑
# =========================================================
func _handle_stamina_regen(delta: float) -> void:
	# 如果当前耐力小于上限，说明需要恢复
	if current_stamina < max_stamina:
		stamina_regen_timer += delta
		# 倒计时达到 1.5 秒时，恢复 1 点耐力
		if stamina_regen_timer >= 1.5:
			current_stamina += 1
			stamina_regen_timer = 0.0 # 恢复后重置计时器重新倒数
			if stamina_bar:
				stamina_bar.value = current_stamina

func _handle_dash(delta: float) -> void:
	# 1. 如果正在冲刺，递减冲刺计时器；时间到则结束冲刺状态
	if _is_dashing:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_is_dashing = false
			
	# 2. 检测按键输入：玩家按下 "dash" 键、且目前没有在冲刺中、且至少有 1 点耐力
	if Input.is_action_just_pressed("dash") and not _is_dashing and current_stamina >= DASH_COST:
		_is_dashing = true
		_dash_timer = DASH_DURATION # 开始 0.15 秒的加速计时
		current_stamina -= DASH_COST # 扣除耐力
		if stamina_bar:
			stamina_bar.value = current_stamina

func _handle_movement() -> void:
	# 获取方向键输入 (ui_*)
	var ui_input: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# 获取 WASD 物理按键输入
	var wasd_x: float = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var wasd_y: float = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	var wasd_input: Vector2 = Vector2(wasd_x, wasd_y)
	
	# 合并两种输入，并限制向量长度最大为 1.0，防止斜向移动过快
	var input_vector: Vector2 = (ui_input + wasd_input).limit_length(1.0)
	
	# 如果玩家正在移动，记录面朝方向
	if input_vector != Vector2.ZERO:
		_last_facing_direction = input_vector.normalized()
	
	# 计算最终速度：基础速度 * (冲刺时为 2.5，常规为 1.0)
	var current_speed: float = BASE_SPEED
	if _is_dashing:
		current_speed *= DASH_MULTIPLIER
		
	velocity = input_vector * current_speed

# =========================================================
# 受击与死亡逻辑
# =========================================================
func take_damage(amount: float) -> void:
	# 防止连续多次触发死亡逻辑
	if current_hp <= 0:
		return
		
	current_hp -= amount
	
	# 更新悬浮血条 UI
	if health_bar:
		health_bar.value = current_hp
		
	# 如果血量归零或更低，触发死亡
	if current_hp <= 0:
		print("Player Died")
		
		# 停止玩家的所有动作
		_is_dashing = false
		velocity = Vector2.ZERO
		if shoot_timer:
			shoot_timer.stop()
			
		# 检查 UI 节点是否挂载并触发显示
		if game_over_ui:
			if game_over_ui.has_method("show_game_over"):
				game_over_ui.show_game_over()

# =========================================================
# 自动瞄准与射击逻辑
# =========================================================
func get_closest_enemy() -> Node2D:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		return null
		
	var closest_enemy: Node2D = null
	var min_distance: float = INF
	
	var spawn_pos: Vector2 = muzzle.global_position if muzzle else global_position
	
	for enemy: Node in enemies:
		if enemy is Node2D and not enemy.is_queued_for_deletion():
			var distance: float = spawn_pos.distance_to(enemy.global_position)
			if distance < min_distance:
				min_distance = distance
				closest_enemy = enemy as Node2D
				
	return closest_enemy

func _on_shoot_timer_timeout() -> void:
	if not projectile_scene:
		push_warning("Player: 未配置 projectile_scene，无法射击！")
		return
		
	var spawn_pos: Vector2 = muzzle.global_position if muzzle else global_position
	var enemy: Node2D = get_closest_enemy()
	var target_dir: Vector2
	
	if enemy:
		target_dir = spawn_pos.direction_to(enemy.global_position)
	else:
		target_dir = _last_facing_direction
		
	var total_spread_angle: float = deg_to_rad(45.0)
	
	for i in range(current_projectile_count):
		var proj: PlayerProjectile = projectile_scene.instantiate() as PlayerProjectile
		if not proj:
			continue
			
		var final_dir: Vector2 = target_dir
		if current_projectile_count > 1:
			var fraction: float = float(i) / float(current_projectile_count - 1)
			var angle_offset: float = (fraction - 0.5) * total_spread_angle
			final_dir = target_dir.rotated(angle_offset)
			
		# 发射子弹时，将算好的 current_atk 传给子弹
		proj.direction = final_dir
		proj.damage = current_atk
		
		var scene_root: Node = get_tree().current_scene
		if scene_root:
			scene_root.add_child(proj)
		else:
			get_tree().root.add_child(proj)
			
		if muzzle:
			proj.global_position = muzzle.global_position
		else:
			proj.global_position = global_position
