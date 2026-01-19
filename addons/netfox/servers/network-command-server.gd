extends Node
class_name _NetworkCommandServer

var _next_idx := 0
var _rpc_transport := RPCTransport.new()
var _packet_transport := PacketTransport.new()
var _commands := {} # id to `Command`

var _use_raw := ProjectSettings.get_setting("netfox/general/use_raw_commands", false)

static var _logger := NetfoxLogger._for_netfox("NetworkCommandServer")

# TODO: Update time synchronizer to use commands

func _ready():
	add_child(_rpc_transport, true)
	add_child(_packet_transport, true)

	_rpc_transport.on_receive.connect(_handle_command)
	_packet_transport.on_receive.connect(_handle_command)

func _handle_command(sender: int, idx: int, data: PackedByteArray) -> void:
	var command := _commands.get(idx) as Command
	if not command:
		_logger.error("Received unknown command #%d!", [idx])
		return
	command.handle(sender, data)

func register_command(handler: Callable) -> Command:
	var idx := _next_idx
	_next_idx += 1
	return register_command_at(idx, handler)

func register_command_at(idx: int, handler: Callable, mode: MultiplayerPeer.TransferMode = MultiplayerPeer.TRANSFER_MODE_RELIABLE, channel: int = 0) -> Command:
	assert(not _commands.has(idx), "Command #%d is already taken!" % idx)
	var command := Command.new(self, idx, handler, mode, channel)
	_commands[idx] = command
	
	_next_idx = maxi(_next_idx, idx + 1)
	
	return command

func send_command(idx: int, data: PackedByteArray, target_peer: int = 0, mode: MultiplayerPeer.TransferMode = MultiplayerPeer.TRANSFER_MODE_RELIABLE, channel: int = 0) -> void:
	if _use_raw:
		_packet_transport.send(idx, data, target_peer, mode, channel)
	else:
		_rpc_transport.send(idx, data, target_peer, mode, channel)

class Command:
	var _command_server: _NetworkCommandServer

	var _idx: int
	var _handler: Callable
	var _mode: MultiplayerPeer.TransferMode
	var _channel: int

	func _init(p_command_server: _NetworkCommandServer, p_idx: int, p_handler: Callable, p_mode: MultiplayerPeer.TransferMode, p_channel: int):
		_command_server = p_command_server
		_idx = p_idx
		_handler = p_handler
		_mode = p_mode
		_channel = p_channel

	func send(data: PackedByteArray, target_peer: int = 0) -> void:
		_command_server.send_command(_idx, data, target_peer, _mode, _channel)

	func handle(sender: int, data: PackedByteArray) -> void:
		_handler.call(sender, data)

class Transport extends Node:
	signal on_receive(idx: int, data: PackedByteArray)
	
	func send(idx: int, data: PackedByteArray, target_peer: int, mode: MultiplayerPeer.TransferMode, channel: int) -> void:
		pass

class PacketTransport extends Transport:
	var _packet_prefix := PackedByteArray([0, 78, 70]) # "\0nf"

	func _ready():
		(multiplayer as SceneMultiplayer).peer_packet.connect(_handle_packet)

	func send(idx: int, data: PackedByteArray, target_peer: int, mode: MultiplayerPeer.TransferMode, channel: int) -> void:
		var buffer := StreamPeerBuffer.new()
		buffer.put_data(_packet_prefix)
		buffer.put_u8(idx)
		buffer.put_data(data)

		(multiplayer as SceneMultiplayer).send_bytes(buffer.data_array, target_peer, mode, channel)
		
	func _handle_packet(peer: int, packet: PackedByteArray) -> void:
		var buffer := StreamPeerBuffer.new()
		buffer.data_array = packet

		# Check header
		for i in _packet_prefix.size():
			if buffer.get_u8() != _packet_prefix[i]:
				return
		
		# Grab data
		var idx := buffer.get_u8()
		var data := buffer.get_partial_data(buffer.get_available_bytes())[1] as PackedByteArray

		on_receive.emit(peer, idx, data)

class RPCTransport extends Transport:
	func send(idx: int, data: PackedByteArray, target_peer: int, mode: MultiplayerPeer.TransferMode, _channel: int) -> void:
		match mode:
			MultiplayerPeer.TRANSFER_MODE_UNRELIABLE: _submit_unreliable.rpc_id(target_peer, idx, data)
			MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED: _submit_unreliable_ordered.rpc_id(target_peer, idx, data)
			MultiplayerPeer.TRANSFER_MODE_RELIABLE: _submit_reliable.rpc_id(target_peer, idx, data)
	
	@rpc("any_peer", "call_remote", "unreliable")
	func _submit_unreliable(idx: int, data: PackedByteArray):
		var sender := multiplayer.get_remote_sender_id()
		on_receive.emit(sender, idx, data)
	
	@rpc("any_peer", "call_remote", "unreliable_ordered")
	func _submit_unreliable_ordered(idx: int, data: PackedByteArray):
		var sender := multiplayer.get_remote_sender_id()
		on_receive.emit(sender, idx, data)

	@rpc("any_peer", "call_remote", "reliable")
	func _submit_reliable(idx: int, data: PackedByteArray):
		var sender := multiplayer.get_remote_sender_id()
		on_receive.emit(sender, idx, data)
