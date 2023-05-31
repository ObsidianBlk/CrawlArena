extends Control


# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal action_requested(action, payload)
signal focus_changed(focus_position)

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const CELL_SIZE : float = 4.4

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _map : CrawlMap = null
var _editor_entity : CrawlEntity = null
var _dig_mode : bool = true
var _dig_direction : int = 1 # 0 = Down | 1 = Foreward | 2 = Up

# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
@onready var _crawl_mini_map : CrawlMiniMap = %CrawlMiniMap
@onready var _z_elevation_bar : Control = %ZElevationBar
@onready var _dig_state : Control = %DigState
@onready var _crawl_view_3d : CrawlView3D = %CrawlView3D
@onready var _dungeon_viewport : SubViewport = %DungeonViewport
@onready var _entity_container : Node3D = %EntityContainer

@onready var _btn_request_save_map : Button = %RequestSaveMap
@onready var _edit_map_name : LineEdit = %Edit_MapName

@onready var dungeon_io_window : Window = %DungeonIOWindow
@onready var _accept_dialog : AcceptDialog = %AcceptDialog

@onready var _active_cell_state : Control = %ActiveCellState
@onready var _style_control : Control = %StyleControl
@onready var _cell_entity_list : Control = %CellEntityList

@onready var _exit_menu : Popup = %ExitMenu
@onready var _btn_resume : Button = %BtnResume


# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	_crawl_view_3d.cell_size = CELL_SIZE
	_active_cell_state.lookup_table_name = &"level_geometry"	
	_CreateDungeon()
	

func _unhandled_input(event : InputEvent) -> void:
	if _editor_entity == null: return
	if _exit_menu != null and _exit_menu.visible == true: return
	
	if event.is_action_pressed("ui_cancel", false, true):
		if _exit_menu == null: return
		_exit_menu.popup_centered()
		_btn_resume.grab_focus()
		accept_event()
	
	if event.is_action_pressed("foreward", false, true):
		_editor_entity.move(&"foreward", true)
		accept_event()
	if event.is_action_pressed("backward", false, true):
		_editor_entity.move(&"backward", true)
		accept_event()
	if event.is_action_pressed("step_up", false, true):
		_editor_entity.move(&"up", true)
		accept_event()
	if event.is_action_pressed("step_down", false, true):
		_editor_entity.move(&"down", true)
		accept_event()
	if event.is_action_pressed("step_left", false, true):
		_editor_entity.move(&"left", true)
		accept_event()
	if event.is_action_pressed("step_right", false, true):
		_editor_entity.move(&"right", true)
		accept_event()
	if event.is_action_pressed("turn_left", false, true):
		_editor_entity.turn_left()
		accept_event()
	if event.is_action_pressed("turn_right", false, true):
		_editor_entity.turn_right()
		accept_event()
	if event.is_action_pressed("dig", false, true):
		var map : CrawlMap = _editor_entity.get_map()
		if map == null: return
		var surf : Crawl.SURFACE = _editor_entity.facing
		if _dig_direction != 1:
			surf = Crawl.SURFACE.Ground if _dig_direction == 0 else Crawl.SURFACE.Ceiling
		if _dig_mode:
			map.dig(_editor_entity.position, surf)
		else:
			map.fill(_editor_entity.position, surf)
		accept_event()
	if event.is_action_pressed("toggle_dig_direction", false, true):
		_dig_state.cycle_direction()
		accept_event()
	if event.is_action_pressed("toggle_dig_mode", false, true):
		_dig_mode = not _dig_mode
		accept_event()


# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _EntityTypeParts(type : StringName) -> PackedStringArray:
	var parts : PackedStringArray = type.split(":")
	if parts.size() > 2:
		return PackedStringArray([])
	if parts.size() == 1:
		return PackedStringArray([&"unique", parts[0]])
	return parts

func _UpdateElevation() -> void:
	var bounds : AABB = _map.get_aabb()
	if bounds.size.x < 0 or bounds.size.y < 0: return
	_z_elevation_bar.min_z_level = bounds.position.y
	_z_elevation_bar.max_z_level = bounds.end.y - 1

func _ShowAcceptDialog(title : String, text : String) -> void:
	if _accept_dialog.visible : return
	_accept_dialog.title = title
	_accept_dialog.dialog_text = text
	_accept_dialog.popup_centered()

func _ClearDungeon() -> void:
	_active_cell_state.map = null
	_cell_entity_list.map = null
	_crawl_view_3d.map = null
	_crawl_mini_map.map = null
	_crawl_mini_map.focus_entity_uuid = &""
	
	for child in _entity_container.get_children():
		_entity_container.remove_child(child)
		child.queue_free()

	if _map != null:
		if _map.cell_added.is_connected(_on_map_cell_added):
			_map.cell_added.disconnect(_on_map_cell_added)
		if _map.cell_removed.is_connected(_on_map_cell_removed):
			_map.cell_removed.disconnect(_on_map_cell_removed)
		if _map.entity_added.is_connected(_on_map_entity_added):
			_map.entity_added.disconnect(_on_map_entity_added)
		_map = null
	
	if _editor_entity != null:
		if _editor_entity.position_changed.is_connected(_on_editor_entity_position_changed):
			_editor_entity.position_changed.disconnect(_on_editor_entity_position_changed)
		_editor_entity = null

func _ConnectDungeonEntity(entity : CrawlEntity) -> void:
	var elt : CrawlMRLT = Crawl.get_lookup_table(&"entities")
	if elt == null: return
	
	var tparts : PackedStringArray = _EntityTypeParts(entity.type)
	if tparts.size() != 2: return
	var entity_node = elt.load_meta_resource(tparts[0], tparts[1], true)
	if is_instance_of(entity_node, CrawlEntityNode3D):
		if entity.type == &"editor":
			entity.set_block_all(false) # This is a bug fix. Shouldn't be needed anymore, but doesn't hurt.
			if _editor_entity != null: return # Already have one... skip!
			_editor_entity = entity
		else:
			if not focus_changed.is_connected(entity_node.set_focus_position):
				focus_changed.connect(entity_node.set_focus_position)
		entity_node.cell_size = CELL_SIZE
		entity_node.entity = entity
		_entity_container.add_child(entity_node)

func _ConnectDungeon(map : CrawlMap) -> void:
	if _map != null:
		printerr("Failed to connect dungeon map. Any active map must be cleared first.")
		return
	
	_map = map
	if not _map.cell_added.is_connected(_on_map_cell_added):
		_map.cell_added.connect(_on_map_cell_added)
	if not _map.cell_removed.is_connected(_on_map_cell_removed):
		_map.cell_removed.connect(_on_map_cell_removed)
	if not _map.entity_added.is_connected(_on_map_entity_added):
		_map.entity_added.connect(_on_map_entity_added)
	
	_edit_map_name.text = _map.name
	var entities = _map.get_entities()
	for entity in entities:
		_ConnectDungeonEntity(entity)
	
	_active_cell_state.map = _map
	_cell_entity_list.map = _map
	_crawl_view_3d.map = _map
	_crawl_mini_map.map = _map
	_UpdateElevation()
	
	if _editor_entity != null:
		if not _editor_entity.position_changed.is_connected(_on_editor_entity_position_changed):
			_editor_entity.position_changed.connect(_on_editor_entity_position_changed)
		_crawl_mini_map.focus_entity_uuid = _editor_entity.uuid
		_on_editor_entity_position_changed(Vector3i.ZERO, _editor_entity.position)


func _CreateDungeon() -> void:
	_ClearDungeon()
	
	var map : CrawlMap = CrawlMap.new()
	map.id = UUID.v7()
	map.add_resource(&"default")
	map.add_cell(Vector3i.ZERO)
	
	var entity : CrawlEntity = CrawlEntity.new()
	entity.type = &"editor"
	entity.uuid = UUID.v7()
	entity.set_block_all(false)
	
	map.add_entity(entity)
	
	_ConnectDungeon(map)

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_request_new_map_pressed() -> void:
	# TODO: Check if a map already exists and if that map is "dirty"
	#   if so, bring up a dialog box warning that a new Dungeon will
	#   erase the existing one.
	#   If the map is NOT dirty, then just create a new dungeon.
	_CreateDungeon()

func _on_request_load_map_pressed() -> void:
	if dungeon_io_window == null: return
	if dungeon_io_window.visible: return
	dungeon_io_window.popup_centered()

func _on_request_save_map_pressed() -> void:
	if _map == null: return
	if _edit_map_name.text.is_empty():
		_ShowAcceptDialog(
			"Dungeon Name Missing",
			"Cannot save dungeon without a name."
		)
		return
	var err : int = DungeonDatabase.save_dungeon(_map)
	if err != OK:
		_ShowAcceptDialog(
			"Dungeon Save Failed",
			"Failed to save the dungeon."
		)
		# TODO: Lookup error codes that could be returned and
		#   display a more informative message.
		printerr("Failed to save the dungeon map. Error code ", err)
	else:
		_ShowAcceptDialog(
			"Dungeon Saved",
			"Dungeon successfully saved."
		)

func _on_dungeon_io_window_dungeon_loaded(map : CrawlMap) -> void:
	if map == null: return
	_ClearDungeon()
	_ConnectDungeon(map)

func _on_dungeon_io_window_dungeon_deleted(id : StringName) -> void:
	if _map != null and _map.id == id:
		_CreateDungeon()

func _on_map_cell_added(map_position : Vector3i) -> void:
	_style_control.copy_style_to_map(
		_map, map_position,
		{
			"set_if_src_empty":true,
			"set_if_dst_empty":false,
			"ignore_blocking":true
		},
		false
	)
	_UpdateElevation()

func _on_map_cell_removed(_map_position : Vector3i) -> void:
	_UpdateElevation()

func _on_map_entity_added(entity : CrawlEntity) -> void:
	if entity.type == &"": return
	var parts : PackedStringArray = entity.type.split(":")
	if parts.size() <= 0 or parts.size() > 2: return
	var section_name : StringName = &"unique" if parts.size() == 1 else parts[0]
	var resource_name : StringName = parts[1] if parts.size() == 2 else parts[0]
	
	var mrlt : CrawlMRLT = Crawl.get_lookup_table(&"entities")
	if mrlt == null: return
	if not mrlt.has_meta_resource(section_name, resource_name):
		printerr("FAILED TO ADD ENTITY NODE: No entity node of type \"", entity.type, "\" found.")
		return
	var node = mrlt.load_meta_resource(section_name, resource_name, true)
	if node == null:
		printerr("FAILED TO INSTATIATE ENTITY NODE: No node instance for entity type \"", entity.type, "\".")
		return
	if not is_instance_of(node, CrawlEntityNode3D):
		printerr("ENTITY NODE TYPE INVALID: Entity type \"", entity.type, "\" returned invalid node type.")
		node.queue_free()
		return
		
	node.cell_size = CELL_SIZE
	node.entity = entity
	if node.has_method("set_passive_mode"):
		node.passive_mode = true
	_entity_container.add_child(node)


func _on_editor_entity_position_changed(_from : Vector3i, to : Vector3i) -> void:
	_z_elevation_bar.z_level = to.y
	_active_cell_state.map_position = to
	_cell_entity_list.map_position = to
	_crawl_view_3d.focus_position = to
	focus_changed.emit(to)

func _on_dig_state_direction_changed(direction : int) -> void:
	_dig_direction = direction

func _on_active_cell_surface_resource_selected(surface : Crawl.SURFACE, resource_name : StringName) -> void:
	if _map == null: return
	var mrid : int = _map.get_resource_id(resource_name)
	if mrid < 0 and resource_name != &"":
		mrid = _map.add_resource(resource_name)
	_map.set_cell_surface_resource(_editor_entity.position, surface, mrid,true)

func _on_active_cell_stair_state_toggled() -> void:
	if _map == null or _editor_entity == null: return
	if not _map.has_cell(_editor_entity.position): return
	var pos : Vector3i = _editor_entity.position
	_map.set_cell_stairs(pos, not _map.is_cell_stairs(pos))

func _on_active_cell_surface_blocking_toggled(surface : Crawl.SURFACE) -> void:
	if _map == null or _editor_entity == null: return
	if not _map.has_cell(_editor_entity.position): return
	var pos : Vector3i = _editor_entity.position
	var is_blocking : bool = _map.is_cell_surface_blocking(pos, surface)
	_map.set_cell_surface_blocking(pos, surface, not is_blocking, true)

func _on_edit_map_name_text_changed(new_text : String) -> void:
	if _btn_request_save_map == null: return
	_btn_request_save_map.disabled = new_text.is_empty()
	_map.name = new_text

func _on_btn_style_active_cell_pressed():
	if _map == null or _editor_entity == null: return
	_style_control.copy_style_to_map(
		_map, _editor_entity.position,
		{
			"set_if_src_empty":true,
			"set_if_dst_empty":false,
			"ignore_blocking":true
		},
		false
	)

func _on_cell_entity_list_add_requested(section_name : StringName, resource_name : StringName) -> void:
	if _map == null or _editor_entity == null: return
	var entity : CrawlEntity = CrawlEntity.new()
	entity.uuid = UUID.v7()
	entity.type = StringName("%s:%s"%[section_name, resource_name])
	entity.position = _editor_entity.position
	entity.facing = _editor_entity.facing
	_map.add_entity(entity)
	

func _on_btn_resume_pressed():
	_exit_menu.visible = false

func _on_btn_quit_editor_pressed():
	action_requested.emit(&"close", null)

func _on_btn_quit_desktop_pressed():
	action_requested.emit(&"quit_app", null)
