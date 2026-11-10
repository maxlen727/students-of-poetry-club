extends Node
## Arch chan 的年龄：按系统日期实时计算，写入 Dialogic 变量 arch_age。
##
## 不能只在 _ready() 里算一次：Dialogic.clear(FULL_CLEAR)（返回标题时会调用）
## 和读档都会把变量重置成 project.godot 里的默认值，所以每次时间线开始都重新写入。

const ARCH_YEAR := 2002
const ARCH_MONTH := 3
const ARCH_DAY := 11


func _ready() -> void:
	update_arch_age()
	Dialogic.timeline_started.connect(update_arch_age)


func update_arch_age() -> void:
	var d := Time.get_date_dict_from_system()

	var age: int = d.year - ARCH_YEAR
	if d.month < ARCH_MONTH or (d.month == ARCH_MONTH and d.day < ARCH_DAY):
		age -= 1

	Dialogic.VAR.set("arch_age", age)
