extends Node
class_name GameCommandParser


# --------------------------------------------------------------------------------------
# Signals
# --------------------------------------------------------------------------------------
signal player_action_requested(pid, action_code)
signal start_requested(user)
signal user_joined_team(pid, username)
signal user_left_team(pid, username)
signal user_submitted_actions(pid, username)
signal user_turn_active(pid, username)
signal game_preparing()
signal action_processing_completed()

# --------------------------------------------------------------------------------------
# Constants and ENUMs
# --------------------------------------------------------------------------------------
enum STATE {Idle=0, Prep=1, Command=2, Process=3}

# --------------------------------------------------------------------------------------
# Export Variables
# --------------------------------------------------------------------------------------
@export_category("Game Command Parser")
@export var command_prefix : String = "!"
@export var max_actions_per_round : int = 5

# --------------------------------------------------------------------------------------
# Variables
# --------------------------------------------------------------------------------------
var _users : Dictionary = {}
var _idle_users : Dictionary = {}
var _teams : Dictionary = {
	"A":{"list":[], "active_idx":0, "buffer":[]},
	"B":{"list":[], "active_idx":0, "buffer":[]}
}

var _active_team : String = "A"

var _game_state : STATE = STATE.Idle

# --------------------------------------------------------------------------------------
# Override Methods
# --------------------------------------------------------------------------------------
func _ready() -> void:
	GSMC.user_active.connect(_on_GSMC_user_active)
	GSMC.user_inactive.connect(_on_GSMC_user_inactive)
	GSMC.user_dropped.connect(_on_GSMC_user_dropped)

# --------------------------------------------------------------------------------------
# Private Methods
# --------------------------------------------------------------------------------------
func _RemoveUserFromTeam(user : GSMCUser, team : String) -> void:
	var idx : int = _teams[team].list.find(user.full_uid)
	if idx < 0: return
	_teams[team].list.remove_at(idx)
	if _teams[team].active_idx >= idx:
		if _teams[team].active_idx > idx:
			_teams[team].active_idx -= 1
		elif _teams[team].active_idx >= _teams[team].list.size():
			_teams[team].active_idx = 0
		# TODO: Announce to the next user/player that they are now the active player.
	print("Removed \"", user.username, "\" from team \"", team, "\".")
	user_left_team.emit(1 if team == "A" else 2, user.username)

func _NextTeamUser(team : String) -> void:
	_teams[team].active_idx += 1
	if _teams[team].active_idx >= _teams[team].list.size():
		_teams[team].active_idx = 0

func _AnnounceActiveTeamPlayer(team : String) -> void:
	var idx : int = _teams[team].active_idx
	if not (idx >= 0 and idx < _teams[team].list.size()): return
	var full_uid : String = _teams[team].list[idx]
	if not full_uid in _users:
		printerr("Failed to find user ", full_uid)
		return
	var username : String = _users[full_uid].user.username
	_users[full_uid].user.send("%s... it is now your turn!"%[username])
	user_turn_active.emit(1 if team == "A" else 2, username)

func _TeamBuffersEmpty() -> bool:
	return _teams["A"].buffer.size() <= 0 and _teams["B"].buffer.size() <= 0


func _ProcessNextAction() -> void:
	var team : Dictionary = _teams[_active_team]
	if _TeamBuffersEmpty():
		_NextTeamUser("A")
		_NextTeamUser("B")
		action_processing_completed.emit()
		return
	if team.buffer.size() <= 0:
		_active_team = "A" if _active_team == "B" else "B"
		return
	
	var action : String = team.buffer.pop_front()
	var ateam : String = _active_team
	_active_team = "A" if _active_team == "B" else "B"
	player_action_requested.emit(1 if ateam == "A" else 2, action)

func _Handle_Join(user : GSMCUser, payload : String) -> void:
	if user.full_uid in _users:
		user.reply("You've already joined. You're on team %s"%[_users[user.full_uid]["team_id"]])
		return
	
	var add_to_team : Callable = func(team : String) -> void:
		_users[user.full_uid] = {"team_id":team, "user":user}
		_teams[team].list.append(user.full_uid)
		print("\"", user.username, "\" has joined team \"", team, "\"!")
		user.reply("has been added to team %s!"%[team])
		user_joined_team.emit(1 if team == "A" else 2, user.username)
	
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


func _Handle_Leave(user : GSMCUser) -> void:
	if not user.full_uid in _users: return
	var team : String = _users[user.full_uid]["team_id"]
	_RemoveUserFromTeam(user, team)
	_users.erase(user.full_uid)

func _Handle_Clear_Team(team : String) -> void:
	_teams[team].list.clear()
	_teams[team].buffer.clear()
	_teams[team].active_idx = 0


func _Handle_Team_Rand_Actions(team : String) -> void:
	if _teams[team].buffer.size() > 0: return
	var rand_ops : Array = ["w", "a", "s", "d", "q", "e"]
	for i in range(max_actions_per_round):
		var idx : int = randi_range(0, rand_ops.size() - 1)
		_teams[team].buffer.append(rand_ops[idx])

func _Handle_Actions(user : GSMCUser, payload : String) -> void:
	if not user.full_uid in _users: return
	var user_team : String = _users[user.full_uid]["team_id"]
	
	var team : Dictionary = _teams[user_team]
	if team.list[team.active_idx] != user.full_uid: return
	if team.buffer.size() > 0:
		user.reply("you have already sent in your commands.")
		return
	
	if payload.length() > max_actions_per_round:
		payload = payload.left(max_actions_per_round)
	
	for i in range(max_actions_per_round):
		var act : String = ""
		if i < payload.length():
			act = payload.substr(i, 1)
		else:
			var rand_ops : Array = ["w", "a", "s", "d", "q", "e"]
			var idx : int = randi_range(0, rand_ops.size() - 1)
			act = rand_ops[idx]
		team.buffer.append(act)
	user_submitted_actions.emit(1 if user_team == "A" else 2, user.username)

# --------------------------------------------------------------------------------------
# Public Methods
# --------------------------------------------------------------------------------------
func set_state(state : STATE) -> void:
	if state == _game_state: return
	_game_state = state
	if _game_state == STATE.Idle:
		_Handle_Clear_Team("A")
		_Handle_Clear_Team("B")
	if _game_state == STATE.Prep:
		game_preparing.emit()
	if _game_state == STATE.Command:
		_AnnounceActiveTeamPlayer("A")
		_AnnounceActiveTeamPlayer("B")
	if _game_state == STATE.Process:
		_Handle_Team_Rand_Actions("A")
		_Handle_Team_Rand_Actions("B")
		_ProcessNextAction()

func get_user_count() -> int:
	return _users.keys().size()

func get_team_user_count(pid : int) -> int:
	var team = "A" if pid == 1 else "B"
	return _teams[team].list.size()

func handle_message(msgctx : GSMCMessage) -> void:
	if not msgctx.text.begins_with(command_prefix): return
	var parts : PackedStringArray = msgctx.text.split(" ", true, 1)
	
	var cmd = StringName(parts[0].right(parts[0].length() - command_prefix.length()).strip_edges())
	var payload : String = "" if parts.size() < 2 else parts[1].strip_edges()
	
	match _game_state:
		STATE.Idle:
			match cmd:
				&"start_game":
					start_requested.emit(msgctx.user)
		STATE.Prep:
			match cmd:
				&"join", &"j":
					_Handle_Join(msgctx.user, payload)
				&"leave", &"x":
					_Handle_Leave(msgctx.user)
		STATE.Command:
			match cmd:
				&"join", &"j":
					_Handle_Join(msgctx.user, payload)
				&"leave", &"x":
					_Handle_Leave(msgctx.user)
				&"actions", &"a":
					_Handle_Actions(msgctx.user, payload)
		STATE.Process:
			match cmd:
				&"join", &"j":
					_Handle_Join(msgctx.user, payload)
				&"leave", &"x":
					_Handle_Leave(msgctx.user)

# --------------------------------------------------------------------------------------
# Handler Methods
# --------------------------------------------------------------------------------------
func _on_GSMC_user_active(user : GSMCUser) -> void:
	if not user.full_uid in _idle_users: return
	var team : String = _idle_users[user.full_uid]["team_id"]
	_idle_users.erase(user.full_uid)
	_Handle_Join(user, team)

func _on_GSMC_user_inactive(user : GSMCUser) -> void:
	if not user.full_uid in _users: return
	var team : String = _users[user.full_uid]["team_id"]
	_RemoveUserFromTeam(user, team)
	_users.erase(user.full_uid)
	_idle_users[user.full_uid] = {"team_id":team, "user":user}

func _on_GSMC_user_dropped(user : GSMCUser) -> void:
	if user.full_uid in _idle_users:
		_idle_users.erase(user.full_uid)
	elif user.full_uid in _users:
		_Handle_Leave(user)

func _on_action_processed() -> void:
	if _game_state != STATE.Process: return
	_ProcessNextAction()
