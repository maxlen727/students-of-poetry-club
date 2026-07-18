extends Node
## 全局游戏状态/存档管理单例
## 负责记录玩家读到了哪一章、章节解锁进度，并提供存档/读档接口。
## 需要在 Project Settings > Autoload 中添加为 "GameState"（名称需与本文件名一致，
## 或束束可以自行改名，只要在 project.godot 里对应即可）。

const SAVE_DIR := "user://saves/"
const SAVE_FILE := "user://saves/save_slot_1.json"

# 五章时间线的资源路径，章节按顺序解锁
const CHAPTERS := [
	{
		"id": "ch1",
		"title": "第一章：推门始觉有人来",
		"timeline": "res://timelines/ch1_推门始觉有人来.dtl",
	},
	{
		"id": "ch2",
		"title": "第二章：日长不觉诗渐暖",
		"timeline": "res://timelines/ch2_日长不觉诗渐暖.dtl",
	},
	{
		"id": "ch3",
		"title": "第三章：满座无人唯我见",
		"timeline": "res://timelines/ch3_满座无人唯我见.dtl",
	},
	{
		"id": "ch4",
		"title": "第四章：欲握清风指尖空",
		"timeline": "res://timelines/ch4_欲握清风指尖空.dtl",
	},
	{
		"id": "ch5",
		"title": "第五章：灯火阑珊人却在",
		"timeline": "res://timelines/ch5_灯火阑珊人却在.dtl",
	},
]

## 当前存档数据。unlocked_chapter 表示玩家已解锁到第几章（从0开始的下标，
## 例如 0 表示只解锁了第一章，2 表示前三章都已解锁）。
## completed 记录每章是否已经通关。
var save_data := {
	"unlocked_chapter": 0,
	"completed": [false, false, false, false, false],
	"last_played_chapter": 0,
}

## 当前正在游玩的章节下标，用于时间线结束后判断要不要推进解锁进度。
var current_chapter_index := -1


func _ready() -> void:
	_ensure_save_dir()
	load_game()


func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


## 开始指定下标的章节（0-based）。会记录 current_chapter_index，
## 时间线结束时配合 _on_dialogic_timeline_ended 自动解锁下一章。
func start_chapter(index: int) -> void:
	if index < 0 or index >= CHAPTERS.size():
		push_error("GameState: 章节下标越界 %s" % index)
		return

	current_chapter_index = index
	save_data["last_played_chapter"] = index
	save_game()

	if not Dialogic.timeline_ended.is_connected(_on_dialogic_timeline_ended):
		Dialogic.timeline_ended.connect(_on_dialogic_timeline_ended)

	Dialogic.start(CHAPTERS[index]["timeline"])


func _on_dialogic_timeline_ended() -> void:
	if current_chapter_index < 0:
		return

	# 标记当前章节已完成
	if current_chapter_index < save_data["completed"].size():
		save_data["completed"][current_chapter_index] = true

	# 解锁下一章（如果还有）
	var next_index: int = current_chapter_index + 1
	if next_index < CHAPTERS.size():
		save_data["unlocked_chapter"] = max(save_data["unlocked_chapter"], next_index)

	save_game()
	current_chapter_index = -1

	# 章节播放结束后返回标题界面
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")


## 是否已解锁指定章节
func is_chapter_unlocked(index: int) -> bool:
	return index <= save_data.get("unlocked_chapter", 0)


func is_chapter_completed(index: int) -> bool:
	var completed: Array = save_data.get("completed", [])
	if index < completed.size():
		return completed[index]
	return false


## 是否已经通关全部5章
func is_game_completed() -> bool:
	var completed: Array = save_data.get("completed", [])
	if completed.size() < CHAPTERS.size():
		return false
	for c in completed:
		if not c:
			return false
	return true


func save_game() -> void:
	_ensure_save_dir()
	var file := FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if file == null:
		push_error("GameState: 存档写入失败 %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_FILE):
		return
	var file := FileAccess.open(SAVE_FILE, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		# 逐字段合并，避免旧存档缺字段导致后续访问报错
		for key in parsed.keys():
			save_data[key] = parsed[key]


## 清空存档，恢复到游戏最初状态（保留供设置界面的"重新开始"功能调用）
func reset_save() -> void:
	save_data = {
		"unlocked_chapter": 0,
		"completed": [false, false, false, false, false],
		"last_played_chapter": 0,
	}
	save_game()
