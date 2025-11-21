@tool
extends Button

signal close_pressed
signal right_clicked
signal dragged_over
signal dropped(source_index: int, target_index: int)

var close_button: Button

func _ready() -> void:
	icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	action_mode = ACTION_MODE_BUTTON_PRESS
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	toggle_mode = true

func show_close_button():
	if (close_button == null):
		close_button = create_close_button()

	add_child(close_button)

func hide_close_button():
	if (close_button != null):
		remove_child(close_button)

func create_close_button() -> Button:
	close_button = Button.new()
	close_button.icon = EditorInterface.get_editor_theme().get_icon(&"Close", &"EditorIcons")
	close_button.flat = true
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(on_close_pressed)
	close_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)

	return close_button

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton && event.pressed:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			on_close_pressed()
		elif (event.button_index == MOUSE_BUTTON_RIGHT):
			button_pressed = true
			on_right_click()

func on_right_click():
	right_clicked.emit()

func on_close_pressed() -> void:
	close_pressed.emit()

func _get_drag_data(at_position: Vector2) -> Variant:
	var preview: Button = Button.new()
	preview.text = text
	preview.icon = icon
	preview.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	preview.alignment = HORIZONTAL_ALIGNMENT_LEFT
	preview.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	preview.add_theme_stylebox_override(&"normal", get_theme_stylebox(&"normal"))

	set_drag_preview(preview)

	var drag_data: Dictionary[String, Variant]
	drag_data["type"] = "script_list_element"
	drag_data["script_list_element"] = EditorInterface.get_script_editor().get_current_editor()
	drag_data["index"] = get_index()

	return drag_data

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if !(data is Dictionary):
		return false

	var can_drop: bool = data.has("index")

	if (can_drop):
		dragged_over.emit()

	return can_drop

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if (!_can_drop_data(at_position, data)):
		return

	dropped.emit(data["index"], get_index())
