extends RefCounted
class_name GSMCUser


# ------------------------------------------------------------------------------
# Public Variables
# ------------------------------------------------------------------------------
var uid : String = "":					set = set_uid
var service : String = "":				set = set_service
var username : String = "":				set = set_username
var is_owner : bool = false:			set = set_is_owner

# ------------------------------------------------------------------------------
# Private Variables
# ------------------------------------------------------------------------------
var _locked : bool = false
var _meta : Dictionary = {}
var _cb : Dictionary = {}


# ------------------------------------------------------------------------------
# Setters
# ------------------------------------------------------------------------------
func set_uid(id : String) -> void:
	if not _locked:
		uid = id

func set_service(s : String) -> void:
	if not _locked:
		service = s

func set_username(u : String) -> void:
	if not _locked:
		username = u

func set_is_owner(o : bool) -> void:
	if not _locked:
		is_owner = o

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _init(service_name : String, id : String, info : Dictionary = {}) -> void:
	if service_name.is_empty():
		printerr("GSMCUser Creation Error: Service property cannot be empty.")
		_locked = true
		return
	if id.is_empty():
		printerr("GSMCUser Creation Error: User ID property cannot be empty.")
		_locked = true
		return
	service = service_name
	uid = id
	
	if "username" in info and typeof(info["username"]) == TYPE_STRING:
		username = info["username"]
	if "owner" in info and typeof(info["owner"]) == TYPE_BOOL:
		is_owner = info["owner"]
	if "meta" in info and typeof(info["meta"]) == TYPE_DICTIONARY:
		_meta = info["meta"]
	
	for op in ["send", "reply", "whisper"]:
		if op in info and typeof(info[op]) == TYPE_CALLABLE:
			_cb[op] = info[op]
	
	_locked = true


# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func is_valid() -> bool:
	return not (service.is_empty() or uid.is_empty())

func set_metadata(key : String, value : Variant) -> void:
	_meta[key] = value

func get_metadata(key : String) -> Variant:
	if key in _meta:
		return _meta[key]
	return null

func has_metadata(key : String) -> bool:
	return key in _meta

func send(msg : String) -> void:
	if "send" in _cb:
		_cb["send"].call(msg)

func reply(msg : String) -> void:
	if "reply" in _cb:
		_cb["reply"].call(msg)

func whisper(msg : String) -> void:
	if "whisper" in _cb:
		_cb["whisper"].call(msg)
