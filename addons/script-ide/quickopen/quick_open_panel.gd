## Quick open panel to quickly access all resources that are in the project.
## Initially shows all resources, but can be changed to more specific resources
## or filtered down with text.
@tool
extends PopupPanel

const ADDONS: StringName = &"res://addons"
const SEPARATOR: StringName = &" - "
const STRUCTURE_START: StringName = &"("
const STRUCTURE_END: StringName = &")"

#region UI
@onready var filter_bar: TabBar = %FilterBar
@onready var search_option_btn: OptionButton = %SearchOptionBtn
@onready var filter_txt: LineEdit = %FilterTxt
@onready var files_list: ItemList = %FilesList
#endregion

var plugin: EditorPlugin

var scenes: Array[FileData]
var scripts: Array[FileData]
var resources: Array[FileData]
var others: Array[FileData]

# For performance and memory considerations, we add all files into one reusable array.
var all_files: Array[FileData]

var is_rebuild_cache: bool = true

#region Plugin and Shortcut processing
func _ready() -> void:
	files_list.item_selected.connect(open_file)
	search_option_btn.item_selected.connect(rebuild_cache_and_ui.unbind(1))
	filter_txt.text_changed.connect(fill_files_list.unbind(1))

	filter_bar.tab_changed.connect(change_fill_files_list.unbind(1))

	about_to_popup.connect(on_show)

	var file_system: EditorFileSystem = EditorInterface.get_resource_filesystem()
	file_system.filesystem_changed.connect(schedule_rebuild)

	if (plugin != null):
		filter_txt.gui_input.connect(plugin.navigate_on_list.bind(files_list, open_file))

func _shortcut_input(event: InputEvent) -> void:
	if (!event.is_pressed() || event.is_echo()):
		return

	if (plugin.tab_cycle_forward_shc.matches_event(event)):
		get_viewport().set_input_as_handled()

		var new_tab: int = filter_bar.current_tab + 1
		if (new_tab == filter_bar.get_tab_count()):
			new_tab = 0
		filter_bar.current_tab = new_tab
	elif (plugin.tab_cycle_backward_shc.matches_event(event)):
		get_viewport().set_input_as_handled()

		var new_tab: int = filter_bar.current_tab - 1
		if (new_tab == -1):
			new_tab = filter_bar.get_tab_count() - 1
		filter_bar.current_tab = new_tab
#endregion

func open_file(index: int):
	var file: String = files_list.get_item_metadata(index)

	if (ResourceLoader.exists(file)):
		var res: Resource = load(file)

		if (res is Script):
			EditorInterface.edit_script(res)
			EditorInterface.set_main_screen_editor.call_deferred("Script")
		else:
			EditorInterface.edit_resource(res)

		if (res is PackedScene):
			EditorInterface.open_scene_from_path(file)

			# Need to be deferred as it does not work otherwise.
			var root: Node = EditorInterface.get_edited_scene_root()
			if (root is Node3D):
				EditorInterface.set_main_screen_editor.call_deferred("3D")
			else:
				EditorInterface.set_main_screen_editor.call_deferred("2D")
	else:
		# Text files (.txt, .md) will not be recognized, which seems to be a very bad
		# limitation from the Engine. The methods called by the Engine are also not exposed.
		# So we just select the file, which is better than nothing.
		EditorInterface.select_file(file)

	# Deferred as otherwise we get weird errors in the console.
	# Probably due to this beeing called in a signal and auto unparent is true.
	# 100% Engine bug or at least weird behavior.
	hide.call_deferred()

func schedule_rebuild():
	is_rebuild_cache = true

func on_show():
	if (search_option_btn.selected != 0):
		search_option_btn.selected = 0

		is_rebuild_cache = true

	var rebuild_ui: bool = false
	var all_tab_not_pressed: bool = filter_bar.current_tab != 0
	rebuild_ui = is_rebuild_cache || all_tab_not_pressed

	if (is_rebuild_cache):
		rebuild_cache()

	if (rebuild_ui):
		if (all_tab_not_pressed):
			# Triggers the ui update.
			filter_bar.current_tab = 0
		else:
			fill_files_list()

	filter_txt.select_all()
	focus_and_select_first()

func rebuild_cache():
	is_rebuild_cache = false

	all_files.clear()
	scenes.clear()
	scripts.clear()
	resources.clear()
	others.clear()

	build_file_cache()

func rebuild_cache_and_ui():
	rebuild_cache()
	fill_files_list()

	focus_and_select_first()

func focus_and_select_first():
	filter_txt.grab_focus()

	if (files_list.item_count > 0):
		files_list.select(0)

func build_file_cache():
	var dir: EditorFileSystemDirectory = EditorInterface.get_resource_filesystem().get_filesystem()
	build_file_cache_dir(dir)

	all_files.append_array(scenes)
	all_files.append_array(scripts)
	all_files.append_array(resources)
	all_files.append_array(others)

func build_file_cache_dir(dir: EditorFileSystemDirectory):
	for index: int in dir.get_subdir_count():
		build_file_cache_dir(dir.get_subdir(index))

	for index: int in dir.get_file_count():
		var file: String = dir.get_file_path(index)
		if (search_option_btn.get_selected_id() == 0 && file.begins_with(ADDONS)):
			continue

		var last_delimiter: int = file.rfind(&"/")

		var file_name: String = file.substr(last_delimiter + 1)
		var file_structure: String = &""
		if (file_name.length() + 6 != file.length()):
			file_structure = SEPARATOR + STRUCTURE_START + file.substr(6, last_delimiter - 6) + STRUCTURE_END

		var file_data: FileData = FileData.new()
		file_data.file = file
		file_data.file_name = file_name
		file_data.file_name_structure = file_name + file_structure
		file_data.file_type = dir.get_file_type(index)

		# Needed, as otherwise we have no icon.
		if (file_data.file_type == &"Resource"):
			file_data.file_type = &"Object"

		match (file.get_extension()):
			&"tscn": scenes.append(file_data)
			&"gd": scripts.append(file_data)
			&"tres": resources.append(file_data)
			&"gdshader": resources.append(file_data)
			_: others.append(file_data)

func change_fill_files_list():
	fill_files_list()

	focus_and_select_first()

func fill_files_list():
	files_list.clear()

	if (filter_bar.current_tab == 0):
		fill_files_list_with(all_files)
	elif (filter_bar.current_tab == 1):
		fill_files_list_with(scenes)
	elif (filter_bar.current_tab == 2):
		fill_files_list_with(scripts)
	elif (filter_bar.current_tab == 3):
		fill_files_list_with(resources)
	elif (filter_bar.current_tab == 4):
		fill_files_list_with(others)

func fill_files_list_with(files: Array[FileData]):
	var filter_text: String = filter_txt.text
	files.sort_custom(sort_by_filter)

	for file_data: FileData in files:
		var file: String = file_data.file
		if (filter_text.is_empty() || filter_text.is_subsequence_ofn(file)):
			var icon: Texture2D = EditorInterface.get_base_control().get_theme_icon(file_data.file_type, &"EditorIcons")

			files_list.add_item(file_data.file_name_structure, icon)
			files_list.set_item_metadata(files_list.item_count - 1, file)
			files_list.set_item_tooltip(files_list.item_count - 1, file)

func sort_by_filter(file_data1: FileData, file_data2: FileData) -> bool:
	var filter_text: String = filter_txt.text
	var name1: String = file_data1.file_name
	var name2: String = file_data2.file_name

	for index: int in filter_text.length():
		var a_oob: bool = index >= name1.length()
		var b_oob: bool = index >= name2.length()

		if (a_oob):
			if (b_oob):
				return false;
			return true
		if (b_oob):
			return false

		var char: String = filter_text[index]
		var a_match: bool = char == name1[index]
		var b_match: bool = char == name2[index]

		if (a_match && !b_match):
			return true

		if (b_match && !a_match):
			return false

	return name1 < name2

class FileData:
	var file: String
	var file_name: String
	var file_name_structure: String
	var file_type: StringName
