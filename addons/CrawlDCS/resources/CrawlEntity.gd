extends Resource
class_name CrawlEntity

# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal name_changed(new_name)
signal position_changed(from, to)
signal facing_changed(from, to)

signal assigned_to_map()
signal removed_from_map()

signal meta_value_changed(key)
signal meta_value_removed(key)

signal interaction(info)
signal attacked(info)

signal schedule_started(data)
signal schedule_ended(data)


# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const MAX_TRANSLATION_QUEUE_SIZE : int = 4

# ------------------------------------------------------------------------------
# Export Variables
# ------------------------------------------------------------------------------
@export var uuid : StringName = &"":									set = set_uuid
@export var entity_name : String = "":									set = set_entity_name
@export var type : StringName = &"":									set = set_type
@export var position : Vector3i = Vector3i.ZERO:						set = set_position
@export var facing : Crawl.SURFACE = Crawl.SURFACE.North:	set = set_facing
@export var blocking : int = 0x3F
@export var meta : Dictionary = {}


# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _mapref : WeakRef = weakref(null)
var _translation_locked : bool = false
var _queue : Array = []

# ------------------------------------------------------------------------------
# Setters
# ------------------------------------------------------------------------------
func set_uuid(id : StringName) -> void:
	if uuid == &"" and id != &"":
		uuid = id
		emit_changed()

func set_type(t : StringName) -> void:
	if type == &"" and t != &"":
		var parts : PackedStringArray = t.split(":")
		var count : int = parts.size()
		if not (count >= 1 and count <= 2): return
		if count == 2 and parts[1].is_empty(): return
		type = t
		emit_changed()

func set_entity_name(n : String) -> void:
	if n != entity_name:
		entity_name = n
		name_changed.emit(entity_name)
		emit_changed()

func set_position(pos : Vector3i) -> void:
	if pos != position:
		var from : Vector3i = position
		position = pos
		position_changed.emit(from, position)
		emit_changed()

func set_facing(f : Crawl.SURFACE) -> void:
	if f != facing:
		var old : Crawl.SURFACE = facing
		facing = f
		facing_changed.emit(old, facing)
		emit_changed()

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _SetMap(map : CrawlMap) -> void:
	if _mapref.get_ref() == map: return
	_mapref = weakref(map)
	if _mapref.get_ref() == null:
		removed_from_map.emit()
	else:
		assigned_to_map.emit()

func _AddToQueue(f : Callable) -> void:
	if _queue.size() < MAX_TRANSLATION_QUEUE_SIZE:
		_queue.append(f)

func _DirectionNameToFacing(dir : StringName) -> Crawl.SURFACE:
	var d_facing : Crawl.SURFACE = Crawl.SURFACE.Ground
	match dir:
		&"foreward", &"forward":
			d_facing = facing
		&"backward":
			d_facing = Crawl.surface_get_adjacent(facing)
		&"left":
			d_facing = Crawl.surface_90deg(facing, 1)
		&"right":
			d_facing = Crawl.surface_90deg(facing, -1)
		&"up":
			d_facing = Crawl.SURFACE.Ceiling
		&"down":
			d_facing = Crawl.SURFACE.Ground
	return d_facing

func _EntitiesBlockingAt(pos : Vector3i, surface : Crawl.SURFACE) -> bool:
	if _mapref.get_ref() == null: return false
	var map : CrawlMap = _mapref.get_ref()
	var entities : Array = map.get_entities({&"position": pos})
	if entities.size() > 0:
		for entity in entities:
			if entity == self: continue # We can't block ourselves!
			if entity.is_blocking(surface):
				return true
	return false

func _CanMove(dir : Crawl.SURFACE, ignore_entities : bool = false) -> bool:
	var neighbor_position : Vector3i = position + Crawl.surface_to_direction_vector(dir)
	if _mapref.get_ref() == null: return false
	var map : CrawlMap = _mapref.get_ref()
	if map.is_cell_surface_blocking(position, dir): return false
	if not ignore_entities:
		if _EntitiesBlockingAt(position, dir): return false
		var adj_dir : Crawl.SURFACE = Crawl.surface_get_adjacent(dir)
		if _EntitiesBlockingAt(neighbor_position, adj_dir): return false
	return true

func _Move(dir : Crawl.SURFACE, ignore_map : bool) -> int:
	var neighbor_position : Vector3i = position + Crawl.surface_to_direction_vector(dir)
	var pold : Vector3i = position
	
	if _mapref.get_ref() == null or ignore_map:
		position = neighbor_position
		return OK
	
	var move_allowed : bool = _CanMove(dir)
	var stairs_ahead : StringName = _StairsAhead(dir)
	if not move_allowed:
		if stairs_ahead == &"up":
			position = neighbor_position + Crawl.surface_to_direction_vector(Crawl.SURFACE.Ceiling)
			return OK
		return ERR_UNAVAILABLE
	
	if stairs_ahead == &"down":
		position = neighbor_position + Crawl.surface_to_direction_vector(Crawl.SURFACE.Ground)
	else:
		position = neighbor_position
	return OK

func _StairsAhead(surface : Crawl.SURFACE) -> StringName:
	if _mapref.get_ref() == null: return &""
	var map : CrawlMap = _mapref.get_ref()
	
	var neighbor_position : Vector3i = position + Crawl.surface_to_direction_vector(surface)
	
	if _CanMove(surface):
		# If the neighbor's ground is blocking, there are no stairs.
		if map.is_cell_surface_blocking(neighbor_position, Crawl.SURFACE.Ground): return &""
		
		# Get the diagnal down position.
		var diag_down_position = neighbor_position + Crawl.surface_to_direction_vector(Crawl.SURFACE.Ground)
		# Is there a cell
		if not map.has_cell(diag_down_position): return &""
		# Does that cell have stairs
		if not map.is_cell_stairs(diag_down_position): return &""
		return &"down"

	# If there a traversable space above...
	if not _CanMove(Crawl.SURFACE.Ceiling): return &""
	
	# Get cell position diagnally up from current position.
	var diag_up_position = neighbor_position + Crawl.surface_to_direction_vector(Crawl.SURFACE.Ceiling)
	# If there a cell at the diagnal-up position
	if not map.has_cell(diag_up_position): return &"" # If not, can't move
	# We also can't move if we're not already ON stairs for upward transitions.
	if not map.is_cell_stairs(position): return &""
	return &"up"

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func clone() -> CrawlEntity:
	var ent = CrawlEntity.new()
	ent.uuid = UUID.v7()
	ent.type = type
	ent.position = position
	ent.facing = facing
	ent.blocking = blocking
	return ent

func get_map() -> CrawlMap:
	return _mapref.get_ref()

func lock_translation(lock : bool) -> void:
	_translation_locked = lock

func is_translation_locked() -> bool:
	return _translation_locked

func translation_queue_size() -> int:
	return _queue.size()

func process_translation_queue() -> int:
	if _translation_locked: return -1
	if _queue.size() > 0:
		var next : Callable = _queue.pop_front()
		next.call()
	return _queue.size()

func flush_translation_queue() -> void:
	_queue.clear()

func set_meta_value(key : String, value : Variant) -> void:
	if key.is_empty(): return
	meta[key] = value
	meta_value_changed.emit(key)
	emit_changed()

func get_meta_value(key : String, default : Variant = null) -> Variant:
	if key in meta:
		return meta[key]
	return default

func has_meta_key(key : String) -> bool:
	return key in meta

func get_meta_keys() -> PackedStringArray:
	return PackedStringArray(meta.keys())

func erase_meta_key(key : String) -> void:
	if not key in meta: return
	meta.erase(key)
	meta_value_removed.emit(key)
	emit_changed()

func set_blocking(surface : Crawl.SURFACE, enable : bool) -> void:
	var i : int = Crawl.SURFACE.values().find(surface)
	if enable:
		blocking = blocking | (1 << i)
	else:
		blocking = blocking & (~(1 << i))
	emit_changed()

func set_block_all(enable : bool) -> void:
	blocking = Crawl.ALL_SURFACES if enable else 0
	emit_changed()

func is_blocking(surface : Crawl.SURFACE) -> bool:
	var i : int = Crawl.SURFACE.values().find(surface)
	return (blocking & (1 << i)) != 0

func stairs_ahead(dir : StringName) -> StringName:
	var direction_surface : Crawl.SURFACE = _DirectionNameToFacing(dir)
	return _StairsAhead(direction_surface)

func on_stairs() -> bool:
	if _mapref.get_ref() == null: return false
	return _mapref.get_ref().is_cell_stairs(position)

func get_basetype() -> String:
	if type == &"": return ""
	return type.split(":")[0]

func is_basetype(base_type : StringName) -> bool:
	if type.begins_with(&"%s:"%[base_type]): return true
	if type == base_type: return true
	return false

func get_subtype() -> String:
	if type == &"": return ""
	var parts : PackedStringArray = type.split(":")
	if parts.size() != 2:
		return ""
	return parts[1]

func is_subtype(sub_type : StringName) -> bool:
	return type.ends_with(":%s"%[sub_type])

func can_move(dir : StringName, ignore_entities : bool = false) -> bool:
	if _translation_locked: return false
	var d_facing : Crawl.SURFACE = _DirectionNameToFacing(dir)
	return _CanMove(d_facing, ignore_entities)

func move(dir : StringName, ignore_map : bool = false) -> int:
	if _translation_locked:
		_AddToQueue(move.bind(dir, ignore_map))
		return OK
	
	var d_facing : Crawl.SURFACE = _DirectionNameToFacing(dir)
	return _Move(d_facing, ignore_map)

func turn_left() -> int:
	if _translation_locked:
		_AddToQueue(turn_left)
		return OK
	
	var ofacing : Crawl.SURFACE = facing
	facing = Crawl.surface_90deg(facing, 1)
	return OK

func turn_right() -> int:
	if _translation_locked:
		_AddToQueue(turn_right)
		return OK
	
	var ofacing : Crawl.SURFACE = facing
	facing = Crawl.surface_90deg(facing, -1)
	return OK

func get_entities(options : Dictionary = {}) -> Array:
	if _mapref.get_ref() == null: return []
	return _mapref.get_ref().get_entities(options)

func get_local_entities(options : Dictionary = {}) -> Array:
	options[&"position"] = position
	return get_entities(options)

func get_adjacent_entities(options : Dictionary = {}) -> Array:
	var neighbor_position : Vector3i = position + Crawl.surface_to_direction_vector(facing)
	options[&"position"] = neighbor_position
	return get_entities(options)

func get_entities_in_direction(surface : Crawl.SURFACE, options : Dictionary = {}) -> Array:
	var dposition : Vector3i = position + Crawl.surface_to_direction_vector(surface)
	options[&"position"] = dposition
	return get_entities(options)

func schedule_start(data : Dictionary = {}) -> void:
	# This is mostly a helper method to communicate to the owning
	# CrawlEntityNode3D node.
	schedule_started.emit(data)

func schedule_end(data : Dictionary = {}) -> void:
	# This is mostly a helper method to communicate to a 'Scheduler' script that
	# facilitates entity schedules.
	schedule_ended.emit(data)

func interact(info : Dictionary) -> void:
	interaction.emit(info)

func attack(info : Dictionary) -> void:
	attacked.emit(info)
