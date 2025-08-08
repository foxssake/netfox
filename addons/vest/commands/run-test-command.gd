@tool
extends Node

static var _instance = null

static func find():
	return _instance

static func execute() -> void:
	if _instance:
		_instance.create_test()
	else:
		push_warning("No instance of Create Test command found!")

func run_test():
	_run(false)

func debug_test():
	_run(true)

func _run(is_debug: bool) -> void:
	var editor_interface := Vest._get_editor_interface()
	var script_editor := editor_interface.get_script_editor() as ScriptEditor

	var edited_script := script_editor.get_current_script()
	if not edited_script:
		# TODO: Polyfilled toast mechanism so user can see these warns
		push_warning("No script to run! Open a script in the script editor.")
		return

	if not _is_ancestor_of(VestTest, edited_script):
		push_warning("Currently open script is not a test! Extend VestTest.")
		return

	print_verbose("Running test \"%s\"" % [edited_script.resource_path])
	var vest_ui := VestUI._get_ui()
	vest_ui.run_script(edited_script, is_debug)

func _is_ancestor_of(base_script: Script, script: Script) -> bool:
	for i in range(128): # Prevent runaway loops
		if script == null: break
		if base_script == script: return true

		script = script.get_base_script()
	return false

func _ready():
	_instance = self
	var editor := Vest._get_editor_interface()
	editor.get_command_palette().add_command("Run test", "vest/run-test", run_test, "F7")
	editor.get_command_palette().add_command("Debug test", "vest/debug-test", debug_test, "Ctrl+F7")

func _exit_tree():
	var editor := Vest._get_editor_interface()
	editor.get_command_palette().remove_command("vest/run-test")
	editor.get_command_palette().remove_command("vest/debug-test")

func _shortcut_input(event):
	if event is InputEventKey:
		if event.key_label == KEY_F7 and not event.shift_pressed and event.is_pressed():
			if event.is_command_or_control_pressed():
				debug_test()
			else:
				run_test()
			get_viewport().set_input_as_handled()
