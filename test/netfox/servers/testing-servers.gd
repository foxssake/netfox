extends Node
class_name TestingServers

var _command_server: CommandServer
var _identity_server: _NetworkIdentityServer
var _history_server: _NetworkHistoryServer
var _synchronization_server: _NetworkSynchronizationServer
var _simulation_server: _RollbackSimulationServer

static func create() -> TestingServers:
	var servers := TestingServers.new()

	Vest.get_tree().root.add_child.call_deferred(servers)
	await servers.ready

	return servers

func _ready():
	_command_server = CommandServer.new()
	_history_server = _NetworkHistoryServer.new()
	_identity_server = _NetworkIdentityServer.new(_command_server)
	_synchronization_server = _NetworkSynchronizationServer.new(_command_server, _history_server, _identity_server, _simulation_server)
	_simulation_server = _RollbackSimulationServer.new(_history_server)
	var servers := [_command_server, _history_server, _identity_server, _synchronization_server, _simulation_server]

	for server in servers:
		add_child.call_deferred(server)

	for server in servers:
		await server.ready

func command_server() -> CommandServer:
	return _command_server

func identity_server() -> _NetworkIdentityServer:
	return _identity_server

func history_server() -> _NetworkHistoryServer:
	return _history_server

func synchronization_server() -> _NetworkSynchronizationServer:
	return _synchronization_server

func simulation_server() -> _RollbackSimulationServer:
	return _simulation_server


class CommandServer extends _NetworkCommandServer:
	var commands_sent := [] as Array[Array]

	func send_command(idx: int, data: PackedByteArray, target_peer: int = 0, mode: MultiplayerPeer.TransferMode = MultiplayerPeer.TRANSFER_MODE_RELIABLE, channel: int = 0) -> void:
		commands_sent.append([idx, data, target_peer, mode, channel])
