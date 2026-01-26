extends RefCounted
class_name TrimsockReader

var _line_reader: _TrimsockLineReader = _TrimsockLineReader.new()
var _line_parser: _TrimsockLineParser = _TrimsockLineParser.new()
var _queued_raw: TrimsockCommand = null

func ingest_text(text: String) -> Error:
	return _line_reader.ingest(text.to_utf8_buffer())

func ingest_bytes(bytes: PackedByteArray) -> Error:
	return _line_reader.ingest(bytes)

func read() -> TrimsockCommand:
	var command := _pop()
	if command:
		_TrimsockConventions.apply(command)
	return command

func _pop() -> TrimsockCommand:
	# We read a raw command earlier, waiting to have enough data
	if _queued_raw:
		var data_size := int(_queued_raw.text)
		if not _line_reader.has_data(data_size):
			return null
		
		_queued_raw.raw = _line_reader.read_data(data_size)
		_queued_raw.text = ""
		_queued_raw.chunks.clear()
		
		var result := _queued_raw
		_queued_raw = null
		return result

	# No queued command, try to read a new one
	var line := _line_reader.read_text()
	if not line:
		return null
	
	var command := _line_parser.parse(line)
	if command.is_raw:
		# Command is raw, we'll keep it in the queue until we read the binary
		# data for it
		_queued_raw = command
		
		# Try getting it immediately, in case we already have the data in buffer
		return _pop()

	return command
