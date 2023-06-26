extends Node
class_name PlayerActionCtrl


# ------------------------------------------------------------------------------
# signals
# ------------------------------------------------------------------------------
signal action_processed()

# ------------------------------------------------------------------------------
# Constant
# ------------------------------------------------------------------------------
const META_KEY_PID : String = "player_id"
const META_KEY_ITEM : String = "held_item"
const META_KEY_WEAPON : String = "held_weapon"
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
	if _active_entity != null:
		if _active_entity.schedule_ended.is_connected(_on_entity_schedule_ended):
			_active_entity.schedule_ended.disconnect(_on_entity_schedule_ended)
		_active_entity = null
	if map == null: return
	
	var entities : Array = map.get_entities({"type":&"unique:player"})
	for entity in entities:
		if not entity.has_meta_key(META_KEY_PID): continue
		
		var pid = entity.get_meta_value(META_KEY_PID, 0)
		if typeof(pid) != TYPE_INT or pid != player_id: continue
		
		_active_entity = entity
		if not _active_entity.schedule_ended.is_connected(_on_entity_schedule_ended):
			_active_entity.schedule_ended.connect(_on_entity_schedule_ended)
		break

func _HandleMove(direction : StringName) -> void:
	if _active_entity.can_move(direction):
		_active_entity.move(direction)
	else:
		action_processed.emit()

func _CheckGrab(meta_key : String, type : StringName) -> bool:
	if _active_entity.has_meta_key(meta_key): return false
	var entities : Array = _active_entity.get_local_entities({&"primary_type":type})
	if entities.size() <= 0: return false
	
	if not _active_entity.grab_entity(entities[0]): return false
	
	_active_entity.set_meta_value(meta_key, entities[0])
	return true

func _HandleGrab() -> void:
	if _CheckGrab(META_KEY_ITEM, &"item"): return
	if _CheckGrab(META_KEY_WEAPON, &"weapon"): return
	# If we get here, all above statements returned false and nothing was grabbed
	action_processed.emit()

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func handle_action(pid : int, code : String) -> void:
	if _active_entity == null or pid != player_id:
		action_processed.emit()
		return
	
	match code:
		"w", "W":
			_HandleMove(&"foreward")
			#_active_entity.move(&"foreward")
		"s", "S":
			_HandleMove(&"backward")
			#_active_entity.move(&"backward")
		"a", "A":
			_HandleMove(&"left")
			#_active_entity.move(&"left")
		"d", "D":
			_HandleMove(&"right")
			#_active_entity.move(&"right")
		"q", "Q":
			_active_entity.turn_left()
		"e", "E":
			_active_entity.turn_right()
		"f", "F":
			_active_entity.attack({})
		"g", "G":
			_HandleGrab()

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_entity_schedule_ended(_data : Dictionary) -> void:
	action_processed.emit()
