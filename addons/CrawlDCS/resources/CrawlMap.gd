@tool
extends Resource
class_name CrawlMap


# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal cell_added(position)
signal cell_removed(position)
signal cell_changed(position)

#signal focus_position_changed(position)
#signal focus_facing_changed(surface)

signal entity_added(entity)
signal entity_removed(entity)

# ------------------------------------------------------------------------------
# Constants and ENUMs
# ------------------------------------------------------------------------------

const CELL_SCHEMA : Dictionary = {
	&"blocking":{&"req":true, &"type":TYPE_INT, &"min":0, &"max":0x3F},
	&"climbable":{&"req":false, &"type":TYPE_INT, &"min":0, &"max":0x3F},
	&"stair":{&"req":false, &"type":TYPE_BOOL},
	&"rid":{&"req":true, &"type":TYPE_ARRAY, &"item":{&"type":TYPE_INT, &"min":-1}},
	&"visited":{&"req":true, &"type":TYPE_BOOL}
}

const GRID_SCHEMA : Dictionary = {
	&"!KEY_OF_TYPE_V3I":{&"type":TYPE_VECTOR3I, &"def":{&"type":TYPE_DICTIONARY, &"def":CELL_SCHEMA}}
}

const RESOURCES_SCHEMA : Dictionary = {
	&"!KEY_OF_TYPE_str":{&"type":TYPE_STRING, &"def":{&"type":TYPE_INT, &"min":-1}}
}

const ENTITY_SEARCH_SCHEMA : Dictionary = {
	&"position":{&"req":false, &"type":TYPE_VECTOR3I},
	&"type":{&"req":false, &"type":TYPE_STRING_NAME},
	&"primary_type":{&"req":false, &"type":TYPE_STRING_NAME},
	&"sub_type":{&"req":false, &"type":TYPE_STRING_NAME},
	&"range":{&"req":false, &"type":TYPE_INT, &"min":0}
}

# ------------------------------------------------------------------------------
# "Export" Variables
# ------------------------------------------------------------------------------
var _name : String = ""
var _author : String = ""
var _world_env : StringName = &""
var _resources : Dictionary = {}
var _grid : Dictionary = {}
var _entities : Dictionary = {}

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _next_rid : int = 0

var _default_surface : Dictionary = {
	Crawl.SURFACE.Ceiling: 0,
	Crawl.SURFACE.Ground: 0,
	Crawl.SURFACE.North: 0,
	Crawl.SURFACE.South: 0,
	Crawl.SURFACE.East: 0,
	Crawl.SURFACE.West: 0
}

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------

func _get(property : StringName) -> Variant:
	match property:
		&"name":
			return _name
		&"author":
			return _author
		&"world_env":
			return _world_env
		&"grid":
			return _grid
		&"resources":
			return _resources
		&"entities":
			return _entities
	return null

func _set(property : StringName, value : Variant) -> bool:
	var success : bool = false
	match property:
		&"name":
			if typeof(value) == TYPE_STRING:
				_name = value
				success = true
		&"author":
			if typeof(value) == TYPE_STRING:
				_author = value
				success = true
		&"world_env":
			if typeof(value) == TYPE_STRING_NAME:
				_world_env = value
				success = true
		&"grid":
			if typeof(value) == TYPE_DICTIONARY:
				if DSV.verify(value, GRID_SCHEMA) == OK:
					_grid = value
					success = true
				else:
					printerr("Failed to load grid.")
		&"resources":
			if typeof(value) == TYPE_DICTIONARY:
				if DSV.verify(value, RESOURCES_SCHEMA) == OK:
					_resources = value
					_next_rid = 0
					for key in _resources.keys():
						if _resources[key] > _next_rid:
							_next_rid = _resources[key] + 1
					success = true
				else:
					printerr("Failed to load resources.")
		&"entities":
			if typeof(value) == TYPE_DICTIONARY:
				if _EntitiesValid(value):
					clear_entities()
					_entities = value
					for uuid in _entities.keys():
						_entities[uuid]._SetMap(self)
						entity_added.emit(_entities[uuid])
					success = true
				else:
					printerr("Failed to load Entities.")
	
	return success

func _get_property_list() -> Array:
	var arr : Array = [
		{
			name = "Crawl Map",
			type = TYPE_NIL,
			usage = PROPERTY_USAGE_CATEGORY
		},
		{
			name = "name",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT
		},
		{
			name = "author",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT
		},
		{
			name = "world_env",
			type = TYPE_STRING_NAME,
			usage = PROPERTY_USAGE_STORAGE
		},
		{
			name = "grid",
			type = TYPE_DICTIONARY,
			usage = PROPERTY_USAGE_STORAGE
		},
		{
			name = "entities",
			type = TYPE_DICTIONARY,
			usage = PROPERTY_USAGE_STORAGE
		},
		{
			name = "resources",
			type = TYPE_DICTIONARY,
			usage = PROPERTY_USAGE_STORAGE
		},
	]
	
	return arr

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _EntitiesValid(edata : Dictionary) -> bool:
	for key in edata.keys():
		if typeof(key) != TYPE_STRING_NAME and typeof(key) != TYPE_STRING: return false
		if not is_instance_of(edata[key], CrawlEntity): return false
	return true

func _CreateDefaultCell() -> Dictionary:
	return {
		&"blocking": 0x3F,
		&"visited":false,
		&"rid": [
			_default_surface[Crawl.SURFACE.North],
			_default_surface[Crawl.SURFACE.East],
			_default_surface[Crawl.SURFACE.South],
			_default_surface[Crawl.SURFACE.West],
			_default_surface[Crawl.SURFACE.Ground],
			_default_surface[Crawl.SURFACE.Ceiling],
		]
	}


func _CalcNeighborFrom(position : Vector3i, surface : Crawl.SURFACE) -> Vector3i:
	return position + Crawl.surface_to_direction_vector(surface)


func _CloneCell(cell : Dictionary, ncell : Dictionary = {}) -> Dictionary:
	ncell[&"blocking"] = cell[&"blocking"]
	ncell[&"visited"] = cell[&"visited"]
	ncell[&"rid"] = []
	for rid in cell[&"rid"]:
		ncell[&"rid"] = rid
	if &"stair" in cell:
		ncell[&"stair"] = cell[&"stair"]
	if &"climbable" in cell:
		ncell[&"climbable"] = cell[&"climbable"]
	return ncell

func _CloneGrid() -> Dictionary:
	var ngrid : Dictionary = {}
	for key in _grid:
		ngrid[key] = _CloneCell(_grid[key])
	return ngrid

func _CloneResources() -> Dictionary:
	var resources : Dictionary = {}
	for key in _resources:
		resources[key] = _resources[key]
	return resources

func _CloneEntities() -> Dictionary:
	var entities : Dictionary = {}
	for key in _entities:
		var ent : CrawlEntity = _entities[key].clone()
		entities[ent.uuid] = ent
	return entities

func _CalcBlocking(block_val : int, surface : Crawl.SURFACE, block : bool) -> int:
	if block:
		return (block_val | surface) & 0x3F
	return (block_val & (~surface)) & 0x3F

func _SetCellSurface(position : Vector3i, surface : Crawl.SURFACE, data : Dictionary, bi_directional : bool) -> void:
	var changed : bool = false
	if &"blocking" in data:
		_grid[position][&"blocking"] = _CalcBlocking(_grid[position][&"blocking"], surface, data[&"blocking"])
		changed = true
	if &"resource_id" in data:
		var idx : int = Crawl.SURFACE.values().find(surface)
		if idx >= 0:
			_grid[position][&"rid"][idx] = data[&"resource_id"]
		changed = true
	if &"climbable" in data:
		if &"climbable" in _grid[position]:
			# Obviously _CalcBlocking() works for climbable as well :)
			_grid[position][&"climbable"] = _CalcBlocking(_grid[position][&"climbable"], surface, data[&"climbable"])
	
	if changed:
		cell_changed.emit(position)
	
	if bi_directional:
		var pos : Vector3i = _CalcNeighborFrom(position, surface)
		if not pos in _grid: return
		var surf : Crawl.SURFACE = Crawl.surface_get_adjacent(surface)
		_SetCellSurface(pos, surf, data, false)


func _GetCellSurface(position : Vector3i, surface : Crawl.SURFACE) -> Dictionary:
	var idx : int = Crawl.SURFACE.values().find(surface)
	if idx >= 0:
		return {
			&"blocking": _grid[position][&"blocking"] & surface != 0,
			&"resource_id": _grid[position][&"rid"][idx]
		}
	return {}

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func clone(clone_entities : bool = false) -> CrawlMap:
	var cm : CrawlMap = CrawlMap.new()
	cm._grid = _CloneGrid()
	cm._world_env = _world_env
	cm._resources = _CloneResources()
	if clone_entities:
		cm._entities = _CloneEntities()
	return cm

func add_resource(resource : StringName) -> int:
	if resource in _resources:
		return ERR_ALREADY_IN_USE
	_resources[resource] = _next_rid
	_next_rid += 1
	return OK

func has_resource(resource : StringName) -> bool:
	return resource in _resources

func get_resource_id(resource : StringName) -> int:
	if resource in _resources:
		return _resources[resource]
	return -1

func get_resource_name_from_id(resource_id) -> StringName:
	var key = _resources.find_key(resource_id)
	return key if key != null else &""

func get_resources() -> Array:
	return _resources.keys()

func clear_unused_resources() -> void:
	var nr : Dictionary = {}
	var highest_rid : int = 0
	for cell in _grid.keys():
		for rid in _grid[cell][&"rid"]:
			if rid < 0:
				continue
			var key = _resources.find_key(rid)
			if key == null:
				continue
			if key in nr:
				continue
			nr[key] = _resources[key]
			if rid > highest_rid:
				highest_rid = rid + 1
	_resources = nr
	_next_rid = highest_rid

func set_world_environment(env : StringName) -> void:
	_world_env = env

func get_world_environment() -> StringName:
	return _world_env

func set_default_surface_resource(surface : Crawl.SURFACE, resource : StringName) -> void:
	var rid : int = get_resource_id(resource)
	if rid < 0:
		if add_resource(resource) != OK: return
		rid = _next_rid - 1
	_default_surface[surface] = rid

func set_default_surface_resource_id(surface : Crawl.SURFACE, rid : int) -> void:
	if get_resource_name_from_id(rid) == &"": return
	_default_surface[surface] = rid

func add_entity(entity : CrawlEntity) -> void:
	if entity.type == &"" or entity.uuid == &"":
		return
	
	if not entity.uuid in _entities:
		_entities[entity.uuid] = entity
		entity._SetMap(self)
		entity_added.emit(entity)

func remove_entity(entity : CrawlEntity) -> void:
	if not entity.uuid in _entities: return
	_entities.erase(entity.uuid)
	entity._SetMap(null)
	entity_removed.emit(entity)

func remove_entity_by_uuid(uuid : StringName) -> void:
	if not uuid in _entities: return
	remove_entity(_entities[uuid])

func clear_entities() -> void:
	if _entities.is_empty(): return
	var uuid_list : Array = _entities.keys()
	for uuid in uuid_list:
		remove_entity_by_uuid(uuid)

func has_entity(entity : CrawlEntity) -> bool:
	return entity.uuid in _entities

func has_entity_uuid(uuid : StringName) -> bool:
	return uuid in _entities

func get_entity(uuid : StringName) -> CrawlEntity:
	if not uuid in _entities: return null
	return _entities[uuid]

func get_entities(options : Dictionary = {}) -> Array:
	if DSV.verify(options, ENTITY_SEARCH_SCHEMA) != OK: return []
	
	var earr : Array = []
	for uuid in _entities.keys():
		if &"position" in options:
			if &"range" in options and options[&"range"] > 0:
				var from : Vector3 = Vector3(options[&"position"])
				var to : Vector3 = Vector3(_entities[uuid].position)
				var d : float = from.distance_to(to)
				if d > options[&"range"]:
					continue
			else:
				if _entities[uuid].position != options[&"position"]: continue
		if &"type" in options:
			if _entities[uuid].type != options[&"type"]: continue
		elif &"primary_type" in options:
			if not _entities[uuid].is_basetype(options[&"primary_type"]): continue
		elif &"sub_type" in options:
			if not _entities[uuid].is_subtype(options[&"sub_type"]): continue
		earr.append(_entities[uuid])
	return earr


func clear_entities_outside_map() -> void:
	var removal : Array = []
	for type in _entities.keys():
		for entity in _entities[type]:
			if not entity.position in _grid:
				removal.append(entity)
	for entity in removal:
		remove_entity(entity)

func add_cell(position : Vector3i, open_to_adjacent : bool = false) -> int:
	if position in _grid:
		return ERR_ALREADY_EXISTS
	_grid[position] = _CreateDefaultCell()
	cell_added.emit(position)
	if open_to_adjacent:
		for surface in Crawl.SURFACE.values():
			var neighbor_position : Vector3i = _CalcNeighborFrom(position, surface)
			if neighbor_position in _grid:
				dig(position, surface)
	else:
		cell_changed.emit(position)
	return OK

func has_cell(position : Vector3i) -> bool:
	return position in _grid


func copy_cell(from_position : Vector3i, to_position : Vector3i) -> int:
	if from_position != to_position: # Nothing to do if from and to are the same.
		if not from_position in _grid:
			return ERR_DOES_NOT_EXIST
		if to_position in _grid:
			_CloneCell(_grid[from_position], _grid[to_position])
		else:
			_grid[to_position] = _CloneCell(_grid[from_position])
			cell_added.emit(to_position)
		cell_changed.emit(to_position)
	return OK

func remove_cell(position : Vector3i) -> void:
	if not position in _grid: return
	_grid.erase(position)
	cell_removed.emit(position)

func set_cell_stairs(position : Vector3i, has_stairs : bool) -> void:
	if not position in _grid:
		printerr("CrawlMap Error: No cell at position ", position)
		return
	_grid[position][&"stair"] = has_stairs
	cell_changed.emit(position)

func clear_cell_stairs(position : Vector3i) -> void:
	if not position in _grid:
		printerr("CrawlMap Error: No cell at position ", position)
		return
	if &"stair" in _grid[position]:
		_grid[position].erase(&"stair")
		cell_changed.emit(position)

func is_cell_stairs(position : Vector3i) -> bool:
	if not position in _grid: return false
	if not &"stair" in _grid[position]: return false
	return _grid[position][&"stair"]

func set_cell_surface(position : Vector3i, surface : Crawl.SURFACE, blocking : bool, resource_id : Variant, bi_directional : bool = false) -> void:
	if not position in _grid:
		printerr("CrawlMap Error: No cell at position ", position)
		return
	
	var data : Dictionary = {
		&"blocking": blocking
	}
	if typeof(resource_id) == TYPE_INT:
		if resource_id < 0 or _resources.find_key(resource_id) != null:
			data[&"resource_id"] = resource_id
	elif typeof(resource_id) == TYPE_STRING_NAME or typeof(resource_id) == TYPE_STRING:
		if resource_id in _resources:
			data[&"resource_id"] = _resources[resource_id]
		else:
			var rid : int = _next_rid
			_resources[StringName(resource_id)] = rid
			_next_rid += 1
			data[&"resource_id"] = rid
	
	_SetCellSurface(position, surface, data, bi_directional)

func set_cell_surfaces_to_defaults(position : Vector3i) -> void:
	if not position in _grid:
		printerr("CrawlMap Error: No cell at position ", position)
		return
	
	clear_cell_stairs(position)
	if _grid[position][&"rid"][0] >= 0:
		_grid[position][&"rid"][0] = _default_surface[Crawl.SURFACE.North]
	if _grid[position][&"rid"][1] >= 0:
		_grid[position][&"rid"][1] = _default_surface[Crawl.SURFACE.East]
	if _grid[position][&"rid"][2] >= 0:
		_grid[position][&"rid"][2] = _default_surface[Crawl.SURFACE.South]
	if _grid[position][&"rid"][3] >= 0:
		_grid[position][&"rid"][3] = _default_surface[Crawl.SURFACE.West]
	if _grid[position][&"rid"][4] >= 0:
		_grid[position][&"rid"][4] = _default_surface[Crawl.SURFACE.Ground]
	if _grid[position][&"rid"][5] >= 0:
		_grid[position][&"rid"][5] = _default_surface[Crawl.SURFACE.Ceiling]
	
	cell_changed.emit(position)

func set_cell_surface_blocking(position : Vector3i, surface : Crawl.SURFACE, blocking : bool, bi_directional : bool = false) -> void:
	if not position in _grid:
		printerr("CrawlMap Error: No cell at position ", position)
		return
	_SetCellSurface(position, surface, {&"blocking":blocking}, bi_directional)


func set_cell_surface_resource(position : Vector3i, surface : Crawl.SURFACE, resource_id : Variant, bi_directional : bool = false) -> void:
	if not position in _grid:
		printerr("CrawlMap Error: No cell at position ", position)
		return

	var data : Dictionary = {}
	if typeof(resource_id) == TYPE_INT:
		if resource_id < 0 or _resources.find_key(resource_id) != null:
			data[&"resource_id"] = resource_id
	elif typeof(resource_id) == TYPE_STRING_NAME or typeof(resource_id) == TYPE_STRING:
		if resource_id in _resources:
			data[&"resource_id"] = _resources[resource_id]
		else:
			var rid : int = _next_rid
			_resources[StringName(resource_id)] = rid
			_next_rid += 1
			data[&"resource_id"] = rid
	
	if not data.is_empty():
		_SetCellSurface(position, surface, data, bi_directional)


func get_cell(position : Vector3i, surface : Crawl.SURFACE) -> Dictionary:
	if not position in _grid:
		printerr("CrawlMap Error: No cell at position ", position)
		return {}
	return _GetCellSurface(position, surface)

func get_cell_surface_resource_id(position : Vector3i, surface : Crawl.SURFACE) -> int:
	if position in _grid:
		var info : Dictionary = _GetCellSurface(position, surface)
		if not info.is_empty():
			return info[&"resource_id"]
	else:
		printerr("CrawlMap Error: No cell at position ", position)
	return -1

func get_cell_surface_resource(position : Vector3i, surface : Crawl.SURFACE) -> StringName:
	if position in _grid:
		var info : Dictionary = _GetCellSurface(position, surface)
		if not info.is_empty():
			var key = _resources.find_key(info[&"resource_id"])
			if key != null:
				return key
	else:
		printerr("CrawlMap Error: No cell at position ", position)
	return &""

func get_cell_surface_resource_ids(position : Vector3i) -> Array:
	if position in _grid:
		var rids : Array = []
		for rid in _grid[position][&"rid"]:
			rids.append(rid)
		return rids
	else:
		printerr("CrawlMap Error: No cell at position ", position)
	return []

func get_cell_surface_resources(position : Vector3i) -> Array:
	if position in _grid:
		var resources : Array = []
		for rid in _grid[position][&"rid"]:
			var key = _resources.find_key(rid)
			if key != null:
				resources.append(key)
		return resources
	else:
		printerr("CrawlMap Error: No cell at position ", position)
	return []

func is_cell_surface_blocking(position : Vector3i, surface : Crawl.SURFACE) -> bool:
	if position in _grid:
		var info : Dictionary = _GetCellSurface(position, surface)
		if not info.is_empty():
			return info[&"blocking"]
	else:
		printerr("CrawlMap Error: No cell at position ", position)
	return true

func get_used_cells(visited_only : bool = false) -> Array:
	var list : Array = _grid.keys()
	if visited_only:
		list = list.filter(func(pos : Vector3i): return _grid[pos][&"visited"])
	return list

func get_used_cells_from(position : Vector3i, visited_only : bool = false, limit_to_layer : bool = false, cell_range : int = 0) -> Array:
	var cells : Array = []
	for cell in _grid.keys():
		if limit_to_layer and cell.y != position.y:
			continue
		if cell_range > 0 and Vector3(position).distance_to(Vector3(cell)) > float(cell_range):
			continue
		if visited_only and not _grid[cell][&"visited"]:
			continue
		cells.append(cell)
	return cells

func fill(position : Vector3i, direction : Crawl.SURFACE) -> void:
	var neighbor_position : Vector3i = _CalcNeighborFrom(position, direction)
	if not neighbor_position in _grid: return
	remove_cell(neighbor_position)
	for surface in Crawl.SURFACE.values():
		var cell_position : Vector3i = _CalcNeighborFrom(neighbor_position, surface)
		if not cell_position in _grid: continue
		var opposite_surface : Crawl.SURFACE = Crawl.surface_get_adjacent(surface)
		set_cell_surface(cell_position, opposite_surface, true, _default_surface[surface])

func dig(position : Vector3i, direction : Crawl.SURFACE) -> void:
	if not position in _grid:
		add_cell(position)
	var neighbor_position : Vector3i = _CalcNeighborFrom(position, direction)
	if not neighbor_position in _grid:
		add_cell(neighbor_position)
	set_cell_surface(position, direction, false, -1, true)

func dig_room(position : Vector3i, size : Vector3i) -> void:
	# Readjusting position for possible negative size values.
	position.x += size.x if size.x < 0 else 0
	position.y += size.y if size.y < 0 else 0
	position.z += size.z if size.z < 0 else 0
	
	size = abs(size)
	var target : Vector3i = position + size
	
	var _set_surface : Callable = func(pos : Vector3i, surf : Crawl.SURFACE, blocking : bool) -> void:
		if not pos in _grid: return
		var rid : int = _default_surface[surf]
		set_cell_surface(pos, surf, blocking, rid if blocking else -1)
	
	for k in range(position.z, target.z):
		for j in range(position.y, target.y):
			for i in range(position.x, target.x):
				var pos : Vector3i = Vector3i(i,j,k)
				if not pos in _grid:
					add_cell(pos)
					_set_surface.call(pos, Crawl.SURFACE.Ground, j == position.y)
					_set_surface.call(pos, Crawl.SURFACE.Ceiling, j + 1 == target.y)
					_set_surface.call(pos, Crawl.SURFACE.North, k + 1 == target.z)
					_set_surface.call(pos, Crawl.SURFACE.South, k == position.z)
					_set_surface.call(pos, Crawl.SURFACE.East, i == position.x)
					_set_surface.call(pos, Crawl.SURFACE.West, i + 1 == target.x)

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
#func _on_focus_entity_position_changed(from : Vector3i, to : Vector3i) -> void:
#	focus_position_changed.emit(to)
#
#func _on_focus_entity_facing_changed(from : Crawl.SURFACE, to : Crawl.SURFACE) -> void:
#	focus_facing_changed.emit(to)
