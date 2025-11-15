extends TrimsockReactor
class_name TrimsockTCPClientReactor

var _connection: StreamPeerTCP


func _init(connection: StreamPeerTCP):
	_connection = connection
	attach(_connection)

func submit(command: TrimsockCommand) -> TrimsockExchange:
	return send(_connection, command)

func submit_request(command: TrimsockCommand) -> TrimsockExchange:
	return request(_connection, command)

func submit_stream(command: TrimsockCommand) -> TrimsockExchange:
	return stream(_connection, command)

func _poll() -> void:
	_connection.poll()

	if _connection.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		# Can't read
		return

	# Grab available data
	var available := _connection.get_available_bytes()
	var res := _connection.get_partial_data(available)
	if res[0] == OK:
		_ingest(_connection, res[1])

func _write(target: Variant, command: TrimsockCommand) -> void:
	assert(target is StreamPeerTCP, "Invalid target!")
	var peer := target as StreamPeerTCP
	command.serialize_to_stream(peer)
