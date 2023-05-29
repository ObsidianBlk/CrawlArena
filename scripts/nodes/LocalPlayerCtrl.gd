extends Node
class_name LocalPlayerCtrl


# ------------------------------------------------------------------------------
# Constant
# ------------------------------------------------------------------------------
const META_KEY_PID : String = "player_id"

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


func _unhandled_input(event : InputEvent) -> void:
	if _active_entity == null: return
	if event.is_action_pressed("foreward", false, true):
		_active_entity.move(&"foreward")
	if event.is_action_pressed("backward", false, true):
		_active_entity.move(&"backward")
	if event.is_action_pressed("step_up", false, true):
		_active_entity.move(&"up")
	if event.is_action_pressed("step_down", false, true):
		_active_entity.move(&"down")
	if event.is_action_pressed("step_left", false, true):
		_active_entity.move(&"left")
	if event.is_action_pressed("step_right", false, true):
		_active_entity.move(&"right")
	if event.is_action_pressed("turn_left", false, true):
		_active_entity.turn_left()
	if event.is_action_pressed("turn_right", false, true):
		_active_entity.turn_right()

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _UpdateActiveEntity() -> void:
	_active_entity = null
	if map == null: return
	
	print("Updating Active Entity")
	
	var entities : Array = map.get_entities({"type":&"unique:player"})
	for entity in entities:
		if not entity.has_meta_key(META_KEY_PID): continue
		
		var pid = entity.get_meta_value(META_KEY_PID, 0)
		if typeof(pid) != TYPE_INT or pid != player_id: continue
		
		print("Active Entity: ", entity)
		_active_entity = entity
		break

