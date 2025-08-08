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

	return await run_script(test_script)
