extends Control

# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal add_entity_requested(section_name, resource_name)

# ------------------------------------------------------------------------------
# Export Variables
# ------------------------------------------------------------------------------
@export_category("Cell Entity List")
@export var map : CrawlMap = null:						set = set_map
@export var map_position : Vector3i = Vector3i.ZERO:	set = set_map_position
@export var lookup_table_name : StringName = &"":		set = set_lookup_table_name


# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _ready_state : bool = false

# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
@onready var _edit_active_entity_name : LineEdit = %EditActiveEntityName
@onready var _op_facing : OptionButton = %OpFacing
@onready var _btn_entity_settings : Button = $Layout/Toolbar/BtnEntitySettings
@onready var _btn_remove_entity : Button = $Layout/Toolbar/BtnRemoveEntity

@onready var _entity_ui_container : Control = %EntityUIContainer

@onready var _cell_entity_list : ItemList = %CellEntityList
@onready var _rsw : Window = %RSW


# ------------------------------------------------------------------------------
# Setters
# ------------------------------------------------------------------------------
func set_map(m : CrawlMap) -> void:
	if m != map:
		if map != null:
			if map.entity_added.is_connected(_on_map_entity_added):
				map.entity_added.disconnect(_on_map_entity_added)
			if map.entity_removed.is_connected(_on_map_entity_removed):
				map.entity_removed.disconnect(_on_map_entity_removed)
		map = m
		if map != null:
			if not map.entity_added.is_connected(_on_map_entity_added):
				map.entity_added.connect(_on_map_entity_added)
			if not map.entity_removed.is_connected(_on_map_entity_removed):
				map.entity_removed.connect(_on_map_entity_removed)
		_UpdateCellEntityList()

func set_map_position(p : Vector3i) -> void:
	if p != map_position:
		map_position = p
		_UpdateCellEntityList()

func set_lookup_table_name(ltn : StringName) -> void:
	if ltn != lookup_table_name:
		lookup_table_name = ltn
		if _rsw != null:
			_rsw.lookup_table_name = lookup_table_name

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	_ready_state = true
	_entity_ui_container.visible = false
	_cell_entity_list.visible = true

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _GetEntityTypeResourceData(type : StringName) -> Dictionary:
	if type == &"": return {}
	if lookup_table_name == &"": return {}
	var mrlt : CrawlMRLT = Crawl.get_lookup_table(lookup_table_name)
	if mrlt == null: return {}
	
	var parts : PackedStringArray = type.split(":")
	if parts.size() > 0 and parts.size() <= 2:
		var section : StringName = &"unique" if parts.size() == 1 else parts[0]
		var resource_name : StringName = parts[0] if parts.size() == 1 else parts[1]
		return mrlt.get_meta_resource_data(section, resource_name)
	return {}

func _ResetToolbar() -> void:
	if not _ready_state: return
	
	_op_facing.select(0)
	_op_facing.disabled = true
	_btn_entity_settings.disabled = true
	_btn_remove_entity.disabled = true
	_edit_active_entity_name.text = ""
	_edit_active_entity_name.editable = false

func _AddEntityToCellEntityList(entity : CrawlEntity) -> void:
	if entity.type == &"editor": return # Don't handle the "editor" type.
	if _cell_entity_list == null or _GetEntityIndexFromUUID(entity.uuid) >= 0: return
	var entity_data : Dictionary = _GetEntityTypeResourceData(entity.type)
	var uisrc : String = "" if not "ui" in entity_data else entity_data["ui"]
	if not ResourceLoader.exists(uisrc):
		uisrc = ""
	
	var idx : int = _cell_entity_list.item_count
	_cell_entity_list.add_item(entity.entity_name if entity.entity_name != &"" else entity.type)
	_cell_entity_list.set_item_metadata(idx, {"uuid":entity.uuid, "ui": uisrc})

func _RemoveEntityFromCellEntityList(entity : CrawlEntity) -> void:
	var idx : int = _GetEntityIndexFromUUID(entity.uuid)
	if idx < 0: return
	_cell_entity_list.remove_item(idx)

func _UpdateCellEntityList() -> void:
	if map == null: return
	if not map.has_cell(map_position): return
	
	_ResetToolbar()
	
	_cell_entity_list.clear()
	if _entity_ui_container.visible:
		_CloseEntitySettings()
	
	var entities : Array = map.get_entities({"position":map_position})
	for entity in entities:
		_AddEntityToCellEntityList(entity)

func _GetEntityIndexFromUUID(uuid : StringName) -> int:
	if _cell_entity_list == null: return -1
	for i in range(_cell_entity_list.item_count):
		var meta : Dictionary = _cell_entity_list.get_item_metadata(i)
		if meta.uuid == uuid:
			return i
	return -1

func _GetSelectedEntityIdx() -> int:
	if _cell_entity_list == null: return -1
	var idxs : PackedInt32Array = _cell_entity_list.get_selected_items()
	if idxs.size() > 0:
		return idxs[0]
	return -1

func _OpenEntitySettings(idx : int) -> void:
	if _entity_ui_container == null or _entity_ui_container.visible: return
	var meta : Dictionary = _cell_entity_list.get_item_metadata(idx)
	if meta.ui.is_empty(): return # There's no ui to obtain
	
	var entity : CrawlEntity = map.get_entity(meta.uuid)
	if entity == null: return
	
	var CUI = load(meta.ui)
	if not is_instance_of(CUI, PackedScene): return
	
	var ui = CUI.instantiate()
	if not is_instance_of(ui, Control): return
	
	_entity_ui_container.add_child(ui)
	ui.entity = entity
	_entity_ui_container.visible = true
	_cell_entity_list.visible = false

func _CloseEntitySettings() -> void:
	if _entity_ui_container == null or not _entity_ui_container.visible: return
	for child in _entity_ui_container.get_children():
		_entity_ui_container.remove_child(child)
		child.queue_free()
	_entity_ui_container.visible = false
	_cell_entity_list.visible = true

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_map_entity_added(_entity : CrawlEntity) -> void:
	if _entity.position == map_position:
		_AddEntityToCellEntityList(_entity)

func _on_map_entity_removed(_entity : CrawlEntity) -> void:
	if _entity.position == map_position:
		_RemoveEntityFromCellEntityList(_entity)
		if _entity_ui_container.visible:
			_CloseEntitySettings()

func _on_cell_entity_list_item_selected(idx : int) -> void:
	if map == null: return
	var meta : Dictionary = _cell_entity_list.get_item_metadata(idx)
	var entity : CrawlEntity = map.get_entity(meta.uuid)
	if entity == null: return
	
	_btn_remove_entity.disabled = false
	if not meta.ui.is_empty():
		_btn_entity_settings.disabled = false
	
	_op_facing.disabled = false
	var op_idx : int = _op_facing.get_item_index(entity.facing)
	if op_idx >= 0:
		_op_facing.select(op_idx)
	
	_edit_active_entity_name.editable = true
	_edit_active_entity_name.text = entity.entity_name

func _on_cell_entity_list_item_activated(idx : int) -> void:
	_OpenEntitySettings(idx)

func _on_edit_active_entity_name_text_submitted(new_text : String) -> void:
	if map == null: return
	var idx : int = _GetSelectedEntityIdx()
	if idx < 0:
		_edit_active_entity_name.text = ""
		return
	var meta : Dictionary = _cell_entity_list.get_item_metadata(idx)
	var entity : CrawlEntity = map.get_entity(meta.uuid)
	if entity == null: return
	entity.entity_name = new_text
	if new_text.is_empty():
		_cell_entity_list.set_item_text(idx, entity.type)
	else:
		_cell_entity_list.set_item_text(idx, new_text)

func _on_btn_add_entity_pressed() -> void:
	if _rsw == null: return
	if _rsw.visible: return
	_rsw.section_name = &""
	_rsw.popup_centered()

func _on_btn_remove_entity_pressed() -> void:
	if map == null: return
	var idx : int = _GetSelectedEntityIdx()
	if idx < 0: return
	var meta : Dictionary = _cell_entity_list.get_item_metadata(idx)
	map.remove_entity_by_uuid(meta.uuid)
	_cell_entity_list.remove_item(idx)
	_ResetToolbar()

func _on_btn_entity_settings_pressed() -> void:
	var idx : int = _GetSelectedEntityIdx()
	if idx >= 0:
		if _entity_ui_container.visible:
			_CloseEntitySettings()
		else:
			_OpenEntitySettings(idx)

func _on_rsw_item_selected(section_name : StringName, resource_name : StringName) -> void:
	add_entity_requested.emit(section_name, resource_name)
