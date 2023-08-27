extends Area3D

@export var effects: Array[PackedScene] = []

var is_active: bool = true
var cooldown: float = 4.0
var fade_speed: float = 8.0

var respawn_tick: int = 0

func _ready():
	NetworkTime.after_tick.connect(_tick)
	set_multiplayer_authority(1)

func _tick(delta, tick):
	if is_active:
		scale = scale.lerp(Vector3.ONE, fade_speed * delta)
		for body in get_overlapping_bodies():
			if body.is_in_group("Brawlers"):
				_take() # Predict
				if is_multiplayer_authority():
					# rpc("_spawn_effect", effects.pick_random(), body)
					rpc("_spawn_effect", randi_range(0, effects.size() - 1), body.get_path())
					rpc("_take")
	else:
		scale = scale.lerp(Vector3.ONE * 0.0005, fade_speed * delta)
		if tick == respawn_tick:
			_respawn() # Predict
			if is_multiplayer_authority():
				rpc("_respawn")

@rpc("authority", "reliable", "call_local")
func _spawn_effect(effect_idx: int, target_path: NodePath):
	var effect = effects[effect_idx]
	var target = get_tree().get_root().get_node(target_path)

	var spawn = effect.instantiate()
	target.add_child(spawn)

@rpc("authority", "reliable")
func _take():
	respawn_tick = NetworkTime.tick + cooldown * NetworkTime.tickrate
	is_active = false

@rpc("authority", "reliable")
func _respawn():
	is_active = true
