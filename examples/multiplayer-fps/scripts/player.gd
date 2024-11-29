extends CharacterBody3D

@export var state_machine: RewindableStateMachine

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var current_state_label: Label3D = $StateNameLabel3D
@onready var input: PlayerInputFPS = $Input
@onready var head: Node3D = $Head
@onready var hud: CanvasGroup = $HUD
@onready var health: Health = $Health

static var _logger: _NetfoxLogger = _NetfoxLogger.for_netfox("PropertyCache")

var color: Color:
	get: return _color
	set(v): set_color(v)

var _color: Color = Color.WHITE
var _material: StandardMaterial3D = StandardMaterial3D.new()

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var teleport_position = null

func _ready():
	# Set spawn position
	position = Vector3(0, 4, 0)
	
	# Set starting state
	state_machine.state = &"Idle"
	current_state_label.text = name
	
	# Ensure material is unique
	mesh_instance.material_override = _material
	hud.hide()
	health.health_depleted.connect(func ():
		health.set_health(100)
		die(get_parent().get_next_spawn_point().global_position)
	)

# Callback during rollback tick
func _rollback_tick(delta: float, tick: int, is_fresh: bool) -> void:
	if teleport_position:
		global_position = teleport_position
		$TickInterpolator.teleport()
		teleport_position = null
	elif is_multiplayer_authority():
		visible = true
		
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

func damage():
	if is_multiplayer_authority():
		$HitSFX.play()
		health.add_health(-33)

func die(new_global_position: Vector3):
	$DieSFX.play()
	_logger.warning("%s Died" % name)
	teleport_position = new_global_position
	visible = false
