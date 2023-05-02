@tool
extends Control


# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal surface_resource_pressed(surface, current_resource_name)
signal surface_blocking_toggled(surface)
signal stair_state_toggled()

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const ICON_STAIR_ADD : Texture = preload("res://assets/dungeon_editor/icons/add_stairs.svg")
const ICON_STAIR_REMOVE : Texture = preload("res://assets/dungeon_editor/icons/remove_stairs.svg")
const ICON_WALL_BLOCKING : Texture = preload("res://assets/dungeon_editor/icons/wall_blocking.svg")
const ICON_WALL_UNBLOCKED : Texture = preload("res://assets/dungeon_editor/icons/wall_unblocked.svg")

# ------------------------------------------------------------------------------
# Export Variables
# ------------------------------------------------------------------------------
@export_category("Map Cell Control")
@export_group("Visuals")
@export var preview_size : int = 32:							set = set_preview_size
@export_group("Resource")
@export var map : CrawlMap = null:								set = set_map
@export var map_position : Vector3i = Vector3i.ZERO:			set = set_map_position
@export var lookup_table_name : StringName = &"":				set = set_lookup_table_name

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
@onready var _rvc_north : Control = %RVC_North
@onready var _rvc_west : Control = %RVC_West
@onready var _rvc_east : Control = %RVC_East
@onready var _rvc_south : Control = %RVC_South
@onready var _rvc_ceiling : Control = %RVC_Ceiling
@onready var _rvc_ground : Control = %RVC_Ground

@onready var _btn_stair_toggle : Button = %StairToggle

@onready var _btn_north_blocking : Button = %NorthBlocking
@onready var _btn_west_blocking : Button = %WestBlocking
@onready var _btn_east_blocking : Button = %EastBlocking
@onready var _btn_south_blocking : Button = %SouthBlocking
@onready var _btn_ceiling_blocking : Button = %CeilingBlocking
@onready var _btn_ground_blocking : Button = %GroundBlocking


# ------------------------------------------------------------------------------
# Setters
# ------------------------------------------------------------------------------
func set_preview_size(s : int) -> void:
	if s > 0 and s != preview_size:
		preview_size = s
		_UpdatePreviewSize()

func set_map(m : CrawlMap) -> void:
	if m != map:
		if not Engine.is_editor_hint() and map != null:
			for signal_name in [&"cell_changed", &"cell_added", &"cell_removed"]:
				if map.is_connected(signal_name, _on_map_cell_changed):
					map.disconnect(signal_name, _on_map_cell_changed)
		map = m
		if not Engine.is_editor_hint() and map != null:
			for signal_name in [&"cell_changed", &"cell_added", &"cell_removed"]:
				if not map.is_connected(signal_name, _on_map_cell_changed):
					map.connect(signal_name, _on_map_cell_changed)
		_UpdateCellState()

func set_map_position(p : Vector3i) -> void:
	if p != map_position:
		map_position = p
		_UpdateCellState()

func set_lookup_table_name(ltn : StringName) -> void:
	if ltn != lookup_table_name:
		lookup_table_name = ltn
		_UpdateLookupTable()

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	_rvc_north.pressed.connect(_on_rvc_surface_pressed.bind(Crawl.SURFACE.North))
	_rvc_south.pressed.connect(_on_rvc_surface_pressed.bind(Crawl.SURFACE.South))
	_rvc_east.pressed.connect(_on_rvc_surface_pressed.bind(Crawl.SURFACE.East))
	_rvc_west.pressed.connect(_on_rvc_surface_pressed.bind(Crawl.SURFACE.West))
	_rvc_ceiling.pressed.connect(_on_rvc_surface_pressed.bind(Crawl.SURFACE.Ceiling))
	_rvc_ground.pressed.connect(_on_rvc_surface_pressed.bind(Crawl.SURFACE.Ground))
	
	_btn_north_blocking.pressed.connect(_on_btn_surface_blocking_pressed.bind(Crawl.SURFACE.North))
	_btn_south_blocking.pressed.connect(_on_btn_surface_blocking_pressed.bind(Crawl.SURFACE.South))
	_btn_east_blocking.pressed.connect(_on_btn_surface_blocking_pressed.bind(Crawl.SURFACE.East))
	_btn_west_blocking.pressed.connect(_on_btn_surface_blocking_pressed.bind(Crawl.SURFACE.West))
	_btn_ceiling_blocking.pressed.connect(_on_btn_surface_blocking_pressed.bind(Crawl.SURFACE.Ceiling))
	_btn_ground_blocking.pressed.connect(_on_btn_surface_blocking_pressed.bind(Crawl.SURFACE.Ground))
	
	_btn_stair_toggle.pressed.connect(_on_btn_stairs_toggled)
	
	_UpdateLookupTable()
	_UpdatePreviewSize()
	_UpdateCellState()

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _IsValidMapInfo() -> bool:
	if map != null:
		return map.has_cell(map_position)
	return false

func _UpdatePreviewSize() -> void:
	for ctrl in [_rvc_north, _rvc_south, _rvc_east, _rvc_west, _rvc_ceiling, _rvc_ground]:
		if ctrl == null: continue
		ctrl.view_size = preview_size

func _UpdateLookupTable() -> void:
	if Engine.is_editor_hint(): return
	for ctrl in [_rvc_north, _rvc_south, _rvc_east, _rvc_west, _rvc_ceiling, _rvc_ground]:
		if ctrl == null: continue
		ctrl.lookup_table_name = lookup_table_name

func _UpdateCellSurfaceState(ctrl : Control, btn : Button, surface : Crawl.SURFACE) -> void:
	var map_valid : bool = (map != null and map.has_cell(map_position))
	if ctrl != null:
		if map_valid:
			ctrl.resource_name = map.get_cell_surface_resource(map_position, surface)
		else:
			ctrl.resource_name = &""
	if btn != null:
		btn.icon = ICON_WALL_BLOCKING
		if not map_valid: return
		if not map.is_cell_surface_blocking(map_position, surface):
			btn.icon = ICON_WALL_UNBLOCKED

func _UpdateCellState() -> void:
	if Engine.is_editor_hint(): return
	
	_UpdateCellSurfaceState(_rvc_north, _btn_north_blocking, Crawl.SURFACE.North)
	_UpdateCellSurfaceState(_rvc_south, _btn_south_blocking, Crawl.SURFACE.South)
	_UpdateCellSurfaceState(_rvc_east, _btn_east_blocking, Crawl.SURFACE.East)
	_UpdateCellSurfaceState(_rvc_west, _btn_west_blocking, Crawl.SURFACE.West)
	_UpdateCellSurfaceState(_rvc_ceiling, _btn_ceiling_blocking, Crawl.SURFACE.Ceiling)
	_UpdateCellSurfaceState(_rvc_ground, _btn_ground_blocking, Crawl.SURFACE.Ground)
	
	var map_valid : bool = (map != null and map.has_cell(map_position))
	if _btn_stair_toggle != null:
		_btn_stair_toggle.icon = ICON_STAIR_ADD
		if not map_valid: return
		if map.is_cell_stairs(map_position):
			_btn_stair_toggle.icon = ICON_STAIR_REMOVE

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_map_cell_changed(cell_position : Vector3i) -> void:
	if cell_position != map_position: return
	_UpdateCellState()

func _on_rvc_surface_pressed(surface : Crawl.SURFACE) -> void:
	if map == null or not map.has_cell(map_position): return
	var resource_name : StringName = map.get_cell_surface_resource(map_position, surface)
	surface_resource_pressed.emit(surface, resource_name)

func _on_btn_surface_blocking_pressed(surface : Crawl.SURFACE) -> void:
	if map == null: return
	surface_blocking_toggled.emit(surface)

func _on_btn_stairs_toggled() -> void:
	stair_state_toggled.emit()

