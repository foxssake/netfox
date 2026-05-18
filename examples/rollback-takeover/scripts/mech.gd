extends CharacterBody3D
class_name TakeoverMech

@export var move_speed := 4.

@onready var mount = $Mount as Node3D
@onready var _logger := NetfoxLogger.new("to", "Mech:" + name)

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var driver: NodePath

static var _all := [] as Array[TakeoverMech]

static func find_in_range(to: Node3D, distance: float = 3.) -> TakeoverMech:
	for mech in _all:
		if mech.global_position.distance_to(to.global_position) < distance:
			return mech
	return null

func take_over(player: TakeoverPlayer) -> bool:
	assert(NetworkRollback.is_rollback(), "Can't take over mech outside of rollback!")
	
	if driver.is_empty():
		driver = player.get_path()
		_logger.info("%s took over", [player])
		return true
	return false

func _enter_tree():
	_all.append(self)

func _exit_tree():
	_all.erase(self)

func _rollback_tick(dt: float, _t: int, _if: bool) -> void:
	_force_update_is_on_floor()
	if not is_on_floor():
		velocity.y -= gravity * dt

	var driver_player: TakeoverPlayer = null
	if not driver.is_empty():
		driver_player = get_node(driver)
	
	if is_instance_valid(driver_player):
		var driver_movement := Vector3(driver_player.input.movement.x, 0., driver_player.input.movement.y)
		var direction = (transform.basis * driver_movement).normalized()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		
		if not direction.is_zero_approx():
			_logger.debug("Driver movement: %.2v", [direction])
		
		driver_player.global_position = mount.global_position
		NetworkRollback.mutate(driver_player)

	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor
	
func _force_update_is_on_floor() -> void:
	var old_velocity = velocity
	velocity *= 0
	move_and_slide()
	velocity = old_velocity
