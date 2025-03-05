extends RefCounted
class_name VestComparisonPopup

var window: Window
var expected: TextEdit
var got: TextEdit
var ok_button: Button
var reset_button: Button

var _expected: String = ""
var _got: String = ""

# For some reason, when instantiating in Godot 4.0.4, the script doesn't attach, even though it's
# added in the editor.
#
# This means that _ready doesn't run, and set_contents isn't recognized.
#
# The workaround is this weird pattern where the class is instantiated with a reference to the
# scriptless scene ( Window ), and takes over.

# NOTE: This class may be rewritten, as we went from supporting 4.0.4 to 4.1.4

static func of(expected: String, got: String):
	var popup_scene := (load("res://addons/vest/ui/comparison-popup.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var popup := VestComparisonPopup.new(popup_scene)

	popup.set_contents(expected, got)

	return popup

func set_contents(p_expected: String, p_got: String):
	_expected = p_expected
	_got = p_got

	reset()

func reset():
	expected.text = _expected
	got.text = _got

func close():
	window.queue_free()
	free()

func _init(p_window: Window):
	p_window.title = "vest - Comparison"
	p_window.position = (DisplayServer.screen_get_size(-1) - p_window.size) / 2

	window = p_window
	ok_button = window.get_node("%OK Button")
	reset_button = window.get_node("%Reset Button")
	expected = window.get_node("%Expected")
	got = window.get_node("%Got")

	window.close_requested.connect(func(): close())
	ok_button.pressed.connect(func(): window.queue_free())
	reset_button.pressed.connect(func(): reset())
