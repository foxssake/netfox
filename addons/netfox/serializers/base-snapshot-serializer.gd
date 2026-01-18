extends RefCounted
class_name _BaseSnapshotSerializer

# TODO: Swap to (object to (property to NetworkSchemaSerializer))
var _schemas := {} # RecordedProperty key to NetworkSchemaSerializer
var _fallback_schema := NetworkSchemas.variant()

static var _logger := NetfoxLogger._for_netfox("DenseSnapshotSerializer")

func _init(p_schemas: Dictionary):
	assert(p_schemas != null, "Missing schemas!")
	# Intentionally storing reference, so it can be modified from the outside
	# e.g. RollbackSynchronizerServer adds a property
	_schemas = p_schemas

func _write_property(node: Node, property: NodePath, value: Variant, buffer: StreamPeerBuffer) -> void:
	var serializer := _schemas.get(RecordedProperty.key_of(node, property), _fallback_schema) as NetworkSchemaSerializer
	serializer.encode(value, buffer)

func _read_property(node: Node, property: NodePath, buffer: StreamPeerBuffer) -> Variant:
	var serializer := _schemas.get(RecordedProperty.key_of(node, property), _fallback_schema) as NetworkSchemaSerializer
	return serializer.decode(buffer)

func _write_identifier(subject: Object, peer: int, buffer: StreamPeerBuffer) -> Error:
	var netref := NetworkSchemas._netref()
	var identifier := NetworkIdentityServer.get_identifier_of(subject)
	if not identifier:
		_logger.error("Can't synchronize %s, identifier missing!", [subject])
		return ERR_DOES_NOT_EXIST

	var idref := identifier.reference_for(peer)
	netref.encode(idref, buffer)
	return OK
