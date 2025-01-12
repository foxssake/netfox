extends Node
class_name NetworkTickrateHandshake

# TODO: Doc

enum {
	NOTHING,
	WARN,
	DISCONNECT,
	ADJUST,
	SIGNAL
}

var mismatch_action: int = ProjectSettings.get_setting("netfox/time/tickrate_mismatch_action", WARN)

var _known_tickrates: Dictionary = {}

static var _logger := _NetfoxLogger.for_netfox("NetworkTickrateHandshake")

signal on_tickrate_mismatch(peer: int, tickrate: int)

func run() -> void:
	if multiplayer.is_server():
		# Broadcast tickrate
		_submit_tickrate.rpc(NetworkTime.tickrate)
		
		# Submit to anyone joining
		multiplayer.peer_connected.connect(func(peer):
			if not self:
				_logger.error("Can't submit tickrate: %s", [self])
				return
			_submit_tickrate.rpc_id(peer, NetworkTime.tickrate + randi_range(5, 15))
		)
	else:
		# Submit tickrate to server
		_submit_tickrate.rpc_id(1, NetworkTime.tickrate + randi_range(5, 15))

func _ready() -> void:
	name = "NetworkTickrateHandshake"

func _handle_tickrate_mismatch(peer: int, tickrate: int) -> void:
	match mismatch_action:
		NOTHING: pass
		WARN:
			_logger.warning(
				"Local tickrate %dtps differs from tickrate of peer #%d at %dtps! " +
				"Make sure that tickrates are correctly configured in the Project settings! " +
				"See netfox/Time/Tickrate.", [
					NetworkTime.tickrate, peer, tickrate
				])
		DISCONNECT:
			if multiplayer.is_server():
				_logger.warning("Peer #%d's tickrate of %dtps differs from expected %dtps! Disconnecting.", [
					peer, tickrate, NetworkTime.tickrate
				])
				multiplayer.multiplayer_peer.disconnect_peer(peer)
		ADJUST:
			if not multiplayer.is_server():
				_logger.info("Local tickrate %dtps differs from tickrate of host at %dtps! Adjusting.", [
					NetworkTime.tickrate, tickrate
				])
				# TODO: Make tickrate mutable at user's digression
				ProjectSettings.set_setting("netfox/time/tickrate", tickrate)
		SIGNAL:
			on_tickrate_mismatch.emit(peer, tickrate)

@rpc("any_peer", "reliable", "call_remote")
func _submit_tickrate(tickrate: int) -> void:
	var sender = multiplayer.get_remote_sender_id()
	_known_tickrates[sender] = tickrate
	_logger.debug("Received tickrate %d from peer %d", [tickrate, sender])

	if tickrate != NetworkTime.tickrate:
		_handle_tickrate_mismatch(sender, tickrate)
