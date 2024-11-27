extends CharacterBody3D

@export var state_machine: RewindableStateMachine

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var current_state_label: Label3D = $StateNameLabel3D
@onready var input: PlayerInputFPS = $Input
@onready var head: Node3D = $Head

var color: Color:
	get: return _color
	set(v): set_color(v)

var _color: Color = Color.WHITE
var _material: StandardMaterial3D = StandardMaterial3D.new()

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	# Set spawn position
	position = Vector3(0, 4, 0)
	
	# Set starting state
	state_machine.state = &"Idle"
	current_state_label.text = name
	
	# Ensure material is unique
	mesh_instance.material_override = _material

# Callback during rollback tick
func _rollback_tick(delta: float, tick: int, is_fresh: bool) -> void:
	_force_update_is_on_floor()
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	# Handle look left and right
	rotate_object_local(Vector3(0, 1, 0), input.look_angle.x)
	
	# Handle look up and down
	head.rotate_object_local(Vector3(1, 0, 0), input.look_angle.y)
	
	head.rotation.x = clamp(head.rotation.x, -1.57, 1.57)
	head.rotation.z = 0
	head.rotation.y = 0

func _force_update_is_on_floor():
	var old_velocity = velocity
	velocity = Vector3.ZERO
	move_and_slide()
	velocity = old_velocity

func set_color(color: Color):
	if color == _color:
		return

	_material.albedo_color = color
	_color = color
