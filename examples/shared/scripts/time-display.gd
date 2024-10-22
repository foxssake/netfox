extends Label

func _ready():
	NetworkTime.on_tick.connect(_tick)

func _tick(_delta: float, _t: int):
	pass
	
func _process(_delta):
	text = "Time: %.2f at tick #%d, clock at %.2f%%" % [NetworkTime.time, NetworkTime.tick, NetworkTime.clock_stretch_factor * 100.]
	text += "\nClock offset: %.2fms, Remote offset: %.2fms" % [NetworkTime.clock_offset * 1000., NetworkTime.remote_clock_offset * 1000.]
	text += "\nRemote RTT: %.2fms +/- %.2fms" % [NetworkTimeSynchronizer.rtt * 1000., NetworkTimeSynchronizer.rtt_jitter * 1000.]
	text += "\nFactor: %.2f" % [NetworkTime.tick_factor]
	text += "\nFPS: %s" % [Engine.get_frames_per_second()]

	if not get_tree().get_multiplayer().is_server():
		# Grab latency to server and display
		var enet = get_tree().get_multiplayer().multiplayer_peer as ENetMultiplayerPeer
		if enet == null:
			return
			
		var server = enet.get_peer(1)
		var last_rtt = server.get_statistic(ENetPacketPeer.PEER_LAST_ROUND_TRIP_TIME)
		var last_variance = server.get_statistic(ENetPacketPeer.PEER_LAST_ROUND_TRIP_TIME_VARIANCE)
		var mean_rtt = server.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
		var mean_variance = server.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME_VARIANCE)

		text += "\nLast RTT: %s +/- %s\nMean RTT: %s +/- %s" % [last_rtt, last_variance, mean_rtt, mean_variance]
