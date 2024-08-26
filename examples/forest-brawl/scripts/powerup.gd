extends Area3D

@export var effects: Array[PackedScene] = []
@export var cooldown: float = 30.0

var is_active: bool = true
var fade_speed: float = 8.0

var respawn_tick: int = 0

func _ready():
	NetworkTime.after_tick.connect(_tick)
	set_multiplayer_authority(1)

func _tick(delta, tick):
	if is_active:
		scale = scale.lerp(Vector3.ONE, fade_speed * delta)
		for body in get_overlapping_bodies():
			if body.is_in_group("Brawlers") and not _has_powerup(body):
				_take() # Predict
				if is_multiplayer_authority():
					_spawn_effect.rpc(randi_range(0, effects.size() - 1), body.get_path())
					_take.rpc()
	else:
		scale = scale.lerp(Vector3.ONE * 0.0005, fade_speed * delta)
		if tick == respawn_tick:
			_respawn() # Predict
			if is_multiplayer_authority():
				_respawn.rpc()

func _has_powerup(target: Node) -> bool:
	return target.get_children()\
		.filter(func(child): return child is Effect)\
		.any(func(effect: Effect): return effect.is_active())

@rpc("authority", "reliable", "call_local")
func _spawn_effect(effect_idx: int, target_path: NodePath):
	var effect = effects[effect_idx]
	var target = get_tree().get_root().get_node(target_path)

	var spawn = effect.instantiate()
	target.add_child(spawn)

@rpc("authority", "reliable")
func _take():
	respawn_tick = NetworkTime.tick + NetworkTime.seconds_to_ticks(cooldown)
	is_active = false

@rpc("authority", "reliable")
func _respawn():
	is_active = true
