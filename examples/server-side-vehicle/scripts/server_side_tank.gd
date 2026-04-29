extends VehicleBody3D

## Script example for server side coded tank.

@onready var input_sender = $InputSender
@onready var camera_3d = $Camera3D

# Called when the node enters the scene tree for the first time.
func _ready():
	# Await so that player spawner sets our input authority.
	await get_tree().process_frame
	
	if input_sender.get_multiplayer_authority() == multiplayer.get_unique_id():
		camera_3d.current = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
