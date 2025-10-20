extends RefCounted
class_name TrimsockExchange

var _source: Variant
var _reactor: TrimsockReactor
var _command: TrimsockCommand

var _is_open: bool = true
var _queue: Array[TrimsockCommand] = []


signal _on_command(command: TrimsockCommand)


func _init(command: TrimsockCommand, source: Variant, reactor: TrimsockReactor):
	_command = command
	_source = source
	_reactor = reactor

#region Properties
func source() -> Variant:
	return _source

func id() -> String:
	return _command.exchange_id

func session() -> Variant:
	return _reactor.get_session(_source)

func set_session(data: Variant) -> void:
	_reactor.set_session(_source, data)

func is_open() -> bool:
	return _is_open

func can_reply() -> bool:
	return _command.type != TrimsockCommand.Type.SIMPLE

func close() -> void:
	_is_open = false
#endregion

#region Write
func send(command: TrimsockCommand) -> bool:
	if not is_open():
		return false

	_reactor._write(_source, command)
	return true

func send_and_close(command: TrimsockCommand) -> bool:
	if not send(command):
		return false

	close()
	return true

func reply(command: TrimsockCommand) -> bool:
	if not can_reply() or not is_open():
		return false

	command.as_success_response()
	command.name = ""
	command.exchange_id = id()

	send(command)
	close()
	return true

func fail(command: TrimsockCommand) -> bool:
	if not can_reply() or not is_open():
		return false

	command.as_error_response()
	command.name = ""
	command.exchange_id = id()

	send(command)
	close()
	return true

func stream(command: TrimsockCommand) -> bool:
	if not can_reply() or not is_open():
		return false

	command.as_stream()
	command.name = ""
	command.exchange_id = id()

	send(command)
	return true

func stream_finish(command: TrimsockCommand) -> bool:
	if not can_reply() or not is_open():
		return false

	command.clear()
	command.as_stream()
	command.name = ""
	command.exchange_id = id()

	send(command)
	close()
	return true

func reply_or_send(command: TrimsockCommand) -> bool:
	if not is_open():
		return false

	if not reply(command):
		send_and_close(command)

	return true

func fail_or_send(command: TrimsockCommand) -> bool:
	if not is_open():
		return false

	if not fail(command):
		send_and_close(command)

	return true
#endregion

#region Read
func push(command: TrimsockCommand) -> void:
	match command.type:
		TrimsockCommand.Type.SUCCESS_RESPONSE,\
		TrimsockCommand.Type.ERROR_RESPONSE,\
		TrimsockCommand.Type.STREAM_FINISH:
			close()

	_queue.append(command)
	_on_command.emit(command)

func read() -> TrimsockCommand:
	while _queue.is_empty():
		await _on_command
	return _queue.pop_front()
#endregion
