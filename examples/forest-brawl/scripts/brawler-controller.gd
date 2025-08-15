extends CharacterBody3D
class_name BrawlerController

# Stats
@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var mass: float = 4.0

# Spawn
@export var spawn_point: Vector3 = Vector3(0, 4, 0)
@export var death_depth: float = 4.0
@export var respawn_time: float = 4.0

# Dependencies
@onready var input := $Input as BrawlerInput
@onready var rollback_synchronizer := $RollbackSynchronizer as RollbackSynchronizer
@onready var animation_tree := $AnimationTree as AnimationTree
@onready var weapon := $Weapon as BrawlerWeapon
@onready var mesh := $"bomber-guy/rig/Skeleton3D/Cube_008" as MeshInstance3D
@onready var nametag := $Nametag as Label3D
@onready var fall_sound := $"Fall Sound" as PlayRandomStream3D

var player_name: String = "":
	set(p_name):
		if p_name.length() > 24:
			p_name = p_name.substr(0, 21) + "..."
		player_name = p_name
		nametag.text = p_name

var player_id: int = -1
var last_hit_player: BrawlerController
var last_hit_tick: int = -1
var gravity = ProjectSettings.get_setting(&"physics/3d/default_gravity")
var respawn_tick: int = -1
var respawn_count: int = 0

func register_hit(from: BrawlerController):
	if from == self:
		push_error("Player %s (#%s) trying to register hit on themselves!" % [player_name, player_id])
		return

	last_hit_player = from
	last_hit_tick = NetworkRollback.tick if NetworkRollback.is_rollback() else NetworkTime.tick

func shove(motion: Vector3):
	move_and_collide(motion / mass)

func _ready():
	if not input:
		input = $Input

	_snap_to_spawn()

	GameEvents.on_brawler_spawn.emit(self)
	NetworkTime.on_tick.connect(_tick)

	if not player_name:
		player_name = "Nameless Brawler #%s" % [player_id]
	
	# Set player color
	var color = Color.from_hsv((hash(player_id) % 256) / 256.0, 1.0, 1.0)
	var material: StandardMaterial3D = mesh.get_active_material(0)
	material = material.duplicate()
	material.albedo_color = color
	mesh.set_surface_override_material(0, material)

func _process(delta):
	# Update animation
	# Running
	var movement = Vector3(velocity.x, 0, velocity.z) * speed
	var relative_velocity = quaternion.inverse() * movement
	relative_velocity.y = 0
	relative_velocity /= speed
	relative_velocity = Vector2(relative_velocity.x, relative_velocity.z)
	var animated_velocity = animation_tree.get("parameters/Move/blend_position") as Vector2

	animation_tree.set("parameters/Move/blend_position", animated_velocity.move_toward(relative_velocity, delta / 0.2))
	
	# Float
	_force_update_is_on_floor()
	var animated_float = animation_tree.get("parameters/Float/blend_amount") as float
	var actual_float = 1.0 if not is_on_floor() else 0.0
	animation_tree.set("parameters/Float/blend_amount", move_toward(animated_float, actual_float, delta / 0.2))
	
	# Speed
	animation_tree.set("parameters/MoveScale/scale", speed / 3.75)
	animation_tree.set("parameters/ThrowScale/scale", min(weapon.fire_cooldown / (10. / 24.), 1.0))

func _tick(_delta, tick):
	# Run throw animation if firing
	if weapon.last_fire == tick:
		animation_tree.set("parameters/Throw/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func _rollback_tick(delta, tick, is_fresh):
	# Respawn
	if tick == respawn_tick:
		_snap_to_spawn()
		velocity = Vector3.ZERO
		last_hit_tick = -1
		
		if is_fresh:
			GameEvents.on_brawler_respawn.emit(self)

	# Skip predictions
	if rollback_synchronizer.is_predicting():
		rollback_synchronizer.ignore_prediction(self)
		return

	# Apply gravity
	_force_update_is_on_floor()
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Stick to moving platforms
	var platform_velocity := Vector3.ZERO
	var collision_result := KinematicCollision3D.new()
	if test_move(global_transform, Vector3.DOWN * delta, collision_result):
		var collider := collision_result.get_collider()
		if collider is MovingPlatform:
			var platform := collider as MovingPlatform
			platform_velocity = platform.get_velocity()

	# Jump
	if input.movement.y > 0 and is_on_floor():
		velocity.y = jump_velocity * input.movement.y

	# Movement
	var direction = Vector3(input.movement.x, 0, input.movement.z).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	
	# Aim
	if input.aim:
		transform = transform.looking_at(position + Vector3(input.aim.x, 0, input.aim.z), Vector3.UP, true).scaled_local(scale)

	# Apply movement
	velocity += platform_velocity
	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor
	velocity -= platform_velocity
	
	# Death
	if position.y < -death_depth and tick > respawn_tick and is_fresh:
		var respawn_cooldown = respawn_time * NetworkTime.tickrate
		respawn_tick = tick + respawn_cooldown
		respawn_count += 1

		fall_sound.play_random()

		GameEvents.on_brawler_fall.emit(self)

func _exit_tree():
	GameEvents.on_brawler_despawn.emit(self)

func _snap_to_spawn():
	var spawns = get_tree().get_nodes_in_group("Spawn Points")
	var idx = hash(player_id + respawn_count * 39) % spawns.size()
	var spawn = spawns[idx] as Node3D
	
	global_transform = spawn.global_transform

func _force_update_is_on_floor():
	var old_velocity = velocity
	velocity *= 0
	move_and_slide()
	velocity = old_velocity
