extends Control


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

@onready var _active_cell_state : Control = %ActiveCellState

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	_crawl_view_3d.cell_size = CELL_SIZE
	_active_cell_state.lookup_table_name = &"level_geometry"	
	_CreateDungeon()
	

func _input(event : InputEvent) -> void:
	if _editor_entity == null: return
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
func _ClearDungeon() -> void:
	_active_cell_state.map = null
	_crawl_view_3d.map = null
	_crawl_mini_map.map = null
	_crawl_mini_map.focus_entity_uuid = &""
	
	for child in _entity_container.get_children():
		_entity_container.remove_child(child)
		child.queue_free()

	if _map != null:
		if _map.cell_added.is_connected(_on_map_cell_count_changed):
			_map.cell_added.disconnect(_on_map_cell_count_changed)
		if _map.cell_removed.is_connected(_on_map_cell_count_changed):
			_map.cell_removed.disconnect(_on_map_cell_count_changed)
		_map = null
	
	if _editor_entity != null:
		if _editor_entity.position_changed.is_connected(_on_editor_entity_position_changed):
			_editor_entity.position_changed.disconnect(_on_editor_entity_position_changed)
		_editor_entity = null

func _CreateDungeon() -> void:
	_ClearDungeon()
	
	_map = CrawlMap.new()
	_map.id = UUID.v7()
	_map.add_resource(&"default")
	_map.add_cell(Vector3i.ZERO)
	
	_editor_entity = CrawlEntity.new()
	_editor_entity.type = &"editor"
	_editor_entity.uuid = UUID.v7()
	
	_map.add_entity(_editor_entity)
	
	_map.cell_added.connect(_on_map_cell_count_changed)
	_map.cell_removed.connect(_on_map_cell_count_changed)
	_editor_entity.position_changed.connect(_on_editor_entity_position_changed)
	
	_active_cell_state.map = _map
	_crawl_view_3d.map = _map
	_crawl_mini_map.map = _map
	_crawl_mini_map.focus_entity_uuid = _editor_entity.uuid
	
	var elt : CrawlMRLT = Crawl.get_lookup_table(&"entities")
	if elt != null:
		var view : Node3D = elt.load_meta_resource(&"unique", &"editor", true)
		if view != null:
			view.cell_size = CELL_SIZE
			view.entity = _editor_entity
			_entity_container.add_child(view)
	
	_on_map_cell_count_changed(Vector3i.ZERO)
	_on_editor_entity_position_changed(Vector3i.ZERO, _editor_entity.position)
	

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
		# TODO: Show dialog that states that a map name is missing
		return
	var err : int = DungeonDatabase.save_dungeon(_map)
	if err != OK:
		# TODO: Show dialog box stating there was a failure to save map.
		printerr("Failed to save the dungeon map. Error code ", err)

func _on_dungeon_io_window_dungeon_loaded(map : CrawlMap) -> void:
	if map == null: return
	# TODO 1: Clear current dungeon!
	# TODO 2: rework _CreateDungeon in such a way as it creates a dungeon and
	#   passes that dungeon to a new method called _ConnectDungeon
	# TODO 3: Call _ConnectDungeon with the given map!
	print("Given a dungeon with ID ", map.id)

func _on_dungeon_io_window_dungeon_deleted(id : StringName) -> void:
	if _map != null and _map.id == id:
		_CreateDungeon()

func _on_map_cell_count_changed(_pos : Vector3i) -> void:
	var bounds : AABB = _map.get_aabb()
	if bounds.size.x < 0 or bounds.size.y < 0: return
	_z_elevation_bar.min_z_level = bounds.position.y
	_z_elevation_bar.max_z_level = bounds.end.y - 1

func _on_editor_entity_position_changed(_from : Vector3i, to : Vector3i) -> void:
	_z_elevation_bar.z_level = to.y
	_active_cell_state.map_position = to
	_crawl_view_3d.focus_position = to

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
