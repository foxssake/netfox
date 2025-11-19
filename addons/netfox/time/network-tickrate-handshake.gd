extends Node
class_name NetworkTickrateHandshake

## Internal class to manage the tickrate handshake.
##
## Whenever a new peer joins, they exchange their configured tickrate with the 
## host. If the tickrate mismatches, a warning is emitted by default, as this is
## assumed to be a developer mistake.
## [br][br]
## However, if this is expected, different actions can be configured.

## Emit a warning on tickrate mismatch
const WARN := 0

## Disconnect peer on tickrate mismatch[br]
## This is enforced by the host.
const DISCONNECT := 1

## Adjust tickrate to the host's on mismatch
const ADJUST := 2

## Emit [signal on_tickrate_mismatch] on mismatch[br]
## This is emitted on both host and client.
const SIGNAL := 3

## Configures what happens on a tickrate mismatch.[br]
## Defaults to [constant WARN], based on project settings.
var mismatch_action: int = ProjectSettings.get_setting(&"netfox/time/tickrate_mismatch_action", WARN)

static var _logger := NetfoxLogger._for_netfox("NetworkTickrateHandshake")

## Emitted when a tickrate mismatch is encountered, and [member mismatch_action] is set to 
## [constant SIGNAL].
signal on_tickrate_mismatch(peer: int, tickrate: int)

## Run the tickrate handshake.
## [br][br]
## This will connect to signals, so that every new peer receives tickrate info
## from the host.
## [br][br]
## Called by [_NetworkTime], no need to call manually.
func run() -> void:
	if multiplayer.is_server():
		# Broadcast tickrate
		_submit_tickrate.rpc(NetworkTime.tickrate)
		
		# Submit tickrate to anyone joining
		multiplayer.peer_connected.connect(_handle_new_peer)
	else:
		# Submit tickrate to host
		_submit_tickrate.rpc_id(1, NetworkTime.tickrate)

## Stop the tickrate handshake.
## [br][br]
## Called by [_NetworkTime], no need to call manually.
func stop() -> void:
	if multiplayer.peer_connected.is_connected(_handle_new_peer):
		multiplayer.peer_connected.disconnect(_handle_new_peer)

func _ready() -> void:
	name = "NetworkTickrateHandshake"

func _handle_new_peer(peer: int) -> void:
	if multiplayer.is_server():
		_submit_tickrate.rpc_id(peer, NetworkTime.tickrate)

func _handle_tickrate_mismatch(peer: int, tickrate: int) -> void:
	match mismatch_action:
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
				ProjectSettings.set_setting(&"netfox/time/tickrate", tickrate)
		SIGNAL:
			on_tickrate_mismatch.emit(peer, tickrate)

@rpc("any_peer", "reliable", "call_remote")
func _submit_tickrate(tickrate: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	_logger.debug("Received tickrate %d from peer %d", [tickrate, sender])

	if tickrate != NetworkTime.tickrate:
		_handle_tickrate_mismatch(sender, tickrate)
