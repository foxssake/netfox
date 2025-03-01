@tool
extends EditorPlugin

var bottom_control: Control

const SETTINGS = [
	{
		"name": "vest/general/test_glob",
		"value": "res://*.test.gd",
		"type": TYPE_STRING
	},
	{
		"name": "vest/general/debug_port",
		"value": 59432,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,65535"
	}
]

func _enter_tree():
	Vest._register_scene_tree(get_tree())
	Vest._register_editor_interface(get_editor_interface())

	bottom_control = (preload("res://addons/vest/ui/vest-ui.tscn") as PackedScene).instantiate()
	resource_saved.connect(bottom_control.handle_resource_saved)

	add_control_to_bottom_panel(bottom_control, "Vest")

	add_settings(SETTINGS)

func _exit_tree():
	resource_saved.disconnect(bottom_control.handle_resource_saved)
	remove_control_from_bottom_panel(bottom_control)
	bottom_control.queue_free()

	remove_settings(SETTINGS)

func add_settings(settings: Array):
	for setting in settings:
		add_setting(setting)

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

func remove_settings(settings: Array):
	for setting in settings:
		remove_setting(setting)

func remove_setting(setting: Dictionary):
	if not ProjectSettings.has_setting(setting.name):
		return

	ProjectSettings.clear(setting.name)
