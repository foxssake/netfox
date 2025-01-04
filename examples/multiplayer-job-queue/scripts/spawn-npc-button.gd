extends StaticBody3D

@export var spawner: MultiplayerSpawner

var npc_scene: PackedScene = load("res://examples/multiplayer-job-queue/scenes/npc.tscn")

func _ready():
	spawner.spawn_function = _on_spawn
	
func _on_spawn(data):
	return npc_scene.instantiate()

func interact():
	if !is_multiplayer_authority(): return
	spawner.spawn()
