extends Node

# =========================================================
# Variables & Signals
# =========================================================
signal stats_updated

const MAX_TOTAL_POINTS: int = 100

# Reserved array of level paths for smooth transitions when adding more scenes
@export var level_scenes: Array[String] = [
	"res://scene/level1_swarm.tscn",
	"res://scene/level2_golem.tscn",
	"res://scene/level3_houd.tscn",
	"res://scene/level4_leech.tscn",
	"res://scene/level5_warden.tscn"
]

# State variables
var current_level_index: int = 0
var remaining_points: int = 100

# Core zero-sum game dictionary (all initialized to 0)
var stats: Dictionary = {
	"hp": 0,
	"atk": 0,
	"stamina": 0,
	"projectiles": 0,
	"enemy_slow": 0,
	"enemy_atk_debuff": 0,
	"enemy_def_debuff": 0
}

# =========================================================
# Level Flow Control
# =========================================================

# Start a completely new game
func start_new_game() -> void:
	current_level_index = 0
	_reset_all_stats()
	get_tree().call_deferred("change_scene_to_file", "res://scene/AllocationUI.tscn")

# Pure UI transition
func go_to_allocation() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://scene/AllocationUI.tscn")

# Load the actual combat scene
func load_current_level() -> void:
	if current_level_index < level_scenes.size():
		get_tree().call_deferred("change_scene_to_file", level_scenes[current_level_index])
	else:
		# Temporarily ignore the game clear UI, just print a message in the background
		print("Game Beaten!")

# Clear the current level and proceed to the next one
func next_level() -> void:
	current_level_index += 1
	go_to_allocation()

# Retry on death (with penalty or pure allocation reset)
func retry_current_level() -> void:
	_reset_all_stats()
	go_to_allocation()

# =========================================================
# Core Allocation Logic & Validation
# =========================================================

# Process requests sent by dragging the slider
func update_stat(stat_name: String, value: int) -> void:
	if not stats.has(stat_name):
		return
		
	# Ensure the passed value is not negative
	var safe_value: int = maxi(0, value)
	
	# 1. Simulated calculation: Assuming this update is successful, what is the total sum of the dictionary?
	var projected_total: int = 0
	for key: String in stats:
		if key == stat_name:
			projected_total += safe_value
		else:
			projected_total += stats[key] as int
			
	# 2. Cap Check
	# If the sum is <= 100, it is considered a valid allocation operation
	if projected_total <= MAX_TOTAL_POINTS:
		stats[stat_name] = safe_value
		
	# 3. Final Accounting and Broadcasting
	# Regardless of whether the update above was successful, recalculate remaining points at the end
	var actual_total: int = 0
	for key: String in stats:
		actual_total += stats[key] as int
		
	remaining_points = MAX_TOTAL_POINTS - actual_total
	
	# Force emit the signal, this step is extremely critical.
	# If the player forcefully drags the slider to maximum causing projected_total > 100, the underlying data won't change.
	# After emitting this signal, AllocationUI will catch it and execute set_value_no_signal,
	# instantly pulling the "out-of-bounds" slider back to its actual valid tick mark.
	stats_updated.emit()

# Reset all resource allocations
func _reset_all_stats() -> void:
	for key: String in stats:
		stats[key] = 0
		
	remaining_points = MAX_TOTAL_POINTS
	stats_updated.emit()
