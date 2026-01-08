extends VestTest

func get_suite_name() -> String:
	return "NetworkIdentityServer"

func suite() -> void:
	define("register_node()", func():
		test("should register", func():
			# Register node
			# Assert for identifier
			todo()
		)
		
		test("should fail on node node in tree", func(): todo())
	)

	define("deregister_node()", func():
		test("should remove known", func(): todo())
		test("should do nothing on unknown", func(): todo())
	)
	
	define("flush_queue()", func():
		test("should send ids", func(): todo())
	)
	
	define("resolve_reference()", func():
		test("should return by id", func(): todo())
		test("should return by name", func(): todo())
		test("should return null on unknown", func(): todo())
		test("should queue on name", func(): todo())
	)
