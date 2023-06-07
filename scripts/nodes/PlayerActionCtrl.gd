extends Node
class_name PlayerActionCtrl


# ------------------------------------------------------------------------------
# Constant
# ------------------------------------------------------------------------------
const META_KEY_PID : String = "player_id"
const CMD_DELAY : float = 0.8

# ------------------------------------------------------------------------------
# Export Variables
# ------------------------------------------------------------------------------
@export var map : CrawlMap = null:					set = set_map
@export_range(1, 10) var player_id : int = 1:		set = set_player_id

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _active_entity : CrawlEntity = null

# ------------------------------------------------------------------------------
# Setters
# ------------------------------------------------------------------------------
func set_map(m : CrawlMap) -> void:
	if m == map: return
	if map != null:
		pass # Disconnect what needs to be disconnected
	map = m
	if map != null:
		_UpdateActiveEntity()

func set_player_id(pid : int) -> void:
	if not (pid >= 1 and pid <= 10) or pid == player_id: return
	player_id = pid
	_UpdateActiveEntity()

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	_UpdateActiveEntity()

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _UpdateActiveEntity() -> void:
	_active_entity = null
	if map == null: return
	
	var entities : Array = map.get_entities({"type":&"unique:player"})
	for entity in entities:
		if not entity.has_meta_key(META_KEY_PID): continue
		
		var pid = entity.get_meta_value(META_KEY_PID, 0)
		if typeof(pid) != TYPE_INT or pid != player_id: continue
		
		print("Active Entity: ", entity)
		_active_entity = entity
		break

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func handle_action(pid : int, code : String) -> void:
	if _active_entity == null: return
	if pid != player_id: return
	match code:
		"w", "W":
			_active_entity.move(&"foreward")
		"s", "S":
			_active_entity.move(&"backward")
		"a", "A":
			_active_entity.move(&"left")
		"d", "D":
			_active_entity.move(&"right")
		"q", "Q":
			_active_entity.turn_left()
		"e", "E":
			_active_entity.turn_right()
