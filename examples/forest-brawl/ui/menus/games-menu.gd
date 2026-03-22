extends BaseMenu

@onready var presets_option := %"Presets Option" as OptionButton
@onready var noray_input := %"noray Input" as LineEdit
@onready var nohub_input := %"nohub Input" as LineEdit
@onready var connect_button := %"Connect Button" as Button
@onready var status_label := %"Status Label" as Label
@onready var dock_button := %"Dock Button" as Button

@onready var lobbies_container := %"Lobbies Container" as LobbiesContainer
@onready var new_lobby_form := %"New Lobby Form" as NewLobbyForm
@onready var back_button := %"Back Button" as Button
@onready var host_button := %"Host Button" as Button

@onready var dock_container := $MarginContainer/HBoxContainer/PanelContainer/HBoxContainer/MarginContainer as Control
@onready var dock_panel := $MarginContainer/HBoxContainer/PanelContainer as Control

var _poll_interval := 2.
var _poll_wait := 0.

var _is_hosting := false

var _logger := NetfoxLogger.new("forest-brawl", "GamesMenu")

func is_active() -> bool:
	return is_visible_in_tree()

func _ready() -> void:
	super()

	presets_option.item_selected.connect(_select_preset)
	connect_button.pressed.connect(_connect)
	dock_button.pressed.connect(_dock)
	back_button.pressed.connect(_back)
	host_button.pressed.connect(_host)

	lobbies_container.on_join.connect(func(lobby_id: String):
		_join(lobby_id)
	)

	# Populate presets
	presets_option.clear()
	for hosts in ForestBrawlConnector.known_service_hosts:
		presets_option.add_item(hosts.name)
	presets_option.select(0)
	_select_preset(0)

func _process(dt: float) -> void:
	if not is_active():
		return

	# Poll lobbies
	_poll_wait -= dt
	if _poll_wait < 0.0 and ForestBrawlConnector.is_connected_to_services():
		_logger.debug("Listing lobbies...")
		_poll_wait = _poll_interval
		var response := await ForestBrawlConnector.nohub().list_lobbies()
		if not response.is_success():
			_logger.warn("Failed listing lobbies: %s" % [response])
		else:
			_logger.debug("Found lobbies: %s" % [response.value()])
			lobbies_container.set_lobbies(response.value())

func _execute() -> void:
	_connect()

func _cancel() -> void:
	_disconnect()
	lobbies_container.clear()

func _select_preset(idx: int) -> void:
	var preset := ForestBrawlConnector.known_service_hosts[idx]
	noray_input.text = preset.noray_address
	nohub_input.text = preset.nohub_address

func _connect() -> void:
	_disconnect()

	status_label.text = "Status: Connecting..."
	var err := await ForestBrawlConnector.connect_to_services(noray_input.text, nohub_input.text)
	if err != OK:
		_logger.error("Failed to connect to services: " + error_string(err))
		_disconnect()
	else:
		status_label.text = "Status: Online"

func _disconnect() -> void:
	if not _is_hosting:
		ForestBrawlConnector.disconnect_from_services()
	status_label.text = "Status: Offline"
	_is_hosting = false

func _dock() -> void:
	if dock_container.visible:
		dock_container.hide()
		dock_button.text = ">"
	else:
		dock_container.show()
		dock_button.text = "<"
	dock_panel.size_flags_horizontal ^= Control.SIZE_EXPAND

func _host() -> void:
	if not ForestBrawlConnector.is_connected_to_services():
		return

	var lobby_name := new_lobby_form.get_lobby_name()
	var lobby_limit := new_lobby_form.get_player_limit()

	var noray_address := ForestBrawlConnector.noray_address()

	if not lobby_name:
		_logger.warn("Lobby name can't be empty!")
		return
	if lobby_limit <= 0:
		_logger.warn("Invalid player limit!")
		return

	var player_limit := int(lobby_limit)
	var address := "noray://%s/%s" % [noray_address, Noray.oid]

	var response := await ForestBrawlConnector.host_lobby(lobby_name, address, player_limit)
	if not response.is_success():
		_logger.warn("Failed to create lobby! %s", [response])
		return
	else:
		_logger.info("Created lobby! %s", [response.value()])
		_poll_wait = -1.

	var err := await ForestBrawlConnector.host_noray()
	if err != OK:
		_logger.warn("Failed to host game: " + error_string(err))
		return

	# Success!
	_is_hosting = true

func _join(lobby_id: String) -> void:
	if not ForestBrawlConnector.is_connected_to_services():
		return

	_logger.debug("Attempting to join lobby #%s", [lobby_id])
	var response := await ForestBrawlConnector.nohub().join_lobby(lobby_id)
	if not response.is_success():
		_logger.warn("Failed to join lobby %s: %s", [lobby_id, response])
		return

	var address := response.value()
	_logger.debug("Received address: %s", [address])
	ForestBrawlConnector.join(address)
