@tool
extends Control


# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal pressed()

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const DEFAULT_THEME_TYPE : StringName = &"ResourceView3DControl"
const THEME_STYLE_NORMAL : StringName = &"normal"
const THEME_STYLE_FOCUS : StringName = &"focus"
const THEME_STYLE_HOVER : StringName = &"hover"
const THEME_STYLE_PRESS : StringName = &"press"

# ------------------------------------------------------------------------------
# Export Variables
# ------------------------------------------------------------------------------
@export_category("Resource View 3D Control")
@export_group("Resource")
@export var lookup_table_name : StringName = &"":							set = set_lookup_table_name
@export var resource_section : StringName = &"":							set = set_resource_section
@export var resource_name : StringName = &"":								set = set_resource_name
@export var resource_position : Vector3 = Vector3.ZERO:						set = set_resource_position
@export_group("Sizing")
@export var view_size : int = 32:											set = set_view_size
@export_group("Lighting")
@export_range(-90.0, 90.0, 0.1) var light_angle_degrees : float = 0.0:		set = set_light_angle_degrees
@export_group("Camera")
@export var camera_height : float = 1.0:									set = set_camera_height
@export_range(-90.0, 90.0, 0.1) var camera_pitch_degrees : float = 0.0:		set = set_camera_pitch_degrees
@export var camera_zoom : float = 2.0:										set = set_camera_zoom
@export_group("Animation")
@export var enable_seesaw : bool = true:									set = set_enable_seesaw
@export_range(0.0, 180.0, 0.1) var arc_degrees : float = 90.0:				set = set_arc_degrees
@export var duration : float = 2.0:											set = set_duration

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _press_active : bool = false
var _mouse_entered : bool = false
var _focus_active : bool = false

var _anim_active : bool = false

var _resource_node : Node3D = null

# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
@onready var _cpanel : PanelContainer = %CPanel
@onready var _sub_viewport : SubViewport = %SubViewport
@onready var _camera : Camera3D = %Camera3D
@onready var _gimble : Node3D = %Gimble
@onready var _pitch : Node3D = %Pitch
@onready var _sun : DirectionalLight3D = %Sun

# ------------------------------------------------------------------------------
# Setters
# ------------------------------------------------------------------------------
func set_lookup_table_name(ltn : StringName) -> void:
	if ltn != lookup_table_name:
		lookup_table_name = ltn
		_UpdateResourceNode()

func set_resource_section(rs : StringName) -> void:
	if rs != resource_section:
		resource_section = rs
		_UpdateResourceNode()

func set_resource_name(rn : StringName) -> void:
	if rn != resource_name:
		resource_name = rn
		_UpdateResourceNode()

func set_resource_position(rp : Vector3) -> void:
	resource_position = rp
	if _resource_node != null:
		_resource_node.position = resource_position

func set_view_size(s : int) -> void:
	if s > 0 and s != view_size:
		view_size = s
		_UpdatePanelSize()

func set_light_angle_degrees(d : float) -> void:
	if d >= -90.0 and d <= 90.0:
		light_angle_degrees = d
		if _sun != null:
			_sun.rotation_degrees.x = light_angle_degrees

func set_camera_height(h : float) -> void:
	if h != camera_height:
		camera_height = h
		_UpdateCameraPlacement()

func set_camera_pitch_degrees(p : float) -> void:
	if p >= -90.0 and p <= 90.0 and p != camera_pitch_degrees:
		camera_pitch_degrees = p
		_UpdateCameraPlacement()

func set_camera_zoom(z : float) -> void:
	if z >= 0.0 and z != camera_zoom:
		camera_zoom = z
		_UpdateCameraPlacement()

func set_enable_seesaw(e : bool) -> void:
	if e != enable_seesaw:
		enable_seesaw = e
		if enable_seesaw:
			_AnimCamera()

func set_arc_degrees(d : float) -> void:
	if d >= 0.0 and d <= 180.0 and d != arc_degrees:
		arc_degrees = d

func set_duration(d : float) -> void:
	if d >= 0.0 and d != duration:
		duration = d

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	set_light_angle_degrees(light_angle_degrees)
	_UpdatePanelStyle()
	_UpdatePanelSize()
	_UpdateCameraPlacement()
	_UpdateResourceNode()
	if enable_seesaw:
		_AnimCamera()

func _gui_input(event : InputEvent) -> void:
	if _mouse_entered and is_instance_of(event, InputEventMouseButton):
		if event.button_index == MOUSE_BUTTON_LEFT:
			_press_active = event.is_pressed()
			_UpdatePanelStyle.call_deferred()
			if _press_active:
				pressed.emit()
			accept_event()
	elif _focus_active:
		if event.is_action_pressed("ui_accept"):
			_press_active = true
			_UpdatePanelStyle()
			pressed.emit()
			accept_event()
		elif event.is_action_released("ui_accept"):
			_press_active = false
			_UpdatePanelStyle()
			accept_event()

func _notification(what : int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			_mouse_entered = true
			_UpdatePanelStyle()
		NOTIFICATION_MOUSE_EXIT:
			_mouse_entered = false
			_UpdatePanelStyle()
		NOTIFICATION_FOCUS_ENTER:
			_focus_active = true
			_UpdatePanelStyle()
		NOTIFICATION_FOCUS_EXIT:
			_focus_active = false
			_UpdatePanelStyle()
		NOTIFICATION_THEME_CHANGED:
			_UpdatePanelStyle()
		NOTIFICATION_VISIBILITY_CHANGED:
			pass
		NOTIFICATION_RESIZED:
			pass

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _GetThemeType() -> StringName:
	if theme_type_variation != &"":
		return theme_type_variation
	return DEFAULT_THEME_TYPE

func _GetThemeStyleBox(style_name : StringName) -> StyleBox:
	return get_theme_stylebox(style_name, _GetThemeType())

#func _GetThemeFont(font_name : StringName) -> Font:
#	return get_theme_font(font_name, _GetThemeType())
#
#func _GetThemeFontSize(font_size_name : StringName) -> int:
#	return get_theme_font_size(font_size_name, _GetThemeType())
#
#func _GetThemeColor(color_name : StringName) -> Color:
#	var tt : StringName = _GetThemeType()
#	if has_theme_color(color_name, tt):
#		return get_theme_color(color_name, tt)
#	return Color.BLACK
#
#func _GetThemeConstant(const_name : StringName) -> int:
#	return get_theme_constant(const_name, _GetThemeType())

func _UpdatePanelStyle() -> void:
	if _cpanel == null: return
	if _mouse_entered and _press_active:
		_cpanel.add_theme_stylebox_override(&"panel", _GetThemeStyleBox(THEME_STYLE_PRESS))
	elif _mouse_entered:
		_cpanel.add_theme_stylebox_override(&"panel", _GetThemeStyleBox(THEME_STYLE_HOVER))
	elif _focus_active:
		_cpanel.add_theme_stylebox_override(&"panel", _GetThemeStyleBox(THEME_STYLE_FOCUS))
	else:
		_cpanel.add_theme_stylebox_override(&"panel", _GetThemeStyleBox(THEME_STYLE_NORMAL))

func _UpdatePanelSize() -> void:
	if _cpanel == null: return
	_cpanel.custom_minimum_size = Vector2.ONE * float(view_size)

func _UpdateCameraPlacement() -> void:
	if _gimble == null or _pitch == null or _camera == null: return
	_gimble.position.y = camera_height
	_pitch.rotation_degrees.x = camera_pitch_degrees
	_camera.position.z = -camera_zoom

func _UpdateResourceNode() -> void:
	if Engine.is_editor_hint(): return # Don't update this in editor!
	if _sub_viewport == null: return
	if _resource_node != null:
		_sub_viewport.remove_child(_resource_node)
		_resource_node.queue_free()
		_resource_node = null
	if lookup_table_name == &"" or resource_section == &"" or resource_name == &"": return
	
	var mrlt : CrawlMRLT = Crawl.get_lookup_table(lookup_table_name)
	if mrlt == null:
		printerr("ResourceView3DControl [", self.name, "]: No lookup table named \"", lookup_table_name, "\"")
		return
	
	_resource_node = mrlt.load_meta_resource(resource_section, resource_name, true)
	if _resource_node == null:
		printerr("ResourceView3DControl [", self.name, "]: Failed to get resource node \"", resource_section, ":", resource_name, "\"")
		return
	_sub_viewport.add_child(_resource_node)
	_resource_node.position = resource_position


func _AnimCamera() -> void:
	if Engine.is_editor_hint(): return # Don't do this in editor!
	if _anim_active or not enable_seesaw: return
	if arc_degrees <= 0.0 or duration <= 0.0: return
	
	# Just in case arc_degrees or duration gets changed in the middle of the animation.
	var arc : float = arc_degrees
	var dur : float = duration
	
	_anim_active = true
	var tween : Tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_gimble, "rotation_degrees:y", arc * 0.5, dur * 0.5)
	await(tween.finished)
	
	if not enable_seesaw:
		_gimble.rotation_degrees.z = 0.0
		_anim_active = false
		return
	
	tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_gimble, "rotation_degrees:y", -(arc * 0.5), dur)
	await(tween.finished)
	
	if not enable_seesaw:
		_gimble.rotation_degrees.z = 0.0
		_anim_active = false
		return
	
	tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_gimble, "rotation_degrees:y", 0.0, dur * 0.5)
	tween.finished.connect(
		func():
			_anim_active = false
			_AnimCamera.call_deferred()
	)
	

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------

