extends Node
class_name MsgPlayerCtrl


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
var _cmd_buffer : Array = []

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

func _ProcessBuffer() -> void:
	if _active_entity == null: return
	if _cmd_buffer.size() <= 0: return
	var cmd = _cmd_buffer.pop_front()
	match cmd:
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
	
	await get_tree().create_timer(CMD_DELAY).timeout
	_ProcessBuffer()

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func handle_message(msgctx : OT4G_IRC.MessageContext) -> void:
	if _cmd_buffer.size() > 0: return
	if not msgctx.message.begins_with("!"): return
	if msgctx.message.length() != 6: return
	
	_cmd_buffer.append(msgctx.message.substr(1, 1))
	_cmd_buffer.append(msgctx.message.substr(2, 1))
	_cmd_buffer.append(msgctx.message.substr(3, 1))
	_cmd_buffer.append(msgctx.message.substr(4, 1))
	_cmd_buffer.append(msgctx.message.substr(5, 1))
	
	msgctx.reply("Thank you... processing your commands now Master!")
	_ProcessBuffer()
