extends BaseMenu

@onready var host_input := %"Host Input" as LineEdit
@onready var port_input := %"Port Input" as LineEdit

@onready var back_button := %"Back Button" as Button
@onready var connect_button := %"Connect Button" as Button
@onready var host_button := %"Host Button" as Button

func _ready():
	super()

	back_button.pressed.connect(_back)
	connect_button.pressed.connect(_connect)
	host_button.pressed.connect(_host)

func _connect():
	var host := host_input.text
	var port = _get_port()

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(host, port)
	if err != OK:
		push_error("Failed to start client: %s" % [error_string(err)])
		return

	multiplayer.multiplayer_peer = peer

	while peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING:
		peer.poll()
		await get_tree().process_frame

	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		push_error("Failed to connect!")
		return

	get_parent_control().hide() # Success

func _host():
	var port := _get_port()

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port)
	if err != OK:
		push_error("Failed to start server: %s" % [error_string(err)])
		return

	multiplayer.multiplayer_peer = peer
	get_parent_control().hide() # Success

func _get_port() -> int:
	if not port_input.text.is_valid_int():
		return 16384
	else:
		return int(port_input.text)
