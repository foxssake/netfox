extends RefCounted
class_name VestCLIRunner

## Implements functionality to run tests

var _peer: StreamPeerTCP = null

## Run tests with [Params]
func run(params: VestCLI.Params) -> int:
	var validation_errors := params.validate()
	if not validation_errors.is_empty():
		for error in validation_errors:
			OS.alert(error)
			push_error(error)
		return 1

	await _connect(params)

	var results := await _run_tests(params)
	_report(params, results)
	_send_results_over_network(params, results)

	_disconnect()

	if results.get_aggregate_status() == VestResult.TEST_PASS:
		print_rich("All tests [color=green]passed[/color]!")
		return 0
	else:
		print_rich("There are test [color=red]failures[/color]!")
		return 1

func _run_tests(params: VestCLI.Params) -> VestResult.Suite:
	var runner := VestLocalRunner.new()
	runner.on_partial_result.connect(func(result: VestResult.Suite):
		if _peer != null:
			if result != null:
				_peer.put_var(result._to_wire(), true)
			else:
				_peer.put_var(result, true)
	)

	var results: VestResult.Suite
	if params.run_file:
		results = await runner.run_script_at(params.run_file, params.only_mode)
	elif params.run_glob:
		results = await runner.run_glob(params.run_glob, params.only_mode)

	return results

func _report(params: VestCLI.Params, results: VestResult.Suite):
	var report := TAPReporter.report(results)

	if params.report_format:
		if params.report_file in ["", "-"]:
			print(report)
		else:
			var fa := FileAccess.open(params.report_file, FileAccess.WRITE)
			fa.store_string(report)
			fa.close()

func _connect(params: VestCLI.Params):
	if not params.host and params.port == -1:
		return

	var host := params.host
	var port := params.port

	if not host: host = "127.0.0.1"
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

	peer.set_no_delay(true)
	_peer = peer

func _disconnect():
	if _peer != null:
		_peer.disconnect_from_host()

func _send_results_over_network(params: VestCLI.Params, results: VestResult.Suite):
	if not _peer:
		return

	_peer.put_var(results._to_wire(), true)
