extends Node

var _next_id := 0
var _identifiers := {} # object to NetworkIdentifier
var _push_queue := [] as Array[IdentityNotification]

@onready var _cmd_ids := NetworkCommandServer.register_command_at(_NetworkCommands.IDS, _handle_ids)

static var _logger := NetfoxLogger._for_netfox("NetworkIdentityServer")

func register(what: Object, path: String) -> void:
	if _identifiers.has(what):
		return
	
	var identifier := NetworkIdentifier.new(what, path, _make_id())
	_identifiers[what] = identifier

func deregister(what: Object) -> void:
	_identifiers.erase(what)

func clear() -> void:
	_identifiers.clear()
	_next_id = 0

func register_node(node: Node) -> void:
	if not node.is_inside_tree():
		_logger.error("Can't register node %s that is not inside tree!", [node])
		return
	register(node, node.get_path())

func deregister_node(node: Node) -> void:
	deregister(node)

# TODO: Consider specific queries, NetworkIdentifier might be an impl detail
func get_identifier_of(what: Object) -> NetworkIdentifier:
	return _identifiers[what]

func resolve_reference(peer: int, identity_reference: NetworkIdentityReference, allow_queue: bool = true) -> NetworkIdentifier:
	if identity_reference.has_id():
		return _get_identifier_by_id(peer, identity_reference.get_id())
	else:
		var identifier := _get_identifier_by_name(identity_reference.get_full_name())
		if allow_queue and identifier:
			queue_for(identifier, peer)
		return identifier

func queue_for(identifier: NetworkIdentifier, peer: int) -> void:
	_push_queue.append(IdentityNotification.of(peer, identifier))

func flush_queue() -> void:
	var ids := {}
	
	for item in _push_queue:
		if not ids.has(item.peer): ids[item.peer] = {}
		ids[item.peer][item.identifier.get_full_name()] = item.identifier.get_local_id()

	for peer in ids:
		_cmd_ids.send(_serialize_ids(ids[peer]), peer)

func _get_identifier_by_name(full_name: String) -> NetworkIdentifier:
	# TODO: Optimize, probably by caching
	for value in _identifiers.values() as Array:
		var identifier := value as NetworkIdentifier
		if identifier.get_full_name() == full_name:
			return identifier
	return null

func _get_identifier_by_id(peer: int, id: int) -> NetworkIdentifier:
	# TODO: Optimize, probably by caching
	for value in _identifiers.values() as Array:
		var identifier := value as NetworkIdentifier
		if identifier.get_id_for(peer) == id:
			return identifier
	return null

func _make_id() -> int:
	_next_id += 1
	return _next_id

func _handle_ids(sender: int, data: PackedByteArray) -> void:
	var ids := _deserialize_ids(data)

	for full_name in ids:
		var id := ids[full_name] as int
		var identifier := _get_identifier_by_name(full_name)
		if not identifier:
			# Probably deleted since then
			# TODO: Queue in case node was not registered *yet*
			_logger.debug("Received identifier for unknown object with full name %s, id #%d", [full_name, id])
			continue
		identifier.set_id_for(sender, id)

func _serialize_ids(ids: Dictionary) -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	var varuint := NetworkSchemas.varuint()

	for full_name in ids.keys():
		var id := ids[full_name] as int

		buffer.put_utf8_string(full_name)
		varuint.encode(ids[full_name], buffer)

	return buffer.data_array

func _deserialize_ids(data: PackedByteArray) -> Dictionary:
	var ids := {}
	var varuint := NetworkSchemas.varuint()
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data

	while buffer.get_available_bytes() > 0:
		var full_name := buffer.get_utf8_string()
		var id := varuint.decode(buffer) as int

		ids[full_name] = id

	return ids

# TODO: Consider private
class NetworkIdentifier:
	var _subject: Object
	var _full_name: String
	var _ids: Dictionary = {} # peer to id
	var _local_id: int

	func _init(subject: Object, full_name: String, local_id: int):
		_subject = subject
		_full_name = full_name
		_local_id = local_id

	func has_id_for(peer: int) -> bool:
		# TODO: Also return true for local peer, just to be correct
		return _ids.has(peer)

	func get_id_for(peer: int) -> int:
		return _ids.get(peer, -1)

	func set_id_for(peer: int, id: int) -> void:
		_ids[peer] = id

	func get_local_id() -> int:
		return _local_id
		
	func get_full_name() -> String:
		return _full_name
		
	func get_subject() -> Object:
		return _subject

	func reference_for(peer: int) -> NetworkIdentityReference:
		if has_id_for(peer):
			return NetworkIdentityReference.of_id(get_id_for(peer))
		else:
			return NetworkIdentityReference.of_full_name(get_full_name())

class NetworkIdentityReference:
	var _full_name: String = ""
	var _id: int = -1

	static func of_full_name(full_name: String) -> NetworkIdentityReference:
		var reference := NetworkIdentityReference.new()
		reference._full_name = full_name
		return reference

	static func of_id(id: int) -> NetworkIdentityReference:
		var reference := NetworkIdentityReference.new()
		reference._id = id
		return reference

	func has_id() -> bool:
		return _id > 0

	func get_id() -> int:
		return _id

	func get_full_name() -> String:
		return _full_name

	func equals(other: Variant) -> bool:
		if other is NetworkIdentityReference:
			return _full_name == other._full_name and _id == other._id
		return false

	func _to_string() -> String:
		if has_id():
			return "NetworkIdentityReference#%d" % [_id]
		else:
			return "NetworkIdentityReference(%s)" % [_full_name]

# TODO: Private
class IdentityNotification:
	var peer: int
	var identifier: NetworkIdentifier
	
	static func of(p_peer: int, p_identifier: NetworkIdentifier) -> IdentityNotification:
		var request := IdentityNotification.new()
		request.peer = p_peer
		request.identifier = p_identifier
		return request
