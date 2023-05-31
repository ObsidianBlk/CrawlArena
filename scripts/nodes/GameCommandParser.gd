extends Node
class_name GameCommandParser


# --------------------------------------------------------------------------------------
# Signals
# --------------------------------------------------------------------------------------
signal player_action_requested(pid, action_code)

# --------------------------------------------------------------------------------------
# Constants and ENUMs
# --------------------------------------------------------------------------------------
enum STATE {Prep=0, Command=1, Process=2}
const ACTION_DELAY : float = 0.8

# --------------------------------------------------------------------------------------
# Export Variables
# --------------------------------------------------------------------------------------
@export_category("Game Command Parser")
@export var command_prefix : String = "!"
@export var max_actions_per_round : int = 5

# --------------------------------------------------------------------------------------
# Variables
# --------------------------------------------------------------------------------------
var _players : Dictionary = {}
var _teams : Dictionary = {
	"A":{"list":[], "active_idx":0, "buffer":[]},
	"B":{"list":[], "active_idx":0, "buffer":[]}
}

var _active_team : String = "A"

var _game_state : STATE = STATE.Prep

# --------------------------------------------------------------------------------------
# Private Methods
# --------------------------------------------------------------------------------------
func _RemoveUserFromTeam(user : OT4G_IRC.UserInfo, team : String) -> void:
	var idx : int = _teams[team].list.find(user.username)
	if idx < 0: return
	_players.erase(user.username)
	_teams[team].list.remove_at(idx)
	if _teams[team].active_idx >= idx:
		if _teams[team].active_idx > idx:
			_teams[team].active_idx -= 1
		elif _teams[team].active_idx >= _teams[team].list.size():
			_teams[team].active_idx = 0
		# TODO: Announce to the next user/player that they are now the active player.
	print("Removed \"", user.username, "\" from team \"", team, "\".")

func _NextTeamPlayer(team : String) -> void:
	_teams[team].active_idx += 1
	if _teams[team].active_idx >= _teams[team].list.size():
		_teams[team].active_idx = 0
	var username : String = _teams[team].list[_teams[team].active_idx]
	if not username in _players:
		printerr("Failed to find user ", username)
		return
	# TODO: Instead return the user name of the next player so that both teams' players are announced
	#   in the same message
	_players[username].user.mention("... it is now your turn!")


func _Handle_Join(user : OT4G_IRC.UserInfo, payload : String) -> void:
	if user.username in _players:
		user.mention("You've already joined. You're on team %s"%[_players[user.username]["team_id"]])
		return
	
	var add_to_team : Callable = func(team : String) -> void:
		_players[user.username] = {"team_id":team, "user":user}
		_teams[team].list.append(user.username)
		print("\"", user.username, "\" has joined team \"", team, "\"!")
		user.mention("has been added to team %s!"%[team])
	
	match payload.to_upper():
		"A":
			add_to_team.call("A")
		"B":
			add_to_team.call("B")
		_:
			if _teams["A"].list.size() < _teams["B"].list.size():
				add_to_team.call("A")
			elif _teams["B"].list.size() < _teams["A"].list.size():
				add_to_team.call("B")
			else:
				add_to_team.call("A" if randi_range(0, 1000) > 500 else "B")


func _Handle_Leave(user : OT4G_IRC.UserInfo) -> void:
	_RemoveUserFromTeam(user, "A")
	_RemoveUserFromTeam(user, "B")


func _Handle_Actions(user : OT4G_IRC.UserInfo, payload : String) -> void:
	var team : Dictionary = _teams[_active_team]
	if not team.list[team.active_idx] == user.username: return
	if team.buffer.size() > 0:
		user.mention("you have already sent in your commands.")
		return
	
	if payload.length() > max_actions_per_round:
		payload = payload.left(max_actions_per_round)
	
	for i in range(max_actions_per_round):
		var act : String = ""
		if i < payload.length():
			act = payload.substr(i, 1)
		team.buffer.append(act)

func _ProcessGame() -> void:
	var team : Dictionary = _teams[_active_team]
	if team.buffer.size() <= 0:
		_NextTeamPlayer("A")
		_NextTeamPlayer("B")
		set_game_state(STATE.Command)
		return
	
	var action : String = team.buffer.pop_front()
	player_action_requested.emit(1 if _active_team == "A" else 2, action)
	_active_team = "A" if _active_team == "B" else "B"
	await get_tree().create_timer(ACTION_DELAY).timeout
	_ProcessGame()

# --------------------------------------------------------------------------------------
# Public Methods
# --------------------------------------------------------------------------------------
func set_game_state(state : STATE) -> void:
	_game_state = state
	if _game_state == STATE.Process:
		_ProcessGame()


func handle_message(msgctx : OT4G_IRC.MessageContext) -> void:
	if not msgctx.message.begins_with(command_prefix): return
	var parts : PackedStringArray = msgctx.message.split(":", true, 1)
	var cmd = StringName(parts[0].strip_edges())
	var payload = "" if parts.size() < 2 else parts[2].strip_edges()
	
	match _game_state:
		STATE.Prep:
			match cmd:
				&"!join", &"!j":
					_Handle_Join(msgctx.user, payload)
				&"!leave", &"!x":
					_Handle_Leave(msgctx.user)
		STATE.Command:
			match cmd:
				&"!leave", &"!x":
					_Handle_Leave(msgctx.user)
				&"!actions", &"!a":
					_Handle_Actions(msgctx.user, payload)
		STATE.Process:
			match cmd:
				&"!leave", &"!x":
					_Handle_Leave(msgctx.user)

