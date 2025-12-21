extends RefCounted
class_name _NetworkSchema

var _serializers: Dictionary
var _fallback: NetworkSchemaSerializer

func _init(serializers: Dictionary, fallback: NetworkSchemaSerializer = NetworkSchemas.variant()) -> void:
	_serializers = serializers
	_fallback = fallback

func encode(path: String, value: Variant, buffer: StreamPeerBuffer) -> void:
	(_serializers.get(path, _fallback) as NetworkSchemaSerializer).encode(value, buffer)

func decode(path: String, buffer: StreamPeerBuffer) -> Variant:
	return (_serializers.get(path, _fallback) as NetworkSchemaSerializer).decode(buffer)
