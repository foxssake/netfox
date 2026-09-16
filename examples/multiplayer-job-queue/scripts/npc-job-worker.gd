extends NetworkJobWorker

@export var spawner: MultiplayerSpawner
@export var spawn_root: Node3D

var npc_scene: PackedScene = load("res://examples/multiplayer-job-queue/scenes/npc.tscn")

func _ready():
	spawner.spawn_function = _on_spawn
	
func _on_spawn(data):
	var npc = npc_scene.instantiate()
	npc.uid = data.uid
	return npc
	
## This method is called by the NetworkJobQueue when a job is enqueued.
func job_enqueued(job: Dictionary) -> void:
	spawner.spawn({ "uid": job._uid })
	
## This method is called by the NetworkJobQueue when a job is ready to be processed. You should extend this node and override this method in your own worker.
func process_job(job: Dictionary) -> void:
	for child in spawn_root.get_children():
		if child.uid == job._uid:
			child.target_waypoint = child.waypoint_count - 1
