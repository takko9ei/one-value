class_name LevelController
extends Node2D

# =========================================================
# [Agent Context] Node Structure Explanation
# =========================================================
# Attached to the LevelController node
# The scene is expected to contain the following child nodes:
# - LevelController (Node2D)
#   ├── SpawnTimer (Timer) : Controls the spawn interval
#   └── SpawnPoints (Node2D) : Container holding multiple Marker2D as spawn points
# =========================================================

# =========================================================
# Level Parameters (Exposed for each Stage to adjust independently)
# =========================================================
@export var enemy_scene: PackedScene
@export var total_enemies_to_kill: int = 20
@export var spawn_interval: float = 1.0
@export var max_enemies_on_screen: int = 15

# =========================================================
# Internal State Variables
# =========================================================
var current_kills: int = 0
var _spawn_points: Array[Marker2D] = []

# =========================================================
# Node References
# =========================================================
@onready var spawn_timer: Timer = $SpawnTimer

func _ready() -> void:
	# 1. Initialize SpawnTimer
	if spawn_timer:
		spawn_timer.wait_time = spawn_interval
		spawn_timer.timeout.connect(_on_spawn_timer_timeout)
		spawn_timer.start()
	else:
		push_error("LevelController: Could not find SpawnTimer node!")
		
	# 2. Retrieve all spawn points
	var points_container: Node = get_node_or_null("SpawnPoints")
	if points_container:
		for child: Node in points_container.get_children():
			if child is Marker2D:
				_spawn_points.append(child)
				
	if _spawn_points.is_empty():
		push_warning("LevelController: No Marker2D spawn points found under SpawnPoints!")

func _on_spawn_timer_timeout() -> void:
	# Safety check
	if not enemy_scene or _spawn_points.is_empty():
		return
		
	# Check the current number of monsters on screen, limit the maximum spawn count
	var current_enemies: Array[Node] = get_tree().get_nodes_in_group("enemy")
	if current_enemies.size() >= max_enemies_on_screen:
		return # Too many monsters on screen, skip spawning this time
		
	# Randomly pick a spawn point
	var random_point: Marker2D = _spawn_points.pick_random()
	
	# Instantiate enemy
	var enemy: EnemyBase = enemy_scene.instantiate() as EnemyBase
	if enemy:
		enemy.global_position = random_point.global_position
		
		# Key: Connect the enemy's death signal to the controller's counting function
		enemy.died.connect(_on_enemy_died)
		
		# Add the enemy to the current scene tree
		var current_scene: Node = get_tree().current_scene
		if current_scene:
			current_scene.add_child(enemy)
		else:
			get_tree().root.add_child(enemy)

var _is_cleared: bool = false

func _on_enemy_died() -> void:
	if _is_cleared:
		return
		
	# Every time an enemy emits the died signal, kill count + 1
	current_kills += 1
	
	# Check clear conditions
	if current_kills >= total_enemies_to_kill:
		_is_cleared = true
		# Clear conditions met, stop spawning
		if spawn_timer:
			spawn_timer.stop()
			
		print("Level Cleared! 关卡通过！")
		
		# Proceed to the next level or transition to the allocation UI
		if GameManager.has_method("next_level"):
			GameManager.next_level()
		else:
			push_error("LevelController: next_level() method is not defined in GameManager!")
