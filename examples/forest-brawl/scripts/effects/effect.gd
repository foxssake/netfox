extends Node3D
class_name Effect

@export var duration: float = 8.0
@export var winddown_time: float = 2.0
@export var particles: GPUParticles3D = null
@export var aura: MeshInstance3D = null

var _apply_tick: int = 0
var _cease_tick: int = 0
var _destroy_tick: int = 0

func _ready():
	if not get_parent() is BrawlerController:
		push_error("Powerup effect added to non-player!")
		queue_free()
		return
	
	set_multiplayer_authority(1)

	NetworkRollback.before_loop.connect(func(): NetworkRollback.notify_resimulation_start(_apply_tick), CONNECT_ONE_SHOT)
	NetworkRollback.on_process_tick.connect(_rollback_tick)
	NetworkTime.on_tick.connect(_tick)
	
	_apply_tick = NetworkTime.tick + 1
	_cease_tick = _apply_tick + NetworkTime.seconds_to_ticks(duration)
	_destroy_tick = max(
		_cease_tick + NetworkTime.seconds_to_ticks(winddown_time),
		_cease_tick + NetworkRollback.history_limit
	)
	
	if particles:
		particles.emitting = false
	
	if aura:
		aura.scale = Vector3.ONE * 0.005

func _process(delta):
	if aura:
		aura.scale = aura.scale.move_toward(Vector3.ONE if is_active() else Vector3.ONE * 0.005, delta * 4)

func _rollback_tick(tick):
	if is_multiplayer_authority() and NetworkRollback.is_simulated(get_target()):
		if tick == _apply_tick:
			_apply()
		if tick == _cease_tick:
			_cease()

func _tick(_delta, tick):
	if particles != null:
		if tick == _apply_tick:
			particles.emitting = true
		if tick == _cease_tick:
			particles.emitting = false
	if tick >= _destroy_tick:
		queue_free()

func _apply():
	pass

func _cease():
	pass

func get_target() -> BrawlerController:
	return get_parent_node_3d() as BrawlerController

func is_active() -> bool:
	var tick = NetworkRollback.tick if NetworkRollback.is_rollback() else NetworkTime.tick
	return tick >= _apply_tick and tick < _cease_tick
