extends CharacterBody3D

@export var speed = 5.0
@export var jump_strength = 5.0

@onready var display_name: Label3D = $DisplayNameLabel3D
@onready var input: PlayerInputFPS = $Input
@onready var head: Node3D = $Head
@onready var hud: CanvasGroup = $HUD

static var _logger: _NetfoxLogger = _NetfoxLogger.for_netfox("PropertyCache")

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var health: int = 100

func _ready():
	display_name.text = name
	position = Vector3(0, 4, 0)
	hud.hide()

# Callback during rollback tick
func _rollback_tick(delta: float, tick: int, is_fresh: bool) -> void:
	if health <= 0.0:
		$DieSFX.play()
		if is_multiplayer_authority():
			die()
		
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
	
	print(health)

func _force_update_is_on_floor():
	var old_velocity = velocity
	velocity = Vector3.ZERO
	move_and_slide()
	velocity = old_velocity

func damage():
	$HitSFX.play()
	health -= 34
	_logger.warning("%s HP now at %s" % [name, health])

func die():
	_logger.warning("%s Died" % name)
	global_position = get_parent().get_next_spawn_point().global_position
	$TickInterpolator.teleport()
	health = 100
