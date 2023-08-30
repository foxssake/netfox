extends Node3D

@export var duration: float = 8.0
@export var winddown_time: float = 2.0
@export var particles: GPUParticles3D = null
@export var aura: MeshInstance3D = null

var _apply_tick: int = 0
var _cease_tick: int = 0
var _destroy_tick: int = 0

var _did_apply: bool = false
var _did_cease: bool = false

func _ready():
	if not get_parent() is BrawlerController:
		push_error("Powerup effect added to non-player!")
		free()
		return
	
	set_multiplayer_authority(1)
	NetworkRollback.before_loop.connect(func(): NetworkRollback.notify_input_tick(_apply_tick))
	NetworkRollback.on_process_tick.connect(_tick)
	NetworkTime.on_tick.connect(_real_tick)
	
	_apply_tick = NetworkTime.tick + 1
	_cease_tick = _apply_tick + duration * NetworkTime.tickrate
	_destroy_tick = max(
		_cease_tick + winddown_time * NetworkTime.tickrate,
		_cease_tick + NetworkRollback.history_limit
	)
	
	if particles:
		particles.emitting = false
	
	if aura:
		aura.scale = Vector3.ONE * 0.005

func _process(delta):
	if aura:
		aura.scale = aura.scale.move_toward(Vector3.ONE if is_active() else Vector3.ONE * 0.005, delta * 4)

func _tick(tick):
	if is_multiplayer_authority() and NetworkRollback.is_simulated(get_target()):
		if tick == _apply_tick:
			_apply()
		if tick == _cease_tick:
			_cease()

func _real_tick(_delta, _tick):
	if particles != null:
		if _tick == _apply_tick:
			particles.emitting = true
		if _tick == _cease_tick:
			particles.emitting = false
	if _tick >= _destroy_tick:
		queue_free()

func _apply():
	get_target().scale *= 2.0

func _cease():
	get_target().scale /= 2.0

func get_target() -> BrawlerController:
	return get_parent_node_3d() as BrawlerController

func is_active() -> bool:
	var tick = NetworkRollback.tick if NetworkRollback.is_rollback() else NetworkTime.tick
	return tick >= _apply_tick and tick < _cease_tick
