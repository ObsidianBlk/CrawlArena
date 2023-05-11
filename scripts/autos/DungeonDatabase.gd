extends Node


# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal dungeon_entry_updated(id)
signal dungeon_entry_removed(id)

signal dungeon_file_saved(filepath)
signal dungeon_file_removed(filepath)

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
func count() -> int:
	if _ddr == null: return 0
	return _ddr.count()

func get_dungeon_list() -> Array:
	if _ddr == null: return []
	return _ddr.get_list()

func get_dungeon_info(id : StringName) -> Dictionary:
	if _ddr == null: return {}
	return _ddr.get_entry(id)

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
	if _ddr == null: return ERR_DATABASE_CANT_READ
	if not DirAccess.dir_exists_absolute(DUNGEON_FILE_DIRECTORY):
		return ERR_FILE_BAD_PATH
	if map.id == &"" or map.name.is_empty():
		return ERR_UNCONFIGURED
	
	var filename : String = "%s-%s.tres"%[map.id.substr(0, 7), map.name]
	filename = filename.validate_filename()
	var filepath : String = DUNGEON_FILE_DIRECTORY.path_join(filename)
	
	var info : Dictionary = _ddr.get_entry(map.id)
	if info.is_empty():
		if FileAccess.file_exists(filepath):
			return ERR_FILE_ALREADY_IN_USE
	else:
		if info["filepath"] != filepath and FileAccess.file_exists(info["filepath"]):
			var err : int = DirAccess.remove_absolute(info["filepath"])
			if err == OK:
				dungeon_file_removed.emit(info["filepath"])
	
	if filepath.is_empty():
		return ERR_CANT_RESOLVE
	
	var err : int = ResourceSaver.save(map, filepath)
	if err == OK:
		dungeon_file_saved.emit(filepath)
		_ddr.set_entry(map.id, filepath, map.name)
		dungeon_entry_updated.emit(map.id)
		err = ResourceSaver.save(_ddr, DDR_FILE_PATH)
	return err


func delete_dungeon(id : StringName) -> int:
	if _ddr == null: return ERR_DATABASE_CANT_READ
	var info : Dictionary = _ddr.get_entry(id)
	if info.is_empty():
		return ERR_CANT_ACQUIRE_RESOURCE
	
	var err : int = OK
	if not FileAccess.file_exists(info["filepath"]):
		print("WARNING: Dungeon entry ID \"", id, "\" filepath missing (", info["filepath"], "). Removing database entry.")
		err = ERR_FILE_NOT_FOUND
	else:
		err = DirAccess.remove_absolute(info["filepath"])
		if err != OK:
			return err # File may still be on the system. Want to try not to keep dangling files if possible.
		dungeon_entry_removed.emit(info["filepath"])
	
	_ddr.remove_entry(id)
	dungeon_entry_removed.emit(id)
	
	return err
