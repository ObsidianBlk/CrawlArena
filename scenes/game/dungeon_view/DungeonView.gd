extends Control


# ------------------------------------------------------------------------------
# Export Variables
# ------------------------------------------------------------------------------
@export var map : CrawlMap = null:							set = set_map
@export var player_id : int = 1

# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
@onready var _dungeon : Dungeon = %Dungeon

# ------------------------------------------------------------------------------
# Setters
# ------------------------------------------------------------------------------
func set_map(m : CrawlMap) -> void:
	if m != map:
		map = m
		if _dungeon != null:
			_dungeon.map = map

func set_player_id(pid : int) -> void:
	if pid >= 0 and pid != player_id:
		player_id = pid
		if _dungeon != null:
			_dungeon.focus_pid = player_id

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	if _dungeon != null:
		if _dungeon.map != map:
			_dungeon.map = map
		_dungeon.focus_pid = player_id


