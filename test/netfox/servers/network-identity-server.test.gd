extends VestTest

func get_suite_name() -> String:
	return "NetworkIdentityServer"

var command_server: TestingCommandServer
var identity_server: _NetworkIdentityServer

var node: Node
var orphan_node: Node

func before_case(__):
	# Makes sure local peer is 1, otherwise identifiers get random local IDs
	Vest.get_tree().root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	
	command_server = TestingCommandServer.new()
	identity_server = _NetworkIdentityServer.new(command_server)

	node = Node.new()
	node.name = "Node"

	orphan_node = Node.new()

	Vest.get_tree().root.add_child.call_deferred(node)
	Vest.get_tree().root.add_child.call_deferred(command_server)
	Vest.get_tree().root.add_child.call_deferred(identity_server)

	await node.ready
	await command_server.ready
	await identity_server.ready

func after_case(__):
	identity_server.queue_free()
	command_server.queue_free()
	node.queue_free()
	orphan_node.queue_free()

func suite() -> void:
	define("register_node()", func():
		test("should register", func():
			# Register node
			identity_server.register_node(node)

			# Assert for identifier
			var identifier := identity_server._get_identifier_of(node)
			expect_not_null(identifier)
			expect_equal(identifier.get_full_name(), "/root/Node")
		)
		
		test("should fail on node node in tree", func():
			# Register node
			identity_server.register_node(orphan_node)

			# Assert for identifier
			var identifier := identity_server._get_identifier_of(orphan_node)
			expect_null(identifier)
		)
	)

	define("deregister_node()", func():
		test("should remove known", func():
			# Register node
			identity_server.register_node(node)
			expect_not_null(identity_server._get_identifier_of(node))

			# Deregister
			identity_server.deregister_node(node)
			expect_null(identity_server._get_identifier_of(node))
		)

		test("should do nothing on unknown", func():
			identity_server.deregister_node(orphan_node)
			expect_null(identity_server._get_identifier_of(orphan_node))
		)
	)
	
	define("flush_queue()", func():
		test("should send ids", func():
			# Register node
			identity_server.register_node(node)
			
			var identifier := identity_server._get_identifier_of(node)
			var full_name := identifier.get_full_name()
			
			# Try and resolve some unknown identities
			identity_server._resolve_reference(2, identifier.reference_for(2))
			identity_server._resolve_reference(3, identifier.reference_for(3))
			
			# Flush queue
			identity_server.flush_queue()
			
			# Check commands sent
			expect_equal(command_server.commands_sent.size(), 2)
			for i in command_server.commands_sent.size():
				var command := command_server.commands_sent[i]

				expect_equal(command[0], _NetworkCommands.IDS)		# Command id
				expect_equal(command[2], 2 + i)						# Peer
				expect_equal(command[3], MultiplayerPeer.TRANSFER_MODE_RELIABLE)
		)
	)
	
	define("_resolve_reference()", func():
		test("should return by id", func():
			# Register node
			identity_server.register_node(node)
			var identifier := identity_server._get_identifier_of(node)
			
			# Resolve
			var reference := _NetworkIdentityReference.of_id(identifier.get_local_id())
			expect_equal(identity_server._resolve_reference(1, reference), identifier)
		)

		test("should return by name", func():
			# Register node
			identity_server.register_node(node)
			var identifier := identity_server._get_identifier_of(node)
			
			# Resolve
			var reference := _NetworkIdentityReference.of_full_name(identifier.get_full_name())
			expect_equal(identity_server._resolve_reference(1, reference), identifier)
		)

		test("should return null on unknown", func():
			var reference := _NetworkIdentityReference.of_full_name("Unknown Node")
			expect_null(identity_server._resolve_reference(1, reference))
		)
	)
