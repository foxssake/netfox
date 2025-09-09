extends Node3D

static var _logger := _NetfoxLogger.new("", "Visibility Manager")

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
		var node := player_nodes[peer] as Node3D
		var rbs := player_synchronizers[peer] as RollbackSynchronizer
		
		# We don't own state
		if not rbs.is_multiplayer_authority(): continue
		
		# Only transmit data to players who can see us
		for other_peer in player_synchronizers:
			if other_peer == peer: continue

			var other_node := player_nodes[other_peer] as Node3D
			var can_see := _check_line_of_sight(node, other_node)
			rbs.visibility_filter.set_visibility_for(other_peer, can_see)

		rbs.visibility_filter.update_visibility()

func _check_line_of_sight(from: Node3D, to: Node3D) -> bool:
	var space := get_world_3d().direct_space_state
	
	var query := PhysicsRayQueryParameters3D.new()
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = 2 # Only collide with level geometry
	query.from = from.global_position
	query.to = to.global_position
	
	return space.intersect_ray(query).is_empty()
