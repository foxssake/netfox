extends GridContainer
class_name LobbiesContainer

signal on_join(lobby_id: String)

var _lobbies: Array[NohubLobby] = []

func set_lobbies(lobbies: Array[NohubLobby]) -> void:
	_lobbies.assign(lobbies)
	_render()

func clear() -> void:
	_lobbies.clear()
	_render()

func _render() -> void:
	# Clear container, retain header
	var children := get_children()
	for i in range(columns, get_child_count()):
		children[i].queue_free()

	# Render list
	for lobby in _lobbies:
		var name_label := Label.new()
		name_label.text = lobby.data.get("name", "???")

		var players_label := Label.new()
		players_label.text = "%s / %s" % [lobby.data.get("player-count", "?"), lobby.data.get("player-capacity", "?")]

		var join_button := Button.new()
		join_button.text = ">"
		join_button.tooltip_text = "Join this lobby"
		join_button.pressed.connect(func(): on_join.emit(lobby.id))

		add_child(name_label)
		add_child(players_label)
		add_child(join_button)
