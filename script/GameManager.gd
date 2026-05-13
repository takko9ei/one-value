extends Node

# Emitted whenever any stat is successfully changed.
signal stats_updated

# The maximum total points allowed across all stats.
@export var total_pool: int = 100

# Dictionary storing all resource allocations.
# Keys are Strings, values are integers.
var stats: Dictionary = {
	"hp": 0,
	"atk": 0,
	"stamina": 0,
	"projectiles": 0,
	"enemy_slow": 0,
	"enemy_atk_debuff": 0,
	"enemy_def_debuff": 0
}

# Updates a specific stat while ensuring the overall total doesn't exceed total_pool.
func update_stat(stat_name: String, new_value: int) -> void:
	# Validate if the stat exists in our dictionary.
	if not stats.has(stat_name):
		push_error("GameManager: Attempted to update non-existent stat: ", stat_name)
		return
	
	# Prevent negative stat values (assuming stats cannot be less than 0).
	var clamped_new_value: int = maxi(0, new_value)
	
	# Calculate the current sum of all stats.
	var current_total: int = 0
	for key: String in stats:
		current_total += stats[key] as int
	
	# Calculate how many points are used by ALL OTHER stats except the one we are modifying.
	var points_used_by_others: int = current_total - (stats[stat_name] as int)
	
	# The maximum value this specific stat can take is whatever remains in the pool.
	var max_allowed_value: int = total_pool - points_used_by_others
	
	# Clamp the requested value to ensure we don't exceed the total pool.
	var final_value: int = mini(clamped_new_value, max_allowed_value)
	
	# Apply the change and emit the signal only if the value actually changed.
	if (stats[stat_name] as int) != final_value:
		stats[stat_name] = final_value
		stats_updated.emit()
