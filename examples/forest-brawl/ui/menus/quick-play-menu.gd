extends BaseMenu

@onready var status_label := %Status as Label
@onready var back_button := %"Back Button" as Button
@onready var host_button := %"Host Button" as Button

func is_active() -> bool:
	return is_visible_in_tree()

func _ready() -> void:
	super()

	back_button.pressed.connect(_back)
	host_button.pressed.connect(_host)

func _execute() -> void:
	status_label.text = "Connecting to services..."
	var err := await ForestBrawlConnector.connect_to_any_service_host()
	if err != OK:
		status_label.text = "Connection failed: %s" % [error_string(err)]
		return

	status_label.text = "Looking for games..."
	var expanded_search := false
	var search_time := 0.0
	var lobby: NohubLobby

	while is_active():
		await get_tree().create_timer(1.0).timeout
		search_time += 1.0

		var response := await ForestBrawlConnector.nohub().list_lobbies()
		if not response.is_success():
			status_label.text = "nohub error: %s" % [response.error().message]

		# Only consider quick-play lobbies
		var lobbies := response.value()\
			.filter(func (it: NohubLobby):
				return it.data.get("quick-play", "") == "enabled" or expanded_search
				)

		if not lobbies.is_empty():
			# TODO: More advanced strategies?
			lobby = lobbies.pick_random()
			break

		if search_time > 5.0 and not expanded_search:
			status_label.text = "Expanding search..."
			expanded_search = true

	if not is_active():
		return

	status_label.text = "Joining..."
	var response := await ForestBrawlConnector.nohub().join_lobby(lobby.id)
	if not response.is_success():
		status_label.text = "nohub error: %s" % [response.error().message]
		return

	var address := response.value()
	print("Joining address: %s" % [address])
	err = ForestBrawlConnector.join(address)
	if err != OK:
		status_label.text = "Couldn't join %s: %s" % [address, error_string(err)]

func _host() -> void:
	status_label.text = "Creating lobby..."

	# Create lobby
	var lobby_name := "Quick Play #%x" % [randi_range(0x10000000, 0xFFFFFFFF)]
	var player_capacity := 8
	var address := "noray://%s/%s" % [ForestBrawlConnector.noray_address(), Noray.oid]

	var response := await ForestBrawlConnector.host_quick_play(address, player_capacity)
	if not response.is_success():
		status_label.text = "Lobby fail: %s" % [response.error().message]

	# Start game
	status_label.text = "Starting..."
	var err := await ForestBrawlConnector.host_noray()
	if err != OK:
		status_label.text = "Fail: %s" % [error_string(err)]
