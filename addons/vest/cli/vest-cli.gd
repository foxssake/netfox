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

	## How to handle tests marked as `only`
	var only_mode: int = Vest.__.ONLY_DISABLED

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

		match only_mode:
			Vest.__.ONLY_DISABLED: result.append("--no-only")
			Vest.__.ONLY_AUTO: result.append("--auto-only")
			Vest.__.ONLY_ENABLED: result.append("--only")

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
			elif arg == "--no-only": result.only_mode = Vest.__.ONLY_DISABLED
			elif arg == "--only": result.only_mode = Vest.__.ONLY_ENABLED
			elif arg == "--auto-only": result.only_mode = Vest.__.ONLY_AUTO

		return result

## Run vest CLI with parameters.
## [br][br]
## Returns the spawned process' ID.
static func run(params: Params) -> int:
	var args = ["--headless", "-s", (VestCLI as Script).resource_path]
	return OS.create_instance(args + params.to_args())

## Run vest in debug mode.
static func debug(params: Params):
	Vest.__.LocalSettings.run_params = params
	Vest.__.LocalSettings.flush()
	Vest._get_editor_interface()\
		.play_custom_scene(preload("res://addons/vest/cli/vest-cli-scene.tscn").resource_path)

func _init():
	Vest._register_scene_tree(self)

	# Wait a frame for autoloads to register
	await process_frame

	var params := Params.parse(OS.get_cmdline_args())
	var runner := VestCLIRunner.new()

	var exit_code := await runner.run(params)

	quit(exit_code)
