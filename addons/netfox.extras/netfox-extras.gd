@tool
extends EditorPlugin

const ROOT = "res://addons/netfox.extras"

var SETTINGS = [
	NetfoxLogger._make_setting("netfox/logging/netfox_extras_log_level"),
	
	# Window Tiler Settings
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
	
	# Autoconnect settings
	{
		"name": "netfox/autoconnect/enabled",
		"value": false,
		"type": TYPE_BOOL
	},
	{
		"name": "netfox/autoconnect/host",
		"value": "127.0.0.1",
		"type": TYPE_STRING
	},
	{
		"name": "netfox/autoconnect/port",
		"value": 9999,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "1,65535,hide_slider"
	},
	{
		"name": "netfox/autoconnect/use_compression",
		"value": false,
		"type": TYPE_BOOL
	},
	{
		"name": "netfox/autoconnect/simulated_latency_ms",
		"value": 0.0,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,200,or_greater"
	},
	{
		"name": "netfox/autoconnect/simulated_packet_loss_chance",
		"value": 0.0,
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,1"
	}
]

const AUTOLOADS = [
	{
		"name": "WindowTiler",
		"path": ROOT + "/window-tiler.gd"
	},
	{
		"name": "NetworkSimulator",
		"path": ROOT + "/network-simulator.gd"
	}
]

const TYPES: Array[Dictionary] = [
	{
		"name": "RewindableStateMachine",
		"base": "Node",
		"script": ROOT + "/state-machine/rewindable-state-machine.gd",
		"icon": ROOT + "/icons/rewindable-state-machine.svg"
	},
	{
		"name": "RewindableState",
		"base": "Node",
		"script": ROOT + "/state-machine/rewindable-state.gd",
		"icon": ROOT + "/icons/rewindable-state.svg"
	},
	{
		"name": "NetworkRigidBody2D",
		"base": "RigidBody2D",
		"script": ROOT + "/physics/network-rigid-body-2d.gd",
		"icon": ROOT + "/icons/network-rigid-body-2d.svg"
	},
	{
		"name": "NetworkRigidBody3D",
		"base": "RigidBody3D",
		"script": ROOT + "/physics/network-rigid-body-3d.gd",
		"icon": ROOT + "/icons/network-rigid-body-3d.svg"
	},
]

const PhysicsDriverToggles := preload("res://addons/netfox.extras/physics/physics-driver-toggles.gd")

var _tool_menu_items := [] as Array[String]

func _enter_tree():
	for setting in SETTINGS:
		add_setting(setting)

	for autoload in AUTOLOADS:
		add_autoload_singleton(autoload.name, autoload.path)
	
	for type in TYPES:
		add_custom_type(type.name, type.base, load(type.script), load(type.icon))

	_render_tool_menu()

func _exit_tree():
	if ProjectSettings.get_setting("netfox/general/clear_settings", false):
		for setting in SETTINGS:
			remove_setting(setting)

	for autoload in AUTOLOADS:
		remove_autoload_singleton(autoload.name)
	
	for type in TYPES:
		remove_custom_type(type.name)

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
