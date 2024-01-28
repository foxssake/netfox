extends RefCounted
class_name NorayProtocolHandler
## This class parses incoming data from noray's protocol.
##
## Unless you're writing your own noray integration, [Noray] should cover most
## use cases.

## Emitted for every command parsed during a [method ingest] call.
signal on_command(command: String, data: String)

var _strbuf: String = ""

## Resets the parser.
func reset():
	_strbuf = ""

## Parse an incoming piece of data.
func ingest(data: String):
	_strbuf += data
	if not _strbuf.contains("\n"):
		return

	var idx = _strbuf.rfind("\n")
	var lines = _strbuf.substr(0, idx).split("\n", false)
	_strbuf = _strbuf.erase(0, idx + 1)

	for line in lines:
		if not line.contains(" "):
			on_command.emit(line, "")
		else:
			var parts = line.split(" ")
			var command = parts[0]
			var param = parts[1]
			on_command.emit(command, param)
