extends VestTest

func get_suite_name() -> String:
	return "NetworkTickrateHandshake"

func suite() -> void:
	var base_tickrate := 60
	var mismatching_tickrate := 48
	
	on_case_begin.connect(func(__):
		# Reset tickrate
		NetworkMocks.set_tickrate(base_tickrate)
	)
	
	test("client should disconnect on mismatch", func():
		# Difficult to pretend we're a client AND detect a disconnect
		todo()
	)

	test("client should adjust on mismatch", func():
		var handshake := await get_handshake(false)
		handshake.mismatch_action = NetworkTickrateHandshake.ADJUST
		
		handshake.submit_tickrate(mismatching_tickrate)
		expect_equal(NetworkTime.tickrate, mismatching_tickrate, "Tickrate was not adjusted!")
	)

	test("server should not adjust on mismatch", func():
		var handshake := await get_handshake(true)
		handshake.mismatch_action = NetworkTickrateHandshake.ADJUST
		
		handshake.submit_tickrate(mismatching_tickrate)
		expect_equal(NetworkTime.tickrate, base_tickrate, "Tickrate was adjusted!")
	)

	test("client should emit signal on mismatch", func():
		var handshake := await get_handshake(false)
		handshake.mismatch_action = NetworkTickrateHandshake.SIGNAL
		capture_signal(handshake.on_tickrate_mismatch, 2)
		
		handshake.submit_tickrate(mismatching_tickrate)
		
		expect_equal(
			get_signal_emissions(handshake.on_tickrate_mismatch),
			[[0, mismatching_tickrate]]
		)
	)

func get_handshake(is_authority: bool) -> TestingTickrateHandshake:
	var handshake := TestingTickrateHandshake.new(is_authority)
	
	# Add to tree
	# TODO(vest): Use Vest.get_tree() after upgrade
	Vest._scene_tree.root.add_child.call_deferred(handshake)
	await handshake.ready
	
	return handshake

class TestingTickrateHandshake extends NetworkTickrateHandshake:
	var _is_tickrate_auth: bool
	
	func _init(p_is_tickrate_auth: bool):
		_is_tickrate_auth = p_is_tickrate_auth
	
	func submit_tickrate(tickrate: int):
		_submit_tickrate(tickrate)
		
	func _is_authority() -> bool:
		return _is_tickrate_auth
