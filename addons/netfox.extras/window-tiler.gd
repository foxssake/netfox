extends Node


func _ready() -> void:
	EngineDebugger.register_message_capture("tile-session", _on_tile_session)
	EngineDebugger.send_message.call_deferred("tile-session:get_id", [])


func _on_tile_session(message: String, data: Array) -> bool:
	if message == "session_id":
		var info: Dictionary = data[0]
		var id = info.get("id", -1)
		var total = info.get("total", 0)
		if total > 1:
			for i in range(total):
				if i == id:
					tile_window(i, total)
		return true
	return false


func tile_window(i: int, total: int) -> void:

	if not ProjectSettings.get_setting("netfox/extras/auto_tile_windows", true):
		return

	var screen = ProjectSettings.get_setting("netfox/extras/screen", 0)
	var screen_rect = DisplayServer.screen_get_usable_rect(screen)

	var window: Window = get_tree().get_root()
	window.set_current_screen(screen)
	window.borderless = ProjectSettings.get_setting("netfox/extras/borderless", true)

	# Divide up the screen

	var windows_per_row = int(ceil(sqrt(total)))
	var windows_per_col = int(ceil(total / float(windows_per_row)))
	var window_size = Vector2(
		screen_rect.size.x / windows_per_row, screen_rect.size.y / windows_per_col
	)

	window.set_size(window_size)

	# Position of the window based on index.

	var row = i / windows_per_row
	var col = i % windows_per_row

	var x = screen_rect.position.x + col * window_size.x
	var y = screen_rect.position.y + row * window_size.y

	window.set_position(Vector2(x, y))
