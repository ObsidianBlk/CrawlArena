extends CrawlEntityNode3D
class_name Player


# ------------------------------------------------------------------------------
# Signal
# ------------------------------------------------------------------------------
signal passive_mode_changed(enabled)

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const META_KEY_COLOR : String = "color"
const META_KEY_PID : String = "player_id"
const META_KEY_ITEM : String = "held_item"
const META_KEY_WEAPON : String = "held_weapon"

# ------------------------------------------------------------------------------
# Export Variables
# ------------------------------------------------------------------------------
@export_category("Player")
@export var current : bool = true:						set = set_current
@export var passive_mode : bool = false:				set = set_passive_move
@export var body_ground_offset : float = 0.2:			set = set_body_ground_offset
@export var camera_height : float = 1.8:				set = set_camera_height
@export var camera_offset : float = 1.4:				set = set_camera_offset


# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _group_name : StringName = &""

# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
@onready var _gimble : Node3D = $Body/Gimble
@onready var _camera : Camera3D = $Body/Gimble/Camera3D
@onready var _body : Node3D = $Body

@onready var _mesh = $Body/MeshInstance3D
@onready var _weapon : Node3D = $Body/ShortSword

# ------------------------------------------------------------------------------
# Setters
# ------------------------------------------------------------------------------
func set_current(c : bool) -> void:
	if c != current:
		current = c
		if _camera != null:
			_camera.current = current

func set_passive_move(p : bool) -> void:
	if p != passive_mode:
		passive_mode = p
		_UpdateViewerPassiveMode()
		passive_mode_changed.emit(passive_mode)
		

func set_body_ground_offset(o : float) -> void:
	if o != body_ground_offset:
		body_ground_offset = o
		if _body != null:
			_body.position.y = body_ground_offset

func set_camera_height(h : float) -> void:
	if h > 0.0 and h != camera_height:
		camera_height = h
		_UpdateCameraPositioning()

func set_camera_offset(o : float) -> void:
	if o > 0.0 and o != camera_offset:
		camera_offset = o
		_UpdateCameraPositioning()

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	transition_started.connect(_on_player_transition_started)
	transition_complete.connect(_on_player_transition_complete)
	entity_changing.connect(_on_player_entity_changing)
	entity_changed.connect(_on_player_entity_changed)
	_on_player_entity_changed()
	#_UpdateCameraPositioning()
	#_UpdateViewerPassiveMode()
	if _body != null:
		_body.position.y = body_ground_offset

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _UpdateMeshColor(color : Color) -> void:
	if _mesh != null:
		_mesh.set_instance_shader_parameter("color", color)


func _UpdateCameraPositioning() -> void:
	if _gimble == null or _camera == null: return
	_gimble.position.y = camera_height
	_camera.position.z = -camera_offset

func _UpdateViewerPassiveMode() -> void:
	if _camera == null or _mesh == null: return
	_camera.current = false if passive_mode else current
	_mesh.visible = passive_mode

func _HandleAttack() -> void:
	if current:
		entity.schedule_start()
	_weapon.change_state(&"attack")
	await _weapon.animation_complete
	_weapon.change_state(&"idle")
	if current:
		entity.schedule_end()

func _GetNameString() -> String:
	# NOTE: This method is for information during debugging... at least at the moment.
	if entity != null:
		return "Player-%s (%s)"%[entity.get_meta_value(META_KEY_PID, 0), self]
	return "NONE"

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_player_entity_changing() -> void:
	if entity == null: return
	
	if _group_name != &"":
		remove_from_group(_group_name)
		_group_name = &""
	
	if entity.meta_value_changed.is_connected(_on_player_entity_meta_value_changed):
		entity.meta_value_changed.disconnect(_on_player_entity_meta_value_changed)
	if entity.meta_value_removed.is_connected(_on_player_entity_meta_value_removed):
		entity.meta_value_removed.disconnect(_on_player_entity_meta_value_removed)
	if entity.attacked.is_connected(_on_player_attacked):
		entity.attacked.disconnect(_on_player_attacked)

func _on_player_entity_changed() -> void:
	if entity == null: return
	if not entity.meta_value_changed.is_connected(_on_player_entity_meta_value_changed):
		entity.meta_value_changed.connect(_on_player_entity_meta_value_changed)
	if not entity.meta_value_removed.is_connected(_on_player_entity_meta_value_removed):
		entity.meta_value_removed.connect(_on_player_entity_meta_value_removed)
	if not entity.attacked.is_connected(_on_player_attacked):
		entity.attacked.connect(_on_player_attacked)
	
	_on_player_entity_meta_value_changed(META_KEY_PID)
	_on_player_entity_meta_value_changed(META_KEY_COLOR)

func _on_player_entity_meta_value_changed(key : String) -> void:
	if entity == null or _mesh == null: return
	match key:
		META_KEY_COLOR:
			var value = entity.get_meta_value(key, Color.WHITE)
			if typeof(value) == TYPE_COLOR:
				_mesh.set_instance_shader_parameter("color", value)
		META_KEY_PID:
			var value = entity.get_meta_value(key, 0)
			if _group_name != &"":
				remove_from_group(_group_name)
				_group_name = &""
			_group_name = StringName("Player_%s"%[entity.get_meta_value(META_KEY_PID, 0)])
			add_to_group(_group_name)
		META_KEY_ITEM:
			# Nothing to animate for picked up items
			entity.schedule_end()
		META_KEY_WEAPON:
			# Don't know what to do yet!
			entity.schedule_end()
			

func _on_player_entity_meta_value_removed(key : String) -> void:
	if entity == null: return
	match key:
		META_KEY_ITEM:
			# Nothing to animate for picked up items
			entity.schedule_end()
		META_KEY_WEAPON:
			# Don't know what to do yet!
			entity.schedule_end()

func _on_player_transition_started(_dir : StringName) -> void:
	if current:
		entity.schedule_start()
	_weapon.change_state(&"moving")

func _on_player_transition_complete() -> void:
	_weapon.change_state(&"idle")
	if current:
		entity.schedule_end()

func _on_player_attacked(info : Dictionary) -> void:
	_HandleAttack.call_deferred()
