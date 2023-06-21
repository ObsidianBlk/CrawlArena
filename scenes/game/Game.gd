extends Control


# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal action_requested(action, payload)

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const GAME_PREP_TIME : float = 15.0
const GAME_COMMAND_TIME : float = 30.0

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _game_prep_timer : float = GAME_PREP_TIME
var _game_command_timer : float = GAME_COMMAND_TIME + 1

var _cmd_time_skipped : bool = false

# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
@onready var _local_player_ctrl : LocalPlayerCtrl = %LocalPlayerCtrl
@onready var _msg_player_ctrl : MsgPlayerCtrl = %MsgPlayerCtrl

@onready var _dungeon_view_a : Control = %DungeonViewA
@onready var _dungeon_view_b : Control = %DungeonViewB

@onready var _player_action_ctrl_a : PlayerActionCtrl = %PlayerActionCtrlA
@onready var _player_action_ctrl_b : PlayerActionCtrl = %PlayerActionCtrlB


@onready var _game_command_parser : GameCommandParser = %GameCommandParser

@onready var _lbl_prep : Label = %LblPrep
@onready var _lbl_user_actions : Label = %LblUserActions

@onready var _lbl_player_a : Label = %LblPlayerA
@onready var _lbl_player_b : Label = %LblPlayerB

@onready var crawl_mini_map : CrawlMiniMap = %CrawlMiniMap

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	var map : CrawlMap = null
	if ResourceLoader.exists("user://dungeons/871a756-Area052923.tres"):
		map = ResourceLoader.load("user://dungeons/871a756-Area052923.tres")
	if is_instance_of(map, CrawlMap):
		#_local_player_ctrl.map = map
		_dungeon_view_a.map = map
		_dungeon_view_b.map = map
		_player_action_ctrl_a.map = map
		_player_action_ctrl_b.map = map
		crawl_mini_map.map = map
		#_msg_player_ctrl.map = map

func _unhandled_input(event : InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		action_requested.emit(&"close", null)

func _process(delta : float) -> void:
	if _game_prep_timer < GAME_PREP_TIME:
		_game_prep_timer += delta
		if _game_prep_timer >= GAME_PREP_TIME:
			_lbl_prep.text = ""
			_on_game_prep_complete() # This should not be in the Handler section
		else:
			_lbl_prep.text = "Waiting for players: %.2f"%[_game_prep_timer]
	elif _game_command_timer <= GAME_COMMAND_TIME:
		_game_command_timer += delta
		if _game_command_timer > GAME_COMMAND_TIME:
			_lbl_prep.text = ""
			_game_command_parser.set_state(GameCommandParser.STATE.Process)
		else:
			_lbl_prep.text = "Waiting for commands: %.2f"%[_game_command_timer]

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func handle_message(msgctx : GSMCMessage) -> void:
	#if _msg_player_ctrl == null: return
	#_msg_player_ctrl.handle_message(msgctx)
	if _game_command_parser == null: return
	_game_command_parser.handle_message(msgctx)

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_game_command_parser_start_requested(user : GSMCUser) -> void:
	if not user.is_owner:
		print("User ", user.username, " is not the master user!")
		return
	_game_command_parser.set_state(GameCommandParser.STATE.Prep)
	_game_prep_timer = 0.0

func _on_game_prep_complete() -> void:
	if _game_command_parser.get_user_count() <= 0:
		_game_command_parser.set_state(GameCommandParser.STATE.Idle)
		return
	_game_command_parser.set_state(GameCommandParser.STATE.Command)
	_cmd_time_skipped = false
	_game_command_timer = 0.0

func _on_game_command_parser_action_processing_completed() -> void:
	_on_game_prep_complete()

func _on_game_command_parser_user_joined_team(pid : int, username : String) -> void:
	_lbl_user_actions.text = "%s has joined team %d"%[username, pid]

func _on_game_command_parser_user_left_team(pid : int, username : String) -> void:
	_lbl_user_actions.text = "%s has left team %d"%[username, pid]

func _on_game_command_parser_user_submitted_actions(pid : int, username : String) -> void:
	if not _cmd_time_skipped:
		_cmd_time_skipped = true
		if _game_command_timer < GAME_COMMAND_TIME * 0.5:
			_game_command_timer = GAME_COMMAND_TIME * 0.5
	else:
		if _game_command_timer >= GAME_COMMAND_TIME * 0.5 and _game_command_timer < GAME_COMMAND_TIME:
			_game_command_timer = GAME_COMMAND_TIME


func _on_game_command_parser_user_turn_active(pid : int, username : String) -> void:
	if pid == 1:
		_lbl_player_a.text = "Team A: %s"%[username]
	elif pid == 2:
		_lbl_player_b.text = "Team B: %s"%[username]



