extends CharacterBody3D
class_name BrawlerController

@export var speed = 5.0
@export var jump_velocity = 4.5
@export var input: BrawlerInput
@export var spawn_point: Vector3 = Vector3(0, 4, 0)
@export var death_depth: float = 4.0
@export var respawn_time: float = 4.0
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var weapon: Weapon3D = $Weapon as Weapon3D
@onready var mesh: MeshInstance3D = $"bomber-guy/rig/Skeleton3D/Cube_008"
@onready var nametag: Label3D = $Nametag

var player_name: String = "":
	set(name):
		if name.length() > 24:
			name = name.substr(0, 21) + "..."
		player_name = name
		nametag.text = name

var player_id: int = -1
var last_hit_player: BrawlerController
var last_hit_tick: int = -1
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var respawn_tick: int = -1
var last_respawn: int = -1

func _ready():
	if not input:
		input = $Input

	position = spawn_point

	# TODO: What if the RollbackSynchronizer had a flag for this?
	await get_tree().process_frame
	$RollbackSynchronizer.process_settings()
	
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
	var movement = Vector3(input.movement.x, 0, input.movement.z) * speed
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
	animation_tree.set("parameters/ThrowScale/scale", min(weapon.fire_cooldown / (10 / 24), 1.0))

func _tick(delta, tick):
	if not NetworkRollback.is_rollback():
		# Take a second between respawns at the very least
		if position.y < -death_depth and tick > respawn_tick + 1 * NetworkTime.tickrate:
			respawn_tick = tick + respawn_time * NetworkTime.tickrate
			GameEvents.on_brawler_fall.emit(self)
			print("[%s] Detected fall! Respawning on tick %s + %s -> %s" % [multiplayer.get_unique_id(), tick, respawn_time * NetworkTime.tickrate, respawn_tick])
		if tick == respawn_tick:
			GameEvents.on_brawler_respawn.emit(self)
		
		# Run throw animation if firing
		if weapon.last_fire == tick:
			animation_tree.set("parameters/Throw/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	else:
		# Process respawn
		if tick >= respawn_tick and last_respawn < respawn_tick:
			position = spawn_point
			velocity = Vector3.ZERO
			last_respawn = tick
			last_hit_tick = -1
			print("[%s] Reset position and velocity to respawn at tick %s" % [multiplayer.get_unique_id(), tick])

		# Add the gravity.
		_force_update_is_on_floor()
		if not is_on_floor():
			velocity.y -= gravity * delta

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
		velocity *= NetworkTime.physics_factor
		move_and_slide()
		velocity /= NetworkTime.physics_factor

func _exit_tree():
	GameEvents.on_brawler_despawn.emit(self)

func _force_update_is_on_floor():
	var old_velocity = velocity
	velocity *= 0
	move_and_slide()
	velocity = old_velocity
