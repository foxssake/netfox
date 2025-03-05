@tool
extends Control

@onready var run_all_button := %"Run All Button" as Button
@onready var debug_button := %"Debug Button" as Button
@onready var run_on_save_button := %"Run on Save Button" as Button
@onready var clear_button := %"Clear Button" as Button
@onready var refresh_mixins_button := %"Refresh Mixins Button" as Button
@onready var results_tree := %"Results Tree" as Tree
@onready var summary_label := %"Tests Summary Label" as Label
@onready var summary_icon := %"Test Summary Icon" as TextureRect
@onready var glob_line_edit := %"Glob LineEdit" as LineEdit

var _run_on_save: bool = false

signal on_debug()

func handle_resource_saved(resource: Resource):
	if not resource is Script or not visible:
		return

	if _run_on_save:
		run_all()

func run_all(is_debug: bool = false):
	Vest._register_scene_tree(get_tree())
	var runner := VestDaemonRunner.new()

	clear_results()
	_set_placeholder_text("Waiting for results...")

	var test_start := Vest.time()
	var results: VestResult.Suite
	if not is_debug:
		results = await runner.run_glob(glob_line_edit.text)
	else:
		results = await runner.with_debug().run_glob(glob_line_edit.text)

	var test_duration := Vest.time() - test_start

	# Render individual results
	clear_results()
	if results:
		_render_result(results, results_tree)
		_render_summary(results, test_duration)
	else:
		_set_placeholder_text("Test run failed!")

func clear_results():
	results_tree.clear()
	for connection in results_tree.item_activated.get_connections():
		connection["signal"].disconnect(connection["callable"])

	summary_label.text = ""
	summary_icon.visible = false

func _ready():
	run_all_button.pressed.connect(run_all)
	run_on_save_button.toggled.connect(func(toggled):
		_run_on_save = toggled
	)
	clear_button.pressed.connect(clear_results)
	refresh_mixins_button.pressed.connect(func(): VestMixins.refresh())

	glob_line_edit.text = Vest.get_test_glob()
	glob_line_edit.text_changed.connect(func(text: String):
		Vest.set_test_glob(text)
	)

	debug_button.pressed.connect(func(): run_all(true))

func _notification(what):
	if what == NOTIFICATION_DRAW:
		glob_line_edit.text = Vest.get_test_glob()

func _render_result(what: Object, tree: Tree, parent: TreeItem = null):
	if what is VestResult.Suite:
		var item := tree.create_item(parent)
		item.set_text(0, what.suite.name)
		item.set_text(1, what.get_aggregate_status_string().capitalize())

		item.set_icon(0, _get_status_icon(what))
		item.set_icon_max_width(0, tree.get_theme_font_size(""))

		tree.item_activated.connect(func():
			if tree.get_selected() == item:
				_navigate(what.suite.definition_file, what.suite.definition_line)
		)

		for subsuite in what.subsuites:
			_render_result(subsuite, tree, item)
		for case in what.cases:
			_render_result(case, tree, item)
	elif what is VestResult.Case:
		var item := tree.create_item(parent)
		item.set_text(0, what.case.description)
		item.set_text(1, what.get_status_string().capitalize())
		item.collapsed = what.status == VestResult.TEST_PASS

		item.set_icon(0, _get_status_icon(what))
		item.set_icon_max_width(0, tree.get_theme_font_size(""))

		_render_data(what, tree, item)

		tree.item_activated.connect(func():
			if tree.get_selected() == item:
				_navigate(what.case.definition_file, what.case.definition_line)
		)
	else:
		push_error("Rendering unknown object: %s" % [what])

func _render_summary(results: VestResult.Suite, test_duration: float):
	summary_label.text = "Ran %d tests in %.2fms" % [results.size(), test_duration * 1000.]
	summary_icon.visible = true
	summary_icon.texture = _get_status_icon(results)
	summary_icon.custom_minimum_size = Vector2i.ONE * get_theme_font("").get_height(get_theme_font_size(""))

func _render_data(case: VestResult.Case, tree: Tree, parent: TreeItem):
	var data := case.data.duplicate()

	if case.message:
		var item := tree.create_item(parent)
		item.set_text(0, case.message)

		tree.item_activated.connect(func():
			if tree.get_selected() == item:
				add_child(VestMessagePopup.of(case.message).window)
		)

	if data == null or data.is_empty():
		return

	if data.has("messages"):
		var header_item := tree.create_item(parent)
		header_item.set_text(0, "Messages")

		for message in data["messages"]:
			tree.create_item(header_item).set_text(0, message)

		data.erase("messages")

	if data.has("benchmarks"):
		var header_item := tree.create_item(parent)
		header_item.set_text(0, "Benchmarks")

		for benchmark in data["benchmarks"]:
			var benchmark_item = tree.create_item(header_item)
			benchmark_item.set_text(0, benchmark["name"])
			benchmark_item.set_text(1, benchmark["duration"])

			for measurement in benchmark.keys():
				if measurement == "name": continue

				var measurement_item := tree.create_item(benchmark_item)
				measurement_item.set_text(0, str(measurement).capitalize())
				measurement_item.set_text(1, str(benchmark[measurement]))

		data.erase("benchmarks")

	if data.has("expect") and data.has("got"):
		var header_item := tree.create_item(parent)
		header_item.set_text(0, "Got:")
		header_item.set_text(1, "Expected:")

		var got_string := JSON.stringify(data["got"], "  ")
		var expect_string := JSON.stringify(data["expect"], "  ")

		var comparison_item := tree.create_item(header_item)
		comparison_item.set_text(0, got_string)
		comparison_item.set_text(1, expect_string)

		tree.item_activated.connect(func():
			if tree.get_selected() in [header_item, comparison_item]:
				add_child(VestComparisonPopup.of(expect_string, got_string).window)
		)

		data.erase("got")
		data.erase("expect")

	for key in data:
		var item := tree.create_item(parent)
		item.set_text(0, var_to_str(key))
		item.set_text(1, var_to_str(data[key]))

func _set_placeholder_text(text: String):
	results_tree.clear()
	var placeholder_root := results_tree.create_item()
	results_tree.create_item(placeholder_root).set_text(0, text)

func _navigate(file: String, line: int):
	Vest._get_editor_interface().edit_script(load(file), line)

func _get_status_icon(what: Variant) -> Texture2D:
	if what is VestResult.Suite:
		return _get_status_icon(what.get_aggregate_status())
	elif what is VestResult.Case:
		if what.data.has("benchmarks"):
			if what.status == VestResult.TEST_FAIL:
				return preload("res://addons/vest/icons/benchmark-fail.svg")
			else:
				return preload("res://addons/vest/icons/benchmark.svg")
		else:
			return _get_status_icon(what.status)
	elif what is int:
		match(what):
			VestResult.TEST_VOID: return preload("res://addons/vest/icons/void.svg") as Texture2D
			VestResult.TEST_TODO: return preload("res://addons/vest/icons/todo.svg") as Texture2D
			VestResult.TEST_SKIP: return preload("res://addons/vest/icons/skip.svg") as Texture2D
			VestResult.TEST_FAIL: return preload("res://addons/vest/icons/fail.svg") as Texture2D
			VestResult.TEST_PASS: return preload("res://addons/vest/icons/pass.svg") as Texture2D
	return null

func _get_benchmark_icon() -> Texture2D:
	return preload("res://addons/vest/icons/benchmark.svg") as Texture2D
