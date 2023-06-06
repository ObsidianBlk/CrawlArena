extends Control


# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal action_requested(action, payload)

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const GAME_PREP_TIME : float = 30.0

# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
@onready var _local_player_ctrl : LocalPlayerCtrl = %LocalPlayerCtrl
@onready var _team_a_dungeon : Dungeon = %TeamADungeon
@onready var _team_b_dungeon : Dungeon = %TeamBDungeon
@onready var _msg_player_ctrl : MsgPlayerCtrl = %MsgPlayerCtrl

@onready var _game_command_parser : GameCommandParser = %GameCommandParser

@onready var _lbl_prep : Label = %LblPrep
@onready var _lbl_user_actions : Label = %LblUserActions


# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _game_prep_timer : float = GAME_PREP_TIME

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	var map : CrawlMap = ResourceLoader.load("user://dungeons/871a756-Area052923.tres")
	if is_instance_of(map, CrawlMap):
		#_local_player_ctrl.map = map
		_team_a_dungeon.map = map
		_team_b_dungeon.map = map
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
			_lbl_prep.text = "%.2f"%[_game_prep_timer]

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func handle_message(msgctx : OT4G_IRC.MessageContext) -> void:
	#if _msg_player_ctrl == null: return
	#_msg_player_ctrl.handle_message(msgctx)
	if _game_command_parser == null: return
	_game_command_parser.handle_message(msgctx)

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_game_command_parser_start_requested(user : OT4G_IRC.UserInfo) -> void:
	if user.username != "obsidianblk":
		print("User ", user.username, " is not the master user!")
		return
	_game_command_parser.set_state(GameCommandParser.STATE.Prep)
	_game_prep_timer = 0.0

func _on_game_prep_complete() -> void:
	if _game_command_parser.get_user_count() <= 0:
		print("No users have joined the game... Pouty face")
		_game_command_parser.set_state(GameCommandParser.STATE.Idle)
		return
	_game_command_parser.set_state(GameCommandParser.STATE.Command)

func _on_game_command_parser_user_joined_team(pid : int, username : String) -> void:
	_lbl_user_actions.text = "%s has joined team %d"%[username, pid]

func _on_game_command_parser_user_left_team(pid : int, username : String) -> void:
	_lbl_user_actions.text = "%s has left team %d"%[username, pid]
