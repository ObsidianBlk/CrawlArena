extends Control


# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal action_requested(action, payload)

# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
@onready var _local_player_ctrl : LocalPlayerCtrl = %LocalPlayerCtrl
@onready var _team_a_dungeon : Dungeon = %TeamADungeon


# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	var map : CrawlMap = ResourceLoader.load("user://dungeons/871a756-Area052923.tres")
	if is_instance_of(map, CrawlMap):
		_local_player_ctrl.map = map
		_team_a_dungeon.map = map

func _unhandled_input(event : InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		action_requested.emit(&"close", null)
