extends Node3D
class_name CrawlView3D

# ------------------------------------------------------------------------------
# Constants and ENUMs
# ------------------------------------------------------------------------------
# TODO: Can I do with without the need for the tscn?
const CRAWLVIEWCELL3D : PackedScene = preload("res://addons/CrawlDCS/nodes/3d/CrawlViewCell3D.tscn")

# ------------------------------------------------------------------------------
# Export Variables
# ------------------------------------------------------------------------------
@export var map : CrawlMap = null :				set = set_map
@export var unit_radius : int = 4 :				set = set_unit_radius
@export var cell_size : float = 5.0:			set = set_cell_size
@export var lookup_table_name : StringName:		set = set_lookup_table_name

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _cells : Dictionary = {}
var _map_changed : bool = false
var _cell_update_requested : bool = false

var _focus_position : Vector3i = Vector3i.ZERO

# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
@onready var cell_container : Node3D = null

# ------------------------------------------------------------------------------
# Setters
# ------------------------------------------------------------------------------
func set_map(cmap : CrawlMap) -> void:
	if cmap != map:
		if map != null:
#			if map.focus_position_changed.is_connected(_on_focus_position_changed):
#				map.focus_position_changed.disconnect(_on_focus_position_changed)
			_ClearAllCells()
		map = cmap
		if map != null:
			pass
#			if not map.focus_position_changed.is_connected(_on_focus_position_changed):
#				map.focus_position_changed.connect(_on_focus_position_changed)
#			_focus_position = map.get_focus_position()
		_map_changed = true
		_cell_update_requested = true


func set_unit_radius(ur : int) -> void:
	if ur > 0 and ur != unit_radius:
		unit_radius = ur
		_cell_update_requested = true

func set_cell_size(s : float) -> void:
	if s > 0.0 and s != cell_size:
		cell_size = s
		_cell_update_requested = true

func set_lookup_table_name(ltn : StringName) -> void:
	if ltn != lookup_table_name:
		lookup_table_name = ltn
		_cell_update_requested = true

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	cell_container = Node3D.new()
	add_child(cell_container)

func _process(_delta : float) -> void:
	if cell_container != null and _cell_update_requested:
		_cell_update_requested = false
		_UpdateCells(_focus_position)

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _ClearAllCells() -> void:
	if cell_container == null: return
	for child in cell_container.get_children():
		cell_container.remove_child(child)
		child.queue_free()


func _UpdateCells(origin : Vector3i) -> void:
	if cell_container == null: return
	
	var rad : Vector3 = Vector3(unit_radius, unit_radius, unit_radius)
	var bounds : AABB = AABB(Vector3(origin) - rad, rad*2)
	var stored_pos : Array = []
	var available_cells : Array = []
	
	for child in cell_container.get_children():
		if not is_instance_of(child, CrawlViewCell3D): continue
		if not bounds.has_point(Vector3(child.map_position)):
			available_cells.append(child)
			continue
		if _map_changed:
			child.map = map
		child.cell_size = cell_size
		child.lookup_table_name = lookup_table_name
		stored_pos.append(child.map_position)
	_map_changed = false
	
	for x in range(origin.x - unit_radius, (origin.x + unit_radius) + 1):
		for y in range(origin.y - unit_radius, (origin.y + unit_radius) + 1):
			for z in range(origin.z - unit_radius, (origin.z + unit_radius) + 1):
				var pos : Vector3i = Vector3i(x,y,z)
				if not stored_pos.has(pos):
					if available_cells.size() > 0:
						var cell : CrawlViewCell3D = available_cells.pop_back()
						cell.map_position = pos
						cell.position = pos * cell_size
						cell.cell_size = cell_size
						cell.lookup_table_name = lookup_table_name
					else:
						var cell : CrawlViewCell3D = CRAWLVIEWCELL3D.instantiate()
						cell.cell_size = cell_size
						cell.lookup_table_name = lookup_table_name
						cell.map = map
						cell.map_position = pos
						cell_container.add_child(cell)
						#print("Position : ", pos * CELL_SIZE)
						cell.position = pos * cell_size


# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
#func _on_focus_position_changed(focus_position : Vector3i) -> void:
#	_focus_position = focus_position
#	_cell_update_requested = true
