extends Node
class_name _NetworkIdentityServer

var _command_server: _NetworkCommandServer

var _next_id := 0
var _identifiers := {} # object to NetworkIdentifier
var _push_queue := {} # peer to (full name to id)

var _identifier_by_name := {} # full name to NetworkIdentifier
var _identifier_by_id := {} # peer to (id to NetworkIdentifier)

var _cmd_ids: _NetworkCommandServer.Command

static var _logger := NetfoxLogger._for_netfox("NetworkIdentityServer")

func _init(p_command_server: _NetworkCommandServer = null):
	_command_server = p_command_server

func _ready():
	if not _command_server:
		_command_server = NetworkCommandServer

	_cmd_ids = _command_server.register_command_at(_NetworkCommands.IDS, _handle_ids)

func register(what: Object, path: String) -> void:
	if _identifiers.has(what):
		return
	
	var identifier := _NetworkIdentifier.new(what, path, _make_id(), multiplayer.get_unique_id())
	_identifiers[what] = identifier
	_identifier_by_name[identifier.get_full_name()] = identifier

	identifier.on_id.connect(func(peer: int, id: int): _update_id_cache(identifier, peer, id))
	_update_id_cache(identifier, multiplayer.get_unique_id(), identifier.get_local_id())

func deregister(what: Object) -> void:
	if not _identifiers.has(what):
		return

	var identifier := _identifiers[what] as _NetworkIdentifier
	_identifiers.erase(what)
	_identifier_by_name.erase(identifier.get_full_name())
	_erase_from_id_cache(identifier)

func clear() -> void:
	_identifiers.clear()
	_identifier_by_name.clear()
	_identifier_by_id.clear()
	_next_id = 0

# TODO: Handle peer disconnect by clearing up data

func register_node(node: Node) -> void:
	if not node.is_inside_tree():
		_logger.error("Can't register node %s that is not inside tree!", [node])
		return
	register(node, node.get_path())

func deregister_node(node: Node) -> void:
	deregister(node)

# TODO: Consider specific queries, NetworkIdentifier might be an impl detail
func get_identifier_of(what: Object) -> _NetworkIdentifier:
	return _identifiers.get(what)

func resolve_reference(peer: int, identity_reference: _NetworkIdentityReference, allow_queue: bool = true) -> _NetworkIdentifier:
	if identity_reference.has_id():
		return _get_identifier_by_id(peer, identity_reference.get_id())
	else:
		var identifier := _get_identifier_by_name(identity_reference.get_full_name())
		if allow_queue and identifier:
			queue_for(identifier, peer)
		return identifier

func queue_for(identifier: _NetworkIdentifier, peer: int) -> void:
	if not _push_queue.has(peer):
		_push_queue[peer] = { identifier.get_full_name(): identifier.get_id_for(peer) }
	else: 
		_push_queue[peer][identifier.get_full_name()] = identifier.get_id_for(peer)

func flush_queue() -> void:
	for peer in _push_queue:
		_cmd_ids.send(_serialize_ids(_push_queue[peer]), peer)
	_push_queue.clear()

func _get_identifier_by_name(full_name: String) -> _NetworkIdentifier:
	return _identifier_by_name.get(full_name)

func _get_identifier_by_id(peer: int, id: int) -> _NetworkIdentifier:
	return _identifier_by_id.get(peer, {}).get(id, null)

func _make_id() -> int:
	_next_id += 1
	return _next_id

func _update_id_cache(identifier: _NetworkIdentifier, peer: int, id: int) -> void:
	if not _identifier_by_id.has(peer):
		_identifier_by_id[peer] = { id: identifier }
	else:
		_identifier_by_id[peer][id] = identifier

func _erase_from_id_cache(identifier: _NetworkIdentifier) -> void:
	for peer in identifier.get_known_peers():
		if not _identifier_by_id.has(peer):
			# nani?
			continue

		var cache := _identifier_by_id.get(peer) as Dictionary
		cache.erase(identifier.get_id_for(peer))
		if cache.is_empty():
			_identifier_by_id.erase(peer)

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
