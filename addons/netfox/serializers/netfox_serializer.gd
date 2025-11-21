extends RefCounted
class_name NetfoxSerializer

var _encoder: Callable
var _decoder: Callable

func _init(p_encoder: Callable, p_decoder: Callable) -> void:
	_encoder = p_encoder
	_decoder = p_decoder


func encode(value: Variant, buffer: StreamPeerBuffer) -> void:
	_encoder.call(value, buffer)


func decode(buffer: StreamPeerBuffer) -> Variant:
	return _decoder.call(buffer)
