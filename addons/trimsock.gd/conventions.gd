extends Object
class_name _TrimsockConventions


static func apply(command: TrimsockCommand) -> void:
	parse_type(command)
	parse_params(command)

static func parse_type(command: TrimsockCommand) -> void:
	var at := 0

	# Figure out command type
	while true:
		at = command.name.find("?")
		if at >= 0:
			command.type = TrimsockCommand.Type.REQUEST
			break
		
		at = command.name.find(".")
		if at >= 0:
			command.type = TrimsockCommand.Type.SUCCESS_RESPONSE
			break
		
		at = command.name.find("!")
		if at >= 0:
			command.type = TrimsockCommand.Type.ERROR_RESPONSE
			break
		
		at = command.name.find("|")
		if at >= 0:
			if ((command.is_raw and command.raw.is_empty()) or (not command.is_raw and command.text.is_empty())):
				command.type = TrimsockCommand.Type.STREAM_FINISH
			else:
				command.type = TrimsockCommand.Type.STREAM_CHUNK
			break
		return

	# Extract data
	var name := command.name.substr(0, at)
	var id := command.name.substr(at + 1)

	command.name = name
	command.exchange_id = id

static func parse_params(command: TrimsockCommand) -> void:
	if command.is_raw or command.chunks.is_empty():
		return

	var chunks := [] as Array[String]
	for chunk in command.chunks:
		if chunk.is_quoted:
			# Quoted chunks go in verbatim
			chunks.append(chunk.text)
		else:
			# Unquoted chunks are separated by spaces, and then each separated
			# word is checked for equal signs
			for word in chunk.text.split(" ", false):
				var at := word.find("=")
				if at >= 0:
					chunks.append(word.substr(0, at))
					chunks.append("=")
					chunks.append(word.substr(at + 1))
				else:
					chunks.append(word)
	chunks = chunks.filter(func(it): return it)
	
	# Extract params and kv-pairs
	for i in range(chunks.size()):
		var chunk := chunks[i]
		var prev := chunks[i-1] if i > 0 else ""
		var next := chunks[i+1] if i < chunks.size() - 1 else ""
		
		if next == "=" or prev == "=":
			continue
		if chunk == "=" and prev and next:
			command.kv_pairs.append(TrimsockCommand.pair_of(prev, next))
		else:
			command.params.append(chunk)
	
	# Calculate kv-map
	if not command.kv_pairs.is_empty():
		for pair in command.kv_pairs:
			command.kv_map[pair.key] = pair.value

func _init():
	assert(false, "This class shouldn't be instantiated!")
