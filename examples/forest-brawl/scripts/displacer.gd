extends Area3D

@export var duration: float = 0.5
@export var strength: float = 1.0

var birth_tick: int
var death_tick: int
var despawn_tick: int

func _ready():
	birth_tick = NetworkTime.tick
	death_tick = birth_tick + round(duration * NetworkTime.tickrate)
	despawn_tick = death_tick + NetworkRollback.history_limit

	NetworkRollback.on_process_tick.connect(_tick)
	NetworkTime.on_tick.connect(_real_tick)

func _tick(tick):
	if birth_tick <= tick and tick < death_tick:
		for body in get_overlapping_bodies():
			if body.is_in_group("Brawlers") and \
				body.is_multiplayer_authority() and \
				NetworkRollback.is_simulated(body):
				var diff: Vector3 = body.global_position - global_position
				diff.y = 0
				body.global_position += diff.normalized() * strength * NetworkTime.ticktime
				print("[%s][%s] Displaced to %s" % [body.name, tick, body.global_position])

func _real_tick(delta, tick):
	if tick >= death_tick:
		visible = false

	if tick > despawn_tick:
		queue_free()
