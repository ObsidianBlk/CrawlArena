extends RefCounted
class_name GSMCMessage

# ------------------------------------------------------------------------------
# Public Variables
# ------------------------------------------------------------------------------
var text : String = "":					set = set_text
var service : String = "":				set = set_service
var is_whisper : bool = false:			set = set_is_whisper
var user : GSMCUser = null:				set = set_user
var timestamp : int = 0

# ------------------------------------------------------------------------------
# Private Variables
# ------------------------------------------------------------------------------
var _locked : bool = false
var _meta : Dictionary = {}
var _cb : Dictionary = {}

# ------------------------------------------------------------------------------
# Setters
# ------------------------------------------------------------------------------
func set_text(t : String) -> void:
	if not _locked:
		text = t

func set_service(s : String) -> void:
	if not _locked:
		service = s

func set_is_whisper(w : bool) -> void:
	if not _locked:
		is_whisper = w

func set_user(u : GSMCUser) -> void:
	if not _locked:
		user = u

func set_timestamp(t : int) -> void:
	if timestamp <= 0 and t > 0:
		timestamp = t

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _init(service_name : String, usr : GSMCUser, text : String, info : Dictionary = {}) -> void:
	if service_name.is_empty():
		printerr("GSMCMessage Creation Error: Service property cannot be empty.")
		_locked = true
		return
	if usr == null:
		printerr("GSMCMessage Creation Error: User property cannot be null.")
		_locked = true
		return
	service = service_name
	user = usr
	text = text
	
	if "whisper" in info and typeof(info["whisper"]) == TYPE_BOOL:
		is_whisper = info["whisper"]
	if "meta" in info and typeof(info["meta"]) == TYPE_DICTIONARY:
		for key in info["meta"].keys():
			set_metadata(key, info["meta"][key])

	timestamp = int(Time.get_unix_time_from_system())	
	_locked = true


# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func is_valid() -> bool:
	return not service.is_empty()

func set_metadata(key : String, value : Variant) -> void:
	_meta[key] = value

func get_metadata(key : String) -> Variant:
	if key in _meta:
		return _meta[key]
	return null

func has_metadata(key : String) -> bool:
	return key in _meta

