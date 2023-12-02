@tool
extends EditorPlugin

const ROOT = "res://addons/netfox.noray"

var SETTINGS = [
	_NetfoxLogger.make_setting("netfox/logging/netfox_noray_log_level")
]

const AUTOLOADS = [
	{
		"name": "Noray",
		"path": ROOT + "/noray.gd"
	},
	{
		"name": "PacketHandshake",
		"path": ROOT + "/packet-handshake.gd"
	}
]

func _enter_tree():
	for setting in SETTINGS:
		add_setting(setting)

	for autoload in AUTOLOADS:
		add_autoload_singleton(autoload.name, autoload.path)

func _exit_tree():
	if ProjectSettings.get_setting("netfox/general/clear_settings", false):
		for setting in SETTINGS:
			remove_setting(setting)

	for autoload in AUTOLOADS:
		remove_autoload_singleton(autoload.name)

func add_setting(setting: Dictionary):
	if ProjectSettings.has_setting(setting.name):
		return

	ProjectSettings.set_setting(setting.name, setting.value)
	ProjectSettings.set_initial_value(setting.name, setting.value)
	ProjectSettings.add_property_info({
		"name": setting.get("name"),
		"type": setting.get("type"),
		"hint": setting.get("hint", PROPERTY_HINT_NONE),
		"hint_string": setting.get("hint_string", "")
	})

func remove_setting(setting: Dictionary):
	if not ProjectSettings.has_setting(setting.name):
		return
	
	ProjectSettings.clear(setting.name)
