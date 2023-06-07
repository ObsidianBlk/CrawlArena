extends Node


# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _users : Dictionary = {}

var _user_message_buffer_size : int = 10
var _user_idle_time : float = 3600.0 # This is 1 hour
var _user_idle_check_interval : float = 6.0
var _idle_timer_active : bool = false

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	_RunTimer()

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _CleanUsers() -> void:
	if _user_idle_time <= 0: return
	var now : float = Time.get_unix_time_from_system()
	for service_name in _users.keys():
		for uid in _users[service_name].keys():
			if _users[service_name][uid]["user"].is_owner: continue
			if now - _users[service_name][uid]["last_active"] >= _user_idle_time:
				_users[service_name].erase(uid)
		if _users[service_name].size() <= 0:
			_users.erase(service_name)

func _RunTimer() -> void:
	if _idle_timer_active: return
	if _user_idle_time <= 0 or _user_idle_check_interval <= 0: return
	_idle_timer_active = true
	get_tree().create_timer(_idle_timer_active).timeout.connect(_on_idle_timer_timeout)

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func set_message_buffer_size(size : int) -> void:
	if size >= 0:
		_user_message_buffer_size = size

func get_message_buffer_size() -> int:
	return _user_message_buffer_size

func set_user_idle_time(t : float) -> void:
	if t >= 0.0:
		_user_idle_time = t
	_RunTimer()

func get_user_idle_time() -> float:
	return _user_idle_time

func set_user_idle_check_interval(i : float) -> void:
	if i >= 0.0:
		_user_idle_check_interval = i
	_RunTimer()

func get_user_idle_check_interval() -> float:
	return _user_idle_check_interval

func store_message(service_name : String, uid : String, text : String, info : Dictionary = {}) -> GSMCMessage:
	if not service_name in _users:
		printerr("GSMC Error: Failed to store message. No users for service \"", service_name, "\" in system.")
		return null
	if not uid in _users[service_name]:
		printerr("GSMC Error: Failed to store message. Given user ID not stored in system.")
		return null
	
	var user : GSMCUser = get_user(service_name, uid)
	var msg : GSMCMessage = GSMCMessage.new(service_name, user, text, info)
	_users[service_name][uid]["messages"].append(msg)
	if _users[service_name][uid]["messages"].size() > _user_message_buffer_size:
		_users[service_name][uid]["messages"].pop_front()
	_users[service_name][uid]["last_active"] = Time.get_unix_time_from_system()
	return msg

func store_user(service_name : String, uid : String, info : Dictionary = {}) -> GSMCUser:
	if has_user(service_name, uid):
		print("WARNING: Attempting to store a user that is already in system. Using exiting user object.")
		return get_user(service_name, uid)
	
	var user : GSMCUser = GSMCUser.new(service_name, uid, info)
	if not service_name in _users:
		_users[service_name] = {}
	_users[service_name][uid] = {
		"user":user,
		"messages":[],
		"last_active": Time.get_unix_time_from_system()
	}
	return user

func has_user(service_name : String, uid : String) -> bool:
	if not service_name in _users: return false
	return uid in _users[service_name]

func is_user_stored(user : GSMCUser) -> bool:
	if user == null: return false
	if not user.is_valid(): return false
	return has_user(user.service, user.uid)

func get_user(service_name : String, uid : String) -> GSMCUser:
	if not has_user(service_name, uid): return null
	return _users[service_name][uid]["user"]

func get_user_buffer_size(user : GSMCUser) -> int:
	if not is_user_stored(user): return 0
	return _users[user.service][user.uid]["messages"].size()

func get_user_last_message(user : GSMCUser) -> GSMCMessage:
	if not is_user_stored(user): return null
	if _users[user.service][user.uid]["messages"].size() > 0:
		return _users[user.service][user.uid]["messages"][-1]
	return null

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_idle_timer_timeout() -> void:
	_idle_timer_active = false
	if _user_idle_time > 0.0 and _user_idle_check_interval > 0.0:
		_CleanUsers()
		_RunTimer()
