extends Object
class_name VestDefs

## Grouping class for test definition primitives.
##
## See [VestDefs.Suite][br]
## See [VestDefs.Case][br]
## See [VestDefs.Benchmark][br]

## Test suite definition.
##
## A test suite consists of test cases, and optionally other, nested test
## suites.
##
## @tutorial(Writing tests): https://foxssake.github.io/vest/latest/user-guide/writing-tests/
class Suite:
	## Test suite name, displayed in reports
	var name: String = ""

	## Test cases contained in the suite
	var cases: Array[VestDefs.Case] = []

	## Nested test suites contained in the suite
	var suites: Array[VestDefs.Suite] = []

	## The resource path to the script that defined the suite
	var definition_file: String = ""

	## The line number of the suite definition. [br]
	## Set to -1 for undetermined.
	var definition_line: int = -1

	## Get the number of test cases in the suite.[br]
	## Includes the number of test cases in the suite, and recursively sums up
	## the test cases in any of the nested suites.
	func size() -> int:
		return cases.size() + suites.reduce(func(acc, it): return acc + it.size(), 0)

	func _to_string() -> String:
		return "VestDefs.Suite(name=\"%s\", cases=%s, suites=%s)" % [name, cases, suites]

	func _to_wire() -> Dictionary:
		return { "name": name }

	static func _from_wire(data: Dictionary) -> Suite:
		var result := Suite.new()
		result.name = data["name"]
		return result

## Test case definition.
##
## @tutorial(Writing tests): https://foxssake.github.io/vest/latest/user-guide/writing-tests/
class Case:
	## Test case description, displayed in reports
	var description: String = ""

	## The method called to run the test case
	var callback: Callable

	## The resource path to the script that defined the suite
	var definition_file: String = ""

	## The line number of the suite definition.[br]
	## Set to -1 for undetermined.
	var definition_line: int = -1

	func _to_string() -> String:
		return "VestDefs.Case(\"%s\", \"%s\":%d)" % [description, definition_file, definition_line]

	func _to_wire() -> Dictionary:
		return {
			"description": description,
			"definition_file": definition_file,
			"definition_line": definition_line
		}

	static func _from_wire(data: Dictionary) -> Case:
		var result := Case.new()

		result.description = data["description"]
		result.definition_file = data["definition_file"]
		result.definition_line = data["definition_line"]

		return result

## Benchmark definition.
##
## Benchmarks run a piece of code multiple times, measuring how much time each
## iteration took.
##
## @tutorial(Benchmarking): https://foxssake.github.io/vest/latest/user-guide/benchmarking/
class Benchmark:
	## Method to measure during the benchmark
	var callback: Callable

	## Benchmark name, displayed in the reports
	var name: String = ""

	var _iterations: int = 0
	var _duration: float = 0.0
	var _batch_size: int = 1

	var _max_iterations: int = -1
	var _max_duration: float = -1.0
	var _enable_builtin_measures: bool = true

	var _measures: Array[VestMeasure] = []
	var _metric_signals: Dictionary = {} # metric name to signal
	var _emit_buffer: Array = []

	signal _on_emit_template(value: Variant)

	var _test: VestTest

	## Set a limit on the number of iterations to run.
	func with_iterations(p_iterations: int) -> Benchmark:
		_max_iterations = p_iterations
		return self

	## Set a limit on the duration for running the benchmark.
	## [br][br]
	## The duration limit is in [i]seconds[/i].
	func with_duration(p_duration: float) -> Benchmark:
		_max_duration = p_duration
		return self

	## Set the batch size for running the benchmark.
	## [br][br]
	## When the batch size is greater than one, benchmark runs won't be measured
	## one by one, but in batches.
	## [br][br]
	## This can be useful when running microbenchmarks, where an individual test
	## run is too fast to accurately measure.
	func with_batch_size(p_batch_size: int) -> Benchmark:
		if p_batch_size >= 1:
			_batch_size = p_batch_size
		else:
			push_error("Invalid batch size set for benchmark %s: %d! Ignoring." % [name, p_batch_size])
		return self

	## Add a custom measurement.
	## [br][br]
	## There are many built-in measurements, see [method measure_value],
	## [method measure_average], [method measure_sum], [method measure_min],
	## and [method measure_max].
	func with_measure(measure: VestMeasure) -> Benchmark:
		# Append measure
		_measures.append(measure)

		# Connect to appropriate signal
		var metric := measure.get_metric_name()
		if not _metric_signals.has(metric):
			_metric_signals[metric] = Signal(_on_emit_template)
		(_metric_signals[metric] as Signal).connect(measure.ingest)

		return self

	## Measure the value of [param metric].
	## [br][br]
	## The last value emitted will be included in the report.
	func measure_value(metric: StringName) -> Benchmark:
		with_measure(Vest.ValueMeasure.new(metric))
		return self

	## Measure the average of [param metric].
	func measure_average(metric: StringName) -> Benchmark:
		with_measure(Vest.AverageMeasure.new(metric))
		return self

	## Measure the maximum value of [param metric].
	func measure_max(metric: StringName) -> Benchmark:
		with_measure(Vest.MaxMeasure.new(metric))
		return self

	## Measure the minimum value of [param metric].
	func measure_min(metric: StringName) -> Benchmark:
		with_measure(Vest.MinMeasure.new(metric))
		return self

	## Measure the sum of all emissions of [param metric].
	func measure_sum(metric: StringName) -> Benchmark:
		with_measure(Vest.SumMeasure.new(metric))
		return self

	## Disable the builtin measurements.
	## [br][br]
	## This will stop iterations, durations, iters/sec, and average iteration
	## time from being reported. They're enabled by default.
	func without_builtin_measures() -> Benchmark:
		_enable_builtin_measures = false
		return self

	## Run the benchmark only once.
	func once() -> Benchmark:
		_max_iterations = 1
		_max_duration = 1.0
		return run()

	## Run the benchmark with the configured limits.
	func run() -> Benchmark:
		# Run benchmark
		while _is_within_limits():
			var batch_runs := mini(_batch_size, _get_remaining_iterations())
			var t_start := Vest.time()
			for __ in batch_runs:
				callback.call(_emit)
			var duration := Vest.time() - t_start

			_duration += duration
			_iterations += batch_runs

			# Emit runtime
			_emit(&"duration", duration)

			# Metric emits are buffered, so they don't influence runtime measure
			# much
			# This call flushes the buffered metric emissions
			_flush_emits()

		# Report
		var result_data := _test._get_result().data
		var benchmarks := result_data.get("benchmarks", []) as Array
		benchmarks.append(_to_data())
		result_data["benchmarks"] = benchmarks

		# Set test to pass by default if no asserts are added
		_test.ok("", result_data)

		# Warn user when running benchmarks in too small batches
		var avg_batch_time := get_avg_iteration_time() * _batch_size
		var batch_threshold := 0.001 # 1ms
		if avg_batch_time <= batch_threshold and _enable_builtin_measures:
			Vest.message((
				"Benchmark \"%s\" has run with an average of %.6fms per batch. " +
				"This is probably faster than what can be reliably measured. " +
				"To avoid this warning, increase the batch size to at least %s.") %
				[name, avg_batch_time * 1000., ceil(_batch_size * batch_threshold / avg_batch_time * 1.1)]
			)

		return self

	## Get the number of iterations ran.
	func get_iterations() -> int:
		return _iterations

	## Get the total time it took to run the benchmark.
	func get_duration() -> float:
		return _duration

	## Get the average number of iterations ran per second.
	func get_iters_per_sec() -> float:
		return _iterations / _duration

	## Get the average time it took to run an iteration, in seconds.
	func get_avg_iteration_time() -> float:
		return _duration / _iterations

	## Get the value of a measurement.
	## [br][br]
	## Measurements can be taken from the benchmark report, e.g. "Size - Value"
	## corresponds to [code]get_measurement(&"Size", &"value")[/code].
	## [br][br]
	## The returned value can be used for assertions.
	func get_measurement(metric: StringName, measurement: StringName) -> Variant:
		for measure in _measures:
			if measure.get_metric_name() == metric and measure.get_measure_name() == measurement:
				return measure.get_value()

		assert(false, "Measurement not found!")
		return null

	func _is_within_limits() -> bool:
		return _get_remaining_iterations() > 0 and _get_remaining_time() > 0.

	func _get_remaining_time() -> float:
		if _max_duration >= 0.0:
			return _max_duration - _duration
		return INF

	func _get_remaining_iterations() -> int:
		if _max_iterations >= 0:
			return _max_iterations - _iterations
		return _batch_size + 1

	func _emit(metric: StringName, value: Variant) -> void:
		_emit_buffer.push_back([metric, value])

	func _flush_emits() -> void:
		for emit in _emit_buffer:
			var metric := emit[0] as StringName
			var value = emit[1]

			if not _metric_signals.has(metric): continue
			(_metric_signals.get(metric) as Signal).emit(value)

		_emit_buffer.clear()

	func _to_data() -> Dictionary:
		var result := {}

		# Add custom measures
		for measure in _measures:
			var measure_name := "%s - %s" % [measure.get_metric_name(), measure.get_measure_name().capitalize()]
			result[measure_name] = str(measure.get_value())

		# Add builtin measures
		if _enable_builtin_measures:
			result["iterations"] = _iterations
			result["duration"] = "%.4fms" % [_duration * 1000.0]
			result["iters/sec"] = get_iters_per_sec()
			result["average iteration time"] = "%.4fms" % [get_avg_iteration_time() * 1000.0]

		# Add benchmark data
		result["name"] = name

		return result
