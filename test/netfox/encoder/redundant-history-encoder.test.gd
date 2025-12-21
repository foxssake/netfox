extends VestTest

func get_suite_name() -> String:
	return "RedundantHistoryEncoder"

const REDUNDANCY := 3
const TICK := REDUNDANCY - 1

var source_history: _PropertyHistoryBuffer
var target_history: _PropertyHistoryBuffer
var property_cache: PropertyCache

var property_entries: Array[PropertyEntry]
var source_encoder: _RedundantHistoryEncoder
var target_encoder: _RedundantHistoryEncoder

func before_case(__):
	# Setup
	var root_node := Node3D.new()
	var input_node := SnapshotFixtures.input_node()
	root_node.add_child(input_node)
	property_entries = SnapshotFixtures.input_property_entries(root_node)

	source_history = _PropertyHistoryBuffer.new()
	target_history = _PropertyHistoryBuffer.new()
	property_cache = PropertyCache.new(root_node)

	var schema := _NetworkSchema.new({})
	source_encoder = _RedundantHistoryEncoder.new(source_history, property_cache, schema)
	target_encoder = _RedundantHistoryEncoder.new(target_history, property_cache, schema)

	# By setting different redundancies, we also test for the encoders
	# recognizing redundancy in incoming data
	source_encoder.redundancy = REDUNDANCY
	target_encoder.redundancy = 1

	source_encoder.set_properties(property_entries)
	target_encoder.set_properties(property_entries)

	# Set some base data
	for tick in range(REDUNDANCY):
		source_history.set_snapshot(tick, SnapshotFixtures.input_snapshot(Vector3(tick, 0, 0)))

	target_history.set_snapshot(1, SnapshotFixtures.input_snapshot(Vector3.RIGHT))

func after_case(__):
	NetworkTime._tick = 0

func test_encode_should_decode_to_same():
	# Source encodes a snapshot, and the target decodes it.
	# The two snapshots should match.

	var data := source_encoder.encode(TICK, property_entries)
	var snapshots := target_encoder.decode(data, property_entries)

	for i in range(REDUNDANCY):
		expect_equal(
			snapshots[i].as_dictionary(),
			source_history.get_snapshot(TICK - i).as_dictionary(),
			"Snapshot %d should equal source!" % [i]
		)

func test_decode_should_fail_on_version_mismatch():
	var tick := 0
	var new_properties := property_entries.slice(0, 1)

	# Transmit first tick to match versions
	target_encoder.decode(source_encoder.encode(tick, property_entries), property_entries)

	# Change property config for second transmit
	source_encoder.set_properties(new_properties)
	var encoded := source_encoder.encode(tick, new_properties)
	var decoded := target_encoder.decode(encoded, property_entries)

	expect_empty(decoded)

func test_encode_should_skip_unavailable_ticks():
	# Encoded data should not contain ticks before the first tick in history

	var data := source_encoder.encode(0, property_entries)
	var snapshots := target_encoder.decode(data, property_entries)

	var actual := snapshots.map(func(s): return s.as_dictionary())
	var expected := [SnapshotFixtures.input_snapshot(Vector3.ZERO).as_dictionary()]

	expect_equal(actual, expected)

func test_encode_should_return_empty_on_empty_history():
	# Encoder should not break on empty history

	source_history.clear()
	var data := source_encoder.encode(0, property_entries)
	var snapshots := target_encoder.decode(data, property_entries)

	expect_empty(snapshots)

func test_apply_should_return_earliest_new_tick():
	# Apply should merge incoming data into history.
	# Incoming history:		[x][x][x]
	# Known history:		[ ][x][ ]
	# Hence the earliest new tick should be 0

	var data := source_encoder.encode(TICK, property_entries)
	var snapshots := target_encoder.decode(data, property_entries)
	var earliest_new_tick = target_encoder.apply(TICK, snapshots)

	expect_equal(earliest_new_tick, 0)

func test_apply_should_ignore_unauthorized_data():
	# Apply should sanitize data and ignore all properties not owned by sender

	var data := source_encoder.encode(TICK, property_entries)
	var snapshots := target_encoder.decode(data, property_entries)
	var earliest_new_tick = target_encoder.apply(TICK, snapshots, 2)

	expect_equal(earliest_new_tick, -1)

func test_apply_should_ignore_old_data():
	# Apply should sanitize data and ignore all properties not owned by sender

	var data := source_encoder.encode(TICK, property_entries)
	var snapshots := target_encoder.decode(data, property_entries)

	NetworkTime._tick = TICK + NetworkRollback.history_limit - 2

	var earliest_new_tick = target_encoder.apply(TICK, snapshots)

	expect_equal(earliest_new_tick, TICK - 2)

func test_bandwidth():
	var data := source_encoder.encode(TICK, property_entries)
	var bytes_per_snapshot := var_to_bytes(data).size()

	# 248 to 104 to 80
	Vest.message("Snapshot size with %d redundancy: %d bytes" % [source_encoder.redundancy, bytes_per_snapshot])

	ok()
