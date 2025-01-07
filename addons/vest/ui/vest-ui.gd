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

func handle_resource_saved(resource: Resource):
	if not resource is Script or not visible:
		return

	if _run_on_save:
		run_all()

func run_all():
	var runner := VestRunner.new()
	get_tree().root.add_child(runner)

	clear_results()

	var test_start := _time()
	var results := runner.run_tests()
	var test_duration := _time() - test_start
	var aggregate_result := runner.aggregate_results(results)

	var success_row = load("res://addons/vest/ui/success-row.tscn") as PackedScene
	var fail_row = load("res://addons/vest/ui/fail-row.tscn") as PackedScene

	# Render individual results
	for test_result in results:
		var result_row: VestResultRow
		if test_result.is_success():
			result_row = success_row.instantiate()
		else:
			result_row = fail_row.instantiate()

		results_container.add_child(result_row)
		result_row.set_result(test_result)

	# Render summaries
	summary_label.text = "Ran %d tests in %.2fms" % [results.size(), test_duration * 1000.]
	results_label.text = ("%s %s" % [VestTest.status_emoji(aggregate_result), VestTest.status_string(aggregate_result)]).capitalize()

func clear_results():
	var result_rows := results_container.get_children()
	for row in result_rows:
		results_container.remove_child(row)
		row.queue_free()

func _ready():
	run_all_button.pressed.connect(run_all)
	run_on_save_checkbox.toggled.connect(func(toggled):
		_run_on_save = toggled
	)
	clear_button.pressed.connect(clear_results)

func _time() -> float:
	return Time.get_unix_time_from_system() / 1000.
