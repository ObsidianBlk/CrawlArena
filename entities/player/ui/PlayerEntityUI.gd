extends Control


# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const META_KEY_COLOR : String = "color"
const META_KEY_PID : String = "player_id"

const MIN_PID : int = 1
const MAX_PID : int = 10
const DEFAULT_PID : int = 1

# ------------------------------------------------------------------------------
# Export Variables
# ------------------------------------------------------------------------------
@export var entity : CrawlEntity = null:			set = set_entity

# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
@onready var _sbox_player_id : SpinBox = %SBoxPlayerID
@onready var _color_picker : Control = %ColorPicker



# ------------------------------------------------------------------------------
# Setters
# ------------------------------------------------------------------------------
func set_entity(e : CrawlEntity) -> void:
	if e == entity: return
	if entity != null:
		if entity.meta_value_changed.is_connected(_on_entity_meta_value_changed):
			entity.meta_value_changed.disconnect(_on_entity_meta_value_changed)
	entity = e
	if entity != null:
		if not entity.has_meta_key(META_KEY_COLOR):
			print("Entity ", entity.entity_name, " does not have meta-key ", META_KEY_COLOR)
			entity.set_meta_value(META_KEY_COLOR, _color_picker.color)
		if not entity.has_meta_key(META_KEY_PID):
			print("Entity ", entity.entity_name, " does not have meta-key ", META_KEY_PID)
			entity.set_meta_value(META_KEY_PID, DEFAULT_PID)
		
		if not entity.meta_value_changed.is_connected(_on_entity_meta_value_changed):
			entity.meta_value_changed.connect(_on_entity_meta_value_changed)
		
		_sbox_player_id.value = entity.get_meta_value(META_KEY_PID, DEFAULT_PID)
		_color_picker.color = entity.get_meta_value(META_KEY_COLOR, Color.WHITE)

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_entity_meta_value_changed(key : String) -> void:
	if entity == null: return
	match key:
		META_KEY_COLOR:
			_color_picker.color = entity.get_meta_value(key, Color.WHITE)
		META_KEY_PID:
			var epid : int = entity.get_meta_value(key, DEFAULT_PID)
			if epid >= MIN_PID and epid <= MAX_PID:
				_sbox_player_id.value = epid


func _on_color_picker_changed(color : Color) -> void:
	if entity == null: return
	entity.set_meta_value(META_KEY_COLOR, color)


func _on_sbox_player_id_value_changed(value : float) -> void:
	if entity == null: return
	entity.set_meta_value(META_KEY_PID, int(value))
