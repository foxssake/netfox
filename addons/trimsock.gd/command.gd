extends RefCounted
class_name TrimsockCommand

class Chunk:
	var text: String
	var is_quoted: bool
	
	static func quoted(p_text: String) -> Chunk:
		var chunk := Chunk.new()
		chunk.is_quoted = true
		chunk.text = p_text
		return chunk

	static func unquoted(p_text: String) -> Chunk:
		var chunk := Chunk.new()
		chunk.is_quoted = false
		chunk.text = p_text
		return chunk
	
	static func of_text(p_text: String) -> Chunk:
		var chunk := Chunk.new()
		chunk.is_quoted = p_text.contains(" ")
		chunk.text = p_text
		return chunk

class Pair:
	var key: String
	var value: String

enum Type {
	SIMPLE,
	REQUEST,
	SUCCESS_RESPONSE,
	ERROR_RESPONSE,
	STREAM_CHUNK,
	STREAM_FINISH
}

# Core properties
var name: String = ""
var text: String = ""
var chunks: Array[Chunk] = []
var is_raw: bool = false
var raw: PackedByteArray

# Multiparam
var params: Array[String]

# Key-value pairs
var kv_pairs: Array[Pair]
var kv_map: Dictionary

# Request-response + Stream
var exchange_id: String
var type: Type = Type.SIMPLE

static func from_buffer(name: String, data: PackedByteArray) -> TrimsockCommand:
	var command := TrimsockCommand.new()
	command.is_raw = true
	command.raw = data
	return command

static func simple(name: String, text: String = "") -> TrimsockCommand:
	var command := TrimsockCommand.new()
	command.name = name
	if text:
		command.chunks.append(Chunk.of_text(text))
	
	return command

static func request(name: String, exchange_id: String = "") -> TrimsockCommand:
	var command := TrimsockCommand.new()
	command.name = name
	command.type = Type.REQUEST
	command.exchange_id = exchange_id
	return command

static func success_response(name: String, exchange_id: String = "") -> TrimsockCommand:
	var command := TrimsockCommand.new()
	command.name = name
	command.type = Type.SUCCESS_RESPONSE
	command.exchange_id = exchange_id
	return command

static func error_response(name: String, exchange_id: String = "") -> TrimsockCommand:
	var command := TrimsockCommand.new()
	command.name = name
	command.type = Type.ERROR_RESPONSE
	command.exchange_id = exchange_id
	return command

static func stream_chunk(name: String, exchange_id: String = "") -> TrimsockCommand:
	var command := TrimsockCommand.new()
	command.name = name
	command.type = Type.STREAM_CHUNK
	command.exchange_id = exchange_id
	return command

static func stream_finish(name: String, exchange_id: String = "") -> TrimsockCommand:
	var command := TrimsockCommand.new()
	command.name = name
	command.type = Type.STREAM_FINISH
	command.exchange_id = exchange_id
	return command

static func error_from(command: TrimsockCommand, name: String, data) -> TrimsockCommand:
	var result := TrimsockCommand.new()
	
	if not result.is_simple():
		result.name = ""
		result.type = Type.ERROR_RESPONSE
		result.exchange_id = command.exchange_id
	else:
		result.name = name
	
	if typeof(data) == TYPE_ARRAY:
		for param in data:
			result.params.append(str(param))
	else:
		result.chunks.append(Chunk.of_text(str(data)))
	
	return result

static func unescape(what: String) -> String:
	return (what
		.replace("\\n", "\n")
		.replace("\\r", "\r")
		.replace("\\\"", "\"")
	)

static func escape_quoted(what: String) -> String:
	return what.replace("\"", "\\\"")

static func escape_unquoted(what: String) -> String:
	return (what
		.replace("\n", "\\n")
		.replace("\r", "\\r")
		.replace("\"", "\\\"")
	)

static func pair_of(key: String, value: String) -> Pair:
	var pair := Pair.new()
	pair.key = key
	pair.value = value
	return pair

static func type_string(type: Type) -> String:
	match type:
		Type.SIMPLE: return "Simple"
		Type.REQUEST: return "Request"
		Type.SUCCESS_RESPONSE: return "Success Response"
		Type.ERROR_RESPONSE: return "Error Response"
		Type.STREAM_CHUNK: return "Stream Chunk"
		Type.STREAM_FINISH: return "Stream Finish"
	return "%d???" % [type]


func is_simple() -> bool:
	return type == Type.SIMPLE

func is_request() -> bool:
	return type == Type.REQUEST

func is_success() -> bool:
	return type == Type.SUCCESS_RESPONSE

func is_error() -> bool:
	return type == Type.ERROR_RESPONSE

func is_stream() -> bool:
	return is_stream_chunk() or is_stream_end()

func is_stream_chunk() -> bool:
	return type == Type.STREAM_CHUNK

func is_stream_end() -> bool:
	return type == Type.STREAM_FINISH

func is_empty() -> bool:
	if is_raw:
		return raw.is_empty()
	else:
		return text.is_empty() and chunks.is_empty() and params.is_empty() and kv_pairs.is_empty() and kv_map.is_empty()

func clear():
	raw.clear()
	chunks.clear()
	params.clear()
	kv_pairs.clear()
	kv_map.clear()
	text = ""

func with_name(p_name: String) -> TrimsockCommand:
	name = p_name
	return self

func with_text(p_text: String) -> TrimsockCommand:
	text = p_text
	return self

func with_chunks(p_chunks: Array[Chunk]) -> TrimsockCommand:
	chunks += p_chunks
	return self

func as_raw() -> TrimsockCommand:
	is_raw = true
	text = ""
	chunks = []
	return self

func with_data(data: PackedByteArray) -> TrimsockCommand:
	as_raw()
	raw = data
	return self

func with_params(p_params: Array[String]) -> TrimsockCommand:
	params += p_params
	return self

func with_kv_pairs(p_kv_pairs: Array[Pair]) -> TrimsockCommand:
	kv_pairs += p_kv_pairs
	for pair in kv_pairs:
		kv_map[pair.key] = pair.value
	return self

func with_kv_map(p_kv_map: Dictionary) -> TrimsockCommand:
	for key in p_kv_map:
		var value = p_kv_map[key]
		kv_pairs.append(pair_of(key, value))
	kv_map.merge(p_kv_map, true)
	return self

func with_exchange_id(p_exchange_id: String) -> TrimsockCommand:
	exchange_id = p_exchange_id
	return self

func as_request() -> TrimsockCommand:
	type = Type.REQUEST
	return self

func as_success_response() -> TrimsockCommand:
	type = Type.SUCCESS_RESPONSE
	return self

func as_error_response() -> TrimsockCommand:
	type = Type.ERROR_RESPONSE
	return self

func as_stream() -> TrimsockCommand:
	type = Type.STREAM_FINISH if is_empty() else Type.STREAM_CHUNK
	return self

func serialize() -> PackedByteArray:
	var out := PackedByteArray()
	serialize_to_array(out)
	return out

func serialize_to_array(out: PackedByteArray) -> void:
	var buffer := StreamPeerBuffer.new()
	serialize_to_stream(buffer)
	out.append_array(buffer.data_array)

func serialize_to_stream(out: StreamPeer) -> void:
	# Add raw marker
	if is_raw:
		out.put_8(_ord("\r"))

	# Add name
	if name:
		out.put_data(_escape_name(name).to_utf8_buffer())

	# Add separator if request / stream
	match type:
		Type.REQUEST: out.put_u8(_ord("?"))
		Type.SUCCESS_RESPONSE: out.put_u8(_ord("."))
		Type.ERROR_RESPONSE: out.put_u8(_ord("!"))
		Type.STREAM_CHUNK, Type.STREAM_FINISH:
			out.put_u8(_ord("|"))

	# Add ID
	if type != Type.SIMPLE:
		out.put_data(exchange_id.to_utf8_buffer())

	# Short-circuit on empty command
	if is_empty() and not is_raw:
		out.put_u8(_ord("\n"))
		return
	
	# Space after name
	out.put_u8(_ord(" "))

	# Short-circuit if raw
	if is_raw:
		out.put_data(str(raw.size()).to_ascii_buffer())
		out.put_u8(_ord("\n"))
		out.put_data(raw)
		out.put_u8(_ord("\n"))
		return

	# Print content
	if not chunks.is_empty():
		# Prefer chunks, if available
		for chunk in chunks:
			if chunk.is_quoted:
				out.put_data(_quoted_chunk(chunk.text).to_utf8_buffer())
			else:
				out.put_data(_unquoted_chunk(chunk.text).to_utf8_buffer())
	elif not kv_pairs.is_empty() or not kv_map.is_empty() or not params.is_empty():
		# Fall back to params if no chunks
		var tokens := PackedStringArray()
		
		# Print params first
		for param in params:
			tokens.append(_autoquoted_chunk(param))
		
		# Print kv-params, either from `kv_pairs`, or `kv_map`
		if not kv_pairs.is_empty():
			for pair in kv_pairs:
				tokens.append(_autoquoted_chunk(pair.key) + "=" + _autoquoted_chunk(pair.value))
		else:
			for key in kv_map:
				var value = kv_map[key]
				tokens.append(_autoquoted_chunk(key) + "=" + _autoquoted_chunk(value))

		# Push to buffer
		out.put_data(" ".join(tokens).to_utf8_buffer())
	else:
		# Use `text` as last resort
		out.put_data(_autoquoted_chunk(text).to_utf8_buffer())

	# Add closing NL
	out.put_u8(_ord("\n"))

func equals(what) -> bool:
	if not what is TrimsockCommand:
		return false

	var command := what as TrimsockCommand

	if not command.name == name or \
		not command.type == type:
			return false
	
	if not is_simple() and exchange_id != command.exchange_id:
		return false
	
	if not is_raw:
		return text == command.text
	else:
		return raw == command.raw

func _ord(chr: String) -> int:
	return chr.unicode_at(0)

func _escape_name(what: String) -> String:
	return _autoquoted_chunk(what)

func _quoted_chunk(what: String) -> String:
	return "\"%s\"" % [escape_quoted(what)]

func _unquoted_chunk(what: String) -> String:
	return escape_unquoted(what)

func _autoquoted_chunk(what: String) -> String:
	if what.contains(" "):
		return _quoted_chunk(what)
	else:
		return _unquoted_chunk(what)

func _to_string() -> String:
	if is_raw:
		return "(raw)" + serialize().get_string_from_utf8()
	return serialize().get_string_from_utf8()
