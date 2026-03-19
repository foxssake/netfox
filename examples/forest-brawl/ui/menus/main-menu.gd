extends BaseMenu

@onready var quick_play_button := $"Quick Play Button" as Button
@onready var find_game_button := $"Find a Game Button" as Button
@onready var play_lan_button := $"Play LAN Button" as Button
@onready var settings_button := $"Settings Button" as Button
@onready var quit_button := $"Quit Button" as Button

@onready var quick_play_menu := %"Quick Play Menu" as Control
@onready var games_menu := %"Games Menu" as Control
@onready var lan_menu := %"LAN Menu" as Control
@onready var settings_menu := %"Settings Menu" as Control

func _ready() -> void:
	super()

	quick_play_button.pressed.connect(_quick_play)
	find_game_button.pressed.connect(_find_game)
	play_lan_button.pressed.connect(_play_lan)
	settings_button.pressed.connect(_settings)
	quit_button.pressed.connect(_quit)

func _quick_play() -> void:
	_switch_to(quick_play_menu)

func _find_game() -> void:
	_switch_to(games_menu)

func _play_lan() -> void:
	_switch_to(lan_menu)

func _settings() -> void:
	_switch_to(settings_menu)

func _quit() -> void:
	get_tree().quit()
