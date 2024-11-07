@tool
extends EditorPlugin

const ROOT = "res://addons/netfox.extras"

var SETTINGS = [
	_NetfoxLogger.make_setting("netfox/logging/netfox_extras_log_level"),
	#Window Tiler Settings
	{
		"name": "netfox/extras/auto_tile_windows",
		"value": true,
		"type": TYPE_BOOL
	},
	{
		"name": "netfox/extras/screen",
		"value": 0,
		"type": TYPE_INT
	},
	{
		"name": "netfox/extras/borderless",
		"value": true,
		"type": TYPE_BOOL
	},
]

const AUTOLOADS = [
	{
		"name": "WindowTiler",
		"path": ROOT + "/window-tiler.gd"
	}
]

class WindowTilerEditorDebugger extends EditorDebuggerPlugin:

	func _has_capture(prefix):
		return prefix == "tile-session"

	func _capture(message, data, session_id):

		if message == "tile-session:get_id":
			get_session(session_id).send_message("tile-session:session_id", [{"id": session_id, "total": get_sessions().size()}])
			return true


var window_tiler = WindowTilerEditorDebugger.new()

func _enter_tree():
	for setting in SETTINGS:
		add_setting(setting)

	for autoload in AUTOLOADS:
		add_autoload_singleton(autoload.name, autoload.path)

	add_debugger_plugin(window_tiler)

func _exit_tree():
	if ProjectSettings.get_setting("netfox/general/clear_settings", false):
		for setting in SETTINGS:
			remove_setting(setting)

	for autoload in AUTOLOADS:
		remove_autoload_singleton(autoload.name)

	remove_debugger_plugin(window_tiler)

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
