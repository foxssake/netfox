extends SceneTree
class_name VestCLI

## Class for running vest from the CLI
## [br][br]
## See [VestCLI.Params]

## Vest CLI parameters
class Params:
	## Which test script file to run
	var run_file: String = ""

	## Which test glob to run
	var run_glob: String = "res://*.test.gd"

	## Reporting format - currently only TAP is supported
	var report_format: String = ""

	## Path for saving the report
	var report_file: String = ""

	## Host to connect to for sending results
	var host: String = ""

	## Port to connect to for sending results
	var port: int = -1

	## Validate parameters.
	## [br][br]
	## Returns an array of error messages, or an empty array of the parameters
	## are valid.
	func validate() -> Array[String]:
		var result: Array[String] = []
		if not run_file and not run_glob:
			result.append("No tests specified!")
		if report_format not in ["", "tap"]:
			result.append("Unknown report format \"%s\"!" % report_format)
		if port != -1 and port < 0 or port > 65535:
			result.append("Specified port %d is invalid!" % port)
		return result

	## Convert to an array of CLI parameters.
	func to_args() -> Array[String]:
		var result: Array[String] = []

		if run_file: result.append_array(["--vest-file", run_file])
		if run_glob: result.append_array(["--vest-glob", run_glob])
		if report_format: result.append_array(["--vest-report-format", report_format])
		if report_file: result.append_array(["--vest-report-file", report_file])
		if host: result.append_array(["--vest-host", host])
		if port != -1: result.append_array(["--vest-port", str(port)])

		return result

	## Parse an array of CLI parameters.
	## [br][br]
	## See [method OS.get_cmdline_args].
	static func parse(args: Array[String]) -> Params:
		var result := Params.new()

		for i in range(args.size()):
			var arg := args[i]
			var val := args[i+1] if i+1 < args.size() else ""

			if arg == "--vest-file": result.run_file = val
			elif arg == "--vest-glob": result.run_glob = val
			elif arg == "--vest-report-file": result.report_file = val
			elif arg == "--vest-report-format": result.report_format = val
			elif arg == "--vest-port": result.port = val.to_int()
			elif arg == "--vest-host": result.host = val

		return result

## Implements functionality to run tests
class Runner:
	## Run tests with [Params]
	func run(params: Params) -> int:
		var validation_errors := params.validate()
		if not validation_errors.is_empty():
			for error in validation_errors:
				OS.alert(error)
				push_error(error)
			return 1

		var results := _run_tests(params)
		_report(params, results)
		await _send_results_over_network(params, results)

		if results.get_aggregate_status() == VestResult.TEST_PASS:
			print_rich("All tests [color=green]passed[/color]!")
			return 0
		else:
			print_rich("There are test [color=red]failures[/color]!")
			return 1

	func _run_tests(params: Params) -> VestResult.Suite:
		var runner := VestLocalRunner.new()

		var results: VestResult.Suite
		if params.run_file:
			results = runner.run_script_at(params.run_file)
		elif params.run_glob:
			results = runner.run_glob(params.run_glob)

		return results

	func _report(params: Params, results: VestResult.Suite):
		var report := TAPReporter.report(results)

		if params.report_format:
			if params.report_file in ["", "-"]:
				print(report)
			else:
				var fa := FileAccess.open(params.report_file, FileAccess.WRITE)
				fa.store_string(report)
				fa.close()

	func _send_results_over_network(params: Params, results: VestResult.Suite):
		if not params.host and params.port == -1:
			return

		var host := params.host
		var port := params.port

		if not host: host = "0.0.0.0"
		if port == -1: port = 54932

		var peer := StreamPeerTCP.new()
		var err := peer.connect_to_host(host, port)
		if err != OK:
			push_warning("Couldn't connect on port %d! %s" % [port, error_string(err)])
			return

		await Vest.until(func(): peer.poll(); return peer.get_status() != StreamPeerTCP.STATUS_CONNECTING)
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			push_warning("Connection failed! Socket status: %d" % [peer.get_status()])
			return

		peer.put_var(results._to_wire(), true)
		peer.disconnect_from_host()


## Run vest CLI with parameters.
## [br][br]
## Returns the spawned process' ID.
static func run(params: Params) -> int:
	var args = ["--headless", "-s", (VestCLI as Script).resource_path]
	return OS.create_instance(args + params.to_args())

## Run vest in debug mode.
static func debug():
	Vest._get_editor_interface()\
		.play_custom_scene(preload("res://addons/vest/cli/vest-cli-scene.tscn").resource_path)

func _init():
	Vest._register_scene_tree(self)

	# Wait a frame for autoloads to register
	await process_frame

	var params := Params.parse(OS.get_cmdline_args())
	var runner := Runner.new()

	var exit_code := await runner.run(params)

	quit(exit_code)
