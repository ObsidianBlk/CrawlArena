extends Node


# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const DDR_FILE_PATH : String = "user://dungeon_database.tres"
const DUNGEON_FILE_DIRECTORY : String = "user://dungeons/"

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _ddr : DungeonDatabaseResource = null

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	if ResourceLoader.exists(DDR_FILE_PATH):
		_ddr = ResourceLoader.load(DDR_FILE_PATH)
	if _ddr == null:
		_ddr = DungeonDatabaseResource.new()
	
	if not DirAccess.dir_exists_absolute(DUNGEON_FILE_DIRECTORY):
		var err : int = DirAccess.make_dir_recursive_absolute(DUNGEON_FILE_DIRECTORY)
		if not err == OK:
			printerr("ERROR [", err, "]: Failed to create dungeon directory \"", DUNGEON_FILE_DIRECTORY, "\".")

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func get_dungeon_list() -> Array:
	if _ddr == null: return []
	return _ddr.get_list()

func load_dungeon(id : StringName) -> CrawlMap:
	if _ddr == null: return null
	var info : Dictionary = _ddr.get_entry(id)
	if info.is_empty():
		printerr("No dungeon with ID \"", id, "\" found.")
		return null
	
	var map = ResourceLoader.load(info["filepath"])
	if not is_instance_of(map, CrawlMap):
		printerr("Failed to load dungeon ID \"", id, "\".")
		return null
	
	if map.id != id:
		print("WARNING: Dungeon ID mismatch.")
	
	return map

func save_dungeon(map : CrawlMap) -> int:
	if not DirAccess.dir_exists_absolute(DUNGEON_FILE_DIRECTORY):
		return ERR_FILE_BAD_PATH
	if map.id == &"" or map.name.is_empty():
		return ERR_UNCONFIGURED
	
	var filepath : String = ""
	
	var info : Dictionary = _ddr.get_entry(map.id)
	if info.is_empty():
		var filename : String = "%s-%s.tres"%[map.id.substr(0, 7), map.name]
		filename = filename.validate_filename()
		filepath = DUNGEON_FILE_DIRECTORY.path_join(filename)
		
		if FileAccess.file_exists(filepath):
			return ERR_FILE_ALREADY_IN_USE
	else:
		filepath = info["filepath"]
	
	if filepath.is_empty():
		return ERR_CANT_RESOLVE
	
	var err : int = ResourceSaver.save(map, filepath)
	if err == OK:
		_ddr.set_entry(map.id, filepath, map.name)
		ResourceSaver.save(_ddr, DDR_FILE_PATH)
	return err
