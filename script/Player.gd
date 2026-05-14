class_name Player
extends CharacterBody2D

# =========================================================
# [Agent Context] Node Structure Explanation
# =========================================================
# This script is attached to the Player (CharacterBody2D) root node.
# The scene contains the following child nodes for context:
# - Player (CharacterBody2D) [Root]
#   ├── CollisionShape2D (CollisionShape2D) : Collider
#   ├── Sprite2D (Sprite2D)                 : Player texture/animation
#   ├── ShootTimer (Timer)                  : Timer controlling the fire rate
#   ├── Camera2D (Camera2D)                 : Camera that follows the player
#   └── Muzzle (Marker2D)                   : Bullet spawn position (ensure it exists in the editor)
# =========================================================

# =========================================================
# Node References (Nodes)
# =========================================================
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var shoot_timer: Timer = $ShootTimer
@onready var camera: Camera2D = $Camera2D
@onready var muzzle: Marker2D = $Muzzle

# Floating UI References
@onready var health_bar: ProgressBar = $HealthBar
@onready var stamina_bar: ProgressBar = $StaminaBar

# Reference to the projectile prefab exposed to the editor
@export var projectile_scene: PackedScene

# Reference to the Game Over UI exposed to the editor
@export var game_over_ui: CanvasLayer

# =========================================================
# Attribute Definitions (Stats)
# =========================================================
# Health System
var max_hp: float = 100.0
var current_hp: float = 100.0

# Stamina System
var max_stamina: int = 2
var current_stamina: int = 2
var stamina_regen_timer: float = 0.0

# Dynamic Shooting Attributes
var current_atk: float = 10.0
var current_projectile_count: int = 1

# Movement Configuration
const BASE_SPEED: float = 600.0
const DASH_MULTIPLIER: float = 2.5
const DASH_DURATION: float = 0.15
const DASH_COST: int = 1

var _is_dashing: bool = false
var _dash_timer: float = 0.0

# Records the last direction the player faced, used as default firing direction if no enemies are present
var _last_facing_direction: Vector2 = Vector2.RIGHT

# =========================================================
# Lifecycle
# =========================================================
func _ready() -> void:
	# 1. Initially synchronize GameManager attributes to calculate true max_hp and max_stamina
	_sync_stats()
	
	# 2. Fully restore current health and stamina upon initialization
	current_hp = max_hp
	current_stamina = max_stamina
	
	if health_bar:
		health_bar.value = current_hp
	if stamina_bar:
		stamina_bar.value = current_stamina
	
	# 3. Connect to GameManager signal to update attribute caps and attack power in real time
	if GameManager.has_signal("stats_updated"):
		GameManager.stats_updated.connect(_on_stats_updated)
		
	# 4. Connect shooting timer signal
	if shoot_timer:
		shoot_timer.timeout.connect(_on_shoot_timer_timeout)

func _physics_process(delta: float) -> void:
	# Process sequentially every frame: stamina regen, dash consumption check, regular movement
	_handle_stamina_regen(delta)
	_handle_dash(delta)
	_handle_movement()
	move_and_slide() # Automatically handles boundary and obstacle collisions

# =========================================================
# Attribute Synchronization Logic
# =========================================================
func _on_stats_updated() -> void:
	_sync_stats()

func _sync_stats() -> void:
	# Sync max health: base 100 + 20 per hp point
	var hp_points: float = GameManager.stats.get("hp", 0.0) as float
	max_hp = 100.0 + (hp_points * 20.0)
	# Ensure current health does not overflow when maximum cap decreases due to lost points
	current_hp = minf(current_hp, max_hp)
	
	# Sync UI
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current_hp
	
	# Sync max stamina: base 2 + 1 per 20 stamina points
	var stamina_points: float = GameManager.stats.get("stamina", 0.0) as float
	max_stamina = 2 + floori(stamina_points / 20.0)
	current_stamina = mini(current_stamina, max_stamina)
	
	# Sync UI
	if stamina_bar:
		stamina_bar.max_value = max_stamina
		stamina_bar.value = current_stamina
	
	# Sync shooting attributes: base 10 + 2 per atk point
	var atk_points: float = GameManager.stats.get("atk", 0.0) as float
	current_atk = 10.0 + (atk_points * 2.0)
	
	# Sync multiple projectiles count
	var proj_points: float = GameManager.stats.get("projectiles", 0.0) as float
	current_projectile_count = 1 + floori(proj_points / 20.0)

# =========================================================
# Stamina and Dash Logic
# =========================================================
func _handle_stamina_regen(delta: float) -> void:
	# If current stamina is below max, regeneration is needed
	if current_stamina < max_stamina:
		stamina_regen_timer += delta
		# Recover 1 point of stamina when the timer reaches 1.5 seconds
		if stamina_regen_timer >= 1.5:
			current_stamina += 1
			stamina_regen_timer = 0.0 # Reset timer to start counting down again after recovery
			if stamina_bar:
				stamina_bar.value = current_stamina

func _handle_dash(delta: float) -> void:
	# 1. If currently dashing, decrease the dash timer; when time is up, end the dash state
	if _is_dashing:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_is_dashing = false
			
	# 2. Check input: player pressed "dash" key, is not currently dashing, and has at least 1 stamina
	if Input.is_action_just_pressed("dash") and not _is_dashing and current_stamina >= DASH_COST:
		_is_dashing = true
		_dash_timer = DASH_DURATION # Start the 0.15-second dash duration
		current_stamina -= DASH_COST # Deduct stamina
		if stamina_bar:
			stamina_bar.value = current_stamina

func _handle_movement() -> void:
	# Get directional key inputs (ui_*)
	var ui_input: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# Get WASD physical key inputs
	var wasd_x: float = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var wasd_y: float = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	var wasd_input: Vector2 = Vector2(wasd_x, wasd_y)
	
	# Combine both inputs and limit vector length to max 1.0 to prevent excessive diagonal speed
	var input_vector: Vector2 = (ui_input + wasd_input).limit_length(1.0)
	
	# If the player is moving, record the facing direction
	if input_vector != Vector2.ZERO:
		_last_facing_direction = input_vector.normalized()
	
	# Calculate final speed: base speed * (2.5 when dashing, 1.0 normally)
	var current_speed: float = BASE_SPEED
	if _is_dashing:
		current_speed *= DASH_MULTIPLIER
		
	velocity = input_vector * current_speed

# =========================================================
# Hit and Death Logic
# =========================================================
func take_damage(amount: float) -> void:
	# Prevent triggering death logic multiple times consecutively
	if current_hp <= 0:
		return
		
	current_hp -= amount
	
	# Update floating health bar UI
	if health_bar:
		health_bar.value = current_hp
		
	# If health drops to zero or lower, trigger death
	if current_hp <= 0:
		print("Player Died")
		
		# Stop all player actions
		_is_dashing = false
		velocity = Vector2.ZERO
		if shoot_timer:
			shoot_timer.stop()
			
		# Check if UI node is attached and trigger the display
		if game_over_ui:
			if game_over_ui.has_method("show_game_over"):
				game_over_ui.show_game_over()

# =========================================================
# Auto-Aiming and Firing Logic
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
		push_warning("Player: projectile_scene is not configured, cannot shoot!")
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
			
		# Pass the calculated current_atk to the projectile upon firing
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
