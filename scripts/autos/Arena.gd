extends Node

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const LOOKUPTABLE_LEVEL_GEOMETRY : StringName = &"level_geometry"
const LOOKUPTABLE_ENTITIES : StringName = &"entities"

const KEYRING_TAG : String = "ARENA_KEYRING:1"
const KEYRING_SERVICE_PREFIX : String = "@:"
# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _key_ring : Dictionary = {}

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	_DefineLevelResources()
	_DefineEntityResources()

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _DefineLevelResources() -> void:
	if Crawl.has_lookup_table(LOOKUPTABLE_LEVEL_GEOMETRY): return
	
	var lglt : CrawlMRLT = CrawlMRLT.new()
	lglt.register_from_dictionary({
		"ground":{
			"default":{
				"src":"res://assets/models/Default/Ground.glb",
				"description":"A basic ground floor. Nothing Special."
			},
			"Cobble Blood 01":{
				"src":"res://assets/models/Dungeon_01/Ground/Cobble_Blood_01.glb",
				"description": "Cobblestone ground."
			}
		},
		"ceiling":{
			"default":{
				"src":"res://assets/models/Default/Ceiling.glb",
				"description":"A basic ceiling. Nothing to see here."
			},
			"Tomb 0":{
				"src":"res://assets/models/Dungeon_01/Ceiling/Tomb_01.glb",
				"description":"Tomb ceiling."
			}
		},
		"wall":{
			"default":{
				"src":"res://assets/models/Default/Wall.glb",
				"description":"A basic wall. Don't walk into it."
			},
			"Catacombs 0":{
				"src":"res://assets/models/Dungeon_01/Walls/Catacombs_0.glb",
				"description":"Catacomb wall."
			}
		}
	})
	Crawl.store_lookup_table(LOOKUPTABLE_LEVEL_GEOMETRY, lglt)


func _DefineEntityResources() -> void:
	if Crawl.has_lookup_table(LOOKUPTABLE_ENTITIES): return
	
	var elt : CrawlMRLT = CrawlMRLT.new()
	elt.register_from_dictionary({
		"unique":{
			"editor":{
				"src":"res://addons/CrawlDCS/nodes/3d/objects/crawl_viewer_3d/CrawlViewer3D.tscn",
				"description":"Dungeon Editor"
			},
			"player":{
				"src":"res://entities/player/Player.tscn",
				"description":"Dungeon Player",
				"ui":"res://entities/player/ui/PlayerEntityUI.tscn"
			}
		}
	})
	Crawl.store_lookup_table(LOOKUPTABLE_ENTITIES, elt)

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
		ring[service][prop] = ""
	
	for _i in range(ring[service].size()):
		pass # TODO: Finish this!!
	return ring

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func load_keyring(filepath : String, encrypt_passphrase : String = "") -> int:
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
	
	var service : String = ""
	var ring : Dictionary = {}
	while not file.eof_reached():
		if service == "":
			service = file.get_line()
			ring.clear()
	
	return OK



