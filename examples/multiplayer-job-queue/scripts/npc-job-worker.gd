extends NetworkJobWorker

@export var spawner: MultiplayerSpawner

var npc_scene: PackedScene = load("res://examples/multiplayer-job-queue/scenes/npc.tscn")

func _ready():
	spawner.spawn_function = _on_spawn
	
func _on_spawn(data):
	var npc = npc_scene.instantiate()
	npc.uid = data.uid
	return npc
	
## This method is called by the NetworkJobQueue when a job is enqueued.
func job_enqueued(job: Dictionary) -> void:
	spawner.spawn({ "uid": job.uid })
	
## This method is called by the NetworkJobQueue when a job is ready to be processed. You should extend this node and override this method in your own worker.
func process_job(job: Dictionary) -> void:
	busy = true
	# Do something with the job here
	busy = false
	pass
