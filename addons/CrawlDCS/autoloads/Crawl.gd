extends Node


# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal lookup_table_added(ltname)
signal lookup_table_updated(ltname)

# ------------------------------------------------------------------------------
# Constants and ENUMs
# ------------------------------------------------------------------------------
enum SURFACE {North=0x01, East=0x02, South=0x04, West=0x08, Ground=0x10, Ceiling=0x20}
const ALL_COMPASS_SURFACES : int = 15
const ALL_SURFACES : int = 63

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _lookup_tables : Dictionary = {}

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func surface_get_index(surface : SURFACE) -> int:
	return SURFACE.values().find(surface)

func surface_get_adjacent(surface : SURFACE) -> SURFACE:
	match surface:
		SURFACE.North:
			return SURFACE.South
		SURFACE.East:
			return SURFACE.West
		SURFACE.South:
			return SURFACE.North
		SURFACE.West:
			return SURFACE.East
		SURFACE.Ground:
			return SURFACE.Ceiling
		SURFACE.Ceiling:
			return SURFACE.Ground
	return surface

func surface_to_direction_vector(surface : SURFACE) -> Vector3i:
	match surface:
		SURFACE.North:
			return Vector3i(0,0,1)
		SURFACE.East:
			return Vector3i(-1,0,0)
		SURFACE.South:
			return Vector3i(0,0,-1)
		SURFACE.West:
			return Vector3i(1,0,0)
		SURFACE.Ground:
			return Vector3i(0,-1,0)
		SURFACE.Ceiling:
			return Vector3i(0,1,0)
	return Vector3i.ZERO

func surface_from_direction_vector(dir : Vector3) -> SURFACE:
	dir = dir.normalized()
	var deg45 : float = deg_to_rad(45.0)
	if dir.angle_to(Vector3(0,0,1)) < deg45:
		return SURFACE.North
	if dir.angle_to(Vector3(-1,0,0)) < deg45:
		return SURFACE.East
	if dir.angle_to(Vector3(0,0,-1)) < deg45:
		return SURFACE.South
	if dir.angle_to(Vector3(1,0,0)) < deg45:
		return SURFACE.West
	if dir.angle_to(Vector3(0,1,0)) < deg45:
		return SURFACE.Ceiling
	return SURFACE.Ground

func surface_90deg(surface : SURFACE, amount : int) -> SURFACE:
	if surface & 0x0F == 0: return surface # Only North, South, East, and West will work
	
	var dir : Vector3 = Vector3(surface_to_direction_vector(surface))
	dir = dir.rotated(Vector3.UP, deg_to_rad(90.0 * float(amount)))
	return surface_from_direction_vector(dir)

func surface_to_surface_angle(from : SURFACE, to : SURFACE) -> float:
	if from == to: return 0.0
	var deg90 : float = deg_to_rad(90)
	match from:
		SURFACE.North:
			match to:
				SURFACE.East, SURFACE.West:
					return deg90 if to == SURFACE.West else -deg90
				SURFACE.South:
					return deg90 * 2
				SURFACE.Ground, SURFACE.Ceiling:
					return deg90 if to == SURFACE.Ceiling else -deg90
		SURFACE.East:
			match to:
				SURFACE.South, SURFACE.North:
					return deg90 if to == SURFACE.North else -deg90
				SURFACE.West:
					return deg90 * 2
				SURFACE.Ground, SURFACE.Ceiling:
					return deg90 if to == SURFACE.Ceiling else -deg90
		SURFACE.South:
			match to:
				SURFACE.East, SURFACE.West:
					return deg90 if to == SURFACE.East else -deg90
				SURFACE.North:
					return deg90 * 2
				SURFACE.Ground, SURFACE.Ceiling:
					return deg90 if to == SURFACE.Ceiling else -deg90
		SURFACE.West:
			match to:
				SURFACE.South, SURFACE.North:
					return deg90 if to == SURFACE.South else -deg90
				SURFACE.East:
					return deg90 * 2
				SURFACE.Ground, SURFACE.Ceiling:
					return deg90 if to == SURFACE.Ceiling else -deg90
		SURFACE.Ground:
			return deg90 * 2 if to == SURFACE.Ceiling else deg90
		SURFACE.Ceiling:
			return deg90 * 2 if to == SURFACE.Ground else deg90
	return 0.0


func store_lookup_table(ltname : StringName, mrlt : CrawlMRLT) -> void:
	if ltname == &"": return
	if ltname in _lookup_tables: return
	_lookup_tables[ltname] = mrlt
	if not mrlt.updated.is_connected(_on_mrlt_updated.bind(ltname)):
		mrlt.updated.connect(_on_mrlt_updated.bind(ltname))
	lookup_table_added.emit(ltname)

func has_lookup_table(ltname : StringName) -> bool:
	return ltname in _lookup_tables

func get_lookup_table(ltname : StringName) -> CrawlMRLT:
	if not ltname in _lookup_tables: return null
	return _lookup_tables[ltname]

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_mrlt_updated(ltname : StringName) -> void:
	lookup_table_updated.emit(ltname)

