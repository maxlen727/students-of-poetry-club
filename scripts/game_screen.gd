extends CanvasLayer
## 游戏场景（唯一职责：承载"游玩中"的悬浮 UI）。
##
## 真正的剧情画面由 Dialogic 自己创建的图层场景负责渲染（它是一个 layer=1 的
## CanvasLayer）。本场景的根节点特意也用 CanvasLayer 并设置更高的 layer 值，
## 确保无论 Dialogic 的图层什么时候被动态插入到场景树，我们的按钮和菜单
## 永远显示在最上层、不会被剧情画面盖住。
##
## 职责：
## 1. 进入时触发 GameState 开始/续读当前章节
## 2. 右上角小工具栏：自动播放开关 / 返回主界面
## 3. Esc 快捷键：弹出"返回主界面"确认（避免误触直接丢进度）
##
## 空格 / 回车 / 鼠标左键继续剧情，是 Dialogic 内置的 dialogic_default_action，
## 不需要在这里额外处理。

@onready var auto_play_button: Button = %AutoPlayButton
@onready var exit_confirm_panel: Panel = %ExitConfirmPanel


func _ready() -> void:
	_set_exit_confirm_visible(false)
	_refresh_auto_play_button()

	# 注意：不要写成 Dialogic.Inputs.auto_advance.toggled.connect(...) 这种
	# 多层链式属性访问信号的写法——GDScript 解析器在某些情况下会把它误判成
	# "standalone lambda" 报错。先取出中间对象存到局部变量，再操作即可避开。
	var auto_advance := Dialogic.Inputs.auto_advance
	if not auto_advance.toggled.is_connected(_on_auto_advance_toggled):
		auto_advance.toggled.connect(_on_auto_advance_toggled)

	GameState.begin_or_resume_current_chapter()


func _exit_tree() -> void:
	var auto_advance := Dialogic.Inputs.auto_advance
	if auto_advance.toggled.is_connected(_on_auto_advance_toggled):
		auto_advance.toggled.disconnect(_on_auto_advance_toggled)


## 用 _input 而不是 _unhandled_input，确保在 Dialogic 处理输入之前就先拿到 Esc，
## 不依赖节点树的遍历顺序。
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_exit_confirm()
		get_viewport().set_input_as_handled()


func _toggle_exit_confirm() -> void:
	_set_exit_confirm_visible(not exit_confirm_panel.visible)


## 打开确认框时暂停 Dialogic：否则空格/回车（走 _unhandled_input）和自动播放
## 都会在确认框底下继续推进剧情，点"是"时存下的就不是打开菜单那一刻的进度了。
func _set_exit_confirm_visible(is_visible: bool) -> void:
	exit_confirm_panel.visible = is_visible
	Dialogic.paused = is_visible


func _on_auto_play_button_pressed() -> void:
	var auto_advance := Dialogic.Inputs.auto_advance
	auto_advance.enabled_until_user_input = not auto_advance.is_enabled()


func _on_auto_advance_toggled(_enabled: bool) -> void:
	_refresh_auto_play_button()


func _refresh_auto_play_button() -> void:
	var is_on := Dialogic.Inputs.auto_advance.is_enabled()
	auto_play_button.button_pressed = is_on
	auto_play_button.text = "自动：开" if is_on else "自动：关"


func _on_exit_confirm_yes_pressed() -> void:
	GameState.return_to_title()


func _on_exit_confirm_no_pressed() -> void:
	_set_exit_confirm_visible(false)
