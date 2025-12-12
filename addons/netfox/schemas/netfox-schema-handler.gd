# TODO: Private
extends RefCounted
class_name NetfoxSchemaHandler

var _serializers: Dictionary
var _fallback: NetfoxSerializer

func _init(serializers: Dictionary, fallback: NetfoxSerializer = NetfoxSchemas.variant()) -> void:
	_serializers = serializers
	_fallback = fallback

func encode(path: String, value: Variant, buffer: StreamPeerBuffer) -> void:
	(_serializers.get(path, _fallback) as NetfoxSerializer).encode(value, buffer)

func decode(path: String, buffer: StreamPeerBuffer) -> Variant:
	return (_serializers.get(path, _fallback) as NetfoxSerializer).decode(buffer)
