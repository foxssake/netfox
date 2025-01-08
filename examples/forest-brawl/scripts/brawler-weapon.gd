extends NetworkWeapon3D
class_name BrawlerWeapon

@export var projectile: PackedScene
@export var fire_cooldown: float = 0.15

@onready var input: BrawlerInput = $"../Input"
@onready var sound: AudioStreamPlayer3D = $AudioStreamPlayer3D

var last_fire: int = -1

static var _logger := _NetfoxLogger.new("fb", "BrawlerWeapon")

func _ready():
	NetworkTime.on_tick.connect(_tick)

func _can_fire() -> bool:
	return NetworkTime.seconds_between(last_fire, NetworkTime.tick) >= fire_cooldown

func _can_peer_use(peer_id: int) -> bool:
	return peer_id == input.get_multiplayer_authority()

func _after_fire(projectile: Node3D):
	var bomb := projectile as BombProjectile
	last_fire = get_fired_tick()
	sound.play()

	_logger.trace("[%s] Ticking new bomb %d -> %d", [bomb.name, get_fired_tick(), NetworkTime.tick])
	for t in range(get_fired_tick(), NetworkTime.tick):
		if bomb.is_queued_for_deletion():
			break
		bomb._tick(NetworkTime.ticktime, t)

func _spawn() -> Node3D:
	var bomb_projectile: BombProjectile = projectile.instantiate() as BombProjectile
	get_tree().root.add_child(bomb_projectile, true)
	bomb_projectile.global_transform = global_transform
	bomb_projectile.fired_by = get_parent()

	return bomb_projectile

func _tick(_delta: float, _t: int):
	if input.is_firing:
		fire()
