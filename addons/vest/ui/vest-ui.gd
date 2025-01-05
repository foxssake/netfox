@tool
extends Control
class_name VestUI

@onready var run_all_button := %"Run All Button" as Button
@onready var run_on_save_checkbox := %"Run On Save CheckBox" as CheckBox
@onready var clear_button := %"Clear Button" as Button
@onready var results_container := %Results as VBoxContainer
@onready var summary_label := %"Tests Summary Label" as Label
@onready var results_label := %"Tests Result Label" as Label

var _run_on_save: bool = false
var _enabled: bool = false

func enable():
	_enabled = true

func run_all():
	var runner := VestRunner.new()
	get_tree().root.add_child(runner)

	clear_results()

	var test_start := _time()
	var results := runner.run_tests()
	var test_duration := _time() - test_start
	var aggregate_result := runner.aggregate_results(results)

	# Render individual results
	for test_result in results:
		var result_label := Label.new()
		result_label.text = "%s %s - %s" % \
			[get_status_prefix(test_result.status), test_result.case.module, test_result.case.name]

		results_container.add_child(result_label)

	# Render summaries
	summary_label.text = "Ran %d tests in %.2fms" % [results.size(), test_duration * 1000.]
	results_label.text = ("%s %s" % [get_status_prefix(aggregate_result), VestTest.status_string(aggregate_result)]).capitalize()

func clear_results():
	var result_rows := results_container.get_children()
	for row in result_rows:
		results_container.remove_child(row)
		row.queue_free()

func get_status_prefix(status: int) -> String:
	match status:
		VestTest.UNKNOWN: return "❓"
		VestTest.FAIL: return "❌"
		VestTest.SKIP: return "💤"
		VestTest.PASS: return "✅"
		_: return "⭕"

func _notification(what):
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		if _enabled and _run_on_save:
			run_all()

func _ready():
	run_all_button.pressed.connect(run_all)
	run_on_save_checkbox.toggled.connect(func(toggled):
		_run_on_save = toggled
	)
	clear_button.pressed.connect(clear_results)

func _time() -> float:
	return Time.get_unix_time_from_system() / 1000.
