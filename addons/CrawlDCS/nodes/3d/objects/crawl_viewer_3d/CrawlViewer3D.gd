extends CrawlEntityNode3D

# ------------------------------------------------------------------------------
# Signal
# ------------------------------------------------------------------------------
signal passive_mode_changed(enabled)

# ------------------------------------------------------------------------------
# Export Variables
# ------------------------------------------------------------------------------
@export_category("Crawl Viewer 3D")
@export var current : bool = true:						set = set_current
@export var passive_mode : bool = false:				set = set_passive_move
@export var body_ground_offset : float = 0.2:			set = set_body_ground_offset
@export var camera_height : float = 1.8:				set = set_camera_height
@export var camera_offset : float = 1.4:				set = set_camera_offset


# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
@onready var _gimble : Node3D = $Body/Gimble
@onready var _camera : Camera3D = $Body/Gimble/Camera3D
@onready var _body : Node3D = $Body

@onready var _mesh : MeshInstance3D = $Body/MeshInstance3D




# ------------------------------------------------------------------------------
# Setters
# ------------------------------------------------------------------------------
func set_current(c : bool) -> void:
	if c != current:
		current = c
		if _camera != null and not passive_mode:
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
	_UpdateCameraPositioning()
	_body.position.y = body_ground_offset
	_UpdateViewerPassiveMode()

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _UpdateCameraPositioning() -> void:
	if _gimble == null or _camera == null: return
	_gimble.position.y = camera_height
	_camera.position.z = -camera_offset

func _UpdateViewerPassiveMode() -> void:
	if _camera == null or _mesh == null: return
	_camera.current = false if passive_mode else current
	_mesh.visible = passive_mode
