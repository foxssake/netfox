extends Node

class_name PhysicsDriver

# Physics driver based on netfox ticks
# Step physics in time with netfox and participates in rollback

var physics_space: RID
var snapshots: Dictionary = {}
#var snapshots: Dictionary[int, PackedByteArray] = {}

# Number of physics steps to take per tick
@export var physics_factor: int = 1

func _ready() -> void:
	_init_physics_space()

	#regular ticks
	NetworkTime.before_tick.connect(before_tick)
	NetworkTime.after_tick_loop.connect(after_tick_loop)

	#rollback ticks
	NetworkRollback.on_prepare_tick.connect(on_prepare_tick)
	NetworkRollback.after_prepare_tick.connect(after_prepare_tick)

# Emitted before a tick is run.
func before_tick(_delta: float, tick: int) -> void:
	_snapshot_space(tick)
	step_physics(_delta)

func on_prepare_tick(tick: int) -> void:
	if NetworkRollback._rollback_stage == NetworkRollback._STAGE_BEFORE:
		# First tick of rollback loop, rewind
		_rollback_space(tick)
	else:
		# Subsequent ticks are re-writing history.
		_snapshot_space(tick)

func after_prepare_tick(_tick: int) -> void:
	step_physics(NetworkTime.ticktime)

func after_tick_loop() -> void:
	#remove old snapshots
	for i in snapshots.keys():
		if i < NetworkRollback.history_start:
			snapshots.erase(i)

# Break up physics into smaller steps if needed
func step_physics(_delta: float) -> void:
	for i in range(physics_factor):
		_physics_step(_delta / physics_factor)


# Stops physics engine from auto-stepping and takes control of physics loop
func _init_physics_space() -> void:
	pass

func _physics_step(_delta) -> void:
	pass
	
func _snapshot_space(_tick: int) -> void:
	pass

func _rollback_space(_tick) -> void:
	pass
