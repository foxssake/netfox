extends RefCounted
class_name RollbackFreshnessStore

## This class tracks nodes and whether they have processed any given tick during
## a rollback.

var _data: Dictionary = {}

func is_fresh(node: Node, tick: int) -> bool:
	if not _data.has(tick):
		return true
	
	if not _data[tick].has(node):
		return true
	
	return false

func notify_processed(node: Node, tick: int):
	if not _data.has(tick):
		_data[tick] = {}
	
	_data[tick][node] = true

func trim():
	while _data.size() > NetworkRollback.history_limit:
		_data.erase(_data.keys().min())
