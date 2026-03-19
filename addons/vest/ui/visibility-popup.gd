@tool
extends PopupPanel

@onready var _container := %"Statuses Container" as Control
@onready var _toggle_button := %"Toggle Button" as Button

var _visibilities: Dictionary = {}

signal on_change()

func get_visibility_for(status: int) -> bool:
	return _visibilities.get(status, true)

func is_empty() -> bool:
	# Return true if all visibilites are set to false
	for status in _visibilities:
		if _visibilities[status]:
			return false
	return true

func _init() -> void:
	# Default visibility to true
	for status in range(VestResult.TEST_MAX):
		_visibilities[status] = true

func _ready() -> void:
	_render()
	_toggle_button.pressed.connect(_toggle_all)

func _toggle_all() -> void:
	var visibility := is_empty()
	for status in _visibilities.keys():
		_visibilities[status] = visibility
	_render()
	on_change.emit()

func _render() -> void:
	if _container.get_child_count() != _visibilities.size():
		# Remove children
		for child in _container.get_children():
			child.queue_free()

		for status in _visibilities.keys():
			var checkbox := CheckBox.new()
			checkbox.toggle_mode = true
			checkbox.text = VestResult.get_status_string(status).capitalize()
			checkbox.icon = VestUI.get_status_icon(status)
			checkbox.expand_icon = true

			checkbox.pressed.connect(func():
				_visibilities[status] = not _visibilities[status]
				_render()
				on_change.emit()
			)

			_container.add_child(checkbox)

	# Update checkbox statuses
	for idx in range(_container.get_child_count()):
		var status := _visibilities.keys()[idx] as int
		var checkbox := _container.get_child(idx) as CheckBox
		checkbox.set_pressed_no_signal(_visibilities[status])

	# Update toggle button
	if is_empty():
		_toggle_button.text = "All"
		_toggle_button.icon = Vest.Icons.visible
	else:
		_toggle_button.text = "None"
		_toggle_button.icon = Vest.Icons.hidden
