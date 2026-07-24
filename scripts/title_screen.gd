extends Control
## 标题界面：开始游戏 / 章节选择 / 设置 / 退出

@onready var chapter_list_container: VBoxContainer = %ChapterListContainer
@onready var chapter_select_panel: Panel = %ChapterSelectPanel
@onready var main_menu_box: VBoxContainer = %MainMenuBox
@onready var settings_panel: Panel = %SettingsPanel


@onready var start_button: Button = %StartButton


func _ready() -> void:
	chapter_select_panel.hide()
	settings_panel.hide()
	main_menu_box.show()
	_build_chapter_buttons()
	_refresh_start_button_text()


func _refresh_start_button_text() -> void:
	start_button.text = "继续游戏" if GameState.has_continue_save() else "开始游戏"


func _build_chapter_buttons() -> void:
	for child in chapter_list_container.get_children():
		child.queue_free()

	for i in range(GameState.CHAPTERS.size()):
		var chapter: Dictionary = GameState.CHAPTERS[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(360, 48)

		var unlocked := GameState.is_chapter_unlocked(i)
		var completed := GameState.is_chapter_completed(i)

		var label_text: String = chapter["title"]
		if completed:
			label_text += "  ✓ 已通关"
		elif not unlocked:
			label_text = "🔒 " + "???"

		button.text = label_text
		button.disabled = not unlocked
		button.pressed.connect(_on_chapter_button_pressed.bind(i))
		chapter_list_container.add_child(button)


func _on_chapter_button_pressed(index: int) -> void:
	GameState.start_chapter(index)


func _on_start_button_pressed() -> void:
	# 有可续读的 Dialogic 存档时，精确恢复到离开时的那一句；
	# 否则（全新存档，或该章节已经播完清档）从上次所在章节的开头开始。
	GameState.continue_game()


func _on_chapter_select_button_pressed() -> void:
	_build_chapter_buttons()
	main_menu_box.hide()
	chapter_select_panel.show()


func _on_chapter_select_back_pressed() -> void:
	chapter_select_panel.hide()
	main_menu_box.show()


func _on_settings_button_pressed() -> void:
	main_menu_box.hide()
	settings_panel.show()


func _on_settings_back_pressed() -> void:
	settings_panel.hide()
	main_menu_box.show()


func _on_reset_save_button_pressed() -> void:
	GameState.reset_save()
	_build_chapter_buttons()
	_refresh_start_button_text()


func _on_quit_button_pressed() -> void:
	get_tree().quit()
