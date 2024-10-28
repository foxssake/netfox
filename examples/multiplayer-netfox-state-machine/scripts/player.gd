extends CharacterBody3D

@export var state_machine: NetworkedStateMachine

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var current_state_label: Label3D = $StateNameLabel3D

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	position = Vector3(0, 4, 0)
	
	# Wait a single frame, so player spawner has time to set input owner
	await get_tree().process_frame
	$RollbackSynchronizer.process_settings()
	state_machine.set_state(&"Idle")
	state_machine.on_state_changed.connect(func (_old_state, new_state):
		if new_state.name:
			current_state_label.text = new_state.name
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
	var material: StandardMaterial3D = mesh_instance.get_active_material(0).duplicate(15)
	material.albedo_color = color
	mesh_instance.set_surface_override_material(0, material)
