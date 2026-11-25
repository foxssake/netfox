extends Node3D
class_name SimulatedFPSWeapon

@export var fire_cooldown: float = 0.3
@export var bullet_scene : PackedScene = null
@export var camera : Camera3D = null
@export var player : SimulatedFPSPlayer = null

@onready var input: PlayerInputFPS = $"../../Input"
@onready var sound: AudioStreamPlayer3D = $AudioStreamPlayer3D

var last_fire: int = -1

const REMOTE_FIRE_TOLARANCE_TICS : int = 2

var _last_remote_fire : int = -1

func _ready():
	NetworkTime.after_tick_loop.connect(_on_after_tick_loop)

func _simulated_tick(_delta: float, tick: int, is_fresh: bool) -> void:
	if is_fresh and input.fire and _can_fire(tick):
		_fire(tick)

func _can_fire(tick : int) -> bool:
	if last_fire == -1:
		return true
	
	return NetworkTime.seconds_between(last_fire, tick) >= fire_cooldown

func _fire(fired_tick : int) -> void:
	if not bullet_scene or not camera or not player:
		return
	
	# State property, the cooldown in _can_fire() and the fire sound read it
	last_fire = fired_tick
	
	var origin := camera.global_position
	var direction := -camera.global_basis.z
	
	var bullet := bullet_scene.instantiate() as SimulatedBullet
	bullet.fire(origin, direction)
	get_tree().root.add_child(bullet)
	
	if multiplayer.is_server():
		SimulatorServer.register_projectile(bullet, player.get_player_id(), fired_tick)
	
	_on_fire()

func _on_fire():
	sound.play()

func _on_after_tick_loop() -> void:
	
	if NetworkTime.tick - last_fire <= REMOTE_FIRE_TOLARANCE_TICS:
		# Recently fired
		
		if _last_remote_fire == last_fire:
			# We shoved this fire event return
			return
		
		_last_remote_fire = last_fire
		_on_fire()
