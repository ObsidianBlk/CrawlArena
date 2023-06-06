extends RefCounted
class_name Keyring

# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal service_changed(service_name)
signal cleared()
signal dirtied()

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const KEYRING_TAG : String = "ARENA_KEYRING:1"
const KEYRING_SERVICE_PREFIX : String = "@:"
const KEYRING_KEYVALUE_PREFIX : String = "*:"

const GENERIC_RING_SCHEMA : Dictionary = {
	"!KEY_OF_TYPE_str":{
		"type":TYPE_STRING,
		"def":{
			"type":TYPE_STRING,
			"allow_empty":true
		}
	}
}


# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _key_ring : Dictionary = {}
var _dirty : bool = false

var _registered_schemas : Dictionary = {}

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _LoadRingEntry(file : FileAccess) -> Dictionary:
	var ring : Dictionary = {}
	
	var service : String = file.get_line()
	if service.length() <= KEYRING_SERVICE_PREFIX.length() or not service.begins_with(KEYRING_SERVICE_PREFIX):
		printerr("Keyring load error. Expected service name.")
		return {}
	service = service.right(service.length() - KEYRING_SERVICE_PREFIX.length()).strip_edges()
	if service.is_empty():
		printerr("Keyring load error. Service name is empty.")
		return {}
	ring[service] = {}
	
	var propstr : String = file.get_line()
	var properties : PackedStringArray = propstr.split("&", false)
	if properties.size() <= 0:
		printerr("Keyring load error. Failed to find properties for service \"", service, "\".")
		return {}
	for prop in properties:
		prop = prop.strip_edges()
		if prop.is_empty():
			printerr("Keyring load error. Property field empty for service \"", service, "\".")
			return {}
		ring[service][prop] = null
	
	for _i in range(ring[service].size()):
		var keyval : String = file.get_line().strip_edges()
		if keyval.is_empty():
			printerr("Keyring load error. Failed to load key-value for service \"", service, "\".")
			return {}
		if keyval.length() <= KEYRING_KEYVALUE_PREFIX.length() or not keyval.begins_with(KEYRING_KEYVALUE_PREFIX):
			printerr("Keyring load error. Key-value entry malformed for service \"", service, "\".")
			return {}
		keyval = keyval.right(keyval.length() - KEYRING_KEYVALUE_PREFIX.length())
		var parts : PackedStringArray = keyval.split("=", false)
		if parts.size() != 2:
			printerr("Keyring load error. Key-value entry malformed for service \"", service, "\".")
			return {}
		var key : String = parts[0]
		if not key in ring[service]:
			printerr("Keyring load error. Unknown key \"", key, "\" given for service \"", service, "\".")
			return {}
		ring[service][key] = parts[1]
	
	for key in ring[service].keys():
		if ring[service][key] == null:
			printerr("Keyring load error. Missing expected key \"", key, "\" for service \"", service, "\".")
			return {}
	
	return ring

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func is_dirty() -> bool:
	return _dirty

func clear() -> void:
	_key_ring.clear()
	cleared.emit()


func load(filepath : String, encrypt_passphrase : String = "") -> int:
	if not filepath.is_absolute_path():
		printerr("Absolute path to keyring file required.")
		return ERR_FILE_BAD_PATH
	
	if not FileAccess.file_exists(filepath):
		printerr("No keyring file found.")
		return ERR_FILE_NOT_FOUND
	
	var file : FileAccess = FileAccess.open_encrypted_with_pass(
		filepath, FileAccess.READ, encrypt_passphrase
	)
	if file == null:
		printerr("Failed to open keyring file.")
		return FileAccess.get_open_error()
	
	var tag : String = file.get_line()
	if tag != KEYRING_TAG:
		printerr("Keyring missing identifier tag.")
		file.close()
		return ERR_INVALID_DECLARATION
	
	_dirty = false
	_key_ring.clear()
	var process : bool = true
	while process:
		var ring = _LoadRingEntry(file)
		if ring.is_empty():
			return ERR_INVALID_DATA
		for key in ring.keys():
			_key_ring[key] = ring[key]
			service_changed.emit(key)
		process = not file.eof_reached()
	
	return OK

func save(filepath : String, encrypt_passphrase : String = "") -> int:
	if _key_ring.size() <= 0: return ERR_UNCONFIGURED
	
	var file : FileAccess = FileAccess.open_encrypted_with_pass(
		filepath, FileAccess.WRITE, encrypt_passphrase
	)
	if file == null:
		return FileAccess.get_open_error()
	
	file.store_line(KEYRING_TAG)
	for service in _key_ring.keys():
		file.store_line("%s%s"%[KEYRING_SERVICE_PREFIX, service])
		var keys : String = _key_ring[service].keys().reduce(
			(func(line, item): return item if line.is_empty() else "%s&%s"%[line, item]),
			""
		)
		file.store_line(keys)
		for key in _key_ring[service].keys():
			file.store_line("%s%s=%s"%[KEYRING_KEYVALUE_PREFIX, key, _key_ring[service][key]])
	file.close()
	_dirty = false
	return OK

func register_schema(service_name : String, schema : Dictionary) -> void:
	if schema.is_empty():
		printerr("Keyring service (", service_name, ") schema is empty.")
		return
	_registered_schemas[service_name] = schema

func has_service(service_name : String) -> bool:
	return service_name in _key_ring

func get_services() -> PackedStringArray:
	return PackedStringArray(_key_ring.keys())

func get_service_keys(service_name : String) -> Dictionary:
	var entry : Dictionary = {}
	if service_name in _key_ring:
		for key in _key_ring[service_name].keys():
			entry[key] = _key_ring[service_name][key]
	return entry

func set_service_keys(service_name : String, ring : Dictionary) -> int:
	var schema : Dictionary = GENERIC_RING_SCHEMA
	if service_name in _registered_schemas:
		schema = _registered_schemas[service_name]
	
	var res : int = DSV.verify(ring, schema)
	if res == OK:
		_key_ring[service_name] = ring
		var send_dirty : bool = not _dirty
		_dirty = true
		service_changed.emit(service_name)
		if send_dirty:
			dirtied.emit()
	return res
