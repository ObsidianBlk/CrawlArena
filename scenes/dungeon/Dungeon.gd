extends Node3D
class_name Dungeon


# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal focus_changed(focus_position)

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const CELL_SIZE : float = 4.4

# ------------------------------------------------------------------------------
# Export Variables
# ------------------------------------------------------------------------------
@export_category("Dungeon")
@export var map : CrawlMap = null:						set = set_map
@export_range(1, 10) var focus_pid : int = 1:			set = set_focus_pid

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _active_player : Player = null

# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
@onready var _crawl_view : CrawlView3D = %CrawlView3D
@onready var _entity_container : Node3D = %EntityContainer


# ------------------------------------------------------------------------------
# Setters
# ------------------------------------------------------------------------------
func set_map(m : CrawlMap) -> void:
	if m == map: return
	_ClearMapConnections()
	map = m
	_UpdateMapConnections()
		

func set_focus_pid(pid : int) -> void:
	if not (pid >= 1 and pid <= 10) or pid == focus_pid: return
	_ClearPlayerConnections()
	focus_pid = pid
	_UpdateActivePlayer()

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _enter_tree() -> void:
	if map != null and _active_player == null:
		_UpdateActivePlayer()

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


func _ClearPlayerConnections() -> void:
	if _active_player != null:
		if _active_player.entity.position_changed.is_connected(_on_player_position_changed):
			_active_player.entity.position_changed.disconnect(_on_player_position_changed)
		_active_player.current = false
	_active_player = null

func _UpdateActivePlayer() -> void:
	if map == null or not is_inside_tree(): return
	var enodes : Array = get_tree().get_nodes_in_group("Player_%s"%[focus_pid])
	for node in enodes:
		if not node.is_ancestor_of(_entity_container): continue
		if not is_instance_of(node, Player): continue
		if node.entity == null:
			printerr("WARNING: CrawlEntityNode3D instance without assigned CrawlEntity resource found.")
			continue
		
		node.current = true
		_active_player = node
		if not _active_player.entity.position_changed.is_connected(_on_player_position_changed):
			_active_player.entity.position_changed.connect(_on_player_position_changed)
		_on_player_position_changed(Vector3i.ZERO, _active_player.entity.position)

func _ClearMapConnections() -> void:
	if _crawl_view == null: return
	_ClearPlayerConnections()
	
	if map != null:
		if map.entity_added.is_connected(_on_map_entity_added):
			map.entity_added.disconnect(_on_map_entity_added)
	
	_crawl_view.map = null
	for child in _entity_container.get_children():
		_entity_container.remove_child(child)
		child.queue_free()

func _UpdateMapConnections() -> void:
	if map == null or _crawl_view == null: return
	
	_crawl_view.map = map
	var entities : Array = map.get_entities()
	for entity in entities:
		if entity.type == &"editor": continue
		_ConnectDungeonEntity(entity)
	
	if not map.entity_added.is_connected(_on_map_entity_added):
		map.entity_added.connect(_on_map_entity_added)
	
	_UpdateActivePlayer()


func _ConnectDungeonEntity(entity : CrawlEntity) -> void:
	var elt : CrawlMRLT = Crawl.get_lookup_table(&"entities")
	if elt == null: return
	
	var tparts : PackedStringArray = _EntityTypeParts(entity.type)
	if tparts.size() != 2: return
	var entity_node = elt.load_meta_resource(tparts[0], tparts[1], true)
	if is_instance_of(entity_node, CrawlEntityNode3D):
		if is_instance_of(entity_node, Player):
			entity_node.passive_mode = true
			entity_node.current = false
		if not focus_changed.is_connected(entity_node.set_focus_position):
			focus_changed.connect(entity_node.set_focus_position)
		entity_node.cell_size = CELL_SIZE
		entity_node.entity = entity
		_entity_container.add_child(entity_node)

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_player_position_changed(from : Vector3i, to : Vector3i) -> void:
	if _crawl_view == null: return
	_crawl_view.focus_position = to
	focus_changed.emit(to)

func _on_map_entity_added(entity : CrawlEntity) -> void:
	_ConnectDungeonEntity(entity)
