extends RefCounted

# TODO: Eventually support re-running single tests

func run_script(_script: Script) -> VestResult.Suite:
	# OVERRIDE
	return VestResult.Suite.new()

func run_glob(_p_glob: String) -> VestResult.Suite:
	# OVERRIDE
	return VestResult.Suite.new()

func run_script_at(path: String) -> VestResult.Suite:
	var test_script := load(path)

	if not test_script or not test_script is Script:
		return null

	return run_script(test_script)

func _glob(pattern: String) -> Array[String]:
	var results: Array[String] = []

	var da := DirAccess.open("res://")
	da.include_navigational = false

	var dir_queue := ["res://"]
	var dir_history := []

	# Put an upper limit on iterations, so we can't run into a runaway loop
	for i in range(131072):
		if dir_queue.is_empty():
			break

		var dir_at := dir_queue.pop_front() as String
		da.change_dir(dir_at)
		dir_history.append(dir_at)

		# Add directories to queue
		for dir_name in da.get_directories():
			var dir := _path_join(da.get_current_dir(), dir_name)
			if not dir_history.has(dir) and not dir_queue.has(dir):
				dir_queue.append(dir)

		# Test files
		for file_name in da.get_files():
			var file := _path_join(da.get_current_dir(), file_name)
			if file.match(pattern):
				results.append(file)

	return results

func _path_join(a: String, b: String) -> String:
	if a.ends_with("/"):
		return a + b
	else:
		return a + "/" + b
