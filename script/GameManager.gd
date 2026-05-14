extends Node

# =========================================================
# Variables & Signals (变量与信号声明)
# =========================================================
signal stats_updated

const MAX_TOTAL_POINTS: int = 100

# 预留关卡路径数组，供后续扩充场景时平滑跳转
@export var level_scenes: Array[String] = [
	"res://scene/level1_swarm.tscn",
	"res://scene/level2_golem.tscn",
	"res://scene/level3_houd.tscn",
	"res://scene/level4_leech.tscn",
	"res://scene/level5_warden.tscn"
]

# 状态变量
var current_level_index: int = 0
var remaining_points: int = 100

# 核心零和博弈字典 (初始值全为 0)
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
# Level Flow Control (关卡流转逻辑)
# =========================================================

# 开启全新的一轮游戏
func start_new_game() -> void:
	current_level_index = 0
	_reset_all_stats()
	get_tree().call_deferred("change_scene_to_file", "res://scene/AllocationUI.tscn")

# 纯粹的 UI 跳转
func go_to_allocation() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://scene/AllocationUI.tscn")

# 加载真正的战斗场景
func load_current_level() -> void:
	if current_level_index < level_scenes.size():
		get_tree().call_deferred("change_scene_to_file", level_scenes[current_level_index])
	else:
		# 暂不处理通关 UI，直接在后台打印提示
		print("Game Beaten!")

# 通关当前关卡，进入下一关
func next_level() -> void:
	current_level_index += 1
	go_to_allocation()

# 死亡重开（带惩罚或纯粹的重置分配）
func retry_current_level() -> void:
	_reset_all_stats()
	go_to_allocation()

# =========================================================
# Core Allocation Logic (核心分配逻辑与校验)
# =========================================================

# 处理滑块拖动传来的请求
func update_stat(stat_name: String, value: int) -> void:
	if not stats.has(stat_name):
		return
		
	# 确保传入的值不为负数
	var safe_value: int = maxi(0, value)
	
	# 1. 模拟运算：假设本次更新成功，整个字典加起来是多少？
	var projected_total: int = 0
	for key: String in stats:
		if key == stat_name:
			projected_total += safe_value
		else:
			projected_total += stats[key] as int
			
	# 2. 上限校验 (Cap Check)
	# 如果总和 <= 100，才判定为合法的分配操作
	if projected_total <= MAX_TOTAL_POINTS:
		stats[stat_name] = safe_value
		
	# 3. 结果核算与广播
	# 无论上面那步是否更新成功，最后都要重新核算剩余点数
	var actual_total: int = 0
	for key: String in stats:
		actual_total += stats[key] as int
		
	remaining_points = MAX_TOTAL_POINTS - actual_total
	
	# 强制发出信号，这一步极其关键。
	# 如果玩家强行把滑块拉满导致 projected_total > 100，底层数据不会改变，
	# 此信号发射后，AllocationUI 将捕捉到信号，并执行 set_value_no_signal，
	# 把处于“越界状态”的滑块瞬间拉回到实际合法的刻度上。
	stats_updated.emit()

# 重置全部资源分配
func _reset_all_stats() -> void:
	for key: String in stats:
		stats[key] = 0
		
	remaining_points = MAX_TOTAL_POINTS
	stats_updated.emit()
