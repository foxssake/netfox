extends BaseMenu

@onready var confirm_button := %"Confirm Button" as Button

@onready var player_name_input := %"Player Name Input" as LineEdit
@onready var randomize_button := %"Randomize Button" as Button
@onready var always_randomize_checkbox := %"Always Randomize CheckBox" as CheckBox
@onready var force_relay_checkbox := %"Force relay CheckBox"
@onready var fullscreen_toggle := %"Fullscreen CheckButton" as CheckButton
@onready var vsync_toggle := %"V-Sync CheckButton" as CheckButton
@onready var confine_mouse_toggle := %"Confine Mouse CheckButton" as CheckButton
@onready var volume_slider := %"Volume Slider" as HSlider

var _settings: ForestBrawlSettings

func _ready() -> void:
	super()

	_settings = ForestBrawlSettings.load()
	_apply_settings(_settings)

	player_name_input.text_changed.connect(func(__): _on_change())
	always_randomize_checkbox.toggled.connect(func(__): _on_change())
	force_relay_checkbox.toggled.connect(func(__): _on_change())
	fullscreen_toggle.toggled.connect(func(__): _on_change())
	vsync_toggle.toggled.connect(func(__): _on_change())
	confine_mouse_toggle.toggled.connect(func(__): _on_change())
	volume_slider.changed.connect(func(__): _on_change())

	confirm_button.pressed.connect(_confirm)
	randomize_button.pressed.connect(_randomize_name)

func _execute() -> void:
	_settings = ForestBrawlSettings.load()
	_render_settings(_settings)

func _cancel() -> void:
	if _settings:
		_settings.save()
		ForestBrawlSettings.set_active(_settings)
		print("Saved settings: %s" % _settings.serialize())

func _randomize_name():
	player_name_input.text = NameProvider.name()

func _confirm() -> void:
	_back()

func _on_change() -> void:
	_settings = _read_settings()
	_apply_settings(_settings)

func _render_settings(settings: ForestBrawlSettings) -> void:
	player_name_input.text = settings.player_name
	always_randomize_checkbox.set_pressed_no_signal(settings.randomize_name)
	force_relay_checkbox.set_pressed_no_signal(settings.force_relay)
	fullscreen_toggle.set_pressed_no_signal(settings.full_screen)
	vsync_toggle.set_pressed_no_signal(settings.vsync)
	confine_mouse_toggle.set_pressed_no_signal(settings.confine_mouse)
	volume_slider.set_value_no_signal(lerpf(volume_slider.min_value, volume_slider.max_value, settings.master_volume))

func _read_settings() -> ForestBrawlSettings:
	var settings := ForestBrawlSettings.new()

	settings.player_name = player_name_input.text
	settings.randomize_name = always_randomize_checkbox.button_pressed
	settings.force_relay = force_relay_checkbox.button_pressed
	settings.full_screen = fullscreen_toggle.button_pressed
	settings.vsync = vsync_toggle.button_pressed
	settings.confine_mouse = confine_mouse_toggle.button_pressed
	settings.master_volume = inverse_lerp(volume_slider.min_value, volume_slider.max_value, volume_slider.value)

	return settings

func _apply_settings(settings: ForestBrawlSettings) -> void:
	# Randomize name
	player_name_input.editable = not settings.randomize_name

	# Full screen
	if settings.full_screen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	# V-sync
	if settings.vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ADAPTIVE)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	# Confine mouse
	if settings.confine_mouse:
		DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_CONFINED)
	else:
		DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)

	# Volume
	var volume = lerp(-60, 0, settings.master_volume)
	var mute = volume < -59.5

	AudioServer.set_bus_volume_db(0, volume)
	AudioServer.set_bus_mute(0, mute)
