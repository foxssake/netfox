extends Node
## This class implements a handshake protocol over UDP for multiple classes.

class HandshakeStatus:
	var did_read: bool = false
	var did_write: bool = false
	var did_handshake: bool = false
	
	func _to_string():
		return "$" + \
			("r" if did_read else "-") + \
			("w" if did_write else "-") + \
			("x" if did_handshake else "-")
	
	static func from_string(str: String) -> HandshakeStatus:
		var result = HandshakeStatus.new()
		result.did_read = str.contains("r")
		result.did_write = str.contains("w")
		result.did_handshake = str.contains("x")
		return result

## Conduct handshake over a [PacketPeer] instance.
func over_packet_peer(peer: PacketPeer, timeout: float = 8.0, frequency: float = 0.1) -> Error:
	var result = ERR_TIMEOUT
	var status = HandshakeStatus.new()
	status.did_write = true

	while timeout >= 0:
		# Process incoming packets
		while peer.get_available_packet_count() > 0:
			var packet = peer.get_packet()
			var incoming_status = HandshakeStatus.from_string(packet.get_string_from_ascii())
			
			# We did get a packet, so that means we read them
			status.did_read = true
			
			# They already read us, so that's a handshake
			if incoming_status.did_read:
				status.did_handshake = true
			
			# Both peers ack'd the handshake, we've succeeded
			if incoming_status.did_handshake and status.did_handshake:
				result = OK
				timeout = 0 # Break outer loop
		
		# Send our state
		peer.put_packet(status.to_string().to_ascii_buffer())
		
		await get_tree().create_timer(frequency).timeout
		timeout -= frequency
	
	# If we've read them and we know we've sent data to them successfully,
	# we're *probably* good to connect, even if the handshake did not actually
	# go through.
	# Depending on the context, the calling code may decide to connect anyway,
	# based on this return value. 
	if status.did_read and status.did_write and not status.did_handshake:
		result = ERR_BUSY
	
	return result

## Conduct handshake over an [ENetConnection].
##
## [i]Note[/i] that this is not a full-fledged handshake, since we can't receive
## data over the connection. Instead, we just pretend that the handshake is 
## successful on our end and blast that status for a given time.
func over_enet(connection: ENetConnection, address: String, port: int, timeout: float = 8.0, frequency: float = 0.1) -> Error:
	var result = OK
	var status = HandshakeStatus.new()

	# Pretend this is a perfectly healthy handshake, since we can't receive data here
	status.did_write = true
	status.did_read = true
	status.did_handshake = true
	
	while timeout >= 0:
		# Send our state
		connection.socket_send(address, port, status.to_string().to_ascii_buffer())
		
		await get_tree().create_timer(frequency).timeout
		timeout -= frequency
	
	return result
