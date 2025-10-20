extends TrimsockReactor
class_name TrimsockTCPServerReactor

var _server: TCPServer

func _init(server: TCPServer):
	_server = server

func _poll() -> void:
	# Handle incoming connections
	while _server.is_connection_available():
		attach(_server.take_connection())

	# Poll each connection
	for source in _sources:
		var stream := source as StreamPeerTCP

		# Update status
		stream.poll()

		# Detach closed connections
		# Don't process any further data from them if we can't reply
		var status := stream.get_status()
		if status == StreamPeerTCP.STATUS_NONE or status == StreamPeerTCP.STATUS_ERROR:
			detach(stream)
			continue

		# Grab available data
		var available := stream.get_available_bytes()
		var res := stream.get_partial_data(available)
		if res[0] == OK:
			_ingest(stream, res[1])

func _write(target: Variant, command: TrimsockCommand) -> void:
	assert(target is StreamPeerTCP, "Invalid target!")
	var peer := target as StreamPeerTCP
	command.serialize_to_stream(peer)
