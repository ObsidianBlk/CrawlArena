extends Resource
class_name CrawlMRLT

# ------------------------------------------------------------------------------
# Signal
# ------------------------------------------------------------------------------
signal updated()

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const MRLT_META_DATA_SCHEMA : Dictionary = {
	"!ONLY_DEF":false,
	"src":{&"req":true, &"type":TYPE_STRING},
	"description":{&"req":false, &"type":TYPE_STRING, &"allow_empty":true},
	"ui":{&"req":false, &"type":TYPE_STRING}
}

const MRLT_SCHEMA : Dictionary = {
	"!KEY_OF_TYPE_str":{
		&"type":TYPE_STRING,
		&"def":{
			&"type":TYPE_DICTIONARY,
			&"def":{
				"!KEY_OF_TYPE_str":{
					&"type":TYPE_STRING,
					&"def":{
						&"type":TYPE_DICTIONARY, &"def":MRLT_META_DATA_SCHEMA
					}
				}
			}
		}
	}
}

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _data : Dictionary = {}


# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------

func _get(property : StringName) -> Variant:
	match property:
		&"_data":
			return _data
	return null

func _set(property : StringName, value : Variant) -> bool:
	var success : bool = false
	match property:
		&"_rlt":
			if typeof(value) == TYPE_DICTIONARY:
				if DSV.verify(value, MRLT_SCHEMA) == OK:
					success = true
					_data = value
					updated.emit()
	return success

func _get_property_list() -> Array:
	return [
		{
			name = "_data",
			type = TYPE_DICTIONARY,
			usage = PROPERTY_USAGE_STORAGE
		}
	]


# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func register_from_dictionary(rld : Dictionary) -> void:
	# NOTE: This method can only be used on an empty MRLT!
	if not _data.is_empty(): return
	if DSV.verify(rld, MRLT_SCHEMA) == OK:
		_data = rld
		updated.emit()

func register_meta_resource(section : StringName, mr_name : StringName, meta_data : Dictionary) -> void:
	if not section in _data:
		_data[section] = {}
	if mr_name in _data[section]: return
	if DSV.verify(meta_data, MRLT_META_DATA_SCHEMA) != OK:
		printerr("Failed to register resource. Metadata dictionary format invalid.")
		return
	_data[section][mr_name] = meta_data
	updated.emit()

func has_section(section : StringName) -> bool:
	return section in _data

func get_section_count() -> int:
	return _data.keys().size()

func get_section_list() -> PackedStringArray:
	return PackedStringArray(_data.keys())

func has_meta_resource(section : StringName, mr_name : StringName) -> bool:
	if not section in _data: return false
	return mr_name in _data[section]

func get_meta_resource_count(section : StringName) -> int:
	if not section in _data: return 0
	return _data[section].keys().size()

func get_meta_resource_list(section : StringName) -> PackedStringArray:
	if not section in _data: return PackedStringArray([])
	return PackedStringArray(_data[section].keys())

func get_meta_resource_descriptions(section : StringName) -> Array:
	if not section in _data: return []
	var rdesc : Array = []
	for key in _data[section]:
		var item : Dictionary = {"name":key, "section":section, "description":""}
		if "description" in _data[section][key]:
			item["description"] = _data[section][key]["description"]
			rdesc.append(item)
	return rdesc

func get_meta_resource_data(section : StringName, mr_name : StringName) -> Dictionary:
	if not section in _data: return {}
	if not mr_name in _data[section]: return {}
	var data : Dictionary = {}
	for key in _data[section][mr_name].keys():
		data[key] = _data[section][mr_name][key]
	return data

func load_meta_resource(section : StringName, mr_name : StringName, auto_instance_packed_scene : bool = false) -> Variant:
	if not section in _data: return null
	if not mr_name in _data[section]: return null
	
	var mr = ResourceLoader.load(_data[section][mr_name]["src"])
	if mr == null: return null
	
	if is_instance_of(mr, PackedScene) and auto_instance_packed_scene:
		return mr.instantiate()
	
	return mr

func load_meta_resource_ui(section : StringName, mr_name : StringName) -> Control:
	var data : Dictionary = get_meta_resource_data(section, mr_name)
	if data.is_empty(): return null
	if not "ui" in data: return null
	
	var ui = ResourceLoader.load(data["ui"])
	if ui == null: return null
	
	if is_instance_of(ui, PackedScene):
		var ctrl = ui.instantiate()
		if is_instance_of(ctrl, Control):
			return ctrl
	return null
