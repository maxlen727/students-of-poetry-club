extends Node
## 全局游戏状态/存档管理单例
## 负责记录玩家读到了哪一章、章节解锁进度，并提供存档/读档接口。
## 需要在 Project Settings > Autoload 中添加为 "GameState"（名称需与本文件名一致，
## 或束束可以自行改名，只要在 project.godot 里对应即可）。
##
## 存档分两部分：
## 1. 本脚本的 save_data —— 记录"游戏层面"的进度（解锁到第几章、每章是否通关），
##    存成简单的 json，供标题界面的章节选择使用。
## 2. Dialogic 自带的存档系统（Dialogic.Save）—— 记录"读到当前章节的第几句对话、
##    所有 Dialogic 变量"等精确断点，读档时能把玩家精确带回离开时的那一句话。
## 两者配合，就实现了"自动保存进度、下次打开自动继续"的需求，且不需要手写存档槽 UI。
##
## Dialogic 自带的 autosave 已在 project.godot 里关闭，改由本脚本存档：
## 每推进一句文本存一次（_on_dialogic_event_handled），关窗口时再补存一次。
## 原因：Dialogic 的 autosave 每次都会截一张屏幕缩略图（viewport 纹理回读），
## 在部分显卡/驱动上取不到纹理会报错，而且每句都回读一次 GPU 也拖性能；
## 本游戏没有存档槽界面，用不到缩略图，所以自己存、不截图。

## 对应 Dialogic.Save 里的 ThumbnailMode.NONE（该脚本没有 class_name，无法直接引用枚举）。
const THUMBNAIL_NONE := 0

const SAVE_DIR := "user://saves/"
const SAVE_FILE := "user://saves/save_slot_1.json"

## Dialogic 存档使用的槽位名，游戏内只使用这一个槽位（单线剧情，不需要多存档位）。
const DIALOGIC_SLOT := "main_slot"

## 场景路径：真正播放剧情、承载游戏内 UI（自动播放按钮、Esc菜单等）的场景。
const GAME_SCENE := "res://scenes/game.tscn"

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


## 标记"下一次进入 game.tscn 时，是要读档续玩，还是要从某一章开头新开始"。
## 由 start_chapter() / continue_game() 设置，game.tscn 的 _ready() 会读取它。
var pending_load_from_save := false


## 开始指定下标的章节（0-based），并跳转到游戏场景播放。
## 会记录 current_chapter_index，时间线结束时配合
## _on_dialogic_timeline_ended 自动解锁下一章、无缝衔接下一章。
func start_chapter(index: int) -> void:
	if index < 0 or index >= CHAPTERS.size():
		push_error("GameState: 章节下标越界 %s" % index)
		return

	current_chapter_index = index
	save_data["last_played_chapter"] = index
	save_game()

	pending_load_from_save = false
	_goto_game_scene()


## "开始/继续游戏"按钮调用：如果 Dialogic 存档里有上次读到的精确进度，就读档
## 无缝续读；否则退化为从 save_data 记录的章节开头开始。
func continue_game() -> void:
	if Dialogic.Save.has_slot(DIALOGIC_SLOT):
		current_chapter_index = save_data.get("last_played_chapter", 0)
		pending_load_from_save = true
		_goto_game_scene()
	elif is_game_completed():
		# 通关时存档槽已被删除；不从第一章开始的话会直接跳到第五章。
		start_chapter(0)
	else:
		start_chapter(save_data.get("unlocked_chapter", 0))


func _goto_game_scene() -> void:
	if not Dialogic.event_handled.is_connected(_on_dialogic_event_handled):
		Dialogic.event_handled.connect(_on_dialogic_event_handled)
	if not Dialogic.timeline_started.is_connected(_on_dialogic_timeline_started):
		Dialogic.timeline_started.connect(_on_dialogic_timeline_started)
	if not Dialogic.timeline_ended.is_connected(_on_dialogic_timeline_ended):
		Dialogic.timeline_ended.connect(_on_dialogic_timeline_ended)
	get_tree().change_scene_to_file(GAME_SCENE)


## 由 game.tscn 的 _ready() 调用，真正触发 Dialogic 开始播放或读档续播。
func begin_or_resume_current_chapter() -> void:
	if pending_load_from_save:
		pending_load_from_save = false
		# 读档是异步的，时间线要过几帧才真正开始；
		# 章节下标由 _on_dialogic_timeline_started 按实际时间线校正。
		Dialogic.Save.load(DIALOGIC_SLOT)
	else:
		Dialogic.start(CHAPTERS[current_chapter_index]["timeline"])


func _chapter_index_of_current_timeline() -> int:
	if Dialogic.current_timeline == null:
		return -1
	var path: String = Dialogic.current_timeline.resource_path
	for i in range(CHAPTERS.size()):
		if CHAPTERS[i]["timeline"] == path:
			return i
	return -1


## 以实际开始播放的时间线为准校正当前章节，而不是信 save_data 里的
## last_played_chapter。两者可能不一致（例如上一章刚结束、下一章还没来得及
## 存档就关了游戏），不一致时章节结束会把错误的章节标记为通关。
## Dialogic 收尾用的 [clear] 时间线也会触发这个信号，查不到章节时忽略。
func _on_dialogic_timeline_started() -> void:
	var index := _chapter_index_of_current_timeline()
	if index < 0 or index == current_chapter_index:
		return
	current_chapter_index = index
	save_data["last_played_chapter"] = index
	save_game()


## 写入 Dialogic 精确断点，不截缩略图。
## is_autosave 必须传 false：Dialogic 的 save() 遇到"自动存档且 autosave 已关闭"
## 会直接跳过不写，而我们正是把它的 autosave 关掉了。
func _save_progress() -> void:
	Dialogic.Save.save(DIALOGIC_SLOT, false, THUMBNAIL_NONE)


## 每推进一句文本自动存一次。
func _on_dialogic_event_handled(event: DialogicEvent) -> void:
	if current_chapter_index >= 0 and event is DialogicTextEvent:
		_save_progress()


## 直接关窗口时也存一次精确断点（自动存档只在推进文本时写入）。
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if current_chapter_index >= 0 and Dialogic.current_timeline != null:
			_save_progress()


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

	if next_index < CHAPTERS.size():
		# 还有下一章：直接无缝衔接播放，不退出到主界面。
		# 不删除存档槽：下一章推进第一句文本时会自然覆盖成新章节的进度；
		# 万一在那之前关了游戏，读档后 _on_dialogic_timeline_started 会按
		# 实际时间线校正章节下标。
		current_chapter_index = next_index
		save_data["last_played_chapter"] = next_index
		save_game()
		Dialogic.start(CHAPTERS[next_index]["timeline"])
	else:
		# 已经是最后一章：全剧通关，删除存档槽。
		current_chapter_index = -1
		if Dialogic.Save.has_slot(DIALOGIC_SLOT):
			Dialogic.Save.delete_slot(DIALOGIC_SLOT)
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")


## 返回主界面（Esc 菜单里"返回标题"用）。
##
## 这里的关键坑，来自对 Dialogic 内部机制的两次踩坑排查，记录一下方便以后维护：
##
## 坑1（已排除）：一度以为是"存档瞬间角色正在播放入场/切换立绘动画"导致
## character_nodes 字典还没写入就被访问。但实际看 add_character() 源码，
## character_nodes[key] 是同步、在动画播放之前就写入的，这个猜测是错的。
##
## 坑2（真正原因）：之前用 Dialogic.end_timeline(true) 来清理退出时的剧情图层，
## 它内部调用 clear(ClearFlags.TIMELINE_INFO_ONLY)——这个 flag 会跳过所有
## subsystem 的 _clear_state()，portraits 子系统的 character_nodes / portraits
## 字典完全没有被清空，残留着退出前那一刻的角色数据。下次"继续游戏"读档时，
## _load_state() 在这些"半旧半新"的字典上操作，就会出现 key 冲突/访问失败，
## 崩成 'Invalid access to property... on Dictionary[String, Node]'。
##
## 坑3：改用 Dialogic.clear(FULL_CLEAR) 后，subsystem 状态确实被彻底清空了，
## 但 Styles 子系统的 _clear_state() 只重置了两个字符串变量（style/base_style），
## 并不会真的移除场景树里的图层节点（背景/立绘/文字框）——这个"移除节点"的
## 逻辑其实是写在 end_timeline() 内部单独的一段代码里，不属于 clear()。
## 所以只调用 clear() 会导致图层残留可见，重新出现"退出后画面还叠着"的问题。
##
## 解决：两件事都要做——1) 存档 2) 完整 clear(FULL_CLEAR) 清空所有 subsystem
## 内部数据 3) 手动移除图层节点（照抄 end_timeline() 里对应的那段逻辑）。
func return_to_title() -> void:
	if current_chapter_index >= 0:
		_save_progress()

	current_chapter_index = -1

	# 断开 timeline_ended 监听，避免任何后续调用路径意外触发章节完成逻辑。
	if Dialogic.timeline_ended.is_connected(_on_dialogic_timeline_ended):
		Dialogic.timeline_ended.disconnect(_on_dialogic_timeline_ended)
	if Dialogic.timeline_started.is_connected(_on_dialogic_timeline_started):
		Dialogic.timeline_started.disconnect(_on_dialogic_timeline_started)
	if Dialogic.event_handled.is_connected(_on_dialogic_event_handled):
		Dialogic.event_handled.disconnect(_on_dialogic_event_handled)

	# 1) 完整清空所有 subsystem 内部数据（portraits/backgrounds/audio/...），
	# 确保下次读档面对的是干净状态，不会有残留角色节点引用导致崩溃。
	await Dialogic.clear(DialogicGameHandler.ClearFlags.FULL_CLEAR)

	# 确认框打开时 game_screen 会把 Dialogic 暂停，而 clear() 不会重置 paused。
	# 不在这里解除的话，下次"继续游戏"读档后剧情会卡住不动。
	Dialogic.paused = false

	# 2) 手动移除剧情图层节点（背景/立绘/文字框等），因为 clear() 本身
	# 不负责这件事。逻辑照抄自 Dialogic 内部 end_timeline() 的对应实现。
	if Dialogic.Styles.has_active_layout_node():
		var layout_node := Dialogic.Styles.get_layout_node()
		if is_instance_valid(layout_node) and layout_node.is_inside_tree():
			layout_node.get_parent().remove_child(layout_node)
			layout_node.queue_free()

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
	if Dialogic.Save.has_slot(DIALOGIC_SLOT):
		Dialogic.Save.delete_slot(DIALOGIC_SLOT)


## 是否存在"可续读"的进度（即 Dialogic 精确断点存档）
func has_continue_save() -> bool:
	return Dialogic.Save.has_slot(DIALOGIC_SLOT)
