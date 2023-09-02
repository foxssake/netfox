extends Node
class_name ScoreManager

@export var scorescreen: ScoreScreen
@export var hit_threshold_time: float = 8.0
var _scores = {}

func get_score(player: int) -> int:
	return _scores.get(player, 0)

func _ready():
	GameEvents.on_brawler_spawn.connect(_handle_spawn)
	GameEvents.on_brawler_fall.connect(_handle_fall)
	GameEvents.on_brawler_respawn.connect(_handle_respawn)
	GameEvents.on_brawler_despawn.connect(_handle_despawn)
	set_multiplayer_authority(1)

func _handle_spawn(brawler: BrawlerController):
	var id = brawler.player_id
	_scores[id] = _scores.get(id, 0)

func _handle_fall(brawler: BrawlerController):
	var id = brawler.player_id
	
	# Update scores
	if is_multiplayer_authority():
		if NetworkTime.tick - brawler.last_hit_tick < hit_threshold_time * NetworkTime.tickrate \
			and brawler.last_hit_player:
			var hit_id = brawler.last_hit_player.player_id
			_scores[hit_id] = _scores.get(hit_id, 0) + 1
		else:
			_scores[id] = _scores.get(id, 0) - 1
			
		rpc("_submit_scores", _scores)
	
	# Display scoreboard
	if id == multiplayer.get_unique_id():
		scorescreen.render(_scores)
		scorescreen.active = true

func _handle_respawn(brawler: BrawlerController):
	# Hide scoreboard
	if brawler.player_id == multiplayer.get_unique_id():
		scorescreen.active = false

func _handle_despawn(brawler: BrawlerController):
	_scores.erase(brawler.player_id)

@rpc("authority", "reliable", "call_remote")
func _submit_scores(scores: Dictionary):
	print("Received new scores, updating %s -> %s" % [_scores, scores])
	_scores = scores
	
	# Re-render scoreboard if visible
	if scorescreen.active:
		scorescreen.render(_scores)
