extends RefCounted
class_name _IntervalScheduler

var interval := 1
var _idx := 0

func _init(p_interval: int = 1):
	interval = p_interval

func is_now() -> bool:
	if interval <= 0:
		return false
	elif interval == 1:
		return true
	elif _idx + 1 >= interval:
		_idx = 0
		return true
	else:
		_idx += 1
		return false
