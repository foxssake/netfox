extends RefCounted
class_name _TrimsockLineParser

var line := ""
var at := 0

func parse(p_line: String) -> TrimsockCommand:
	rewind(p_line)
	var command := TrimsockCommand.new()
	
	# Empty command
	if is_eol():
		return command

	# Check for raw message
	command.is_raw = chr() == "\r"
	if command.is_raw: at += 1
	
	# Read command name
	command.name = read_name()
	at += 1 # Skip over space after name
	
	# Read chunks until available
	while not is_eol():
		command.chunks.append(read_chunk())
	
	# Calculate text
	command.text = ""
	for chunk in command.chunks:
		command.text += chunk.text
	
	unescape(command)
	
	return command

func read_name() -> String:
	if chr() == "\"":
		return read_quoted()
	else:
		return read_identifier()

func read_chunk() -> TrimsockCommand.Chunk:
	var chunk := TrimsockCommand.Chunk.new()
	if chr() == "\"":
		chunk.is_quoted = true
		chunk.text = read_quoted()
	else:
		chunk.is_quoted = false
		chunk.text = read_unquoted()
	return chunk

func read_identifier() -> String:
	var from := at
	
	while not is_eol() and chr() != " ":
		at += 1

	return line.substr(from, at - from)

func read_unquoted() -> String:
	var from := at
	
	while not is_eol():
		if chr() == "\\":
			at += 1
		elif chr() == "\n" or chr() == "\"":
			break
		at += 1
	
	return line.substr(from, at - from)

func read_quoted() -> String:
	var from := at
	
	# Skip opening quote
	at += 1
	
	# Iterate until end
	while true:
		if chr() == "\\":
			# Skip escape
			at += 1
		elif chr() == "\"":
			# Found closing quote, stop
			break
		elif is_eol():
			# String ended unexpectedly
			push_warning("Command line ended unexpectedly while reading quoted data: " + line)
			break
		at += 1
	
	# Step over closing quotes
	at += 1
	
	# Return string between quotes
	return line.substr(from + 1, (at - 1) - (from + 1))

func unescape(command: TrimsockCommand) -> void:
	command.name = TrimsockCommand.unescape(command.name)
	for chunk in command.chunks:
		chunk.text = TrimsockCommand.unescape(chunk.text)
	command.text = TrimsockCommand.unescape(command.text)

func chr() -> String:
	return line[at]

func is_eol() -> bool:
	return at >= line.length()

func rewind(p_line: String) -> void:
	line = p_line
	at = 0
