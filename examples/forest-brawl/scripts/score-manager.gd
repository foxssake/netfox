extends Node
class_name ScoreManager

@export var scorescreen: ScoreScreen
@export var hit_threshold_time: float = 8.0
var _scores = {}
var _brawlers = {}

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
	_brawlers[id] = brawler

func _handle_fall(brawler: BrawlerController):
	var id = brawler.player_id
	
	# Update scores
	if is_multiplayer_authority():
		if NetworkTime.seconds_between(brawler.last_hit_tick, NetworkTime.tick) < hit_threshold_time \
			and brawler.last_hit_player:
			var hit_id = brawler.last_hit_player.player_id
			_scores[hit_id] = _scores.get(hit_id, 0) + 1
		else:
			_scores[id] = _scores.get(id, 0) - 1
			
		GameEvents.on_scores_updated.emit(_scores)
		_submit_scores.rpc(_scores)
	
	# Display scoreboard
	if id == multiplayer.get_unique_id():
		scorescreen.render(_render_scores())
		scorescreen.active = true

func _handle_respawn(brawler: BrawlerController):
	# Hide scoreboard
	if brawler.player_id == multiplayer.get_unique_id():
		scorescreen.active = false

func _handle_despawn(brawler: BrawlerController):
	_scores.erase(brawler.player_id)
	_brawlers.erase(brawler.player_id)

@rpc("authority", "reliable", "call_remote")
func _submit_scores(scores: Dictionary):
	print("Received new scores, updating %s -> %s" % [_scores, scores])
	_scores = scores
	GameEvents.on_scores_updated.emit(_scores)
	
	# Re-render scoreboard if visible
	if scorescreen.active:
		scorescreen.render(_render_scores())

func _render_scores() -> Dictionary:
	var render_scores = {}
	for pid in _scores:
		var brawler = _brawlers[pid]
		var score = _scores[pid]
		render_scores[brawler.player_name] = score
	return render_scores
