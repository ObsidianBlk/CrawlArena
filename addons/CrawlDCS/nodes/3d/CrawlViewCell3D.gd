extends Node3D
class_name CrawlViewCell3D

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const DEG90 : float = deg_to_rad(90)

# ------------------------------------------------------------------------------
# Export Variables
# ------------------------------------------------------------------------------
@export var map : CrawlMap = null :						set = set_map
@export var map_position : Vector3i = Vector3i.ZERO:	set = set_map_position
@export var cell_size : float = 5.0:					set = set_cell_size
@export var lookup_table_name : StringName = &"":		set = set_lookup_table_name

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _requested_rebuild : bool = false
var _is_ready : bool = false

var _node : Dictionary = {
	&"ground":{&"node":null, &"resource":&""},
	&"ceiling":{&"node":null, &"resource":&""},
	&"wall_north":{&"node":null, &"resource":&""},
	&"wall_south":{&"node":null, &"resource":&""},
	&"wall_east":{&"node":null, &"resource":&""},
	&"wall_west":{&"node":null, &"resource":&""},
}

# ------------------------------------------------------------------------------
# Setters
# ------------------------------------------------------------------------------
func set_map(nmap : CrawlMap) -> void:
	if nmap != map:
		if map != null:
			if map.cell_added.is_connected(_on_map_cell_changed):
				map.cell_added.disconnect(_on_map_cell_changed)
			if map.cell_changed.is_connected(_on_map_cell_changed):
				map.cell_changed.disconnect(_on_map_cell_changed)
			if map.cell_removed.is_connected(_on_map_cell_changed):
				map.cell_removed.disconnect(_on_map_cell_changed)
		
		map = nmap
		
		if map != null:
			if not map.cell_added.is_connected(_on_map_cell_changed):
				map.cell_added.connect(_on_map_cell_changed)
			if not map.cell_changed.is_connected(_on_map_cell_changed):
				map.cell_changed.connect(_on_map_cell_changed)
			if not map.cell_removed.is_connected(_on_map_cell_changed):
				map.cell_removed.connect(_on_map_cell_changed)
		_requested_rebuild = true


func set_map_position(mpos : Vector3i) -> void:
	if mpos != map_position:
		map_position = mpos
		_requested_rebuild = true

func set_cell_size(s : float) -> void:
	if s > 0.0 and s != cell_size:
		cell_size = s
		_requested_rebuild = true

func set_lookup_table_name(ltn : StringName) -> void:
	if ltn != lookup_table_name:
		lookup_table_name = ltn
		_requested_rebuild = true

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	_is_ready = true

func _process(_delta : float) -> void:
	if _is_ready and _requested_rebuild:
		_requested_rebuild = false
		_BuildCell()

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _UpdateSurfaceNode(node_name : StringName, section : StringName, resource_name : StringName, offset : Vector3, rot_rad : float = 0.0) -> void:
	if not node_name in _node: return
	if _node[node_name][&"resource"] == resource_name:
		if _node[node_name][&"node"] != null:
			_node[node_name][&"node"].visible = true
		return
	
	var mrlt : CrawlMRLT = Crawl.get_lookup_table(lookup_table_name)
	if mrlt == null: return
	
	_node[node_name][&"resource"] = resource_name
	
	if _node[node_name][&"node"] != null:
		remove_child(_node[node_name][&"node"])
		_node[node_name][&"node"].queue_free()
		_node[node_name][&"node"] = null
	if resource_name == &"": return
	var node : Node3D = mrlt.load_meta_resource(section, resource_name, true)
	if node == null:
		print("Resource Not Found: ", section, ", ", resource_name)
		return
	_node[node_name][&"node"] = node
	add_child(node)
	node.position = offset
	if rot_rad != 0.0:
		node.rotate_y(rot_rad)

func _ClearCell() -> void:
	for n in _node:
		if _node[n][&"node"] != null:
			_node[n][&"node"].visible = false

func _BuildCell() -> void:
	if map == null or not map.has_cell(map_position):
		_ClearCell()
		return

	_UpdateSurfaceNode(
		&"ground", &"ground",
		map.get_cell_surface_resource(map_position, Crawl.SURFACE.Ground),
		Vector3.ZERO
	)
	
	_UpdateSurfaceNode(
		&"ceiling", &"ceiling",
		map.get_cell_surface_resource(map_position, Crawl.SURFACE.Ceiling),
		Vector3(0, cell_size, 0)
	)
	
	_UpdateSurfaceNode(
		&"wall_north", &"wall",
		map.get_cell_surface_resource(map_position, Crawl.SURFACE.North),
		Vector3(0, 0, cell_size * 0.5)
	)
	
	_UpdateSurfaceNode(
		&"wall_south", &"wall",
		map.get_cell_surface_resource(map_position, Crawl.SURFACE.South),
		Vector3(0, 0, -cell_size * 0.5), DEG90 * 2
	)
	
	_UpdateSurfaceNode(
		&"wall_west", &"wall",
		map.get_cell_surface_resource(map_position, Crawl.SURFACE.West),
		Vector3(cell_size * 0.5, 0, 0), DEG90
	)
	
	_UpdateSurfaceNode(
		&"wall_east", &"wall",
		map.get_cell_surface_resource(map_position, Crawl.SURFACE.East),
		Vector3(-cell_size * 0.5, 0, 0), -DEG90
	)


# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_map_cell_changed(position : Vector3i) -> void:
	if position == map_position:
		_requested_rebuild = true

