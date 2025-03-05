extends Object
class_name Vest

## Utility singleton for running tests.
##
## @tutorial(Printing custom messages): https://foxssake.github.io/vest/latest/user-guide/printing-custom-messages/

static var _messages: Array[String] = []
static var _scene_tree: SceneTree
static var _editor_interface: EditorInterface

## Add a custom message to the current test.
## [br][br]
## Will be included in the test report.
static func message(p_message: String):
	_messages.append(p_message)

## Wait for [param condition] to be true, or until timeout.
## [br][br]
## This method will start a loop, each time waiting [param interval] seconds.
## On each iteration, [param condition] is called. If its result is true, or the
## [param timeout] has been exceeded, the loop stops.
## [br][br]
## If [param timeout] is 0., the loop may run infinitely, without timeout.
## [br][br]
## Returns [constant OK] if [param condition] was true.[br]
## Returns [constant ERR_TIMEOUT] if [param timeout] was exceeded.[br]
## Returns [constant ERR_UNAVAILABLE] if no [SceneTree] is available.
static func until(condition: Callable, timeout: float = 5., interval: float = 0.0) -> Error:
	var deadline := time() + timeout

	if not _scene_tree:
		push_warning("Missing reference to SceneTree, will return immediately!")
		return ERR_UNAVAILABLE

	while time() < deadline:
		if condition.call():
			return OK

		if is_zero_approx(timeout): await _scene_tree.process_frame
		else: await _scene_tree.create_timer(interval).timeout

	return ERR_TIMEOUT

## Set the test glob.
## [br][br]
## The test glob is used for finding test scripts to run.
static func set_test_glob(glob: String):
	ProjectSettings.set_setting("vest/general/test_glob", glob)

## Get the test glob.
## [br][br]
## The test glob is used for finding test scripts to run.
static func get_test_glob() -> String:
	return ProjectSettings.get_setting("vest/general/test_glob", "res://*.test.gd")

## Get the debug port.
## [br][br]
## The debug port is used for returning results when running in debug mode.
static func get_debug_port() -> int:
	return ProjectSettings.get_setting("vest/general/debug_port", 59432)

## Get the current time, in seconds.
## [br][br]
## Used for benchmarking and waiting [method until] a condition becomes true.
static func time() -> float:
	return Time.get_unix_time_from_system()

static func _clear_messages():
	_messages.clear()

static func _get_messages() -> Array[String]:
	return _messages.duplicate()

static func _register_scene_tree(scene_tree: SceneTree):
	_scene_tree = scene_tree

static func _get_editor_interface() -> EditorInterface:
	return _editor_interface

static func _register_editor_interface(editor_interface: EditorInterface):
	_editor_interface = editor_interface
