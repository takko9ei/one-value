class_name GameOverUI
extends CanvasLayer

# =========================================================
# [Agent Context] Node Structure Explanation
# =========================================================
# This script is attached to the GameOverUI (CanvasLayer) root node.
# The scene is expected to contain the following child nodes:
# - GameOverUI (CanvasLayer) [Root]
#   ├── RestartButton (Button) : Button to restart the game
#   └── BackButton (Button)    : Button to return to the title screen (To be implemented)
# =========================================================

# =========================================================
# Node References
# =========================================================
@onready var restart_button: Button = find_child("RestartButton", true, false) as Button
@onready var back_button: Button = find_child("BackButton", true, false) as Button

func _ready() -> void:
	# Hide itself initially
	hide()
	
	# Ensure buttons exist and connect signals
	if restart_button:
		restart_button.pressed.connect(_on_restart_button_pressed)
	else:
		push_error("GameOverUI: Could not find child node named 'RestartButton'!")
		
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)

func _input(event: InputEvent) -> void:
	# Only respond to shortcuts when the UI is visible (i.e., the player is dead)
	if visible and event is InputEventKey:
		# Check if the physical key R is pressed, and it's the exact moment of pressing
		if event.physical_keycode == KEY_R and event.pressed and not event.echo:
			# Consume this input to prevent passing it to underlying nodes
			get_viewport().set_input_as_handled()
			# Directly call the restart logic
			_on_restart_button_pressed()

# Public function, called by Player upon death
func show_game_over() -> void:
	show()
	# Pause the entire game, stopping all processes for nodes without explicitly set PROCESS_MODE_ALWAYS
	get_tree().paused = true

func _on_restart_button_pressed() -> void:
	# Unpause. We must restore time flow before restarting, otherwise the newly instantiated scene will be born paused
	get_tree().paused = false
	
	# Jump back to the allocation UI to reallocate points
	if GameManager.has_method("retry_current_level"):
		GameManager.retry_current_level()
	else:
		push_error("GameOverUI: retry_current_level() method is not defined in GameManager!")

func _on_back_button_pressed() -> void:
	# Unpause
	get_tree().paused = false
	# Return to the title menu
	get_tree().call_deferred("change_scene_to_file", "res://scene/MainMenu.tscn")
