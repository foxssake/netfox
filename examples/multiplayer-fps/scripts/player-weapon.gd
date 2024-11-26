extends NetworkWeaponHitscan3D
class_name PlayerFPSWeapon

@export var fire_cooldown: float = 0.15

@onready var input: PlayerInputFPS = $"../Input"
@onready var sound: AudioStreamPlayer3D = $AudioStreamPlayer3D

var last_fire: int = -1

func _ready():
	NetworkTime.on_tick.connect(_tick)

func _can_fire() -> bool:
	return NetworkTime.seconds_between(last_fire, NetworkTime.tick) >= fire_cooldown

func _can_peer_use(peer_id: int) -> bool:
	return peer_id == input.get_multiplayer_authority()

func _after_fire():
	last_fire = NetworkTime.tick
	sound.play()

func _on_hit(result: Dictionary):
	var hit_position = result.position
	var hit_normal = result.normal
	var collider = result.collider
	
	print(collider.name)

	pass
	
func _tick(_delta: float, _t: int):
	if input.fire:
		fire()
