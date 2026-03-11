extends RefCounted
class_name _NetworkSchema

var _serializers := {} # subject to (property to NetworkSchemaSerializer)
var _fallback: NetworkSchemaSerializer

func _init(fallback: NetworkSchemaSerializer = NetworkSchemas.variant()) -> void:
	_fallback = fallback

func add(subject: Object, property: NodePath, serializer: NetworkSchemaSerializer) -> void:
	if not _serializers.has(subject):
		_serializers[subject] = { property: serializer }
	else:
		_serializers[subject][property] = serializer

func erase(subject: Object, property: NodePath) -> void:
	if not _serializers.has(subject):
		return

	var subject_schema := _serializers[subject] as Dictionary
	subject_schema.erase(property)

	if subject_schema.is_empty():
		_serializers.erase(subject)

func erase_subject(subject: Object) -> void:
	_serializers.erase(subject)

func encode(subject: Object, property: NodePath, value: Variant, buffer: StreamPeerBuffer) -> void:
	_get_serializer(subject, property).encode(value, buffer)

func decode(subject: Object, property: NodePath, buffer: StreamPeerBuffer) -> Variant:
	return _get_serializer(subject, property).decode(buffer)

func _get_serializer(subject: Object, property: NodePath) -> NetworkSchemaSerializer:
	return _serializers.get(subject, {}).get(property, _fallback)
