extends RefCounted
class_name RollbackFreshnessStore

## This class tracks nodes and whether they have processed any given tick during
## a rollback.

# TODO: _Set
var _data: Dictionary = {}

func is_fresh(node: Node, tick: int) -> bool:
	if not _data.has(tick):
		return true
	
	if not _data[tick].has(node):
		return true
	
	return false

func notify_processed(node: Node, tick: int) -> void:
	if not _data.has(tick):
		_data[tick] = {}
	
	_data[tick][node] = true

func trim() -> void:
	while not _data.is_empty():
		var earliest_tick := _data.keys().min()
		if earliest_tick < NetworkRollback.history_start:
			_data.erase(earliest_tick)
		else:
			break

func clear():
	_data.clear()
