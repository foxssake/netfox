@tool
extends RefCounted
class_name FilenamePattern

var _pattern: String
var _reverse_pattern: RegEx

func _init(p_pattern: String):
	_pattern = p_pattern
	_reverse_pattern = RegEx.create_from_string("^" + p_pattern.replace("*", "(.*)") + "$")

func matches(filename: String) -> bool:
	return filename.match(_pattern)

func reverse(filename: String) -> String:
	if not matches(filename):
		return ""

	var reverse_result := _reverse_pattern.search(filename)

	if not reverse_result: return ""
	if reverse_result.get_group_count() < 1: return ""

	return reverse_result.get_string(1) + ".gd"

func substitute(filename: String) -> String:
	return _pattern.replace("*", filename.get_file().get_basename())

func _to_string():
	return "FilenamePattern(\"%s\")" % [_pattern]
