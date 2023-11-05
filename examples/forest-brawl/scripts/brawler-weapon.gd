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
	# print("Time since last fire: %s <?> %s" % [NetworkTime.seconds_between(last_fire, NetworkTime.tick), fire_cooldown])
	return NetworkTime.seconds_between(last_fire, NetworkTime.tick) >= fire_cooldown

# virtual
func _can_peer_use(peer_id: int) -> bool:
	return peer_id == input.get_multiplayer_authority()

# virtual
func _after_fire(projectile: Node):
	print("Resetting last fired for %s" % [projectile.name])
	last_fire = NetworkTime.tick

# virtual
func _spawn() -> Node:
	var p = projectile.instantiate() as BombProjectile
	get_tree().root.add_child(p, true)
	p.global_transform = spawn_at.global_transform
	p.fired_by = get_parent()
	
	return p

# virtual
func _get_data(projectile: Node) -> Dictionary:
	return {
		"global_transform": (projectile as BombProjectile).global_transform
	}

# virtual
func _apply_data(projectile: Node, data: Dictionary):
	(projectile as BombProjectile).global_transform = data["global_transform"]

# virtual
func _is_reconcilable(projectile: Node, request_data: Dictionary, local_data: Dictionary) -> bool:
	var req_transform = request_data["global_transform"] as Transform3D
	var loc_transform = local_data["global_transform"] as Transform3D
	
	var request_pos = req_transform.origin
	var local_pos = loc_transform.origin
	
	return request_pos.distance_to(local_pos) < distance_threshold

# virtual
func _reconcile(projectile: Node, request_data: Dictionary, response_data: Dictionary):
	var bomb = projectile as BombProjectile
	var request_transform = request_data["global_transform"] as Transform3D
	var response_transform = response_data["global_transform"] as Transform3D

	# Damn bro hope this works
	var relative_transform = bomb.global_transform * request_transform.inverse()
	var final_transform = response_transform * relative_transform
	
	bomb.global_transform = final_transform

func _tick(delta, tick):
	if input.is_firing:
		fire()
