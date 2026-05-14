class_name GameOverUI
extends CanvasLayer

# =========================================================
# 【Agent Context】 节点结构说明
# =========================================================
# 本脚本挂载于 GameOverUI (CanvasLayer) 根节点上。
# 场景期望包含以下子节点：
# - GameOverUI (CanvasLayer) [Root]
#   ├── RestartButton (Button) : 重新开始按钮
#   └── BackButton (Button)    : 返回标题按钮 (待实现)
# =========================================================

# =========================================================
# Node References
# =========================================================
@onready var restart_button: Button = find_child("RestartButton", true, false) as Button
@onready var back_button: Button = find_child("BackButton", true, false) as Button

func _ready() -> void:
	# 初始状态下隐藏自身
	hide()
	
	# 确保按钮存在并连接信号
	if restart_button:
		restart_button.pressed.connect(_on_restart_button_pressed)
	else:
		push_error("GameOverUI: 找不到名为 'RestartButton' 的子节点！")
		
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)

func _input(event: InputEvent) -> void:
	# 只有当 UI 处于显示状态（也就是玩家死了）时，才响应快捷键
	if visible and event is InputEventKey:
		# 判断是否是物理按键 R，并且是按下的一瞬间
		if event.physical_keycode == KEY_R and event.pressed and not event.echo:
			# 消耗掉这个输入，防止传递给底层其他节点
			get_viewport().set_input_as_handled()
			# 直接调用重开逻辑
			_on_restart_button_pressed()

# 公开函数，供 Player 死亡时调用
func show_game_over() -> void:
	show()
	# 将游戏整体暂停，停止所有未显式设置 PROCESS_MODE_ALWAYS 节点的流程
	get_tree().paused = true

func _on_restart_button_pressed() -> void:
	# 解除暂停。重开前必须恢复时间流动，否则新实例化的场景将一出生就在暂停状态
	get_tree().paused = false
	
	# 重载当前场景（未来这里会改为跳回全局分配菜单）
	var err = get_tree().reload_current_scene()
	if err != OK:
		push_error("GameOverUI: 重载场景失败！错误码: ", err)

func _on_back_button_pressed() -> void:
	# 留空，作为后续返回标题使用
	pass
