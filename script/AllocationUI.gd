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
	# 1. Set level display text
	# Safely get current_level_index, default to 0 if not yet added in GameManager
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
	
	# 2. Listen to points updated signal
	if GameManager.has_signal("stats_updated"):
		GameManager.stats_updated.connect(_update_points_label)
	
	# Manually trigger once to initialize remaining points display
	_update_points_label()
	
	# 3. Iterate through all child nodes under SliderContainer (i.e., the 7 HSliders)
	if slider_container:
		for child: Node in slider_container.get_children():
			var slider: HSlider = child as HSlider
			if slider:
				var stat_key: String = slider.name
				# Must ensure slider's name exactly matches the key in GameManager.stats
				if GameManager.stats.has(stat_key):
					# Initialize slider position based on true values from data layer
					slider.value = float(GameManager.stats[stat_key])
					
					# Clever use of bind to tie specific slider instance to the callback function
					# Avoids writing 7 identical functions
					slider.value_changed.connect(_on_slider_value_changed.bind(slider))
				else:
					push_warning("AllocationUI: No corresponding Key for slider in dictionary -> " + stat_key)
					
	# 4. Connect bottom buttons
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_button_pressed)

func _update_points_label() -> void:
	if not points_label:
		return
		
	# Calculate total points currently occupied
	var current_total: int = 0
	for key: String in GameManager.stats:
		current_total += GameManager.stats[key] as int
	
	# Calculate remaining available points
	var remaining_points: int = GameManager.MAX_TOTAL_POINTS - current_total
	points_label.text = "SP: " + str(remaining_points)

func _on_slider_value_changed(new_value: float, slider: HSlider) -> void:
	var stat_key: String = slider.name
	
	# 1. Send slider's new value to GameManager for safety check and points deduction
	GameManager.update_stat(stat_key, int(new_value))
	
	# 2. Critical Sync Check (Extremely Important!):
	# If remaining SP is insufficient, GameManager's internal clamp logic will reject the excess points.
	# For example, if you drag the slider from 10 to 50, but only 5 points remain in the pool,
	# the data layer will only increase it to 15.
	# The underlying data is correct, but the UI slider is now at 50, causing a "desync illusion".
	# Therefore, we must forcefully override the UI with the true underlying data, pulling it back to 15.
	# [Note]: Must use set_value_no_signal, otherwise the assignment triggers value_changed again, causing an infinite loop crash!
	slider.set_value_no_signal(float(GameManager.stats[stat_key]))

func _on_start_button_pressed() -> void:
	if GameManager.has_method("load_current_level"):
		GameManager.load_current_level()
	else:
		push_error("AllocationUI: load_current_level() method is not defined in GameManager!")

func _on_quit_button_pressed() -> void:
	# Switch back to the main menu scene
	get_tree().change_scene_to_file("res://scene/MainMenu.tscn")
