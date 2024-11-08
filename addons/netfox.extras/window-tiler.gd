extends Node


func _ready() -> void:

	var u_time = str(Time.get_unix_time_from_system())
	var file = FileAccess.open(str(OS.get_cache_dir(),"/instance-",u_time), FileAccess.WRITE)
	file.close()

	var instance = count_instance_locks()
	await get_tree().create_timer(0.5).timeout
	var total = count_instance_locks()

	tile_window(instance -1, total)

func count_instance_locks() -> int:
	var count = 0
	var dir = DirAccess.open(OS.get_cache_dir())
	if dir:
		for f in dir.get_files():
			if f.begins_with("instance-"):
				count += 1
	return count


func tile_window(i: int, total: int) -> void:

	if not ProjectSettings.get_setting("netfox/extras/auto_tile_windows", true):
		return

	var screen = ProjectSettings.get_setting("netfox/extras/screen", 0)
	var screen_rect = DisplayServer.screen_get_usable_rect(screen)

	var window: Window = get_tree().get_root()
	window.set_current_screen(screen)

	if total == 1:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		return

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
