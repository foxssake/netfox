@tool
extends EditorPlugin

const ROOT = "res://addons/netfox.extras"

var SETTINGS = [
	_NetfoxLogger.make_setting("netfox/logging/netfox_extras_log_level"),
	
	#Window Tiler Settings
	{
		"name": "netfox/extras/auto_tile_windows",
		"value": false,
		"type": TYPE_BOOL
	},
	{
		"name": "netfox/extras/screen",
		"value": 0,
		"type": TYPE_INT
	},
	{
		"name": "netfox/extras/borderless",
		"value": false,
		"type": TYPE_BOOL
	},
]

const AUTOLOADS = [
	{
		"name": "WindowTiler",
		"path": ROOT + "/window-tiler.gd"
	}
]

const PhysicsDriverToggles := preload("res://addons/netfox.extras/physics/physics-driver-toggles.gd")

var _tool_menu_items := [] as Array[String]

func _enter_tree():
	for setting in SETTINGS:
		add_setting(setting)

	for autoload in AUTOLOADS:
		add_autoload_singleton(autoload.name, autoload.path)

	_render_tool_menu()

func _exit_tree():
	if ProjectSettings.get_setting("netfox/general/clear_settings", false):
		for setting in SETTINGS:
			remove_setting(setting)

	for autoload in AUTOLOADS:
		remove_autoload_singleton(autoload.name)

	_free_tool_menu()

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

func _render_tool_menu():
	_free_tool_menu()
	for driver_toggle in PhysicsDriverToggles.all():
		var prefix := "Enable" if not driver_toggle.is_enabled() else "Disable"
		var item := "%s %s physics driver" % [prefix, driver_toggle.get_name()]

		_tool_menu_items.append(item)

		add_tool_menu_item(item, func():
			# Toggle physics driver, then re-render menu to show changes
			_call_physics_driver_toggle(driver_toggle)
			_render_tool_menu()
		)

func _free_tool_menu():
	for item in _tool_menu_items:
		remove_tool_menu_item(item)
	_tool_menu_items.clear()

func _call_physics_driver_toggle(driver_toggle: PhysicsDriverToggles.PhysicsDriverToggle):
	var error_messages := driver_toggle.toggle()
	if not error_messages.is_empty():
		var error_text := "\n".join(error_messages)

		var dialog := AcceptDialog.new()
		dialog.title = "Physics driver toggle failed!"
		dialog.dialog_text = error_text

		get_editor_interface().popup_dialog_centered(dialog)
	else:
		var dialog := AcceptDialog.new()
		dialog.title = "Physics driver toggle success!"
		dialog.dialog_text = ("%s physics driver was successfully toggled! " +
			"You might need to refresh your script or reload project.") %\
			[driver_toggle.get_name()]

		get_editor_interface().popup_dialog_centered(dialog)
