extends RefCounted
class_name ForestBrawlSettings

const DEFAULT_PATH = "user://settings.json"

var player_name: String = NameProvider.name()
var randomize_name: bool = false
var force_relay: bool = false
var full_screen: bool = false
var vsync: bool = true
var confine_mouse: bool = false
var master_volume: float = 1.

static var _active: ForestBrawlSettings

func to_dictionary() -> Dictionary:
	return {
		"player_name": player_name,
		"randomize_name": randomize_name,
		"force_relay": force_relay,
		"full_screen": full_screen,
		"vsync": vsync,
		"confine_mouse": confine_mouse,
		"master_volume": master_volume
	}

func serialize() -> String:
	return JSON.stringify(to_dictionary(), "  ")

func save(path: String = DEFAULT_PATH) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(serialize())
	file.close()

static func from_dictionary(data: Dictionary) -> ForestBrawlSettings:
	var result := ForestBrawlSettings.new()
	
	result.player_name = data.get("player_name", result.player_name)
	result.randomize_name = data.get("randomize_name", result.randomize_name)
	result.force_relay = data.get("force_relay", result.force_relay)
	result.full_screen = data.get("full_screen", result.full_screen)
	result.vsync = data.get("vsync", result.vsync)
	result.confine_mouse = data.get("confine_mouse", result.confine_mouse)
	result.master_volume = data.get("master_volume", result.master_volume)
	
	return result

static func load(path: String = DEFAULT_PATH) -> ForestBrawlSettings:
	if not FileAccess.file_exists(path):
		return ForestBrawlSettings.new()

	var text := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(text)
	
	if typeof(data) == TYPE_DICTIONARY:
		return ForestBrawlSettings.from_dictionary(data as Dictionary)
	else:
		return ForestBrawlSettings.new()

static func set_active(settings: ForestBrawlSettings) -> void:
	_active = settings

static func get_active() -> ForestBrawlSettings:
	if not _active:
		_active = ForestBrawlSettings.load()
	return _active
