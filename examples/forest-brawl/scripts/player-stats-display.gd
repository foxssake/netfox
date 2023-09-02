extends Control

@export var score_label: Label
@export var effect_label: Label
@export var score_manager: ScoreManager
var brawler: BrawlerController

func _ready():
	GameEvents.on_own_brawler_spawn.connect(func(b): brawler = b)

func _process(_delta):
	if not brawler:
		visible = false
	else:
		visible = true
		score_label.text = str(score_manager.get_score(brawler.player_id))
