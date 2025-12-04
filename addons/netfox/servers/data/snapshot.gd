extends RefCounted
class_name Snapshot

var tick: int
var data: Dictionary = {} # RecordedProperty to Variant value

func _init(p_tick: int):
	tick = p_tick

func has_node(node: Node) -> bool:
	for entry in data.keys():
		if (entry as RecordedProperty).node == node:
			return true
	return false

func _to_string() -> String:
	return "Snapshot(#%d, %s)" % [tick, str(data)]
