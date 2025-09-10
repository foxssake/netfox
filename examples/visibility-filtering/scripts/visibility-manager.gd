extends Node3D

func _ready() -> void:
	NetworkRollback.on_process_tick.connect(_rollback_tick)

func _rollback_tick(_t: int) -> void:
	var player_nodes := {}
	var player_synchronizers := {}

	# NOTE: Input broadcast must be turned off for this to work
	for player in get_tree().get_nodes_in_group("Players"):
		var rbs := player.get_node("RollbackSynchronizer")
		var peer := player.get_node("Input").get_multiplayer_authority()

		player_nodes[peer] = player
		player_synchronizers[peer] = rbs

	for peer in player_synchronizers:
		var node := player_nodes[peer] as ExampleVisibilityFiltering.Player
		var rbs := player_synchronizers[peer] as RollbackSynchronizer
		
		# We don't own state
		if not rbs.is_multiplayer_authority(): continue
		
		# Only transmit data to players who can see us
		for other_peer in player_synchronizers:
			if other_peer == peer: continue

			var other_node := player_nodes[other_peer] as ExampleVisibilityFiltering.Player
			var can_see := node.can_see(other_node)
			rbs.visibility_filter.set_visibility_for(other_peer, can_see)

		rbs.visibility_filter.update_visibility()
