extends Control


# ------------------------------------------------------------------------------
# Export Variables
# ------------------------------------------------------------------------------
@export var map : CrawlMap = null
@export var player_id : int = 1

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _dungeon = null

# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
#@onready var _dungeon : Dungeon = $DVBackPanel/CSubView/SubViewport/DungeonScene


# ------------------------------------------------------------------------------
# Setters
# ------------------------------------------------------------------------------
func set_map (m : CrawlMap) -> void:
	if m != map:
		map = m
		if _dungeon != null:
			_dungeon.map = map

func set_player_id (pid : int) -> void:
	if pid != player_id:
		player_id = pid
		if _dungeon != null:
			_dungeon.focus_pid = player_id

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	print("Dungeon: ", _dungeon)
	print("Long Dungeon: ", get_node_or_null("DVFrontPanel"))
	if _dungeon != null:
		if _dungeon.map != map:
			_dungeon.map = map
		if _dungeon.focus_pid != player_id:
			_dungeon.focus_pid = player_id

