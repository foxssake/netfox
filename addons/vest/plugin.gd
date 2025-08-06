@tool
extends EditorPlugin

var bottom_control: Control

static var SETTINGS := [
	{
		"name": "vest/runner_timeout",
		"value": 8.0,
		"type": TYPE_FLOAT
	},
	{
		"name": "vest/sources_root",
		"value": "res://",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_DIR
	},
	{
		"name": "vest/tests_root",
		"value": "res://tests/",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_DIR
	},
	{
		"name": "vest/test_name_patterns",
		"value": PackedStringArray(["*.test.gd", "test_*.gd"]),
		"type": TYPE_PACKED_STRING_ARRAY,
		"hint": PROPERTY_HINT_DIR
	},
	{
		"name": "vest/new_test_location",
		"value": Vest.NEW_TEST_MIRROR_DIR_STRUCTURE,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join([
			"Mirror directory structure",
			"Next to source",
			"In tests root"
		])
	}
] as Array[Dictionary]

func _enter_tree():
	Vest._register_scene_tree(get_tree())
	Vest._register_editor_interface_provider(get_editor_interface)

	# Manually trigger local settings init?
	Vest.__.LocalSettings._static_init()

	bottom_control = (preload("res://addons/vest/ui/vest-ui.tscn") as PackedScene).instantiate()
	resource_saved.connect(bottom_control.handle_resource_saved)

	add_control_to_bottom_panel(bottom_control, "Vest")

	add_settings(SETTINGS)
	
	# Create commands
	for command in Vest.__.create_commands():
		add_child(command)

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
