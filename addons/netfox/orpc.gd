extends Object
class_name ORPC

static var _PREFIX := PackedByteArray([0, 82, 80, 67]) # "ØRPC"
const _MAX_ID := 4_294_967_295 # 32 bits

static var _multiplayer: SceneMultiplayer
static var _sender: int = -1

# TODO: BiMap
static var _id_to_callable := {}
static var _callable_to_id := {}

static var _logger := _NetfoxLogger.for_netfox("ORPC")

static func use(multiplayer: SceneMultiplayer):
	if _multiplayer == multiplayer:
		return

	if _multiplayer:
		_multiplayer.peer_packet.disconnect(_handle_packet)

	_multiplayer = multiplayer
	_multiplayer.peer_packet.connect(ORPC._handle_packet)

static func register(callable: Callable, name: String) -> int:
	if _callable_to_id.has(callable):
		_logger.warning("Trying to register callable \"%s\" multiple times", [name])
		return _callable_to_id[callable]

	var id := _gen_id(name)
	_id_to_callable[id] = callable
	_callable_to_id[callable] = id

	_logger.debug("Registered \"%s\" with ID %d", [name, id])

	return id

static func unregister(callable: Callable):
	if not _callable_to_id.has(callable):
		return

	var id = _callable_to_id[callable]
	_id_to_callable.erase(id)
	_callable_to_id.erase(callable)

	_logger.debug("Freed ID %d", [id])

static func rpc(callable: Callable, args: Array, peer: int = 0, mode: MultiplayerPeer.TransferMode = 2, channel: int = 0) -> Error:
	if not _multiplayer:
		_logger.error("No multiplayer API set, doing nothing!")
		return ERR_UNCONFIGURED

	if not _callable_to_id.has(callable):
		_logger.error("Trying to call unknown callable!")
		return ERR_METHOD_NOT_FOUND

	var id := _callable_to_id[callable] as int
	var buffer := _encode_call(id, args)

	return _multiplayer.send_bytes(buffer, peer, mode, channel)

static func clear():
	_callable_to_id.clear()
	_id_to_callable.clear()

static func get_remote_sender_id() -> int:
	return _sender

static func _encode_call(id: int, args: Array) -> PackedByteArray:
	var id_buffer := PackedByteArray()
	id_buffer.resize(4)
	id_buffer.encode_u32(0, id)

	var args_buffer := var_to_bytes(args)

	var result := PackedByteArray()
	result.append_array(_PREFIX)
	result.append_array(id_buffer)
	result.append_array(args_buffer)

	return result

# Returns a tuple of [id, args]
static func _decode_call(buffer: PackedByteArray) -> Array:
	if not _is_orpc_packet(buffer):
		_logger.warning("Trying to decode non-ORPC packet!")
		return []

	var id := buffer.decode_u32(_PREFIX.size())
	var args = buffer.decode_var(_PREFIX.size() + 4)

	if args == null or not args is Array:
		_logger.warning("Received invalid args! %s" % [args])
		return []

	return [id, args]

static func _is_orpc_packet(buffer: PackedByteArray) -> bool:
	var prefix := buffer.slice(0, _PREFIX.size())
	return prefix == _PREFIX

static func _handle_packet(sender: int, buffer: PackedByteArray):
	if not _is_orpc_packet(buffer):
		return

	var call_tuple := _decode_call(buffer)
	if call_tuple.is_empty():
		_logger.error("Received invalid call data from peer #%d! %s", [sender, buffer])
		return

	var callable_id := call_tuple[0] as int
	var args := call_tuple[1] as Array

	if not _id_to_callable.has(callable_id):
		_logger.warning("Received unknown callable ID %d!", [callable_id])
		return

	var callable := _id_to_callable[callable_id] as Callable
	_sender = sender
	callable.callv(args)
	_sender = -1

static func _gen_id(name: String) -> int:
	var id := hash(name) % _MAX_ID

	while _id_to_callable.has(id):
		id = hash(id * 39 + 17) % _MAX_ID

	return id
