extends Object
class_name NetfoxTraces

class Frame:
	var source: String
	var name: String
	var data: Dictionary

class Event:
	var source: String
	var name: String
	var data: Variant

class Tracer:
	var name: String
	var _frame: Frame = null

	func _init(p_name: String):
		name = p_name

	func enter(p_name: String, p_initial_data: Dictionary = {}) -> void:
		var frame := Frame.new()
		frame.source = name
		frame.name = p_name
		frame.data = p_initial_data
		_frame = frame

		NetfoxTraces._enter(frame)

	func set_data(key: Variant, value: Variant) -> void:
		if _frame == null: return
		_frame.data[key] = value

	func exit() -> void:
		NetfoxTraces._exit(_frame)

	func emit(p_name: String, p_data: Variant = null) -> void:
		var event := Event.new()
		event.source = name
		event.name = p_name
		event.data = p_data
		NetfoxTraces._emit(event)

class NoopTracer extends Tracer:
	func enter(p_name: String, p_initial_data: Dictionary = {}) -> void:
		pass

	func set_data(key: Variant, value: Variant) -> void:
		pass

	func exit() -> void:
		pass

	func emit(p_name: String, p_data: Variant = null) -> void:
		pass

class FrameHandler:
	func _on_enter(frame: Frame) -> void:
		pass

	func _on_emit(event: Event) -> void:
		pass

	func _on_exit(frame: Frame) -> void:
		pass

	func _close() -> void:
		pass

class XMLFrameHandler extends FrameHandler:
	static func use(out_path: String) -> Error:
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		if file == null:
			return FileAccess.get_open_error()

		NetfoxTraces._register(XMLFrameHandler.new(file))
		return OK

	var _file: FileAccess
	var _depth := 0

	func _init(file: FileAccess):
		_file = file

		# Store header
		_file.store_string("<traces>")

	func _on_enter(frame: Frame) -> void:
		_file.store_string("<frame source=\"%s\" name=\"%s\">" % [
			frame.source.xml_escape(true),
			frame.name.xml_escape(true)
		])
		_depth += 1

	func _on_emit(event: Event) -> void:
		_file.store_string("<event source=\"%s\" name=\"%s\"><data>%s</data></event>" % [
			event.source.xml_escape(true),
			event.name.xml_escape(true),
			JSON.stringify(event.data, "  ", false).xml_escape()
		])

	func _on_exit(frame: Frame) -> void:
		if (frame.data != {}):
			_file.store_string("<data>%s</data>" % [JSON.stringify(frame.data, "  ", false).xml_escape()])
		_file.store_string("</frame>")
		_depth -= 1

	func _close() -> void:
		assert(_depth == 0, "Not all frames closed!")
		# Store footer
		_file.store_string("</traces>")

		_file.close()
		_file = null

static var enabled := true

static var _handlers := [] as Array[FrameHandler]

static func _register(handler: FrameHandler) -> void:
	if not _handlers.has(handler):
		_handlers.append(handler)

static func _enter(frame: Frame) -> void:
	for handler in _handlers:
		handler._on_enter(frame)

static func _emit(event: Event) -> void:
	for handler in _handlers:
		handler._on_emit(event)

static func _exit(frame: Frame) -> void:
	for handler in _handlers:
		handler._on_exit(frame)

static func open() -> void:
	if not enabled: return

	var logger := NetfoxLogger.new("nfxi", "NetfoxTraces")
	var id := "%x%x" % [int(Time.get_unix_time_from_system() * 1000), randi()]
	var filename := "traces.%s.xml" % [id]

	logger.debug("Setting up traces output: %s", [filename])
	var result := XMLFrameHandler.use(filename)
	logger.debug("Setup result: %s", [error_string(result)])

static func close() -> void:
	if _handlers.is_empty(): return

	var logger := NetfoxLogger.new("nfxi", "NetfoxTraces")
	logger.debug("Closing all trace handlers")

	for handler in _handlers:
		handler._close()

static func tracer(name: String) -> Tracer:
	if enabled:
		return Tracer.new(name)
	else:
		return NoopTracer.new(name)
