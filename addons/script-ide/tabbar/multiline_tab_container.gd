@tool
extends PanelContainer

const CLOSE_BTN_SPACER: String = "   "

const CustomTab := preload("custom_tab.gd")

@onready var multiline_tab_bar: HFlowContainer = %MultilineTabBar
@onready var popup_btn: Button = %PopupBtn

var tab_hovered: StyleBoxFlat
var tab_focus: StyleBoxFlat
var tab_selected: StyleBoxFlat
var tab_unselected: StyleBoxFlat

var font_selected_color: Color
var font_unselected_color: Color
var font_hovered_color: Color

var show_close_button_always: bool = false : set = set_show_close_button_always
var is_singleline_tabs: bool = false : set = set_singleline_tabs

var tab_group: ButtonGroup = ButtonGroup.new()

var script_filter_txt: LineEdit
var scripts_item_list: ItemList
var scripts_tab_container: TabContainer
var popup: PopupPanel

var plugin: EditorPlugin

var suppress_theme_changed: bool

var last_drag_over_tab: CustomTab
var drag_marker: ColorRect
var current_tab: CustomTab

#region Plugin and related tab handling processing
func _ready() -> void:
	popup_btn.pressed.connect(on_popup_button_pressed)
	tab_group.pressed.connect(on_new_tab_selected)

	set_process(false)

	if (plugin != null):
		schedule_update()

func _notification(what: int) -> void:
	if (what == NOTIFICATION_DRAG_END || what == NOTIFICATION_MOUSE_EXIT):
		clear_drag_mark()
		return

	if (what == NOTIFICATION_THEME_CHANGED):
		if (suppress_theme_changed):
			return

		suppress_theme_changed = true
		add_theme_stylebox_override(&"panel", EditorInterface.get_editor_theme().get_stylebox(&"tabbar_background", &"TabContainer"))
		suppress_theme_changed = false

		tab_hovered = EditorInterface.get_editor_theme().get_stylebox(&"tab_hovered", &"TabContainer")
		tab_focus = EditorInterface.get_editor_theme().get_stylebox(&"tab_focus", &"TabContainer")
		tab_selected = EditorInterface.get_editor_theme().get_stylebox(&"tab_selected", &"TabContainer")
		tab_unselected = EditorInterface.get_editor_theme().get_stylebox(&"tab_unselected", &"TabContainer")

		if (drag_marker == null):
			drag_marker = ColorRect.new()
			drag_marker.set_anchors_and_offsets_preset(PRESET_LEFT_WIDE)
			drag_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
			drag_marker.custom_minimum_size.x = 4 *  EditorInterface.get_editor_scale()
		drag_marker.color = EditorInterface.get_editor_theme().get_color(&"drop_mark_color", &"TabContainer")

		font_hovered_color = EditorInterface.get_editor_theme().get_color(&"font_hovered_color", &"TabContainer")
		font_selected_color = EditorInterface.get_editor_theme().get_color(&"font_selected_color", &"TabContainer")
		font_unselected_color = EditorInterface.get_editor_theme().get_color(&"font_unselected_color", &"TabContainer")

		if (plugin == null || multiline_tab_bar == null):
			return

		for tab: CustomTab in get_tabs():
			update_tab_style(tab)

func update_tab_style(tab: CustomTab):
	tab.add_theme_stylebox_override(&"normal", tab_unselected)
	tab.add_theme_stylebox_override(&"hover", tab_hovered)
	tab.add_theme_stylebox_override(&"hover_pressed", tab_hovered)
	tab.add_theme_stylebox_override(&"focus", tab_focus)
	tab.add_theme_stylebox_override(&"pressed", tab_selected)

	tab.add_theme_color_override(&"font_color", font_unselected_color)
	tab.add_theme_color_override(&"font_hover_color", font_hovered_color)
	tab.add_theme_color_override(&"font_pressed_color", font_selected_color)

func update_icon_color(tab: CustomTab, color: Color):
	tab.add_theme_color_override(&"icon_normal_color", color)
	tab.add_theme_color_override(&"icon_hover_color", color)
	tab.add_theme_color_override(&"icon_hover_pressed_color", color)
	tab.add_theme_color_override(&"icon_pressed_color", color)
	tab.add_theme_color_override(&"icon_focus_color", color)

func _process(delta: float) -> void:
	sync_tabs_with_item_list()

	if (is_singleline_tabs):
		shift_singleline_tabs_to(current_tab)

	set_process(false)

func _shortcut_input(event: InputEvent) -> void:
	if (!event.is_pressed() || event.is_echo()):
		return

	if (!is_visible_in_tree()):
		return

	if (current_tab == null):
		return

	if (plugin.tab_cycle_forward_shc.matches_event(event)):
		get_viewport().set_input_as_handled()

		var tab_count: int = get_tab_count()
		if (tab_count <= 1):
			return

		var index: int = current_tab.get_index()
		var new_tab: int = index + 1
		if (new_tab == tab_count):
			new_tab = 0

		var tab: CustomTab = get_tab(new_tab)
		tab.button_pressed = true
	elif (plugin.tab_cycle_backward_shc.matches_event(event)):
		get_viewport().set_input_as_handled()

		var tab_count: int = get_tab_count()
		if (tab_count <= 1):
			return

		var index: int = current_tab.get_index()
		var new_tab: int = index - 1
		if (new_tab == -1):
			new_tab = tab_count - 1

		var tab: CustomTab = get_tab(new_tab)
		tab.button_pressed = true

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if !(data is Dictionary):
		return false

	var can_drop: bool = data.has("index") && data["index"] != get_tab_count() - 1

	if (can_drop):
		on_drag_over(get_tab(get_tab_count() - 1))

	return can_drop

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if (!_can_drop_data(at_position, data)):
		return

	on_drag_drop(data["index"], get_tab_count() - 1)
#endregion

func schedule_update():
	set_process(true)

func on_drag_drop(source_index: int, target_index: int):
	var child: Node = scripts_tab_container.get_child(source_index)
	scripts_tab_container.move_child(child, target_index);

	var tab: CustomTab = get_tab(target_index)
	tab.grab_focus()

func on_drag_over(tab: CustomTab):
	if (last_drag_over_tab == tab):
		return

	# The drag marker should always be orphan when here.
	tab.add_child(drag_marker)

	last_drag_over_tab = tab

func clear_drag_mark():
	if (last_drag_over_tab == null):
		return

	last_drag_over_tab = null
	if (drag_marker.get_parent() != null):
		drag_marker.get_parent().remove_child(drag_marker)

func update_tabs():
	update_script_text_filter()

	for tab: CustomTab in get_tabs():
		update_tab(tab)

func get_tabs() -> Array[Node]:
	return multiline_tab_bar.get_children()

func update_selected_tab():
	update_tab(tab_group.get_pressed_button())

func update_tab(tab: CustomTab):
	if (tab == null):
		return

	var index: int = tab.get_index()

	tab.text = scripts_item_list.get_item_text(index)
	tab.icon = scripts_item_list.get_item_icon(index)
	tab.tooltip_text = scripts_item_list.get_item_tooltip(index)

	update_icon_color(tab, scripts_item_list.get_item_icon_modulate(index))

	if (scripts_item_list.is_selected(index)):
		tab.button_pressed = true
		tab.text += CLOSE_BTN_SPACER
	elif (show_close_button_always):
		tab.text += CLOSE_BTN_SPACER

func get_tab(index: int) -> CustomTab:
	if (index < 0 || index >= get_tab_count()):
		return null

	return multiline_tab_bar.get_child(index)

func get_tab_count() -> int:
	return multiline_tab_bar.get_child_count()

func add_tab() -> CustomTab:
	var tab: CustomTab = CustomTab.new()
	tab.button_group = tab_group

	if (show_close_button_always):
		tab.show_close_button()

	update_tab_style(tab)

	tab.close_pressed.connect(on_tab_close_pressed.bind(tab))
	tab.right_clicked.connect(on_tab_right_click.bind(tab))
	tab.mouse_exited.connect(clear_drag_mark)
	tab.dragged_over.connect(on_drag_over.bind(tab))
	tab.dropped.connect(on_drag_drop)

	multiline_tab_bar.add_child(tab)
	return tab

func on_tab_right_click(tab: CustomTab):
	var index: int = tab.get_index()
	scripts_item_list.item_clicked.emit(index, scripts_item_list.get_local_mouse_position(), MOUSE_BUTTON_RIGHT)

func on_new_tab_selected(tab: CustomTab):
	# Hide and show close button.
	if (!show_close_button_always):
		if (current_tab != null):
			current_tab.hide_close_button()

		if (tab != null):
			tab.show_close_button()

	update_script_text_filter()

	var index: int = tab.get_index()
	if (scripts_item_list != null && !scripts_item_list.is_selected(index)):
		scripts_item_list.select(index)
		scripts_item_list.item_selected.emit(index)
		scripts_item_list.ensure_current_is_visible()

	# Remove spacing from previous tab.
	if (!show_close_button_always && current_tab != null):
		update_tab(current_tab)
	current_tab = tab

	if (is_singleline_tabs):
		ensure_singleline_tab_visible(current_tab)

## Removes the script filter text and emits the signal so that the tabs stay
## and we do not break anything there.
func update_script_text_filter():
	if (script_filter_txt.text != &""):
		script_filter_txt.text = &""
		script_filter_txt.text_changed.emit(&"")

func on_tab_close_pressed(tab: CustomTab) -> void:
	scripts_item_list.item_clicked.emit(tab.get_index(), scripts_item_list.get_local_mouse_position(), MOUSE_BUTTON_MIDDLE)

func sync_tabs_with_item_list() -> void:
	if (plugin == null):
		return

	if (get_tab_count() > scripts_item_list.item_count):
		for index: int in range(get_tab_count() - 1, scripts_item_list.item_count - 1, -1):
			var tab: CustomTab = get_tab(index)

			if (tab == current_tab):
				current_tab = null

			multiline_tab_bar.remove_child(tab)
			tab.free()

	for index: int in scripts_item_list.item_count:
		var tab: CustomTab = get_tab(index)
		if (tab == null):
			tab = add_tab()

		update_tab(tab)

func tab_changed():
	update_script_text_filter()

	# When the tab change was not triggered by our component,
	# we need to sync the selection.
	update_tab(get_tab(scripts_tab_container.current_tab))

func script_order_changed() -> void:
	schedule_update()

func set_popup(new_popup: PopupPanel) -> void:
	popup = new_popup

func on_popup_button_pressed() -> void:
	if (popup == null):
		return

	scripts_item_list.get_parent().reparent(popup)
	scripts_item_list.get_parent().visible = true

	popup.size = Vector2(250 * get_editor_scale(), get_parent().size.y - size.y)
	popup.position = popup_btn.get_screen_position() - Vector2(popup.size.x, 0)
	popup.popup()

	script_filter_txt.grab_focus()

func get_editor_scale() -> float:
	return EditorInterface.get_editor_scale()

func set_show_close_button_always(new_value: bool):
	if (show_close_button_always == new_value):
		return

	show_close_button_always = new_value

	if (multiline_tab_bar == null):
		return

	for tab: CustomTab in get_tabs():
		tab.text = scripts_item_list.get_item_text(tab.get_index())
		if (show_close_button_always):
			tab.text += CLOSE_BTN_SPACER
			if (!tab.button_pressed):
				tab.show_close_button()
		else:
			if (!tab.button_pressed):
				tab.hide_close_button()
			else:
				tab.text += CLOSE_BTN_SPACER

#region Singeline handling
func set_singleline_tabs(new_value: bool):
	if (is_singleline_tabs == new_value):
		return

	is_singleline_tabs = new_value

	if (is_singleline_tabs):
		item_rect_changed.connect(update_singleline_tabs_width)

		if (multiline_tab_bar == null):
			return

		shift_singleline_tabs_to(current_tab)
	else:
		item_rect_changed.disconnect(update_singleline_tabs_width)

		if (multiline_tab_bar == null):
			return

		for tab: CustomTab in get_tabs():
			tab.visible = true

func ensure_singleline_tab_visible(tab: CustomTab):
	if (tab != null && tab.visible):
		return

	shift_singleline_tabs_to(tab)

func update_singleline_tabs_width():
	var start: bool
	var tab_bar_width: float = multiline_tab_bar.size.x
	var tabs_width: float

	for tab: CustomTab in get_tabs():
		if (tab.visible):
			shift_singleline_tabs_to(tab)
			break

func shift_singleline_tabs_to(start_tab: CustomTab):
	var start: bool
	var tab_bar_width: float = multiline_tab_bar.size.x
	var tabs_width: float

	for tab: CustomTab in get_tabs():
		if (start_tab == null || tab == start_tab):
			start = true

		if (start):
			tabs_width += tab.size.x

			tab.visible = tabs_width <= tab_bar_width
		else:
			tab.visible = false

	if (current_tab != null && !current_tab.visible):
		shift_singleline_tabs_to(current_tab)
		return

	if (start_tab == null):
		return

	for index: int in range(start_tab.get_index() - 1, -1, -1):
		var tab: CustomTab = get_tabs().get(index)

		tabs_width += tab.size.x
		if (tabs_width > tab_bar_width):
			return

		tab.visible = true
#endregion
