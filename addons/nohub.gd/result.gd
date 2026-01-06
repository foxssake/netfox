extends RefCounted
class_name NohubResult

class ErrorData:
	var name: String
	var message: String

	func _init(p_name: String, p_message: String):
		name = p_name
		message = p_message

	func _to_string() -> String:
		return "%s: %s" % [name, message]

class Lobby extends NohubResult:
	static func of_value(value: NohubLobby) -> Lobby:
		var result := Lobby.new()
		result._is_success = true
		result._value = value
		return result

	func value() -> NohubLobby:
		if _is_success:
			return _value as NohubLobby
		else:
			return null

class LobbyList extends NohubResult:
	static func of_value(value: Array[NohubLobby]) -> LobbyList:
		var result := LobbyList.new()
		result._is_success = true
		result._value = value
		return result

	func value() -> Array[NohubLobby]:
		if _is_success:
			return _value as Array[NohubLobby]
		else:
			return []

class Address extends NohubResult:
	static func of_value(value: String) -> Address:
		var result := Address.new()
		result._is_success = true
		result._value = value
		return result

	func value() -> String:
		if _is_success:
			return _value as String
		else:
			return ""

var _is_success: bool
var _value: Variant
var _error: ErrorData


static func of_error(error: String, message: String) -> NohubResult:
	var result := NohubResult.new()
	result._is_success = false
	result._error = ErrorData.new(error, message)
	return result

static func of_success() -> NohubResult:
	var result := NohubResult.new()
	result._is_success = true
	return result


func is_success() -> bool:
	return _is_success

func error() -> ErrorData:
	if _is_success:
		return null
	else:
		return _error

func _to_string() -> String:
	if _is_success:
		return str(_value)
	else:
		return str(_error)
