extends Node

# Hash the game name, so we always get a valid filename
var _prefix: String = "netfox-window-tiler-%x" % [ProjectSettings.get("application/config/name").hash()]

var _sid: String = "%x" % [hash(int(Time.get_unix_time_from_system() / 2.))]
var _uid: String = "%d" % [Time.get_unix_time_from_system() * 1000_0000.]

static var _logger: _NetfoxLogger = _NetfoxLogger.for_extras("WindowTiler")

func _ready() -> void:
	# Running on a non-editor (export template) build
	if OS.has_feature("template"):
		return

	# Cleanup in case some files were left
	_cleanup()

	# Don't tile if disabled
	if not ProjectSettings.get_setting("netfox/extras/auto_tile_windows", false):
		return

	_logger.debug("Tiling with sid: %s, uid: %s" % [_sid, _uid])
	
	var err = _make_lock(_sid, _uid)
	if err != Error.OK:
		_logger.warning("Failed to create lock for tiling, reason: %s" % [error_string(err)])
		return

	# Search for locks, stop once no new locks are found
	var locks = []
	await get_tree().create_timer(0.25).timeout
	for i in range(20):
		await get_tree().create_timer(0.1).timeout
		var new_locks = _list_lock_ids()

		if locks == new_locks:
			break

		locks = new_locks

	var tile_count = locks.size()
	var idx = locks.find(_uid)
	
	_logger.debug("Tiling as idx %d / %d - %s in %s" % [idx, tile_count, _uid, locks])
	_tile_window(idx, tile_count)

func _make_lock(sid: String, uid: String) -> Error:
	var path = "%s/%s-%s-%s" % [OS.get_cache_dir(), _prefix, sid, uid]
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
			if f.begins_with(_prefix):
				result.append(_get_uid(f))
	
	return result

func _cleanup():
	var result: Array[String] = []
	var dir := DirAccess.open(OS.get_cache_dir())
	
	if dir:
		for f in dir.get_files():
			if f.begins_with(_prefix) and _get_sid(f) != _sid:
					_logger.trace("Cleaned up lock: %s" % [f])
					dir.remove(OS.get_cache_dir() + "/" + f)

func _get_sid(filename: String) -> String:
	return filename.substr(_prefix.length() + 1).get_slice("-", 0)

func _get_uid(filename: String) -> String:
	return filename.substr(_prefix.length() + 1).get_slice("-", 1)

func _tile_window(i: int, total: int) -> void:
	var screen = ProjectSettings.get_setting("netfox/extras/screen", 0)
	var screen_rect = DisplayServer.screen_get_usable_rect(screen)

	var window: Window = get_tree().get_root()
	window.set_current_screen(screen)

	if total == 1:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		return

	window.borderless = ProjectSettings.get_setting("netfox/extras/borderless", false)

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
