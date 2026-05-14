class_name MainMenu
extends Control

# =========================================================
# Node References
# =========================================================
@onready var start_button: Button = $Panel/VBoxContainer/StartButton
@onready var quit_button: Button = $Panel/VBoxContainer/QuitButton

func _ready() -> void:
	# 连接按钮信号
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_button_pressed)

func _on_start_button_pressed() -> void:
	# 尝试调用 GameManager 中的新游戏逻辑
	if GameManager.has_method("start_new_game"):
		GameManager.start_new_game()
	else:
		push_error("MainMenu: GameManager 中尚未定义 start_new_game() 方法！")

func _on_quit_button_pressed() -> void:
	# 退出游戏进程
	get_tree().quit()
