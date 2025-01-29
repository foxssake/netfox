extends CharacterBody3D

@export var speed = 5.0
@export var jump_strength = 5.0

@onready var display_name := $DisplayNameLabel3D as Label3D
@onready var input := $Input as PlayerInputFPS
@onready var tick_interpolator := $TickInterpolator as TickInterpolator
@onready var head := $Head as Node3D
@onready var hud := $HUD as CanvasGroup

static var _logger := _NetfoxLogger.new("game", "Player")

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var health: int = 100
var death_tick: int = -1
var respawn_position: Vector3
var did_respawn := false
var deaths := 0

var _last_death_sfx_idx := 0

func _ready():
	display_name.text = name
	hud.hide()

	NetworkTime.after_tick_loop.connect(_after_tick_loop)

func _after_tick_loop():
	if did_respawn:
		tick_interpolator.teleport()
		did_respawn = false

	if deaths > _last_death_sfx_idx:
		$DieSFX.play()
		_last_death_sfx_idx = deaths

func _rollback_tick(delta: float, tick: int, is_fresh: bool) -> void:
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

		_logger.info("%s died", [name])
		global_position = get_parent().get_next_spawn_point(get_player_id(), deaths)
		did_respawn = true

		health = 100

func _force_update_is_on_floor():
	var old_velocity = velocity
	velocity = Vector3.ZERO
	move_and_slide()
	velocity = old_velocity

func damage():
	# $HitSFX.play() # TODO
	health -= 34
	_logger.info("%s HP now at %s", [name, health])

func get_player_id() -> int:
	return input.get_multiplayer_authority()
