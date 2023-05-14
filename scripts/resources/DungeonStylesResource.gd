extends Resource
class_name DungeonStylesResource


# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const MAX_CELL_DEPTH : int = 256
const TRACKER_ENTITY_TYPE : StringName = &"STYLE_TRACKER"
const INVALID_TRACKING_POSITION : Vector3i = Vector3i(0,1,0)

const STYLE_DICT_SCHEMA : Dictionary = {
	"!KEY_OF_TYPE_str":{
		&"type":TYPE_STRING,
		&"def":{
			&"type": TYPE_VECTOR3I
		}
	}
}

# ------------------------------------------------------------------------------
# "Export" Variables
# ------------------------------------------------------------------------------
var _map : CrawlMap = null
var _styles : Dictionary = {}

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _available_cells : Array = []

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _get(property : StringName) -> Variant:
	match property:
		&"map":
			return _map
		&"styles":
			return _styles
	return null

func _set(property : StringName, value : Variant) -> bool:
	var success : bool = false
	
	match property:
		&"map":
			if _map == null and is_instance_of(value, CrawlMap):
				_map = value
				if not _map.cell_removed.is_connected(_on_cell_removed):
					_map.cell_removed.connect(_on_cell_removed)
				success = true
		&"styles":
			if _styles.is_empty() and typeof(value) == TYPE_DICTIONARY:
				if DSV.verify(value, STYLE_DICT_SCHEMA) == OK:
					_styles = value
					success = true
	
	return success

func _get_property_list() -> Array:
	return [
		{
			name = "map",
			type = TYPE_OBJECT,
			hint = PROPERTY_HINT_RESOURCE_TYPE,
			usage = PROPERTY_USAGE_STORAGE
		},
		{
			name = "styles",
			type = TYPE_DICTIONARY,
			usage = PROPERTY_USAGE_STORAGE
		}
	]

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _GetNameFromPosition(position : Vector3i) -> String:
	var style_name = _styles.find_key(position)
	if typeof(style_name) == TYPE_STRING:
		return style_name
	return ""

func _BuildAvailableCells() -> void:
	if _map == null: return
	if _available_cells.size() == MAX_CELL_DEPTH: return
	
	for z in range(MAX_CELL_DEPTH):
		for x in range(MAX_CELL_DEPTH):
			var position : Vector3i = Vector3i(x, 0, z)
			if not _map.has_cell(position):
				_available_cells.append(position)
				if _available_cells.size() == MAX_CELL_DEPTH: return

func _GetTrackingEntity() -> CrawlEntity:
	if _map == null: return null
	var entities = _map.get_entities({"type":TRACKER_ENTITY_TYPE})
	if entities.size() > 0:
		return entities[0]
	return null

func _GetTrackingPosition() -> Vector3i:
	if _map == null: return INVALID_TRACKING_POSITION
	var te : CrawlEntity = _GetTrackingEntity()
	if te == null: return INVALID_TRACKING_POSITION
	if not _map.has_cell(te.position): return INVALID_TRACKING_POSITION
	return te.position
	

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func count() -> void:
	return _styles.size()

func get_styles() -> Array:
	return _styles.keys()

func has_style(style_name : String) -> bool:
	return style_name in _styles

func add_style(style_name : String) -> int:
	if style_name in _styles: return ERR_ALREADY_EXISTS
	if _available_cells.size() <= 0:
		_BuildAvailableCells()
		if _available_cells.size() <= 0: return ERR_CANT_CREATE
	
	var te : CrawlEntity = _GetTrackingEntity()
	if te == null:
		if not _map.has_cell(Vector3i.ZERO):
			_map.add_cell(Vector3i.ZERO)
		te = get_tracking_entity() # This sneakily makes one if none exists.
	else:
		if te.position == _available_cells[0]:
			if _available_cells[0] == Vector3i.ZERO:
				return ERR_CANT_RESOLVE
			te.position = Vector3i.ZERO
		
		if not _map.has_cell(te.position):
			return ERR_DOES_NOT_EXIST
		
		var pos : Vector3i = _available_cells.pop_front()
		_map.copy_cell(te.position, pos)
		te.position = pos
	
	_styles[style_name] = te.position
	emit_changed()
	return OK

func remove_style(style_name : String) -> void:
	if not style_name in _styles: return
	var position : Vector3i = _styles[style_name]
	_styles.erase(style_name)
	if _map != null and _map.has_cell(position):
		_map.remove_cell(position)
	emit_changed()

func get_tracking_entity() -> CrawlEntity:
	if _map == null: return null
	
	var entity : CrawlEntity = _GetTrackingEntity()
	if entity == null:
		entity = CrawlEntity.new()
		entity.uuid = UUID.v7()
		entity.type = TRACKER_ENTITY_TYPE
		entity.position = Vector3i.ZERO
		_map.add_entity(entity)
		emit_changed()
	return entity

func get_surface_resource(surface : Crawl.SURFACE) -> StringName:
	var position : Vector3i = _GetTrackingPosition()
	if position == INVALID_TRACKING_POSITION:
		return &""
	return _map.get_cell_surface_resource(position, surface)

func set_surface_resource(surface : Crawl.SURFACE, resource_name : StringName) -> void:
	var position : Vector3i = _GetTrackingPosition()
	if position == INVALID_TRACKING_POSITION:
		return
	_map.set_cell_surface_resource(position, surface, resource_name, false)

func get_surface_is_blocking(surface : Crawl.SURFACE) -> bool:
	var position : Vector3i = _GetTrackingPosition()
	if position == INVALID_TRACKING_POSITION:
		return true
	return _map.is_cell_surface_blocking(position, surface)

func set_surface_blocking(surface : Crawl.SURFACE, blocking : bool) -> void:
	var position : Vector3i = _GetTrackingPosition()
	if position == INVALID_TRACKING_POSITION:
		return
	_map.set_cell_surface_blocking(position, surface, blocking, false)

func copy_style_to_map(map : CrawlMap, dstPosition : Vector3i, options : Dictionary = {}, bi_directional : bool = false) -> void:
	if map == null: return
	if not map.has_cell(dstPosition): return
	var position : Vector3i = _GetTrackingPosition()
	if position == INVALID_TRACKING_POSITION:
		return
	map.set_cell_surface_from_map(_map, position, dstPosition, options, bi_directional)

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_cell_removed(position : Vector3i) -> void:
	var style_name = _GetNameFromPosition(position)
	if style_name == "": return
	remove_style(style_name)

