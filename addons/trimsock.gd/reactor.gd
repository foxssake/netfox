extends RefCounted
class_name TrimsockReactor

var _sources: Array = []
var _sessions: Dictionary = {} # source to session data
var _readers: Dictionary = {} # source to reader
var _handlers: Dictionary = {} # command name to handler method
var _exchanges: Array[TrimsockExchange] = []
var _unknown_handler: Callable = func(_cmd, _xchg): pass # TODO(trimsock): Add _xchg param
var _id_generator: TrimsockIDGenerator = RandomTrimsockIDGenerator.new(12)


signal on_attach(source: Variant)
signal on_detach(source: Variant)


func poll() -> void:
	_poll()

	for source in _sources:
		var reader := _readers[source] as TrimsockReader
		while true:
			var command := reader.read()
			if not command:
				break

			_handle(command, source)

func send(target: Variant, command: TrimsockCommand) -> TrimsockExchange:
	# Send command
	_write(target, command)

	# Ensure exchange
	var xchg := _get_exchange_for(command, target)
	if xchg == null:
		xchg = _make_exchange_for(command, target)

	return xchg

func request(target: Variant, command: TrimsockCommand) ->  TrimsockExchange:
	command.as_request()
	if not command.exchange_id:
		command.exchange_id = _id_generator.get_id()
	return send(target, command)

func stream(target: Variant, command: TrimsockCommand) ->  TrimsockExchange:
	command.as_stream()
	if not command.exchange_id:
		command.exchange_id = _id_generator.get_id()
	return send(target, command)

func attach(source: Variant) -> void:
	if _sources.has(source):
		return

	_sources.append(source)
	_readers[source] = TrimsockReader.new()
	on_attach.emit(source)

func detach(source: Variant) -> void:
	if not _sources.has(source):
		return

	_sources.erase(source)
	_sessions.erase(source)
	_readers.erase(source)
	on_detach.emit(source)

func set_session(source: Variant, data: Variant) -> void:
	_sessions[source] = data

func get_session(source: Variant) -> Variant:
	return _sessions.get(source)

func set_id_generator(id_generator: TrimsockIDGenerator) -> void:
	_id_generator = id_generator

func on(command_name: String, handler: Callable) -> TrimsockReactor:
	_handlers[command_name] = handler
	return self

func on_unknown(handler: Callable) -> TrimsockReactor:
	_unknown_handler = handler
	return self


# Grab incoming data, call `_ingest()`
func _poll() -> void:
	pass

# Send command to target
func _write(target: Variant, command: TrimsockCommand) -> void:
	pass

func _ingest(source: Variant, data: PackedByteArray) -> Error:
	assert(_readers.has(source), "Ingesting data from unknown source! Did you call `attach()`?")
	var reader := _readers[source] as TrimsockReader
	return reader.ingest_bytes(data)

func _handle(command: TrimsockCommand, source: Variant) -> void:
	var xchg := _get_exchange_for(command, source)
	if xchg != null:
		# Known exchange, handle it there
		xchg.push(command)
	else:
		# New exchange, create instance and pass to handler
		xchg = _make_exchange_for(command, source)
		var handler := (_handlers.get(command.name) if _handlers.has(command.name) else _unknown_handler) as Callable

		var result := await handler.call(command, xchg)
		if xchg.is_open() and result is TrimsockCommand:
			xchg.send_and_close(result)

		# Free exchange if needed
		if not xchg.is_open():
			_exchanges.erase(xchg)

func _get_exchange_for(command: TrimsockCommand, source: Variant) -> TrimsockExchange:
	if not command.is_simple():
		# Try and find known exchange
		for xchg in _exchanges:
			if xchg.id() == command.exchange_id and xchg._source == source:
				return xchg

	# Command has no ID, or ID not found
	return null

func _make_exchange_for(command: TrimsockCommand, source: Variant) -> TrimsockExchange:
	var xchg := TrimsockExchange.new(command, source, self)
	if not command.is_simple():
		_exchanges.append(xchg)
	return xchg
