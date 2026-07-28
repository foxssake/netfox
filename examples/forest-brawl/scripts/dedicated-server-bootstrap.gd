extends Node

const DEFAULT_PORT := 7777

static var _logger := NetfoxLogger.new("forest-brawl", "DedicatedServerBootstrap")

@onready var _brawler_spawner: BrawlerSpawner = %"Brawler Spawner"

func _ready() -> void:
	if not _should_auto_host():
		return

	var port := _get_port_from_args(DEFAULT_PORT)
	_logger.info("Auto-hosting dedicated server on port %d", [port])

	if _brawler_spawner:
		_brawler_spawner.spawn_host_avatar = false

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port)
	if err != OK:
		_logger.error("Failed to start dedicated server: %s", [error_string(err)])
		get_tree().quit(1)
		return

	multiplayer.multiplayer_peer = peer

func _should_auto_host() -> bool:
	if OS.has_feature("dedicated_server"):
		return true
	if "--server" in OS.get_cmdline_user_args():
		return true
	return false

func _get_port_from_args(default_port: int) -> int:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--port" and i + 1 < args.size() and args[i + 1].is_valid_int():
			return int(args[i + 1])
	return default_port
