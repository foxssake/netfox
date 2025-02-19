extends Node

# Data fields
@onready var state_history_data := %"State History Data" as TextEdit
@onready var input_history_data := %"Input History Data" as TextEdit
@onready var network_tick_data := %"Network Tick Data" as LineEdit
@onready var rollback_tick_data := %"Rollback Tick Data" as LineEdit
@onready var has_input_data := %"Has Input Data" as Label
@onready var input_age_data := %"Input Age Data" as Label
@onready var simset_list := %"Simset List" as ItemList
@onready var skipset_list := %"Skipset List" as ItemList
@onready var transmit_state_data := %"Transmit State Data" as Label

# Tool buttons
@onready var nt_before_loop_button := %"NT Before Loop Button" as Button
@onready var nt_before_tick_button := %"NT Before Tick Button" as Button
@onready var nt_on_tick_button := %"NT On Tick Button" as Button
@onready var nr_before_loop_button := %"NR Before Loop Button" as Button
@onready var nr_prepare_button := %"NR Prepare Button" as Button
@onready var nr_process_button := %"NR Process Button" as Button
@onready var nr_record_button := %"NR Record Button" as Button
@onready var nr_after_loop_button := %"NR After Loop" as Button
@onready var nt_after_tick_button := %"NT After Tick Button" as Button
@onready var nt_after_tick_loop_button := %"NT After Tick Loop Button" as Button

@onready var run_nr_tick_button := %"Run NR Tick Button" as Button
@onready var advance_button := %"Advance Button" as Button

@onready var rollback_synchronizer := self.get_tree().root\
	.find_children("*", "RollbackSynchronizer", true, false)\
	.pop_front() as RollbackSynchronizer

func _ready():
	if not rollback_synchronizer:
		OS.alert("No RollbackSynchronizer found! Add one to the scene and run again!")
		get_tree().quit()

	# Render initial data
	_render_data()

	# Set defaults
	input_history_data.text = """{
		0: { "Input:movement": Vector2(1, 0) },
		1: { "Input:movement": Vector2(1, 1) },
		2: { "Input:movement": Vector2(1, 1) },
		3: { "Input:movement": Vector2(0, 1) },
	}"""

	# Start NetworkTime but make sure it doesn't tick on its own
	NetworkTime.start()
	NetworkTime.set_process(false)

	# Connect signals
	rollback_synchronizer._on_transmit_state.connect(func(state, tick):
		transmit_state_data.text = "@%d: %s" % [tick, var_to_str(state)]
	)

	nt_before_loop_button.pressed.connect(func():
		NetworkTime.before_tick_loop.emit()
	)

	nt_before_tick_button.pressed.connect(func():
		NetworkTime.before_tick.emit(NetworkTime.ticktime, NetworkTime.tick)
	)

	nt_on_tick_button.pressed.connect(func():
		NetworkTime.on_tick.emit(NetworkTime.ticktime, NetworkTime.tick)
	)

	nr_before_loop_button.pressed.connect(func():
		NetworkRollback.before_loop.emit()
	)

	nr_prepare_button.pressed.connect(func():
		NetworkRollback.on_prepare_tick.emit(NetworkRollback.tick)
		NetworkRollback.after_prepare_tick.emit(NetworkRollback.tick)
	)

	nr_process_button.pressed.connect(func():
		NetworkRollback.on_process_tick.emit(NetworkRollback.tick)
		NetworkRollback._tick += 1
	)

	nr_record_button.pressed.connect(func():
		NetworkRollback.on_record_tick.emit(NetworkRollback.tick)
	)

	nr_after_loop_button.pressed.connect(func():
		NetworkRollback.after_loop.emit()
	)

	nt_after_tick_button.pressed.connect(func():
		NetworkTime.after_tick.emit(NetworkTime.ticktime, NetworkTime.tick)
	)

	nt_after_tick_loop_button.pressed.connect(func():
		NetworkTime.after_tick_loop.emit()
		NetworkTime._tick += 1
	)

	run_nr_tick_button.pressed.connect(func():
		NetworkRollback.before_loop.emit()

		NetworkRollback.on_prepare_tick.emit(NetworkRollback.tick)
		NetworkRollback.after_prepare_tick.emit(NetworkRollback.tick)
		NetworkRollback.on_process_tick.emit(NetworkRollback.tick)
		NetworkRollback._tick += 1
		NetworkRollback.on_record_tick.emit(NetworkRollback.tick)

		NetworkRollback.after_loop.emit()
	)

	advance_button.pressed.connect(func():
		NetworkRollback._tick += 1
	)

	# Update UI after any button press
	var buttons = get_parent().find_children("*", "Button")
	for button in buttons:
		(button as Button).button_down.connect(_read_data)
		(button as Button).button_up.connect(_render_data)

func _render_data():
	network_tick_data.text = str(NetworkTime.tick)
	rollback_tick_data.text = str(NetworkRollback.tick)

	state_history_data.text = _serialize_history(rollback_synchronizer._states)
	input_history_data.text = _serialize_history(rollback_synchronizer._inputs)

	if rollback_synchronizer.has_input():
		has_input_data.text = "true"
		input_age_data.text = str(rollback_synchronizer.get_input_age())
	else:
		has_input_data.text = "false"
		input_age_data.text = "?"

	simset_list.clear()
	for sim_entry in rollback_synchronizer._simset.values():
		simset_list.add_item(str(sim_entry), null, false)

	skipset_list.clear()
	for skip_entry in rollback_synchronizer._skipset.values():
		skipset_list.add_item(str(skip_entry), null, false)

func _read_data():
	if network_tick_data.text.is_valid_int():
		NetworkTime._tick = network_tick_data.text.to_int()

	if rollback_tick_data.text.is_valid_int():
		NetworkRollback._tick = rollback_tick_data.text.to_int()

	rollback_synchronizer._states = _parse_history(state_history_data.text)
	rollback_synchronizer._inputs = _parse_history(input_history_data.text)

func _serialize_history(history: _HistoryBuffer) -> String:
	var result = PackedStringArray()

	for tick in history.ticks():
		var snapshot := history.get_snapshot(tick)
		result.append("\t%d: %s" % [tick, var_to_str(snapshot.as_dictionary()).replace("\n", "")])

	return "{\n%s\n}" % [",\n".join(result)]

func _parse_history(history_string: String) -> _HistoryBuffer:
	var result_data = str_to_var(history_string)
	if not result_data is Dictionary:
		return _HistoryBuffer.new()

	var result := _HistoryBuffer.new()
	for tick in result_data.keys():
		var snapshot := _PropertyStoreSnapshot.from_dictionary(result_data[tick])
		result.set_snapshot(tick, snapshot)

	return result
