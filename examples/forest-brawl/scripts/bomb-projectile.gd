extends ShapeCast3D
class_name BombProjectile

@export var speed: float = 12.0
@export var strength: float = 2.0
@export var effect: PackedScene
@export var distance: float = 128.0

var distance_left: float
var fired_by: Node
var ghost_cooldown := 0

@onready var animation_player := $AnimationPlayer as AnimationPlayer
@onready var animation_tree := $AnimationTree as AnimationTree
@onready var tick_interpolator := $TickInterpolator as TickInterpolator
@onready var synchronizer := $PredictiveSynchronizer as PredictiveSynchronizer

@onready var _original_mask := collision_mask
@onready var _logger := NetfoxLogger.new("fb", self.name)

var _explosion: Node3D = null
var _exploded_tick: int = -1

func _ready():
	distance_left = distance
	animation_player.speed_scale = speed / 8. # Adapt animation to move speed

	# Push inital movement to TickInterpolator
	# This is to avoid the projectile appearing in place for a moment before
	# starting to move
	var offset := basis.z * speed * NetworkTime.ticktime

	position -= offset
	tick_interpolator.push_state()
	position += offset
	tick_interpolator.push_state()

	# Hide for a bit so birth anim can kick in
	# Only `show()` if we haven't exploded by then
	hide()
	await get_tree().create_timer(.05).timeout
	if synchronizer.is_alive(NetworkTime.tick):
		show()

func _rollback_tick(dt: float, _t: int, _if: bool) -> void:
	var dst := speed * dt
	var motion := transform.basis.z * dst
	target_position = Vector3.FORWARD * dst
	distance_left -= dst

	if distance_left < 0:
		synchronizer.despawn()
		return

	# Check if we've hit anyone
	force_shapecast_update()

	# Find the closest point of contact
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.motion = motion
	query.shape = shape
	query.transform = global_transform

	var hit_interval := space.cast_motion(query)
	if hit_interval[0] != 1.0 or hit_interval[1] != 1.0 and not _is_ghost():
		# Move to collision
		position += motion * hit_interval[1]
		_explode()
	else:
		position += motion

	# Skip collisions for some ticks
	ghost_cooldown -= 1

func _rollback_spawn() -> void:
	show()
	collision_mask = _original_mask

func _rollback_despawn() -> void:
	hide()
	_original_mask = collision_mask
	collision_mask = 0

func _is_ghost() -> bool:
	return ghost_cooldown > 0

func _explode(tick: int = NetworkRollback.tick):
	synchronizer.despawn()

	if _exploded_tick == tick and is_instance_valid(_explosion):
		_explosion.global_position = global_position
		return

	if _explosion:
		_explosion.queue_free()

	if effect:
		var spawn = effect.instantiate() as Node3D
		get_tree().root.add_child(spawn)
		spawn.global_position = global_position
		spawn.fired_by = fired_by
		spawn.set_multiplayer_authority(get_multiplayer_authority())

		_explosion = spawn

	_exploded_tick = tick
