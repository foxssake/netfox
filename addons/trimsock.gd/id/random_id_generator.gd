extends TrimsockIDGenerator
class_name RandomTrimsockIDGenerator


var charset := "abcdeghijklmnopqrstuvwxyz" + "ABCDEFGHIJLKMNOPQRSTUVWXYZ" + "0123456789"
var length := 8

var _rng := RandomNumberGenerator.new()


func _init(p_length: int = 8, p_charset: String = ""):
	length = p_length
	if p_charset:
		charset = p_charset

func get_id() -> String:
	var id := ""
	for i in length:
		id += charset[_rng.randi() % charset.length()]
	return id
