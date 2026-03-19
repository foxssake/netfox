@tool
extends Control
class_name VestUI

const VisibilityPopup := preload("res://addons/vest/ui/visibility-popup.gd")
const ResultsPanel := preload("res://addons/vest/ui/results-panel.gd")

@onready var run_all_button := %"Run All Button" as Button
@onready var debug_button := %"Debug Button" as Button
@onready var run_on_save_button := %"Run on Save Button" as Button
@onready var filter_results_button := %"Filter Results Button" as Button
@onready var visibility_popup := %"Visibility Popup" as VisibilityPopup
@onready var clear_button := %"Clear Button" as Button
@onready var expand_toggle_button := %"Expand Toggle Button" as Button
@onready var search_button := %"Search Button" as Button
@onready var search_input := %"Search Input" as LineEdit

@onready var refresh_mixins_button := %"Refresh Mixins Button" as Button
@onready var results_panel := %"Results Panel" as ResultsPanel
@onready var summary_label := %"Tests Summary Label" as Label
@onready var summary_icon := %"Test Summary Icon" as TextureRect
@onready var glob_line_edit := %"Glob LineEdit" as LineEdit

@onready var run_summary := %"Run Summary" as Control
@onready var progress_indicator := %"Progress Indicator" as Control
@onready var progress_animator := $"VBoxContainer/Bottom Line/Progress Indicator/Control/AnimationPlayer" as AnimationPlayer

var _run_on_save: bool = false
var _results: VestResult.Suite = null

static var _icon_size := 16
static var _instance: VestUI

static func get_icon_size() -> int:
	return _icon_size

static func _get_ui() -> VestUI:
	return _instance

func handle_resource_saved(resource: Resource):
	if not resource is Script or not visible:
		return

	if _run_on_save:
		run_all()

func run_all(is_debug: bool = false):
	Vest._register_scene_tree(get_tree())
	var runner := VestDaemonRunner.new()
	runner.on_partial_result.connect(func(results):
		results_panel.set_results(results)
	)

	var test_glob := glob_line_edit.text
	Vest.__.LocalSettings.test_glob = test_glob
	Vest.__.LocalSettings.flush()

	results_panel.set_spinner("Waiting for results...", Vest.Icons.debug)
	progress_indicator.show()
	progress_animator.play("spin")
	run_summary.hide()

	var test_start := Vest.time()
	var results: VestResult.Suite
	if not is_debug:
		results = await runner.run_glob(glob_line_edit.text)
	else:
		results = await runner.with_debug().run_glob(glob_line_edit.text)

	var test_duration := Vest.time() - test_start

	# Render individual results
	ingest_results(results, test_duration)

func run_script(script: Script, is_debug: bool = false, only_mode: int = Vest.__.ONLY_AUTO) -> void:
	if not get_tree():
		push_warning("UI has no tree!")
	Vest._register_scene_tree(get_tree())
	var runner := VestDaemonRunner.new()

	results_panel.set_spinner("Waiting for results...", Vest.Icons.debug)
	progress_indicator.show()
	progress_animator.play("spin")
	run_summary.hide()

	var test_start := Vest.time()
	var results: VestResult.Suite
	if not is_debug:
		results = await runner.run_script(script, only_mode)
	else:
		results = await runner.with_debug().run_script(script, only_mode)

	var test_duration := Vest.time() - test_start

	# Render individual results
	ingest_results(results, test_duration)

func ingest_results(results: VestResult.Suite, duration: float = -1.) -> void:
	clear_results()
	_results = results

	if results:
		results_panel.set_results(results)
		_render_summary(results, duration)
	else:
		results_panel.set_spinner("Test run failed!", Vest.Icons.result_fail, false)

func clear_results():
	results_panel.clear()
	summary_label.text = ""
	summary_icon.visible = false

func _ready():
	_icon_size = int(16. * Vest._get_editor_scale())
	results_panel.visibility_popup = visibility_popup

	run_all_button.pressed.connect(run_all)
	run_on_save_button.toggled.connect(func(toggled):
		_run_on_save = toggled
	)
	clear_button.pressed.connect(clear_results)
	refresh_mixins_button.pressed.connect(func(): VestMixins.refresh())

	glob_line_edit.text = Vest.__.LocalSettings.test_glob
	glob_line_edit.text_changed.connect(func(text: String):
		Vest.__.LocalSettings.test_glob = text
	)

	debug_button.pressed.connect(func(): run_all(true))

	filter_results_button.pressed.connect(func():
		visibility_popup.position = filter_results_button.get_screen_position() + Vector2.RIGHT * filter_results_button.size.x
		visibility_popup.show()
	)

	visibility_popup.on_change.connect(func():
		clear_results()
		results_panel.set_results(_results)

		if visibility_popup.is_empty():
			filter_results_button.icon = Vest.Icons.hidden
		else:
			filter_results_button.icon = Vest.Icons.visible
	)

	results_panel.on_collapse_changed.connect(func():
		if (results_panel.is_any_collapsed()):
			expand_toggle_button.icon = Vest.Icons.expand
		else:
			expand_toggle_button.icon = Vest.Icons.collapse
	)

	expand_toggle_button.pressed.connect(func():
		results_panel.toggle_collapsed()
	)

	search_button.pressed.connect(func():
		search_input.show()
		search_input.grab_focus()
	)

	search_input.focus_exited.connect(func():
		if not search_input.text and get_viewport().gui_get_focus_owner() != search_button:
			search_input.hide()
	, CONNECT_DEFERRED)

	search_input.text_changed.connect(func(text: String):
		results_panel.set_search_string(text)
	)

	_instance = self

func _render_summary(results: VestResult.Suite, test_duration: float):
	progress_indicator.hide()
	run_summary.show()

	if test_duration > 0:
		summary_label.text = "Ran %d tests in %s" % [results.size(), VestUI.format_duration(test_duration)]
	else:
		summary_label.text = "Ran %d tests" % [results.size()]
	summary_icon.visible = true
	summary_icon.texture = VestUI.get_status_icon(results)
	summary_icon.custom_minimum_size = Vector2i.ONE * VestUI.get_icon_size() # TODO: Check

static func get_status_icon(what: Variant) -> Texture2D:
	if what is VestResult.Suite:
		return get_status_icon(what.get_aggregate_status())
	elif what is VestResult.Case:
		if what.data.has("benchmarks"):
			if what.status == VestResult.TEST_FAIL:
				return Vest.Icons.benchmark_fail
			else:
				return Vest.Icons.benchmark
		else:
			return get_status_icon(what.status)
	elif what is int:
		match(what):
			VestResult.TEST_VOID: return Vest.Icons.result_void
			VestResult.TEST_TODO: return Vest.Icons.result_todo
			VestResult.TEST_SKIP: return Vest.Icons.result_skip
			VestResult.TEST_FAIL: return Vest.Icons.result_fail
			VestResult.TEST_PASS: return Vest.Icons.result_pass
	return null

static func format_duration(duration: float) -> String:
	if duration > 60.:
		return "%.2fmin" % [duration / 60.]
	elif duration > 1.:
		return "%.2fs" % duration
	elif duration > 0.001:
		return "%.2fms" % [duration * 1000.]
	else:
		return "%.2fµs" % [duration * 1000_000.0]

static func fuzzy_score(needle: String, haystack: String) -> float:
	var ineedle := needle.to_lower()
	var ihaystack := haystack.to_lower()
	return ineedle.similarity(ihaystack) + float(ineedle.is_subsequence_of(ihaystack))

static func fuzzy_match(needle: String, haystack: String) -> bool:
	return fuzzy_score(needle, haystack) > 0.0

static func fuzzy_sorter(needle: String) -> Callable:
	return func(a, b):
		return fuzzy_score(needle, a) < fuzzy_score(needle, b)
