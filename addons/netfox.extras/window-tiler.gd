extends Node

var prefix := "instance"
var sid := "%d" % [Time.get_unix_time_from_system()]
var uid := "%d" % [Time.get_unix_time_from_system() * 1000_0000.]

static var _logger := _NetfoxLogger.for_extras("WindowTiler")

func _ready() -> void:
	_logger.debug("Tiling with sid: %s, uid: %s" % [sid, uid])
	_cleanup()
	_make_lock(sid, uid)
	
	await get_tree().create_timer(0.25).timeout
	var locks = _list_lock_ids()

	var tile_count = locks.size()
	var idx = locks.find(uid)
	
	_logger.debug("Tiling as idx %d / %d - %s in %s" % [idx, tile_count, uid, locks])
	tile_window(idx, tile_count)

func _make_lock(sid: String, uid: String) -> Error:
	var path = "%s/%s-%s-%s" % [OS.get_cache_dir(), prefix, sid, uid]
	var file := FileAccess.open(path, FileAccess.WRITE)
	
	if file == null:
		return FileAccess.get_open_error()
	
	file.close()
	return Error.OK

func _list_lock_ids() -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(OS.get_cache_dir())
	
	if dir:
		for f in dir.get_files():
			if f.begins_with(prefix):
				result.append(_get_uid(f))
	
	return result

func _cleanup():
	var result: Array[String] = []
	var dir := DirAccess.open(OS.get_cache_dir())
	
	if dir:
		for f in dir.get_files():
			if f.begins_with(prefix) and _get_sid(f) != sid:
					_logger.trace("Cleaned up lock: %s" % [f])
					dir.remove(OS.get_cache_dir() + "/" + f)

func _get_sid(filename: String) -> String:
	return filename.get_slice("-", 1)

func _get_uid(filename: String) -> String:
	return filename.get_slice("-", 2)

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
