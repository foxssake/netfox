extends VestTest

func get_suite_name() -> String:
	return "DiffHistoryEncoder"

const TICK := 1
const REFERENCE_TICK := 0
const UNAUTHORIZED_SENDER := 2

var source_history: _PropertyHistoryBuffer
var target_history: _PropertyHistoryBuffer
var property_cache: PropertyCache

var source_encoder: _DiffHistoryEncoder
var target_encoder: _DiffHistoryEncoder

func before_case(__):
	# Setup
	var root_node := Node3D.new()
	source_history = _PropertyHistoryBuffer.new()
	target_history = _PropertyHistoryBuffer.new()
	property_cache = PropertyCache.new(root_node)

	source_encoder = _DiffHistoryEncoder.new(source_history, property_cache)
	target_encoder = _DiffHistoryEncoder.new(target_history, property_cache)

	# Set history
	source_history.set_snapshot(0, _PropertySnapshot.from_dictionary({
		":position": Vector3.ONE,
		":scale": Vector3(1.0, 2.0, 0.8)
	}))

	source_history.set_snapshot(1, _PropertySnapshot.from_dictionary({
		":position": Vector3(1.0, 2.0, -1.0),
		":scale": Vector3(1.0, 2.0, 0.8)
	}))

	source_history.set_snapshot(2, _PropertySnapshot.from_dictionary({
		":position": Vector3(1.0, 2.0, -1.0),
		":scale": Vector3(2.0, 1.0, 1.2)
	}))

	target_history.set_snapshot(0, _PropertySnapshot.from_dictionary({
		":position": Vector3.ONE,
		":scale": Vector3(1.0, 2.0, 0.8)
	}))

func after_case(__):
	NetworkTime._tick = 0

func test_apply_should_sync_history():
	var data := source_encoder.encode(TICK, REFERENCE_TICK)
	var snapshot := target_encoder.decode(data)
	var success := target_encoder.apply(TICK, snapshot, REFERENCE_TICK)

	expect(success, "Snapshot should have been applied!")
	expect_equal(
		target_history.get_snapshot(TICK).as_dictionary(),
		source_history.get_snapshot(TICK).as_dictionary()
	)

func test_apply_should_fail_on_old_data():
	var data := source_encoder.encode(TICK, REFERENCE_TICK)
	var snapshot := target_encoder.decode(data)

	NetworkTime._tick = TICK + NetworkRollback.history_limit + 2

	expect_false(
		target_encoder.apply(TICK, snapshot, REFERENCE_TICK),
		"Snapshot should be rejected!"
	)

func test_apply_should_fail_on_unauthorized_data():
	var data := source_encoder.encode(TICK, REFERENCE_TICK)
	var snapshot := target_encoder.decode(data)

	NetworkTime._tick = TICK + NetworkRollback.history_limit + 2

	expect_false(
		target_encoder.apply(TICK, snapshot, REFERENCE_TICK, UNAUTHORIZED_SENDER),
		"Snapshot should be rejected!"
	)

func test_apply_should_continue_without_reference_tick():
	var data := source_encoder.encode(2, 1)
	var snapshot := target_encoder.decode(data)
	var success := target_encoder.apply(2, snapshot, 1)

	expect(success, "Snapshot should have been applied!")

func test_bandwidth_on_no_change():
	# Set first two ticks to equal
	source_history.set_snapshot(TICK, source_history.get_snapshot(REFERENCE_TICK))

	var data := source_encoder.encode(TICK, REFERENCE_TICK)
	var bytes_per_snapshot := var_to_bytes(data).size()

	Vest.message("Empty diff size: %d bytes" % [bytes_per_snapshot])

	ok()

func test_bandwidth_on_partial_change():
	# Partial diff already set up in before_case()

	var data := source_encoder.encode(TICK, REFERENCE_TICK)
	var bytes_per_snapshot := var_to_bytes(data).size()

	Vest.message("Partial diff size: %d bytes" % [bytes_per_snapshot])

	ok()
