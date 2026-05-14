class_name MainMenu
extends Control

# =========================================================
# Node References
# =========================================================
@onready var start_button: Button = $Panel/VBoxContainer/StartButton
@onready var quit_button: Button = $Panel/VBoxContainer/QuitButton

func _ready() -> void:
	# Connect button signals
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_button_pressed)

func _on_start_button_pressed() -> void:
	# Attempt to call the new game logic in GameManager
	if GameManager.has_method("start_new_game"):
		GameManager.start_new_game()
	else:
		push_error("MainMenu: start_new_game() method is not defined in GameManager!")

func _on_quit_button_pressed() -> void:
	# Quit the game process
	get_tree().quit()
