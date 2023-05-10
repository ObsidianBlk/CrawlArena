extends Resource
class_name DungeonDatabaseResource

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const DUNGEON_FILE_ENTRY_SCHEMA = {
	"id":{"req":true, "type":TYPE_STRING_NAME},
	"filepath":{"req":true, "type":TYPE_STRING},
	"name":{"req":true, "type":TYPE_STRING}
}

# ------------------------------------------------------------------------------
# "Export" Variables
# ------------------------------------------------------------------------------
var _dungeon_list : Array = []

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _get(property : StringName) -> Variant:
	match property:
		"dungeon_list":
			return _dungeon_list
	return null

func _set(property : StringName, value : Variant) -> bool:
	var success : bool = false
	match property:
		"dungeon_list":
			if typeof(value) == TYPE_ARRAY:
				if _DungeonFileArrayValue(value):
					_dungeon_list = value
					success = true
	return success

func _get_property_list() -> Array:
	return [
		{
			name="dungeon_list",
			type=TYPE_ARRAY,
			usage=PROPERTY_USAGE_STORAGE
		}
	]

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _DungeonFileArrayValue(dfa : Array) -> bool:
	if dfa.size() <= 0: return true
	for entry in dfa:
		if not DSV.verify(entry, DUNGEON_FILE_ENTRY_SCHEMA):
			return false
	return true

func _GetIndexFromID(id : StringName) -> int:
	for idx in range(_dungeon_list.size()):
		if _dungeon_list[idx]["id"] == id:
			return idx
	return -1 

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func count() -> int:
	return _dungeon_list.size()

func get_list() -> Array:
	var dfa : Array = []
	for entry in _dungeon_list:
		if not ResourceLoader.exists(entry["filepath"]): continue
		dfa.append({
			"id":entry["id"],
			"filepath":entry["filepath"],
			"name":entry["name"]
		})
	return dfa

func get_entry(id : StringName) -> Dictionary:
	for entry in _dungeon_list:
		if entry["id"] == id:
			return {
				"id":id,
				"filepath":entry["filepath"],
				"name":entry["name"]
			}
	return {}

func set_entry(id : StringName, filepath : String, dungeon_name : String) -> void:
	var entry_idx : int = _GetIndexFromID(id)
	if entry_idx >= 0:
		_dungeon_list[entry_idx]["name"] = dungeon_name
	else:
		_dungeon_list.append({
			"id":id,
			"filepath":filepath,
			"name":dungeon_name
		})

func remove_entry(id : StringName) -> void:
	var entry_idx : int = _GetIndexFromID(id)
	if entry_idx >= 0:
		_dungeon_list.remove_at(entry_idx)

func clean() -> void:
	# The point of this method is to remove entries where the file could not
	#  be found... in case a user removed a dungeon file outside of the application.
	_dungeon_list = get_list()
