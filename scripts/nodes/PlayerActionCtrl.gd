extends Node
class_name PlayerActionCtrl


# ------------------------------------------------------------------------------
# signals
# ------------------------------------------------------------------------------
signal action_processed()
signal hp_changed(pid, hp, max_hp)
signal defeated()

# ------------------------------------------------------------------------------
# Constant
# ------------------------------------------------------------------------------
const META_KEY_PID : String = "player_id"
const META_KEY_ITEM : String = "held_item"
const META_KEY_WEAPON : String = "held_weapon"
const META_KEY_HP : String = "hp"
const CMD_DELAY : float = 0.8

const MAX_HP : int = 18

# ------------------------------------------------------------------------------
# Export Variables
# ------------------------------------------------------------------------------
@export var map : CrawlMap = null:					set = set_map
@export_range(1, 10) var player_id : int = 1:		set = set_player_id

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _alive : bool = true
var _active_entity : CrawlEntity = null

var _action_delay : float = 0.0

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

func _process(delta : float) -> void:
	_action_delay += delta

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _UpdateActiveEntity() -> void:
	if _active_entity != null:
		if _active_entity.schedule_ended.is_connected(_on_entity_schedule_ended):
			_active_entity.schedule_ended.disconnect(_on_entity_schedule_ended)
		if _active_entity.meta_value_changed.is_connected(_on_entity_meta_value_changed):
			_active_entity.meta_value_changed.disconnect(_on_entity_meta_value_changed)
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
		if not _active_entity.meta_value_changed.is_connected(_on_entity_meta_value_changed):
			_active_entity.meta_value_changed.connect(_on_entity_meta_value_changed)
		break

func _ActionProcessed() -> void:
	if _action_delay < CMD_DELAY:
		await get_tree().create_timer(CMD_DELAY - _action_delay).timeout
	action_processed.emit()

func _HandleMove(direction : StringName) -> void:
	if _active_entity.can_move(direction):
		_active_entity.move(direction)
	else:
		_ActionProcessed()

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
	_ActionProcessed()

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func reset() -> void:
	if _active_entity != null:
		_active_entity.set_meta_value(META_KEY_HP, MAX_HP)

func handle_action(pid : int, code : String) -> void:
	if pid != player_id:
		return
	
	_action_delay = 0.0
	if _active_entity == null or not _alive:
		_ActionProcessed()
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
		_:
			_ActionProcessed()

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_entity_schedule_ended(_data : Dictionary) -> void:
	_ActionProcessed()

func _on_entity_meta_value_changed(key : String) -> void:
	if key == META_KEY_HP:
		var val = _active_entity.get_meta_value(key, MAX_HP)
		hp_changed.emit(player_id, val, MAX_HP)
		if val <= 0:
			_alive = false
			defeated.emit()
