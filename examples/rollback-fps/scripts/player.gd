extends CharacterBody3D

@export var speed = 5.0
@export var jump_strength = 5.0

@onready var display_name := $DisplayNameLabel3D as Label3D
@onready var input := $Input as ExampleRollbackFPS.PlayerInput
@onready var tick_interpolator := $TickInterpolator as TickInterpolator
@onready var head := $Head as Node3D
@onready var camera := $Head/Camera3D as Camera3D
@onready var hit_sfx := $"Hit SFX" as AudioStreamPlayer3D
@onready var rollback_synchronizer := $RollbackSynchronizer as RollbackSynchronizer

#+#
static var _logger := NetfoxLogger.new("game", "Player")

var gravity = ProjectSettings.get_setting(&"physics/3d/default_gravity")
var health: int = 100
var death_tick: int = -1
var respawn_position: Vector3
var did_respawn := false
var deaths := 0

# Track deaths and *acknowledged* deaths
# Acknowledge the number of deaths on tick loop start
# If the value changes by the end of the loop, that means the player has
# respawned, and needs to `teleport()`
var _ackd_deaths := 0

var _was_hit := false

func _ready():
	display_name.text = name

	NetworkTime.before_tick_loop.connect(_before_tick_loop)
	NetworkTime.after_tick_loop.connect(_after_tick_loop)

	## Testing the new state schemas
	rollback_synchronizer.set_state_schema({
		":velocity": NetfoxSchemas.vec3(),
		":health": NetfoxSchemas.uint8(),     # Fits 0-255
		":deaths": NetfoxSchemas.uint16(),    # Fits 0-65535
		"Head/PlayerFPSWeapon:last_fire": NetfoxSchemas.int32()
	})

	# Wait for deps to setup
	await get_tree().process_frame
	if input.is_multiplayer_authority():
		camera.current = true
		ExampleRollbackFPS.HUD.set_player(self)

func _before_tick_loop():
	_ackd_deaths = deaths

func _after_tick_loop():
	if _ackd_deaths != deaths:
		tick_interpolator.teleport()
		_ackd_deaths = deaths

	if _was_hit:
		hit_sfx.play()
		_was_hit = false

func _rollback_tick(delta: float, tick: int, is_fresh: bool) -> void:
	# Handle respawn
	if tick == death_tick:
		global_position = respawn_position
		did_respawn = true
	else:
		did_respawn = false

	# Gravity
	_force_update_is_on_floor()
	if is_on_floor():
		if input.jump:
			velocity.y = jump_strength
	else:
		velocity.y -= gravity * delta

	# Handle look left and right
	rotate_object_local(Vector3(0, 1, 0), input.look_angle.x)

	# Handle look up and down
	head.rotate_object_local(Vector3(1, 0, 0), input.look_angle.y)

	head.rotation.x = clamp(head.rotation.x, -1.57, 1.57)
	head.rotation.z = 0
	head.rotation.y = 0

	# Apply movement
	var input_dir = input.movement
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.z)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	# move_and_slide assumes physics delta
	# multiplying velocity by NetworkTime.physics_factor compensates for it
	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor

	# Handle death
	if health <= 0:
		deaths += 1
		global_position = get_parent().get_next_spawn_point(get_player_id(), deaths)
		health = 100

func _force_update_is_on_floor():
	var old_velocity = velocity
	velocity = Vector3.ZERO
	move_and_slide()
	velocity = old_velocity

func damage(amount: int, is_new_hit: bool = false):
	# Queue hit sound
	if is_new_hit:
		_was_hit = true

	health -= amount
	_logger.info("%s HP now at %s", [name, health])

func get_player_id() -> int:
	return input.get_multiplayer_authority()
