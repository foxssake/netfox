extends Node3D

@export var offset: Vector3 = Vector3(0, 2.5, 0)
@export var tween_time: float = 0.2

var is_enabled: bool = true
var target: BrawlerController

func _ready():
	# Start as hidden
	scale = Vector3.ZERO
	is_enabled = false
	
	# Start animation
	$"brawler-crown/AnimationPlayer".play("crown_rotate")
	
	GameEvents.on_scores_updated.connect(_handle_scores)

func _process(delta):
	if not target:
		is_enabled = false
	else:
		var target_pos = target.global_position + offset
		var dst = global_position.distance_squared_to(target_pos)
		global_position = global_position.move_toward(target_pos, dst / tween_time * delta)
		
	scale = scale.move_toward(Vector3.ONE if is_enabled else Vector3.ZERO, delta / tween_time)
	visible = scale.length_squared() > 0.05

func _handle_scores(scores: Dictionary):
	is_enabled = false

	# No crown in single player
	if scores.size() == 1:
		return

	var max_score = scores.values().max()
	var max_players = scores.keys().filter(func(p): return scores[p] == max_score)
	
	# Multiple players share the crown
	if max_players.size() > 1:
		return
	
	var player_id = max_players[0]
	var player = get_tree().get_nodes_in_group("Brawlers")\
		.filter(func(it): return it.player_id == player_id)\
		.pop_back()
	
	target = player
	is_enabled = true
