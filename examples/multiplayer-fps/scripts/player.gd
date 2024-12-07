extends CharacterBody3D

@export var speed = 5.0
@export var jump_strength = 5.0

@onready var display_name := $DisplayNameLabel3D as Label3D
@onready var input := $Input as PlayerInputFPS
@onready var tick_interpolator := $TickInterpolator as TickInterpolator
@onready var head := $Head as Node3D
@onready var hud := $HUD as CanvasGroup

static var _logger := _NetfoxLogger.new("game", "Player")

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var health: int = 100
var pending_damage: int = 0
@export var death_tick: int = -1
@export var respawn_position: Vector3
var did_respawn := false

func _ready():
	display_name.text = name
	position = Vector3(0, 4, 0)
	hud.hide()
	
	NetworkRollback.before_loop.connect(func(): did_respawn = false)
	NetworkTime.on_tick.connect(_tick)

func _tick(dt: float, tick: int):
	if health <= 0:
		$DieSFX.play()
		die()
		tick_interpolator.teleport()
	
	if did_respawn:
		tick_interpolator.teleport()

# Callback during rollback tick
func _rollback_tick(delta: float, tick: int, is_fresh: bool) -> void:
	if tick == death_tick:
		global_position = respawn_position
		did_respawn = true
	
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

func _force_update_is_on_floor():
	var old_velocity = velocity
	velocity = Vector3.ZERO
	move_and_slide()
	velocity = old_velocity

func damage():
	$HitSFX.play()
	if is_multiplayer_authority():
		health -= 34
		_logger.warning("%s HP now at %s", [name, health])

func die():
	if not is_multiplayer_authority():
		return

	_logger.warning("%s died", [name])
#	respawn_position = get_parent().get_next_spawn_point().global_position
	respawn_position = global_position + Vector3.RIGHT
	death_tick = NetworkTime.tick

	health = 100
