extends Window

# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal item_active(idx)

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const RESOURCEENTRYITEM : PackedScene = preload("res://scenes/dungeon_editor/control_nodes/resource_selection_window/resource_entry_item/ResourceEntryItem.tscn")

# ------------------------------------------------------------------------------
# Export Variables
# ------------------------------------------------------------------------------
@export_category("Resource Selection Window")
@export_group("View")
@export var camera_height : float = 1.0:									set = set_camera_height
@export_range(-90.0, 90.0, 0.1) var camera_pitch_degrees : float = 0.0:		set = set_camera_pitch_degrees
@export var camera_zoom : float = 2.0:										set = set_camera_zoom
@export_group("Resource")
@export var lookup_table_name : StringName = &"":							set = set_lookup_table_name
@export var section_name : StringName = &"":								set = set_section_name


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


# ------------------------------------------------------------------------------
# Setters
# ------------------------------------------------------------------------------
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

func set_lookup_table_name(ltn : StringName) -> void:
	if ltn != lookup_table_name:
		lookup_table_name = ltn
		_UpdateResourceList()

func set_section_name(sn : StringName) -> void:
	if sn != section_name:
		section_name = sn
		_UpdateResourceList()

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	_UpdateCameraPlacement()
	_UpdateResourceList()

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _UpdateCameraPlacement() -> void:
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

func _UpdateResourceList() -> void:
	_ClearResourceList()
	if _resource_view == null: return
	_resource_view.lookup_table_name = lookup_table_name
	_resource_view.resource_section = section_name
	
	if lookup_table_name == &"" or section_name == &"": return
	
	var mrlt : CrawlMRLT = Crawl.get_lookup_table(lookup_table_name)
	if mrlt == null: return
	if not mrlt.has_section(section_name): return
	
	var info_list : Array = mrlt.get_meta_resource_descriptions(section_name)
	for info in info_list:
		var entry = RESOURCEENTRYITEM.instantiate()
		if entry == null: continue
		entry.entry_name = info["name"]
		entry.description = info["description"]
		var idx : int = _entries.size()
		_entries.append(entry)
		_list_container.add_child(entry)
		
		entry.active.connect(_on_entry_active.bind(idx, info["name"]))

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func has_active_entry() -> bool:
	return _active_entry >= 0

func get_active_entry_index() -> int:
	return _active_entry

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
func _on_entry_active(idx : int, resource_name : StringName) -> void:
	_resource_view.resource_name = resource_name
	_active_entry = idx
	item_active.emit(idx)
