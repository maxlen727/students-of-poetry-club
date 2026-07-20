extends Node

const ARCH_YEAR = 2002
const ARCH_MONTH = 3
const ARCH_DAY = 11

func _ready():
	update_arch_age()

func update_arch_age():
	var d = Time.get_date_dict_from_system()

	var age = d.year - ARCH_YEAR

	if d.month < ARCH_MONTH:
		age -= 1
	elif d.month == ARCH_MONTH and d.day < ARCH_DAY:
		age -= 1

	Dialogic.VAR.set("arch_age", age)
