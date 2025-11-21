## Copyright (c) 2023-present Marius Hanl under the MIT License.
## The editor plugin entrypoint for Script-IDE.
##
## The Script Tabs and Outline modifies the code that is inside 'script_editor_plugin.cpp'.
## That is, the structure is changed a little bit.
## The internals of then native C++ code are therefore important in order to make this plugin work
## without interfering with the Engine.
## All the other functionality does not modify anything Engine related.
##
## Script-IDE does not use global class_name's in order to not clutter projects using it.
## Especially since this is an editor only plugin, we do not want this plugin in the final game.
## Therefore, code that references other code inside this plugin is untyped.
@tool
extends EditorPlugin

const GETTER: StringName = &"get"
const SETTER: StringName = &"set"
const UNDERSCORE: StringName = &"_"
const INLINE: StringName = &"@"

const BUILT_IN_SCRIPT: StringName = &"::GDScript"

const MULTILINE_TAB_CONTAINER_SCENE: PackedScene = preload("tabbar/multiline_tab_container.tscn")
const MultilineTabContainer := preload("tabbar/multiline_tab_container.gd")

const QUICK_OPEN_SCENE: PackedScene = preload("quickopen/quick_open_panel.tscn")
const QuickOpenPopup := preload("quickopen/quick_open_panel.gd")

const OVERRIDE_SCENE: PackedScene = preload("override/override_panel.tscn")
const OverridePopup := preload("override/override_panel.gd")

const QUICK_OPEN_INTERVAL: int = 400

#region Settings and Shortcuts
## Editor setting path
const SCRIPT_IDE: StringName = &"plugin/script_ide/"
## Editor setting for the outline position
const OUTLINE_POSITION_RIGHT: StringName = SCRIPT_IDE + &"outline_position_right"
## Editor setting to control the order of the outline
const OUTLINE_ORDER: StringName = SCRIPT_IDE + &"outline_order"
## Editor setting to control whether private members (annotated with '_' should be hidden or not)
const HIDE_PRIVATE_MEMBERS: StringName = SCRIPT_IDE + &"hide_private_members"
## Editor setting to control whether we want to auto navigate to the script
## in the filesystem (dock) when selected
const AUTO_NAVIGATE_IN_FS: StringName = SCRIPT_IDE + &"auto_navigate_in_filesystem_dock"
## Editor setting to control whether the script list should be visible or not
const SCRIPT_LIST_VISIBLE: StringName = SCRIPT_IDE + &"script_list_visible"
## Editor setting to control whether the script tabs should be visible or not.
const SCRIPT_TABS_VISIBLE: StringName = SCRIPT_IDE + &"script_tabs_visible"
## Editor setting to control where the script tabs should be.
const SCRIPT_TABS_POSITION_TOP: StringName = SCRIPT_IDE + &"script_tabs_position_top"
## Editor setting to control if all script tabs should have close button.
const SCRIPT_TABS_CLOSE_BUTTON_ALWAYS: StringName = SCRIPT_IDE + &"script_tabs_close_button_always"
## Editor setting to control if all tabs should be shown in a single line.
const SCRIPT_TABS_SINGLELINE: StringName = SCRIPT_IDE + &"script_tabs_singleline"

## Editor setting for the 'Open Outline Popup' shortcut
const OPEN_OUTLINE_POPUP: StringName = SCRIPT_IDE + &"open_outline_popup"
## Editor setting for the 'Open Scripts Popup' shortcut
const OPEN_SCRIPTS_POPUP: StringName = SCRIPT_IDE + &"open_scripts_popup"
## Editor setting for the 'Open Scripts Popup' shortcut
const OPEN_QUICK_SEARCH_POPUP: StringName = SCRIPT_IDE + &"open_quick_search_popup"
## Editor setting for the 'Open Override Popup' shortcut
const OPEN_OVERRIDE_POPUP: StringName = SCRIPT_IDE + &"open_override_popup"
## Editor setting for the 'Tab cycle forward' shortcut
const TAB_CYCLE_FORWARD: StringName = SCRIPT_IDE + &"tab_cycle_forward"
## Editor setting for the 'Tab cycle backward' shortcut
const TAB_CYCLE_BACKWARD: StringName = SCRIPT_IDE + &"tab_cycle_backward"
#endregion

#region Outline type name and icon
const ENGINE_FUNCS: StringName = &"Engine Callbacks"
const FUNCS: StringName = &"Functions"
const SIGNALS: StringName = &"Signals"
const EXPORTED: StringName = &"Exported Properties"
const PROPERTIES: StringName = &"Properties"
const CLASSES: StringName = &"Classes"
const CONSTANTS: StringName = &"Constants"

var engine_func_icon: Texture2D
var func_icon: Texture2D
var func_get_icon: Texture2D
var func_set_icon: Texture2D
var property_icon: Texture2D
var export_icon: Texture2D
var signal_icon: Texture2D
var constant_icon: Texture2D
var class_icon: Texture2D
#endregion

#region Editor settings
var outline_order: PackedStringArray
var is_outline_right: bool = true
var is_hide_private_members: bool = false

var is_script_tabs_visible: bool = true
var is_script_tabs_top: bool = true
var is_script_tabs_close_button_always: bool = false
var is_script_tabs_singleline: bool = false

var is_auto_navigate_in_fs: bool = true
var is_script_list_visible: bool = false

var open_outline_popup_shc: Shortcut
var open_scripts_popup_shc: Shortcut
var open_quick_search_popup_shc: Shortcut
var open_override_popup_shc: Shortcut
var tab_cycle_forward_shc: Shortcut
var tab_cycle_backward_shc: Shortcut
#endregion

#region Existing controls we modify
var outline_container: Control
var outline_parent: Control
var script_filter_txt: LineEdit
var scripts_item_list: ItemList
var script_panel_split_container: VSplitContainer

var old_scripts_tab_container: TabContainer
var old_scripts_tab_bar: TabBar

var script_editor_split_container: HSplitContainer
var old_outline: ItemList
var outline_filter_txt: LineEdit
var sort_btn: Button
#endregion

#region Own controls we add
var outline: ItemList
var outline_popup: PopupPanel
var filter_box: HBoxContainer
var multiline_tab_container: MultilineTabContainer

var scripts_popup: PopupPanel
var quick_open_popup: QuickOpenPopup
var override_popup: OverridePopup

var class_btn: Button
var constant_btn: Button
var signal_btn: Button
var property_btn: Button
var export_btn: Button
var func_btn: Button
var engine_func_btn: Button
#endregion

#region Plugin variables
var keywords: Dictionary[String, bool] = {} # Used as Set.
var outline_type_order: Array[OutlineType] = []
var outline_cache: OutlineCache

var old_script_editor_base: ScriptEditorBase
var old_script_type: StringName

var is_script_changed: bool = false
var file_to_navigate: String = &""
var suppress_settings_sync: bool = false

var quick_open_tween: Tween
#endregion

#region Plugin Enter / Exit setup
## Change the Engine script UI and transform into an IDE like UI
func _enter_tree() -> void:
	init_icons()
	init_settings()
	init_shortcuts()

	# Update on filesystem changed (e.g. save operation).
	var file_system: EditorFileSystem = EditorInterface.get_resource_filesystem()
	file_system.filesystem_changed.connect(schedule_update)

	# Sync settings changes for this plugin.
	get_editor_settings().settings_changed.connect(sync_settings)

	var script_editor: ScriptEditor = EditorInterface.get_script_editor()

	# Change script item list visibility (based on settings).
	scripts_item_list = find_or_null(script_editor.find_children("*", "ItemList", true, false))
	scripts_item_list.allow_reselect = true
	scripts_item_list.item_selected.connect(hide_scripts_popup.unbind(1))
	update_script_list_visibility()

	# Add script filter navigation.
	script_filter_txt = find_or_null(scripts_item_list.get_parent().find_children("*", "LineEdit", true, false))
	script_filter_txt.gui_input.connect(navigate_on_list.bind(scripts_item_list, select_script))

	old_scripts_tab_container = find_or_null(script_editor.find_children("*", "TabContainer", true, false))
	old_scripts_tab_bar = old_scripts_tab_container.get_tab_bar()

	# When something changed, we need to sync our own tab container.
	old_scripts_tab_container.child_order_changed.connect(notify_order_changed)

	multiline_tab_container = MULTILINE_TAB_CONTAINER_SCENE.instantiate()
	multiline_tab_container.plugin = self
	multiline_tab_container.scripts_item_list = scripts_item_list
	multiline_tab_container.script_filter_txt = script_filter_txt
	multiline_tab_container.scripts_tab_container = old_scripts_tab_container

	old_scripts_tab_container.get_parent().add_theme_constant_override(&"separation", 0)
	old_scripts_tab_container.get_parent().add_child(multiline_tab_container)
	update_tabs_position()
	update_tabs_close_button()
	update_tabs_visibility()
	update_singleline_tabs()

	# Create and set script popup.
	script_panel_split_container = scripts_item_list.get_parent().get_parent()
	create_set_scripts_popup()

	# Remove existing outline and add own outline.
	script_editor_split_container = find_or_null(script_editor.find_children("*", "HSplitContainer", true, false))
	outline_container = script_editor_split_container.get_child(0)

	if (is_outline_right):
		update_outline_position()

	outline_parent = find_or_null(outline_container.get_children(), 1)
	old_outline = find_or_null(outline_parent.find_children("*", "ItemList", true, false), 0)
	outline_parent.remove_child(old_outline)

	outline = ItemList.new()
	outline.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	outline.allow_reselect = true
	outline.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outline_parent.add_child(outline)

	outline.item_selected.connect(scroll_outline)

	# Add a filter box for all kind of members
	filter_box = HBoxContainer.new()

	engine_func_btn = create_filter_btn(engine_func_icon, ENGINE_FUNCS)
	func_btn = create_filter_btn(func_icon, FUNCS)
	signal_btn = create_filter_btn(signal_icon, SIGNALS)
	export_btn = create_filter_btn(export_icon, EXPORTED)
	property_btn = create_filter_btn(property_icon, PROPERTIES)
	class_btn = create_filter_btn(class_icon, CLASSES)
	constant_btn = create_filter_btn(constant_icon, CONSTANTS)
	update_outline_button_order()

	outline.get_parent().add_child(filter_box)
	outline.get_parent().move_child(filter_box, outline.get_index())

	# Add navigation to the filter and text filtering.
	outline_filter_txt = find_or_null(outline_container.find_children("*", "LineEdit", true, false), 1)
	outline_filter_txt.gui_input.connect(navigate_on_list.bind(outline, scroll_outline))
	outline_filter_txt.text_changed.connect(update_outline.unbind(1))

	# Add callback when the sorting changed.
	sort_btn = find_or_null(outline_container.find_children("*", "Button", true, false))
	sort_btn.pressed.connect(update_outline)

	old_scripts_tab_bar.tab_changed.connect(on_tab_changed)
	on_tab_changed(old_scripts_tab_bar.current_tab)

## Restore the old Engine script UI and free everything we created
func _exit_tree() -> void:
	var file_system: EditorFileSystem = EditorInterface.get_resource_filesystem()
	file_system.filesystem_changed.disconnect(schedule_update)

	if (script_editor_split_container != null):
		if (script_editor_split_container != outline_container.get_parent()):
			script_editor_split_container.add_child(outline_container)

		# Try to restore the previous split offset.
		if (is_outline_right):
			var split_offset: float = script_editor_split_container.get_child(1).size.x
			script_editor_split_container.split_offset = split_offset

		script_editor_split_container.move_child(outline_container, 0)

		outline_filter_txt.gui_input.disconnect(navigate_on_list)
		outline_filter_txt.text_changed.disconnect(update_outline)
		sort_btn.pressed.disconnect(update_outline)

		outline.item_selected.disconnect(scroll_outline)

		outline_parent.remove_child(filter_box)
		outline_parent.remove_child(outline)
		outline_parent.add_child(old_outline)
		outline_parent.move_child(old_outline, 1)

		filter_box.free()
		outline.free()

	if (old_scripts_tab_bar != null):
		old_scripts_tab_bar.tab_changed.disconnect(on_tab_changed)

	if (old_scripts_tab_container != null):
		old_scripts_tab_container.child_order_changed.disconnect(notify_order_changed)
		old_scripts_tab_container.get_parent().remove_theme_constant_override(&"separation")
		old_scripts_tab_container.get_parent().remove_child(multiline_tab_container)

	if (multiline_tab_container != null):
		multiline_tab_container.free()
		scripts_popup.free()

	if (scripts_item_list != null):
		scripts_item_list.allow_reselect = false
		scripts_item_list.item_selected.disconnect(hide_scripts_popup)
		scripts_item_list.get_parent().visible = true

		if (script_filter_txt != null):
			script_filter_txt.gui_input.disconnect(navigate_on_list)

	if (outline_popup != null):
		outline_popup.free()
	if (quick_open_popup != null):
		quick_open_popup.free()
	if (override_popup != null):
		override_popup.free()

	get_editor_settings().settings_changed.disconnect(sync_settings)
#endregion

#region Plugin and Shortcut processing
## Lazy pattern to update the editor only once per frame
func _process(delta: float) -> void:
	update_editor()
	set_process(false)

## Process the user defined shortcuts
func _shortcut_input(event: InputEvent) -> void:
	if (!event.is_pressed() || event.is_echo()):
		return

	if (open_outline_popup_shc.matches_event(event)):
		get_viewport().set_input_as_handled()
		open_outline_popup()
	elif (open_scripts_popup_shc.matches_event(event)):
		get_viewport().set_input_as_handled()
		open_scripts_popup()
	elif (open_quick_search_popup_shc.matches_event(event)):
		if (quick_open_tween != null && quick_open_tween.is_running()):
			get_viewport().set_input_as_handled()
			if (quick_open_tween != null):
				quick_open_tween.kill()

			quick_open_tween = create_tween()
			quick_open_tween.tween_interval(0.1)
			quick_open_tween.tween_callback(open_quick_search_popup)
			quick_open_tween.tween_callback(func(): quick_open_tween = null)
		else:
			quick_open_tween = create_tween()
			quick_open_tween.tween_interval(QUICK_OPEN_INTERVAL / 1000.0)
			quick_open_tween.tween_callback(func(): quick_open_tween = null)
	elif (open_override_popup_shc.matches_event(event)):
		get_viewport().set_input_as_handled()
		open_override_popup()

## May cancels the quick search shortcut timer.
func _input(event: InputEvent) -> void:
	if (event is InputEventKey):
		if (!open_quick_search_popup_shc.matches_event(event)):
			if (quick_open_tween != null):
				quick_open_tween.kill()
				quick_open_tween = null
#endregion

#region Icon, Settings, Shortcut initialization
## Initializes all plugin icons, while respecting the editor settings.
func init_icons():
	engine_func_icon = create_editor_texture(load_rel("icon/engine_func.svg"))
	func_icon = create_editor_texture(load_rel("icon/func.svg"))
	func_get_icon = create_editor_texture(load_rel("icon/func_get.svg"))
	func_set_icon = create_editor_texture(load_rel("icon/func_set.svg"))
	property_icon = create_editor_texture(load_rel("icon/property.svg"))
	export_icon = create_editor_texture(load_rel("icon/export.svg"))
	signal_icon = create_editor_texture(load_rel("icon/signal.svg"))
	constant_icon = create_editor_texture(load_rel("icon/constant.svg"))
	class_icon = create_editor_texture(load_rel("icon/class.svg"))

## Initializes all settings.
## Every setting can be changed while this plugin is active, which will override them.
func init_settings():
	is_outline_right = get_setting(OUTLINE_POSITION_RIGHT, is_outline_right)
	is_hide_private_members = get_setting(HIDE_PRIVATE_MEMBERS, is_hide_private_members)
	is_script_list_visible = get_setting(SCRIPT_LIST_VISIBLE, is_script_list_visible)
	is_auto_navigate_in_fs = get_setting(AUTO_NAVIGATE_IN_FS, is_auto_navigate_in_fs)
	is_script_tabs_visible = get_setting(SCRIPT_TABS_VISIBLE, is_script_tabs_visible)
	is_script_tabs_top = get_setting(SCRIPT_TABS_POSITION_TOP, is_script_tabs_top)
	is_script_tabs_close_button_always = get_setting(SCRIPT_TABS_CLOSE_BUTTON_ALWAYS, is_script_tabs_close_button_always)
	is_script_tabs_singleline = get_setting(SCRIPT_TABS_SINGLELINE, is_script_tabs_singleline)

	init_outline_order()

## Initializes the outline type structure and sorts it based off the outline order.
func init_outline_order():
	var outline_type: OutlineType = OutlineType.new()
	outline_type.type_name = ENGINE_FUNCS
	outline_type.add_to_outline = func(): add_to_outline_if_selected(engine_func_btn,
		func(): add_to_outline(outline_cache.engine_funcs, engine_func_icon, &"func"))
	outline_type_order.append(outline_type)

	outline_type = OutlineType.new()
	outline_type.type_name = FUNCS
	outline_type.add_to_outline = func(): add_to_outline_if_selected(func_btn,
		func(): add_to_outline_ext(outline_cache.funcs, get_func_icon, &"func", &"static"))
	outline_type_order.append(outline_type)

	outline_type = OutlineType.new()
	outline_type.type_name = SIGNALS
	outline_type.add_to_outline = func(): add_to_outline_if_selected(signal_btn,
		func(): add_to_outline(outline_cache.signals, signal_icon, &"signal"))
	outline_type_order.append(outline_type)

	outline_type = OutlineType.new()
	outline_type.type_name = EXPORTED
	outline_type.add_to_outline = func(): add_to_outline_if_selected(export_btn,
		func(): add_to_outline(outline_cache.exports, export_icon, &"var", &"@export"))
	outline_type_order.append(outline_type)

	outline_type = OutlineType.new()
	outline_type.type_name = PROPERTIES
	outline_type.add_to_outline = func(): add_to_outline_if_selected(property_btn,
		func(): add_to_outline(outline_cache.properties, property_icon, &"var"))
	outline_type_order.append(outline_type)

	outline_type = OutlineType.new()
	outline_type.type_name = CLASSES
	outline_type.add_to_outline = func(): add_to_outline_if_selected(class_btn,
		func(): add_to_outline(outline_cache.classes, class_icon, &"class"))
	outline_type_order.append(outline_type)

	outline_type = OutlineType.new()
	outline_type.type_name = CONSTANTS
	outline_type.add_to_outline = func(): add_to_outline_if_selected(constant_btn,
		func(): add_to_outline(outline_cache.constants, constant_icon, &"const", &"enum"))
	outline_type_order.append(outline_type)

	update_outline_order()

func update_outline_button_order():
	var all_buttons: Array[Button] = [engine_func_btn, func_btn, signal_btn, export_btn, property_btn, class_btn, constant_btn]
	all_buttons.sort_custom(sort_buttons_by_outline_order)

	for btn: Button in all_buttons:
		if (btn.get_parent() != null):
			filter_box.remove_child(btn)

	for btn: Button in all_buttons:
		filter_box.add_child(btn)

func update_outline_order():
	var editor_settings: EditorSettings = get_editor_settings()
	if (editor_settings.has_setting(OUTLINE_ORDER)):
		outline_order = editor_settings.get_setting(OUTLINE_ORDER)
	else:
		outline_order = [ENGINE_FUNCS, FUNCS, SIGNALS, EXPORTED, PROPERTIES, CONSTANTS, CLASSES]
		editor_settings.set_setting(OUTLINE_ORDER, outline_order)

	outline_type_order.sort_custom(sort_types_by_outline_order)

func sort_buttons_by_outline_order(btn1: Button, btn2: Button) -> bool:
	return sort_by_outline_order(btn1.tooltip_text, btn2.tooltip_text)

func sort_types_by_outline_order(type1: OutlineType, type2: OutlineType) -> bool:
	return sort_by_outline_order(type1.type_name, type2.type_name)

func sort_by_outline_order(outline_type1: StringName, outline_type2: StringName) -> bool:
	return outline_order.find(outline_type1) < outline_order.find(outline_type2)

## Initializes all shortcuts.
## Every shortcut can be changed while this plugin is active, which will override them.
func init_shortcuts():
	var editor_settings: EditorSettings = get_editor_settings()
	if (!editor_settings.has_setting(OPEN_OUTLINE_POPUP)):
		var shortcut: Shortcut = Shortcut.new()
		var event: InputEventKey = InputEventKey.new()
		event.device = -1
		event.command_or_control_autoremap = true
		event.keycode = KEY_O

		shortcut.events = [ event ]
		editor_settings.set_setting(OPEN_OUTLINE_POPUP, shortcut)

	if (!editor_settings.has_setting(OPEN_SCRIPTS_POPUP)):
		var shortcut: Shortcut = Shortcut.new()
		var event: InputEventKey = InputEventKey.new()
		event.device = -1
		event.command_or_control_autoremap = true
		event.keycode = KEY_U

		shortcut.events = [ event ]
		editor_settings.set_setting(OPEN_SCRIPTS_POPUP, shortcut)

	if (!editor_settings.has_setting(OPEN_QUICK_SEARCH_POPUP)):
		var shortcut: Shortcut = Shortcut.new()
		var event: InputEventKey = InputEventKey.new()
		event.device = -1
		event.keycode = KEY_SHIFT

		shortcut.events = [ event ]
		editor_settings.set_setting(OPEN_QUICK_SEARCH_POPUP, shortcut)

	if (!editor_settings.has_setting(OPEN_OVERRIDE_POPUP)):
		var shortcut: Shortcut = Shortcut.new()
		var event: InputEventKey = InputEventKey.new()
		event.device = -1
		event.keycode = KEY_INSERT
		event.alt_pressed = true

		shortcut.events = [ event ]
		editor_settings.set_setting(OPEN_OVERRIDE_POPUP, shortcut)

	if (!editor_settings.has_setting(TAB_CYCLE_FORWARD)):
		var shortcut: Shortcut = Shortcut.new()
		var event: InputEventKey = InputEventKey.new()
		event.device = -1
		event.keycode = KEY_TAB
		event.ctrl_pressed = true

		shortcut.events = [ event ]
		editor_settings.set_setting(TAB_CYCLE_FORWARD, shortcut)

	if (!editor_settings.has_setting(TAB_CYCLE_BACKWARD)):
		var shortcut: Shortcut = Shortcut.new()
		var event: InputEventKey = InputEventKey.new()
		event.device = -1
		event.keycode = KEY_TAB
		event.shift_pressed = true
		event.ctrl_pressed = true

		shortcut.events = [ event ]
		editor_settings.set_setting(TAB_CYCLE_BACKWARD, shortcut)

	open_outline_popup_shc = editor_settings.get_setting(OPEN_OUTLINE_POPUP)
	open_scripts_popup_shc = editor_settings.get_setting(OPEN_SCRIPTS_POPUP)
	open_quick_search_popup_shc = editor_settings.get_setting(OPEN_QUICK_SEARCH_POPUP)
	open_override_popup_shc = editor_settings.get_setting(OPEN_OVERRIDE_POPUP)
	tab_cycle_forward_shc = editor_settings.get_setting(TAB_CYCLE_FORWARD)
	tab_cycle_backward_shc = editor_settings.get_setting(TAB_CYCLE_BACKWARD)
#endregion

## Schedules an update on the next frame.
func schedule_update():
	set_process(true)

## Updates all parts of the editor that are needed to be synchronized with the file system change.
func update_editor():
	if (file_to_navigate != &""):
		EditorInterface.select_file(file_to_navigate)
		EditorInterface.get_script_editor().get_current_editor().get_base_editor().grab_focus()
		file_to_navigate = &""

	if (is_script_changed):
		multiline_tab_container.tab_changed()
		is_script_changed = false

		var is_script: bool = get_current_script() != null
		filter_box.visible = is_script
		outline.visible = is_script
	else:
		# We saved / filesystem changed. so need to update everything.
		multiline_tab_container.update_tabs()

	update_outline_cache()
	update_outline()

func notify_order_changed():
	multiline_tab_container.script_order_changed()

func add_to_outline_if_selected(btn: Button, action: Callable):
	if (btn.button_pressed):
		action.call()

func open_quick_search_popup():
	if (quick_open_popup == null):
		quick_open_popup = QUICK_OPEN_SCENE.instantiate()
		quick_open_popup.plugin = self
		quick_open_popup.set_unparent_when_invisible(true)

	quick_open_popup.popup_exclusive_on_parent(EditorInterface.get_script_editor(), get_center_editor_rect())

func open_override_popup():
	var script: Script = get_current_script()
	if (!script):
		return

	if (override_popup == null):
		override_popup = OVERRIDE_SCENE.instantiate()
		override_popup.plugin = self
		override_popup.set_unparent_when_invisible(true)

	override_popup.popup_exclusive_on_parent(EditorInterface.get_script_editor(), get_center_editor_rect())

func hide_scripts_popup():
	if (scripts_popup != null && scripts_popup.visible):
		scripts_popup.hide.call_deferred()

func create_set_scripts_popup():
	scripts_popup = PopupPanel.new()
	scripts_popup.popup_hide.connect(restore_scripts_list)

	# Need to be inside the tree, so it can be shown as popup for the tab container.
	var script_editor: ScriptEditor = EditorInterface.get_script_editor()
	script_editor.add_child(scripts_popup)

	multiline_tab_container.set_popup(scripts_popup)

func restore_scripts_list():
	script_filter_txt.text = &""

	update_script_list_visibility()

	scripts_item_list.get_parent().reparent(script_panel_split_container)
	script_panel_split_container.move_child(scripts_item_list.get_parent(), 0)

func navigate_on_list(event: InputEvent, list: ItemList, submit: Callable):
	if (event.is_action_pressed(&"ui_text_submit")):
		var index: int = get_list_index(list)
		if (index == -1):
			return

		submit.call(index)
		list.accept_event()
	elif (event.is_action_pressed(&"ui_down", true)):
		var index: int = get_list_index(list)
		if (index == list.item_count - 1):
			return

		navigate_list(list, index, 1)
	elif (event.is_action_pressed(&"ui_up", true)):
		var index: int = get_list_index(list)
		if (index <= 0):
			return

		navigate_list(list, index, -1)
	elif (event.is_action_pressed(&"ui_page_down", true)):
		var index: int = get_list_index(list)
		if (index == list.item_count - 1):
			return

		navigate_list(list, index, 5)
	elif (event.is_action_pressed(&"ui_page_up", true)):
		var index: int = get_list_index(list)
		if (index <= 0):
			return

		navigate_list(list, index, -5)
	elif (event is InputEventKey && list.item_count > 0 && !list.is_anything_selected()):
		list.select(0)

func get_list_index(list: ItemList) -> int:
	var items: PackedInt32Array = list.get_selected_items()

	if (items.is_empty()):
		return -1

	return items[0]

func navigate_list(list: ItemList, index: int, amount: int):
	index = clamp(index + amount, 0, list.item_count - 1)

	list.select(index)
	list.ensure_current_is_visible()
	list.accept_event()

func get_center_editor_rect() -> Rect2i:
	var script_editor: ScriptEditor = EditorInterface.get_script_editor()

	var size: Vector2 = Vector2(400, 500) * get_editor_scale()
	var position: Vector2

	if (script_editor.get_parent().get_parent() is Window):
		# Floating editor.
		var window: Window = script_editor.get_parent().get_parent()
		var window_rect: Rect2 = window.get_visible_rect()

		position = window_rect.size / 2 - size / 2
	else:
		position = script_editor.global_position + script_editor.size / 2 - size / 2

	return Rect2i(position, size)

func open_outline_popup():
	if (get_current_script() == null):
		return

	var button_flags: Array[bool] = []
	for child: Node in filter_box.get_children():
		var btn: Button = child
		button_flags.append(btn.button_pressed)

		btn.set_pressed_no_signal(true)

	var old_text: String = outline_filter_txt.text
	outline_filter_txt.text = &""

	if (outline_popup == null):
		outline_popup = PopupPanel.new()
		outline_popup.set_unparent_when_invisible(true)

	var outline_initially_closed: bool = !outline_container.visible
	if (outline_initially_closed):
		outline_container.visible = true

	outline_container.reparent(outline_popup)

	outline_popup.popup_hide.connect(on_outline_popup_hidden.bind(outline_initially_closed, old_text, button_flags))

	outline_popup.popup_exclusive_on_parent(EditorInterface.get_script_editor(), get_center_editor_rect())

	update_outline()
	outline_filter_txt.grab_focus()

func on_outline_popup_hidden(outline_initially_closed: bool, old_text: String, button_flags: Array[bool]):
	outline_popup.popup_hide.disconnect(on_outline_popup_hidden)

	if outline_initially_closed:
		outline_container.visible = false

	outline_container.reparent(script_editor_split_container)
	if (!is_outline_right):
		script_editor_split_container.move_child(outline_container, 0)

	outline_filter_txt.text = old_text

	var index: int = 0
	for flag: bool in button_flags:
		var btn: Button = filter_box.get_child(index)
		btn.set_pressed_no_signal(flag)
		index += 1

	update_outline()

func open_scripts_popup():
	if (scripts_item_list.item_count == 0):
		return

	scripts_item_list.get_parent().reparent(scripts_popup)
	scripts_item_list.get_parent().visible = true

	if (scripts_popup.get_parent() != null):
		scripts_popup.get_parent().remove_child(scripts_popup)
	scripts_popup.popup_exclusive_on_parent(EditorInterface.get_script_editor(), get_center_editor_rect())

	script_filter_txt.grab_focus()

func get_current_script() -> Script:
	var script_editor: ScriptEditor = EditorInterface.get_script_editor()
	return script_editor.get_current_script()

func select_script(selected_idx: int):
	hide_scripts_popup()

	scripts_item_list.item_selected.emit(selected_idx)

func scroll_outline(selected_idx: int):
	if (outline_popup != null && outline_popup.visible):
		outline_popup.hide.call_deferred()

	var script: Script = get_current_script()
	if (!script):
		return

	var text: String = outline.get_item_text(selected_idx)
	var metadata: Dictionary[StringName, StringName] = outline.get_item_metadata(selected_idx)
	var modifier: StringName = metadata[&"modifier"]
	var type: StringName = metadata[&"type"]

	var type_with_text: String = type + " " + text
	if (type == &"func"):
		type_with_text = type_with_text + "("

	var source_code: String = script.get_source_code()
	var lines: PackedStringArray = source_code.split("\n")

	var index: int = 0
	for line: String in lines:
		# Easy case, like 'var abc'
		if (line.begins_with(type_with_text)):
			goto_line(index)
			return

		# We have an modifier, e.g. 'static'
		if (modifier != &"" && line.begins_with(modifier)):
			if (line.begins_with(modifier + " " + type_with_text)):
				goto_line(index)
				return
			# Special case: An 'enum' is treated different.
			elif (modifier == &"enum" && line.contains("enum " + text)):
				goto_line(index)
				return

		# Hard case, probably something like '@onready var abc'
		if (type == &"var" && line.contains(type_with_text)):
			goto_line(index)
			return

		index += 1

	push_error(type_with_text + " or " + modifier + " not found in source code")

func goto_line(index: int):
	var script_editor: ScriptEditor = EditorInterface.get_script_editor()
	script_editor.goto_line(index)

	var code_edit: CodeEdit = script_editor.get_current_editor().get_base_editor()
	code_edit.set_caret_line(index)
	code_edit.set_v_scroll(index)
	code_edit.set_caret_column(code_edit.get_line(index).length())
	code_edit.set_h_scroll(0)

	code_edit.grab_focus()

func create_filter_btn(icon: Texture2D, title: StringName) -> Button:
	var btn: Button = Button.new()
	btn.toggle_mode = true
	btn.icon = icon
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.tooltip_text = title

	var property: StringName = SCRIPT_IDE + title.to_lower().replace(" ", "_")
	btn.set_meta(&"property", property)
	btn.button_pressed = get_setting(property, true)

	btn.toggled.connect(on_filter_button_pressed.bind(btn))
	btn.gui_input.connect(on_right_click.bind(btn))

	btn.add_theme_color_override(&"icon_pressed_color", Color.WHITE)
	btn.add_theme_color_override(&"icon_hover_color", Color.WHITE)
	btn.add_theme_color_override(&"icon_hover_pressed_color", Color.WHITE)
	btn.add_theme_color_override(&"icon_focus_color", Color.WHITE)

	var style_box_empty: StyleBoxEmpty = StyleBoxEmpty.new()
	btn.add_theme_stylebox_override(&"normal", style_box_empty)

	var style_box: StyleBoxFlat = StyleBoxFlat.new()
	style_box.draw_center = false
	style_box.border_color = get_editor_accent_color()
	style_box.set_border_width_all(1 * get_editor_scale())
	style_box.set_corner_radius_all(get_editor_corner_radius() * get_editor_scale())
	btn.add_theme_stylebox_override(&"focus", style_box)

	return btn

func on_right_click(event: InputEvent, btn: Button):
	if !(event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event

	if (!mouse_event.is_pressed() || mouse_event.button_index != MOUSE_BUTTON_RIGHT):
		return

	btn.button_pressed = true

	var pressed_state: bool = false
	for child: Node in filter_box.get_children():
		var other_btn: Button = child

		if (btn != other_btn):
			pressed_state = pressed_state || other_btn.button_pressed

	for child: Node in filter_box.get_children():
		var other_btn: Button = child

		if (btn != other_btn):
			other_btn.button_pressed = !pressed_state

	outline_filter_txt.grab_focus()

func on_filter_button_pressed(pressed: bool, btn: Button):
	set_setting(btn.get_meta(&"property"), pressed)

	update_outline()
	outline_filter_txt.grab_focus()

func update_outline_position():
	if (is_outline_right):
		# Try to restore the previous split offset.
		var split_offset: float = script_editor_split_container.get_child(1).size.x
		script_editor_split_container.split_offset = split_offset
		script_editor_split_container.move_child(outline_container, 1)
	else:
		script_editor_split_container.move_child(outline_container, 0)

func update_script_list_visibility():
	scripts_item_list.get_parent().visible = is_script_list_visible

func create_editor_texture(texture: Texture2D) -> Texture2D:
	var image: Image = texture.get_image().duplicate()
	image.adjust_bcs(1.0, 1.0, get_editor_icon_saturation())

	return ImageTexture.create_from_image(image)

func sync_settings():
	if (suppress_settings_sync):
		return

	var changed_settings: PackedStringArray = get_editor_settings().get_changed_settings()
	for setting: String in changed_settings:
		if (setting == "interface/theme/icon_saturation"):
			init_icons()
			engine_func_btn.icon = engine_func_icon
			func_btn.icon = func_icon
			signal_btn.icon = signal_icon
			export_btn.icon = export_icon
			property_btn.icon = property_icon
			class_btn.icon = class_icon
			constant_btn.icon = constant_icon
			update_outline()
			continue

		if (!setting.begins_with(SCRIPT_IDE)):
			continue

		match (setting):
			OUTLINE_POSITION_RIGHT:
				var new_outline_right: bool = get_setting(OUTLINE_POSITION_RIGHT, is_outline_right)
				if (new_outline_right != is_outline_right):
					is_outline_right = new_outline_right

					update_outline_position()
			OUTLINE_ORDER:
				update_outline_order()
				update_outline_button_order()
				update_outline()
			HIDE_PRIVATE_MEMBERS:
				var new_hide_private_members: bool = get_setting(HIDE_PRIVATE_MEMBERS, is_hide_private_members)
				if (new_hide_private_members != is_hide_private_members):
					is_hide_private_members = new_hide_private_members

					update_outline_cache()
					update_outline()
			SCRIPT_LIST_VISIBLE:
				var new_script_list_visible: bool = get_setting(SCRIPT_LIST_VISIBLE, is_script_list_visible)
				if (new_script_list_visible != is_script_list_visible):
					is_script_list_visible = new_script_list_visible

					update_script_list_visibility()
			SCRIPT_TABS_VISIBLE:
				var new_script_tabs_visible: bool = get_setting(SCRIPT_TABS_VISIBLE, is_script_tabs_visible)
				if (new_script_tabs_visible != is_script_tabs_visible):
					is_script_tabs_visible = new_script_tabs_visible

					update_tabs_visibility()
			SCRIPT_TABS_POSITION_TOP:
				var new_script_tabs_top: bool = get_setting(SCRIPT_TABS_POSITION_TOP, is_script_tabs_top)
				if (new_script_tabs_top != is_script_tabs_top):
					is_script_tabs_top = new_script_tabs_top

					update_tabs_position()
			SCRIPT_TABS_CLOSE_BUTTON_ALWAYS:
				var new_script_tabs_close_button_always: bool = get_setting(SCRIPT_TABS_CLOSE_BUTTON_ALWAYS, is_script_tabs_close_button_always)
				if (new_script_tabs_close_button_always != is_script_tabs_close_button_always):
					is_script_tabs_close_button_always = new_script_tabs_close_button_always

					update_tabs_close_button()
			SCRIPT_TABS_SINGLELINE:
				var new_script_tabs_singleline: bool = get_setting(SCRIPT_TABS_SINGLELINE, is_script_tabs_singleline)
				if (new_script_tabs_singleline != is_script_tabs_singleline):
					is_script_tabs_singleline = new_script_tabs_singleline

					update_singleline_tabs()
			AUTO_NAVIGATE_IN_FS:
				is_auto_navigate_in_fs = get_setting(AUTO_NAVIGATE_IN_FS, is_auto_navigate_in_fs)
			OPEN_OUTLINE_POPUP:
				open_outline_popup_shc = get_shortcut(OPEN_OUTLINE_POPUP)
			OPEN_SCRIPTS_POPUP:
				open_scripts_popup_shc = get_shortcut(OPEN_SCRIPTS_POPUP)
			OPEN_OVERRIDE_POPUP:
				open_override_popup_shc = get_shortcut(OPEN_OVERRIDE_POPUP)
			TAB_CYCLE_FORWARD:
				tab_cycle_forward_shc = get_shortcut(TAB_CYCLE_FORWARD)
			TAB_CYCLE_BACKWARD:
				tab_cycle_backward_shc = get_shortcut(TAB_CYCLE_BACKWARD)
			_:
				# Update filter buttons.
				for btn_node: Node in filter_box.get_children():
					var btn: Button = btn_node
					var property: StringName = btn.get_meta(&"property")

					btn.button_pressed = get_setting(property, btn.button_pressed)

func get_setting(property: StringName, alt: bool) -> bool:
	var editor_settings: EditorSettings = get_editor_settings()
	if (editor_settings.has_setting(property)):
		return editor_settings.get_setting(property)
	else:
		editor_settings.set_setting(property, alt)
		return alt

func set_setting(property: StringName, value: bool):
	var editor_settings: EditorSettings = get_editor_settings()

	suppress_settings_sync = true
	editor_settings.set_setting(property, value)
	suppress_settings_sync = false

func get_shortcut(property: StringName) -> Shortcut:
	return get_editor_settings().get_setting(property)

func on_tab_changed(index: int):
	if (old_script_editor_base != null):
		old_script_editor_base.edited_script_changed.disconnect(update_selected_tab)
		old_script_editor_base = null

	var script_editor: ScriptEditor = EditorInterface.get_script_editor()
	var script_editor_base: ScriptEditorBase = script_editor.get_current_editor()

	if (script_editor_base != null):
		script_editor_base.edited_script_changed.connect(update_selected_tab)

		old_script_editor_base = script_editor_base

	is_script_changed = true

	if (is_auto_navigate_in_fs && script_editor.get_current_script() != null):
		var file: String = script_editor.get_current_script().get_path()

		if (file.contains(BUILT_IN_SCRIPT)):
			# We navigate to the scene in case of a built-in script.
			file = file.get_slice(BUILT_IN_SCRIPT, 0)

		file_to_navigate = file
	else:
		file_to_navigate = &""

	schedule_update()

func update_selected_tab():
	multiline_tab_container.update_selected_tab()

func update_tabs_position():
	if (is_script_tabs_top):
		old_scripts_tab_container.get_parent().move_child(multiline_tab_container, 0)
	else:
		old_scripts_tab_container.get_parent().move_child(multiline_tab_container, 2)

func update_tabs_close_button():
	multiline_tab_container.show_close_button_always = is_script_tabs_close_button_always

func update_tabs_visibility():
	multiline_tab_container.visible = is_script_tabs_visible

func update_singleline_tabs():
	multiline_tab_container.is_singleline_tabs = is_script_tabs_singleline

func update_keywords(script: Script):
	if (script == null):
		return

	var new_script_type: StringName = script.get_instance_base_type()
	if (old_script_type != new_script_type):
		old_script_type = new_script_type

		keywords.clear()
		keywords["_static_init"] = true
		register_virtual_methods(new_script_type)

func register_virtual_methods(clazz: String):
	for method: Dictionary in ClassDB.class_get_method_list(clazz):
		if (method[&"flags"] & METHOD_FLAG_VIRTUAL > 0):
			keywords[method[&"name"]] = true

func update_outline_cache():
	outline_cache = null

	var script: Script = get_current_script()
	if (!script):
		return

	update_keywords(script)

	# Check if built-in script. In this case we need to duplicate it for whatever reason.
	if (script.get_path().contains(BUILT_IN_SCRIPT)):
		script = script.duplicate()

	outline_cache = OutlineCache.new()

	# Collect all script members.
	for_each_script_member(script, func(array: Array[String], item: String): array.append(item))

	# Remove script members that only exist in the base script (which includes the base of the base etc.).
	# Note: The method that only collects script members without including the base script(s)
	# is not exposed to GDScript.
	var base_script: Script = script.get_base_script()
	if (base_script != null):
		for_each_script_member(base_script, func(array: Array[String], item: String): array.erase(item))

func for_each_script_member(script: Script, consumer: Callable):
	# Functions / Methods
	for dict: Dictionary in script.get_script_method_list():
		var func_name: String = dict[&"name"]

		if (keywords.has(func_name)):
			consumer.call(outline_cache.engine_funcs, func_name)
		else:
			if (is_hide_private_members && func_name.begins_with(UNDERSCORE)):
				continue

			# Inline getter/setter will normally be shown as '@...getter', '@...setter'.
			# Since we already show the variable itself, we will skip those.
			if (func_name.begins_with(INLINE)):
				continue

			consumer.call(outline_cache.funcs, func_name)

	# Properties / Exported variables
	for dict: Dictionary in script.get_script_property_list():
		var property: String = dict[&"name"]
		if (is_hide_private_members && property.begins_with(UNDERSCORE)):
			continue

		var usage: int = dict[&"usage"]

		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			if (usage & PROPERTY_USAGE_STORAGE && usage & PROPERTY_USAGE_EDITOR):
				consumer.call(outline_cache.exports, property)
			else:
				consumer.call(outline_cache.properties, property)

	# Static variables (are separated for whatever reason)
	for dict: Dictionary in script.get_property_list():
		var property: String = dict[&"name"]
		if (is_hide_private_members && property.begins_with(UNDERSCORE)):
			continue

		var usage: int = dict[&"usage"]

		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			consumer.call(outline_cache.properties, property)

	# Signals
	for dict: Dictionary in script.get_script_signal_list():
		var signal_name: String = dict[&"name"]

		consumer.call(outline_cache.signals, signal_name)

	# Constants / Classes
	for name_key: String in script.get_script_constant_map():
		if (is_hide_private_members && name_key.begins_with(UNDERSCORE)):
			continue

		var object: Variant = script.get_script_constant_map().get(name_key)
		# Inner classes have no source code, while a const of type GDScript has.
		if (object is GDScript && !object.has_source_code()):
			consumer.call(outline_cache.classes, name_key)
		else:
			consumer.call(outline_cache.constants, name_key)

func update_outline():
	outline.clear()

	if (outline_cache == null):
		return

	for outline_type: OutlineType in outline_type_order:
		outline_type.add_to_outline.call()

func add_to_outline(items: Array[String], icon: Texture2D, type: StringName, modifier: StringName = &""):
	add_to_outline_ext(items, func(str: String): return icon, type, modifier)

func add_to_outline_ext(items: Array[String], icon_callable: Callable, type: StringName, modifier: StringName = &""):
	var text: String = outline_filter_txt.get_text()

	if (is_sorted()):
		items = items.duplicate()
		items.sort_custom(func(str1: String, str2: String): return str1.naturalnocasecmp_to(str2) < 0)

	for item: String in items:
		if (text.is_empty() || text.is_subsequence_ofn(item)):
			var icon: Texture2D = icon_callable.call(item)
			outline.add_item(item, icon, true)

			var dict: Dictionary[StringName, StringName] = {
				&"type": type,
				&"modifier": modifier
			}
			outline.set_item_metadata(outline.item_count - 1, dict)

func get_func_icon(func_name: String) -> Texture2D:
	var icon: Texture2D = func_icon
	if (func_name.begins_with(GETTER)):
		icon = func_get_icon
	elif (func_name.begins_with(SETTER)):
		icon = func_set_icon

	return icon

func get_editor_scale() -> float:
	return EditorInterface.get_editor_scale()

func get_editor_corner_radius() -> int:
	return EditorInterface.get_editor_settings().get_setting("interface/theme/corner_radius")

func get_editor_accent_color() -> Color:
	return EditorInterface.get_editor_settings().get_setting("interface/theme/accent_color")

func get_editor_icon_saturation() -> float:
	return EditorInterface.get_editor_settings().get_setting("interface/theme/icon_saturation")

func is_sorted() -> bool:
	return get_editor_settings().get_setting("text_editor/script_list/sort_members_outline_alphabetically")

func get_editor_settings() -> EditorSettings:
	return EditorInterface.get_editor_settings()

func load_rel(path: String) -> Variant:
	var script_path: String = get_script().get_path().get_base_dir()
	return load(script_path.path_join(path))

static func find_or_null(arr: Array[Node], index: int = 0) -> Node:
	if (arr.is_empty()):
		push_error("""Node that is needed for Script-IDE not found.
Plugin will not work correctly.
This might be due to some other plugins or changes in the Engine.
Please report this to Script-IDE, so we can figure out a fix.""")
		return null
	return arr[index]

## Cache for everything inside we collected to show in the Outline.
class OutlineCache:
	var classes: Array[String] = []
	var constants: Array[String] = []
	var signals: Array[String] = []
	var exports: Array[String] = []
	var properties: Array[String] = []
	var funcs: Array[String] = []
	var engine_funcs: Array[String] = []

## Outline type for a concrete button with their items in the Outline.
class OutlineType:
	var type_name: StringName
	var add_to_outline: Callable
