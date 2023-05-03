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

@onready var _active_cell_state : Control = %ActiveCellState

@onready var _rsw_level : Window = %RSW_Level

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	_map = CrawlMap.new()
	_map.add_resource(&"default")
	_map.add_cell(Vector3i.ZERO)
	
	_editor_entity = CrawlEntity.new()
	_editor_entity.type = &"editor"
	_editor_entity.uuid = UUID.v7()
	
	_map.add_entity(_editor_entity)
	
	_crawl_mini_map.map = _map
	_crawl_mini_map.focus_entity_uuid = _editor_entity.uuid
	
	_map.cell_added.connect(_on_map_cell_count_changed)
	_map.cell_removed.connect(_on_map_cell_count_changed)
	_editor_entity.position_changed.connect(_on_editor_entity_position_changed)
	
	_crawl_view_3d.cell_size = CELL_SIZE
	_crawl_view_3d.map = _map
	var elt : CrawlMRLT = Crawl.get_lookup_table(&"entities")
	if elt != null:
		var view : Node3D = elt.load_meta_resource(&"unique", &"editor", true)
		if view != null:
			view.cell_size = CELL_SIZE
			view.entity = _editor_entity
			_dungeon_viewport.add_child(view)
	
	_active_cell_state.map = _map
	_active_cell_state.lookup_table_name = &"level_geometry"
	_active_cell_state.surface_resource_pressed.connect(_on_active_cell_state_surface_resource_pressed)
	
	_rsw_level.lookup_table_name = &"level_geometry"
	
	_on_map_cell_count_changed(Vector3i.ZERO)
	_on_editor_entity_position_changed(Vector3i.ZERO, _editor_entity.position)

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
# Handler Methods
# ------------------------------------------------------------------------------
func _on_map_cell_count_changed(_pos : Vector3i) -> void:
	var bounds : AABB = _map.get_aabb()
	if bounds.size.x < 0 or bounds.size.y < 0: return
	_z_elevation_bar.min_z_level = bounds.position.y
	_z_elevation_bar.max_z_level = bounds.end.y - 1

func _on_editor_entity_position_changed(_from : Vector3i, to : Vector3i) -> void:
	_z_elevation_bar.z_level = to.y
	_active_cell_state.map_position = to

func _on_dig_state_direction_changed(direction : int):
	_dig_direction = direction

func _on_active_cell_state_surface_resource_pressed(surface : Crawl.SURFACE, current_resource : StringName) -> void:
	if _rsw_level.visible: return
	if not _rsw_level.item_selected.is_connected(_on_level_item_selected.bind(surface)):
		_rsw_level.item_selected.connect(_on_level_item_selected.bind(surface))
	if not _rsw_level.canceled.is_connected(_on_level_item_selection_canceled.bind(surface)):
		_rsw_level.canceled.connect(_on_level_item_selection_canceled.bind(surface))
	match surface:
		Crawl.SURFACE.Ground:
			_rsw_level.section_name = &"ground"
		Crawl.SURFACE.Ceiling:
			_rsw_level.section_name = &"ceiling"
		_:
			_rsw_level.section_name = &"wall"
	_rsw_level.popup_centered()

func _on_level_item_selected(section_name : StringName, resource_name : StringName, surface : Crawl.SURFACE) -> void:
	if _map == null: return
	var mrid : int = _map.get_resource_id(resource_name)
	if mrid < 0 and resource_name != &"":
		mrid = _map.add_resource(resource_name)
	_map.set_cell_surface_resource(_editor_entity.position, surface, mrid,true)
	_on_level_item_selection_canceled.call_deferred(surface)

func _on_level_item_selection_canceled(surface : Crawl.SURFACE) -> void:
	if _rsw_level.item_selected.is_connected(_on_level_item_selected.bind(surface)):
		_rsw_level.item_selected.disconnect(_on_level_item_selected.bind(surface))
	if _rsw_level.canceled.is_connected(_on_level_item_selection_canceled.bind(surface)):
		_rsw_level.canceled.disconnect(_on_level_item_selection_canceled.bind(surface))
