extends TrimsockIDGenerator
class_name IncrementalTrimsockIDGenerator


var _at := -1


func get_id() -> String:
	_at += 1
	return "%x" % _at
