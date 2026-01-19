extends RefCounted
class_name _BaseSnapshotSerializer

var _schemas: _NetworkSchema

static var _default_filter := func(subject: Object): return true
static var _logger := NetfoxLogger._for_netfox("DenseSnapshotSerializer")

func _init(p_schemas: _NetworkSchema):
	assert(p_schemas != null, "Missing schemas!")
	# Intentionally storing reference, so it can be modified from the outside
	# e.g. RollbackSynchronizerServer adds a property
	_schemas = p_schemas

func _write_property(node: Node, property: NodePath, value: Variant, buffer: StreamPeerBuffer) -> void:
	_schemas.encode(node, property, value, buffer)

func _read_property(node: Node, property: NodePath, buffer: StreamPeerBuffer) -> Variant:
	return _schemas.decode(node, property, buffer)

func _write_identifier(subject: Object, peer: int, buffer: StreamPeerBuffer) -> Error:
	var netref := NetworkSchemas._netref()
	var identifier := NetworkIdentityServer.get_identifier_of(subject)
	if not identifier:
		_logger.error("Can't synchronize %s, identifier missing!", [subject])
		return ERR_DOES_NOT_EXIST

	var idref := identifier.reference_for(peer)
	netref.encode(idref, buffer)
	return OK
