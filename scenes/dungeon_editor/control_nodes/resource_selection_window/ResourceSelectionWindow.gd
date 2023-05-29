@tool
extends Window

# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal item_active(idx)
signal item_selected(section_name, resource_name)
signal section_selected(section_name)
signal canceled()

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const RESOURCEENTRYITEM : PackedScene = preload("res://scenes/dungeon_editor/control_nodes/resource_selection_window/resource_entry_item/ResourceEntryItem.tscn")

const DEFAULT_THEME_TYPE : StringName = &"ResourceSelectionWindow"

# ------------------------------------------------------------------------------
# Export Variables
# ------------------------------------------------------------------------------
@export_category("Resource Selection Window")
@export var allow_none : bool = true:										set = set_allow_none
@export_group("View")
@export var camera_height : float = 1.0:									set = set_camera_height
@export_range(-90.0, 90.0, 0.1) var camera_pitch_degrees : float = 0.0:		set = set_camera_pitch_degrees
@export var camera_zoom : float = 2.0:										set = set_camera_zoom
@export_range(-90.0, 90.0, 0.1) var light_angle_degrees : float = 0.0:		set = set_light_angle_degrees
@export_group("Resource")
@export var lookup_table_name : StringName = &"":							set = set_lookup_table_name
@export var section_name : StringName = &"":								set = set_section_name
@export var allow_section_browsing : bool = false:							set = set_allow_section_browsing
@export var resource_position : Vector3 = Vector3.ZERO:						set = set_resource_position

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _entries : Array = []
var _active_entry : int = -1

# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
@onready var _resource_view : Control = %ResourceView3DControl
@onready var _list_container : Control = %ListContainer
@onready var _cpanel : PanelContainer = $CPanel

@onready var _lbl_group : Label = %LblGroup


@onready var _btn_back : Button = %BtnBack
@onready var _spacer : Control= %Spacer


# ------------------------------------------------------------------------------
# Setters
# ------------------------------------------------------------------------------
func set_allow_none(n : bool) -> void:
	if n != allow_none:
		allow_none = n
		_UpdateResourceList()

func set_camera_height(h : float) -> void:
	if h != camera_height:
		camera_height = h
		_UpdateCameraPlacement()

func set_camera_pitch_degrees(p : float) -> void:
	if p >= -90.0 and p <= 90.0 and p != camera_pitch_degrees:
		camera_pitch_degrees = p
		_UpdateCameraPlacement()

func set_camera_zoom(z : float) -> void:
	if z >= 0.0 and z != camera_zoom:
		camera_zoom = z
		_UpdateCameraPlacement()

func set_light_angle_degrees(d : float) -> void:
	if d >= -90.0 and d <= 90.0:
		light_angle_degrees = d
		if Engine.is_editor_hint(): return
		if _resource_view != null:
			_resource_view.light_angle_degrees = light_angle_degrees

func set_lookup_table_name(ltn : StringName) -> void:
	if ltn != lookup_table_name:
		lookup_table_name = ltn
		_UpdateResourceList()

func set_section_name(sn : StringName) -> void:
	if sn != section_name:
		section_name = sn
		_UpdateResourceList()

func set_allow_section_browsing(a : bool) -> void:
	if a != allow_section_browsing:
		allow_section_browsing = a
		if Engine.is_editor_hint(): return
		if _btn_back != null and _spacer != null:
			if allow_section_browsing:
				_btn_back.visible = section_name != &""
				_spacer.visible = section_name != &""
			else:
				_btn_back.visible = false
				_spacer.visible = false

func set_resource_position(p : Vector3) -> void:
	resource_position = p
	if _resource_view != null:
		_resource_view.resource_position = resource_position

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	set_resource_position(resource_position)
	set_light_angle_degrees(light_angle_degrees)
	visibility_changed.connect(_on_visibility_changed)
	_UpdateChildThemeTypeVariations(_GetThemeType())
	_UpdateCameraPlacement()
	if visible:
		_UpdateResourceList()

func _notification(what : int) -> void:
	match what:
		NOTIFICATION_THEME_CHANGED:
			if theme_type_variation != &"":
				_UpdateChildThemeTypeVariations(theme_type_variation)
			else:
				_UpdateChildThemeTypeVariations(DEFAULT_THEME_TYPE)
		NOTIFICATION_VISIBILITY_CHANGED:
			pass

func _unhandled_input(event : InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if allow_section_browsing and section_name != &"":
			section_name = &""
		else:
			visible = false

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _GetThemeType() -> StringName:
	if theme_type_variation != &"":
		return theme_type_variation
	return DEFAULT_THEME_TYPE

func _UpdateChildThemeTypeVariations(variation : StringName) -> void:
	if _resource_view != null:
		if _resource_view.theme_type_variation != variation:
			_resource_view.theme_type_variation = variation
#	if _cpanel != null:
#		if _cpanel.theme_type_variation != variation:
#			_cpanel.theme_type_variation = variation
	for entry in _entries:
		if entry.theme_type_variation != variation:
			entry.theme_type_variation = variation

func _UpdateCameraPlacement() -> void:
	if Engine.is_editor_hint(): return
	if _resource_view == null: return
	_resource_view.camera_height = camera_height
	_resource_view.camera_pitch_degrees = camera_pitch_degrees
	_resource_view.camera_zoom = camera_zoom

func _ClearResourceList() -> void:
	if _list_container == null: return
	for entry in _entries:
		_list_container.remove_child(entry)
		entry.queue_free()
	_entries.clear()
	_active_entry = -1
	_resource_view.resource_name = &""


func _UpdateResourceList() -> void:
	if Engine.is_editor_hint(): return
	_ClearResourceList()
	
	if _resource_view == null: return
	_resource_view.lookup_table_name = lookup_table_name
	_resource_view.resource_section = section_name
	
	if lookup_table_name == &"": return
	if not allow_section_browsing and section_name == &"": return
	
	if allow_section_browsing:
		_btn_back.visible = section_name != &""
		_spacer.visible = section_name != &""
	else:
		_btn_back.visible = false
		_spacer.visible = false
	
	var mrlt : CrawlMRLT = Crawl.get_lookup_table(lookup_table_name)
	if mrlt == null: return
	if not allow_section_browsing and not mrlt.has_section(section_name): return
	
	var StoreEntry = func(info : Dictionary, empty_resource_name : bool = false):
		var entry = RESOURCEENTRYITEM.instantiate()
		if entry != null:
			entry.entry_name = info["name"]
			entry.description = info["description"]
			var idx : int = _entries.size()
			_entries.append(entry)
			_list_container.add_child(entry)
			entry.selected.connect(_on_entry_selected.bind(
				idx,
				&"" if empty_resource_name else info["name"]
			))
			entry.activated.connect(_on_entry_activated.bind(
				idx,
				&"" if empty_resource_name else info["name"]
			))
	
	if section_name == &"":
		_lbl_group.text = "Select Group..."
		var section_list : PackedStringArray = mrlt.get_section_list()
		for section in section_list:
			StoreEntry.call({"name":section, "description":section})
	else:
		_lbl_group.text = "%s:"%[section_name.capitalize()]
		if allow_none:
			StoreEntry.call({"name":&"Empty", "description":"Empty Selection"}, true)
		
		var info_list : Array = mrlt.get_meta_resource_descriptions(section_name)
		for info in info_list:
			if section_name == "unique" and info["name"] == &"editor": continue
			StoreEntry.call(info)

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func entry_count() -> int:
	return _entries.size()

func has_active_entry() -> bool:
	return _active_entry >= 0

func get_active_entry_index() -> int:
	return _active_entry

func clear_selected_entry() -> void:
	for entry in _entries:
		if entry.is_selected():
			entry.set_selected(false)
			_resource_view.resource_name = &""
			break

func activate_entry_by_index(idx : int) -> void:
	if not (idx >= 0 and idx < _entries.size()): return
	if _active_entry == idx: return
	for eidx in range(_entries.size()):
		_entries[eidx].set_active(eidx == idx)
	_active_entry = idx

func activate_entry_by_resource(resource_name : StringName) -> void:
	# DEPRECATED!!! Remove any call to me please!!!
	activate_entry_by_name(resource_name)

func activate_entry_by_name(entry_name : StringName) -> void:
	# TODO: Technically cannot promise _entries[eidx].entry_name is the same
	#   as a resource_name.
	if _entries.size() <= 0: return
	for eidx in range(_entries.size()):
		if _entries[eidx].entry_name == entry_name:
			_active_entry = eidx
			_entries[eidx].set_selected(true)
		else:
			_entries[eidx].set_selected(false)

func set_entry_metadata(idx : int, metadata : Variant) -> void:
	if idx >= 0 and idx < _entries.size():
		_entries[idx].set_meta_data(metadata)

func get_entry_metadata(idx : int) -> Variant:
	if idx >= 0 and idx < _entries.size():
		return _entries[idx].get_meta_data()
	return null

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_visibility_changed() -> void:
	if visible:
		_UpdateResourceList()

func _on_entry_selected(idx : int, entry_name : StringName) -> void:
	if section_name != &"":
		_resource_view.resource_name = entry_name
	for eidx in range(_entries.size()):
		if eidx == idx: continue
		_entries[eidx].set_selected(false)
	_active_entry = idx
	item_active.emit(idx)

func _on_entry_activated(idx : int, entry_name : StringName) -> void:
	if entry_name == &"": return
	var keep_open : bool = false
	if section_name != &"":
		item_selected.emit(section_name, entry_name)
	else:
		section_name = entry_name
		section_selected.emit(section_name)
		keep_open = true
	clear_selected_entry()
	visible = keep_open

func _on_btn_back_pressed() -> void:
	section_name = &""

func _on_btn_select_pressed() -> void:
	if lookup_table_name == &"" or (not allow_section_browsing and section_name == &""): return
	if _active_entry < 0: return
	var keep_open : bool = false
	if section_name != &"":
		item_selected.emit(section_name, _resource_view.resource_name)
	else:
		section_name = _entries[_active_entry].entry_name
		section_selected.emit(section_name)
		keep_open = true
	clear_selected_entry()
	visible = keep_open

func _on_btn_cancel_pressed() -> void:
	clear_selected_entry()
	visible = false
	canceled.emit()
