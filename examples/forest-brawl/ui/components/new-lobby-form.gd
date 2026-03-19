extends GridContainer
class_name NewLobbyForm

@onready var _name_input := $"Lobby Name Input" as LineEdit
@onready var _player_limit_input := $"Lobby Player Limit Input" as LineEdit

func get_lobby_name() -> String:
	return _name_input.text

func get_player_limit() -> int:
	return _player_limit_input.text.to_int()

func _ready():
	_player_limit_input.text_changed.connect(
		func(__): _sanitize_limit_text(),
		CONNECT_DEFERRED
	)

func _sanitize_limit_text() -> void:
	var input := _player_limit_input.text
	var sanitized := str(input.to_int())

	if input.is_empty():
		return

	if input != sanitized:
		_player_limit_input.text = sanitized
