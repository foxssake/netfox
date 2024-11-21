extends CharacterBody3D

@export var state_machine: RewindableStateMachine

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var current_state_label: Label3D = $StateNameLabel3D

var color: Color:
	get: return _color
	set(v): set_color(v)

var _color: Color = Color.WHITE

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	position = Vector3(0, 4, 0)
	
	state_machine.state = &"Idle"
	state_machine.on_display_state_changed.connect(func(_old_state, _new_state):
		current_state_label.text = state_machine.state
	)

# Callback during rollback tick
func _rollback_tick(delta: float, tick: int, is_fresh: bool) -> void:
	_force_update_is_on_floor()
	if not is_on_floor():
		velocity.y -= gravity * delta

func _force_update_is_on_floor():
	var old_velocity = velocity
	velocity = Vector3.ZERO
	move_and_slide()
	velocity = old_velocity

func set_color(color: Color):
	if color == _color:
		return
	
	var material: StandardMaterial3D = mesh_instance.get_active_material(0).duplicate()
	material.albedo_color = color
	mesh_instance.set_surface_override_material(0, material)
	
	_color = color
