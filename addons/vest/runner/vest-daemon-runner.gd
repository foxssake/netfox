extends "res://addons/vest/runner/vest-base-runner.gd"
class_name VestDaemonRunner

## Runs tests in a separate, background process

var _server: TCPServer
var _port: int
var _peer: StreamPeerTCP

var _is_debug_run := false

## Enable debug mode for the next run
func with_debug() -> VestDaemonRunner:
	_is_debug_run = true
	return self

## Run a test script
func run_script(script: Script, only_mode: int = Vest.__.ONLY_DEFAULT) -> VestResult.Suite:
	var params := VestCLI.Params.new()
	params.run_file = script.resource_path
	params.only_mode = only_mode

	return await _run_with_params(params)

## Run test scripts matching glob
## [br][br]
## See [method String.match]
func run_glob(glob: String, only_mode: int = Vest.__.ONLY_DEFAULT) -> VestResult.Suite:
	var params := VestCLI.Params.new()
	params.run_glob = glob
	params.only_mode = only_mode

	return await _run_with_params(params)

func _run_with_params(params: VestCLI.Params) -> VestResult.Suite:
	var timeout := Vest.timeout(Vest.get_runner_timeout())

	# Start host
	if _start(-1) != OK:
		push_error("Couldn't start vest host!")
		return null

	# Start process
	params.host = "127.0.0.1"
	params.port = _port
	if not _is_debug_run:
		VestCLI.run(params)
	else:
		_is_debug_run = false
		VestCLI.debug(params)

	# Wait for agent to connect
	if await timeout.until(func(): return _server.is_connection_available()) != OK:
		push_error("Agent didn't connect in time!")
		return null

	_peer = _server.take_connection()
	var results = null

	while true:
		await Vest.sleep()

		_peer.poll()
		if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			break

		if _peer.get_available_bytes() <= 0:
			# No data, wait some more
			continue

		var message = _peer.get_var(true)
		if message is Dictionary:
			results = message
			on_partial_result.emit(VestResult.Suite._from_wire(results))

	_stop()

	if results == null:
		push_error("Test run failed!")
		return null
	elif results is Dictionary:
		var suite_result = VestResult.Suite._from_wire(results)
		return suite_result
	else:
		push_error("Unrecognized test result data! %s" % [results])
		return null

func _start(port: int = -1):
	# Start host
	_server = TCPServer.new()

	# Find random port for host
	if port < 0:
		for i in range(32):
			port = randi_range(49152, 65535)
			if _server.listen(port, "127.0.0.1") == OK:
				break
	else:
		_server.listen(port, "127.0.0.1")
	_port = port

	if not _server.is_listening():
		push_error("Failed to find available port!")
		return ERR_CANT_CREATE

	return OK

func _stop():
	_peer.disconnect_from_host()
	_server.stop()

	_peer = null
	_server = null
	_port = -1
