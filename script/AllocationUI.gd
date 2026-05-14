class_name AllocationUI
extends Control

# =========================================================
# Node References
# =========================================================
@onready var start_button: Button = $Panel/ButtonContainer/StartButton
@onready var quit_button: Button = $Panel/ButtonContainer/QuitButton
@onready var level_name_label: Label = $Panel/LevelNameLabel
@onready var points_label: Label = $Panel/PointsLabel
@onready var slider_container: Control = $Panel/SliderContainer

func _ready() -> void:
	# 1. 设置关卡显示文本
	# 安全获取 current_level_index，如果 GameManager 中还没加这个变量，默认按第 0 关算
	var stage_names: Array[String] = [
		"Stage1: Swarm",
		"Stage2: Golem",
		"Stage3: Hount",
		"Stage4: Leech",
		"Stage5: Warden",
		"Stage6: Comming Soon..."
	]
	
	var current_level: int = GameManager.get("current_level_index") if "current_level_index" in GameManager else 0
	if level_name_label:
		if current_level >= 0 and current_level < stage_names.size():
			level_name_label.text = stage_names[current_level]
		else:
			level_name_label.text = "Stage " + str(current_level + 1)
	
	# 2. 监听点数更新信号
	if GameManager.has_signal("stats_updated"):
		GameManager.stats_updated.connect(_update_points_label)
	
	# 手动触发一次初始化剩余点数显示
	_update_points_label()
	
	# 3. 遍历 SliderContainer 下的所有子节点（即 7 个 HSlider）
	if slider_container:
		for child: Node in slider_container.get_children():
			var slider: HSlider = child as HSlider
			if slider:
				var stat_key: String = slider.name
				# 必须确保 slider 的 name 与 GameManager.stats 里的 key 拼写完全一致
				if GameManager.stats.has(stat_key):
					# 根据数据层的真实数值初始化滑块位置
					slider.value = float(GameManager.stats[stat_key])
					
					# 巧妙地使用 bind 将具体的 slider 实例绑定到回调函数中，避免写 7 个长得一样的函数
					slider.value_changed.connect(_on_slider_value_changed.bind(slider))
				else:
					push_warning("AllocationUI: 字典中不存在与滑块对应的 Key -> " + stat_key)
					
	# 4. 连接底部按钮
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_button_pressed)

func _update_points_label() -> void:
	if not points_label:
		return
		
	# 计算已被占用的点数总和
	var current_total: int = 0
	for key: String in GameManager.stats:
		current_total += GameManager.stats[key] as int
	
	# 计算剩余的可用点数
	var remaining_points: int = GameManager.MAX_TOTAL_POINTS - current_total
	points_label.text = "SP: " + str(remaining_points)

func _on_slider_value_changed(new_value: float, slider: HSlider) -> void:
	var stat_key: String = slider.name
	
	# 1. 将滑块的新值送往 GameManager 进行安全校验与点数扣减
	GameManager.update_stat(stat_key, int(new_value))
	
	# 2. 关键同步校验（极重要！）：
	# 如果剩余 SP 点数不足，GameManager 内部的 clamp 逻辑会拒绝多余的点数增加。
	# 例如，你想把滑块从 10 拖到 50，但池子里只剩 5 点了，数据层只会加到 15。
	# 此时虽然底层数据是对的，但你的滑块UI已经被拉到了 50，发生了“脱节假象”。
	# 所以这里必须强制使用底层真实数据覆写一遍 UI，将它拉回 15。
	# 【注】：必须用 set_value_no_signal，否则赋值操作又会触发 value_changed 信号导致死循环崩溃！
	slider.set_value_no_signal(float(GameManager.stats[stat_key]))

func _on_start_button_pressed() -> void:
	if GameManager.has_method("load_current_level"):
		GameManager.load_current_level()
	else:
		push_error("AllocationUI: GameManager 中尚未定义 load_current_level() 方法！")

func _on_quit_button_pressed() -> void:
	# 切换回主菜单场景
	get_tree().change_scene_to_file("res://scene/MainMenu.tscn")
