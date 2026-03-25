extends Node3D
class_name BrawlerWeapon

@export var projectile: PackedScene
@export var fire_cooldown: float = 0.15

@onready var input := $"../Input" as BrawlerInput
@onready var sound: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var fire_action := $"Fire Action" as RewindableAction
@onready var rollback_synchronizer := $"../RollbackSynchronizer" as RollbackSynchronizer

var _last_fired: int = -1

@onready var _logger := NetfoxLogger.new("fb", "BrawlerWeapon:" + owner.name)

func _ready():
	fire_action.mutate(self)

func _can_fire(tick: int) -> bool:
	return NetworkTime.seconds_between(_last_fired, tick) >= fire_cooldown

func _rollback_tick(_dt: float, tick: int, _if: bool) -> void:
	if not rollback_synchronizer.is_predicting():
		# TODO: Document this
		# NOTE: DO NOT set RewindableAction from a predicted tick, it will
		# 		conflict with server auth
		fire_action.set_active(input.is_firing and _can_fire(tick))

	match fire_action.get_status():
		RewindableAction.CONFIRMING, RewindableAction.ACTIVE:
			if not fire_action.has_context():
				_logger.info("Firing")
				var spawn := _spawn()
				fire_action.set_context(spawn)
				sound.play()
			_last_fired = tick
		RewindableAction.CANCELLING:
			if fire_action.has_context():
				_logger.info("Unfiring")
				var spawn := fire_action.get_context() as Node3D
				spawn.queue_free()
				fire_action.erase_context()

func _spawn() -> Node3D:
	var bomb_projectile: BombProjectile = projectile.instantiate() as BombProjectile
	get_tree().root.add_child(bomb_projectile, true)
	bomb_projectile.global_transform = global_transform
	bomb_projectile.fired_by = get_parent()

	return bomb_projectile
