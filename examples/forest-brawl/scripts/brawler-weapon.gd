extends NetworkedWeapon
class_name BrawlerWeapon

@export var projectile: PackedScene
@export var spawn_at: Node3D
@export var fire_cooldown: float = 0.15
@export var distance_threshold: float = 0.1

@export var input: BrawlerInput

var last_fire: int = -1

func _ready():
	if not input:
		input = $"../Input"
	
	NetworkTime.on_tick.connect(_tick)

func _can_fire() -> bool:
	return NetworkTime.seconds_between(last_fire, NetworkTime.tick) >= fire_cooldown

func _can_peer_use(peer_id: int) -> bool:
	return peer_id == input.get_multiplayer_authority()

func _after_fire(projectile: Node):
	print("Resetting last fired for %s" % [projectile.name])
	last_fire = NetworkTime.tick

func _spawn() -> Node:
	var p = projectile.instantiate() as BombProjectile
	get_tree().root.add_child(p, true)
	p.global_transform = spawn_at.global_transform
	p.fired_by = get_parent()
	
	return p

func _get_data(projectile: Node) -> Dictionary:
	return {
		"global_transform": (projectile as BombProjectile).global_transform
	}

func _apply_data(projectile: Node, data: Dictionary):
	(projectile as BombProjectile).global_transform = data["global_transform"]

func _is_reconcilable(projectile: Node, request_data: Dictionary, local_data: Dictionary) -> bool:
	var req_transform = request_data["global_transform"] as Transform3D
	var loc_transform = local_data["global_transform"] as Transform3D
	
	var request_pos = req_transform.origin
	var local_pos = loc_transform.origin
	
	return request_pos.distance_to(local_pos) < distance_threshold

func _reconcile(projectile: Node, local_data: Dictionary, remote_data: Dictionary):
	var bomb = projectile as BombProjectile
	var local_transform = local_data["global_transform"] as Transform3D
	var remote_transform = remote_data["global_transform"] as Transform3D

	var relative_transform = bomb.global_transform * local_transform.inverse()
	var final_transform = remote_data * relative_transform
	
	bomb.global_transform = final_transform

func _tick(delta, tick):
	if input.is_firing:
		fire()
