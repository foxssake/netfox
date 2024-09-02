extends Node
# Only used for Forest Brawl example

var local_player_id: int = -1
var local_player_joined_at_tick: int = -1

var player_ids: Array[int] = [] #Server is always Player(0)
var players_joined_at_tick: Array[int] = []
var peer_ids_to_player_ids: Dictionary #<player_id, peer_id>
var player_ids_to_peer_ids: Dictionary #peer_id, player_id>

var session_id: int = -1

#signal on_set()

func _ready():
	NetworkEvents.on_client_start.connect(_handle_connected_to_server)
	NetworkEvents.on_server_start.connect(_handle_host)
	NetworkEvents.on_peer_join.connect(_handle_new_peer)
	
func _handle_host():
	local_player_id = 0
	local_player_joined_at_tick = 0
	
	player_ids.append(local_player_id)
	peer_ids_to_player_ids[1] = local_player_id
	player_ids_to_peer_ids[local_player_id] = 1
	
	session_id = randi()

func _handle_connected_to_server(id: int):
	print("Handle connected %s" % id)

func _handle_new_peer(new_peer_id: int):
	if (multiplayer.is_server()):
		var new_player_id: int = player_ids.size()
		peer_ids_to_player_ids[new_peer_id] = new_player_id
		player_ids_to_peer_ids[new_player_id] = new_peer_id
		player_ids.append(new_player_id)
		
		print("Sending as server, to new peer %s" % new_peer_id)
		set_starting_values.rpc_id(new_peer_id, session_id, peer_ids_to_player_ids)
		
		for picked_peer_id in multiplayer.get_peers():
			if (picked_peer_id != new_peer_id):
				update_values.rpc_id(picked_peer_id, new_peer_id)
	print("Handle new peer %s" % new_peer_id)

@rpc("authority", "reliable", "call_remote")
func set_starting_values(received_session_id: int, received_peer_ids_to_player_ids: Dictionary):
	session_id = received_session_id
	
	peer_ids_to_player_ids = received_peer_ids_to_player_ids
	
	local_player_id = peer_ids_to_player_ids[multiplayer.get_unique_id()]
	
	for picked_peer_id in peer_ids_to_player_ids:
		player_ids_to_peer_ids[peer_ids_to_player_ids[picked_peer_id]] = picked_peer_id
		player_ids.append(peer_ids_to_player_ids[picked_peer_id])

@rpc("authority", "reliable", "call_remote")
func update_values(new_peer_id: int):
	var new_player_id: int = player_ids.size()
	peer_ids_to_player_ids[new_peer_id] = new_player_id
	player_ids_to_peer_ids[new_player_id] = new_peer_id
	player_ids.append(new_player_id)
