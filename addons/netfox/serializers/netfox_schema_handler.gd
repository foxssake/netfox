extends RefCounted
class_name NetfoxSchemaHandler

var _serializers: Dictionary
var _fallback: NetfoxSerializer

func _init(serializers: Dictionary, fallback: NetfoxSerializer) -> void:
	_serializers = serializers
	_fallback = fallback

func encode(path: String, value: Variant, buffer: StreamPeerBuffer) -> void:
	if _serializers.has(path):
		_serializers[path].encode(value, buffer)
	else:
		_fallback.encode(value, buffer)

func decode(path: String, buffer: StreamPeerBuffer) -> Variant:
	if _serializers.has(path):
		return _serializers[path].decode(buffer)
	else:
		return _fallback.decode(buffer)