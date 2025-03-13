extends NetworkWeaponHitscan3D
class_name PlayerFPSWeapon

@export var fire_cooldown: float = 0.25

@onready var input: PlayerInputFPS = $"../../Input"
@onready var sound: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var bullethole: BulletHole = $BulletHole

var last_fire: int = -1

func _ready():
	NetworkTime.on_tick.connect(_tick)

func _can_fire() -> bool:
	return NetworkTime.seconds_between(last_fire, NetworkTime.tick) >= fire_cooldown

func _can_peer_use(peer_id: int) -> bool:
	return peer_id == input.get_multiplayer_authority()

func _on_fire():
	sound.play()
	
func _after_fire():
	last_fire = NetworkTime.tick

func _on_hit(result: Dictionary):
	bullethole.action(result)
	if result.collider.has_method("damage"):
		result.collider.damage()
	
func _tick(_delta: float, _t: int):
	if input.fire:
		fire()
