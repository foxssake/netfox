@tool
extends Node

static var _instance: Vest.__.CreateTestCommand = null

static func find():
	return _instance

static func execute() -> void:
	if _instance:
		_instance.create_test()
	else:
		push_warning("No instance of Create Test command found!")

func create_test():
	var editor := Vest._get_editor_interface()
	var edited_script := editor.get_script_editor().get_current_script() as Script

	if not edited_script:
		editor.get_script_editor().open_script_create_dialog("VestTest", "")
		return

	var script_path := edited_script.resource_path
	var script_directory := script_path.get_base_dir()
	var script_filename := script_path.get_file()

	if Vest.get_test_name_patterns().any(func(it): return it.matches(script_filename)):
		# Script is already a test
		return

	var preferred_pattern := Vest.get_test_name_patterns()[0]
	var test_filename := preferred_pattern.substitute(script_filename)
	var test_directory := get_test_directory(script_directory)
	var test_path := test_directory.path_join(test_filename)

	editor.get_script_editor().open_script_create_dialog("VestTest", test_path)

func get_test_directory(script_dir: String) -> String:
	match Vest.get_new_test_location_preference():
		Vest.NEW_TEST_MIRROR_DIR_STRUCTURE:
			return get_mirrored_test_dir(script_dir)
		Vest.NEW_TEST_NEXT_TO_SOURCE:
			return script_dir
		Vest.NEW_TEST_IN_ROOT:
			return Vest.get_tests_root()

	return script_dir

func get_mirrored_test_dir(script_dir: String) -> String:
	# TODO: Class for managing paths?
	if not script_dir.ends_with("/"):
		script_dir += "/"

	if script_dir.begins_with(Vest.get_sources_root()):
		var relative_to_src_root := script_dir.substr(Vest.get_sources_root().length())
		return Vest.get_tests_root() + relative_to_src_root
	else:
		var relative_to_root := script_dir.replace("res://", "")
		return Vest.get_tests_root() + relative_to_root

func _ready():
	_instance = self
	var editor := Vest._get_editor_interface()
	editor.get_command_palette().add_command("Create test", "vest/create-test", create_test, "Ctrl+Shift+T")

func _exit_tree():
	var editor := Vest._get_editor_interface()
	editor.get_command_palette().remove_command("vest/create-test")

func _shortcut_input(event):
	if event is InputEventKey:
		if event.is_command_or_control_pressed() and event.shift_pressed and event.key_label == KEY_T and event.is_pressed():
			create_test()
			get_viewport().set_input_as_handled()
