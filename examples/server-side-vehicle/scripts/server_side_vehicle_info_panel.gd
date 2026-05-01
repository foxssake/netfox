extends Control

# Server side vehicle info panel
@onready var peer_label : Label = $MarginContainer/VBoxContainer/PeerLabel as Label
@onready var reload_progress_bar = $MarginContainer2/VBoxContainer/ReloadProgressBar
@onready var reload_label = $MarginContainer2/VBoxContainer/ReloadLabel
@onready var score_label = $MarginContainer2/VBoxContainer/ScoreLabel

# Called when the node enters the scene tree for the first time.
func _ready():
	peer_label.text = "Server Side Vehicle Example \n Peer#" + str(multiplayer.get_unique_id())

func _process(_delta):
	var tank = get_parent()
	if not tank:
		return
	
	var percentage = (NetworkTime.tick - tank._last_fire_tick) as float / tank.fire_cooldown_tick as float
	reload_progress_bar.value = percentage * 100.0
	
	if reload_progress_bar.value > 99:
		reload_label.text = "Loaded"
	else:
		reload_label.text = "Loading"
	
	score_label.text = str(tank.score)
