extends Control


# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------


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
@export var lookup_table_name : StringName = ""
@export var meta_resource_name : StringName = ""
@export var camera_height : float = 1.0
@export_range(-90.0, 90.0, 0.1) var camera_pitch_degrees : float = 0.0
@export var camera_zoom : float = 2.0

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _mouse_button_down : bool = false
var _mouse_entered : bool = false
var _focus_active : bool = false

# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
@onready var _cpanel : PanelContainer = %CPanel
@onready var _sub_viewport : SubViewport = %SubViewport
@onready var _camera : Camera3D = %Camera3D
@onready var _gimble : Node3D = %Gimble
@onready var _pitch : Node3D = %Pitch

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	_UpdatePanelStyle()

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

func _GetThemeFont(font_name : StringName) -> Font:
	return get_theme_font(font_name, _GetThemeType())

func _GetThemeFontSize(font_size_name : StringName) -> int:
	return get_theme_font_size(font_size_name, _GetThemeType())

func _GetThemeColor(color_name : StringName) -> Color:
	var tt : StringName = _GetThemeType()
	if has_theme_color(color_name, tt):
		return get_theme_color(color_name, tt)
	return Color.BLACK

func _GetThemeConstant(const_name : StringName) -> int:
	return get_theme_constant(const_name, _GetThemeType())

func _UpdatePanelStyle() -> void:
	if _cpanel == null: return
	if _mouse_button_down:
		_cpanel.add_theme_stylebox_override(&"panel", _GetThemeStyleBox(THEME_STYLE_PRESS))
	elif _mouse_entered:
		_cpanel.add_theme_stylebox_override(&"panel", _GetThemeStyleBox(THEME_STYLE_HOVER))
	elif _focus_active:
		_cpanel.add_theme_stylebox_override(&"panel", _GetThemeStyleBox(THEME_STYLE_FOCUS))
	else:
		_cpanel.add_theme_stylebox_override(&"panel", _GetThemeStyleBox(THEME_STYLE_NORMAL))

func _UpdateCameraPlacement() -> void:
	if _gimble == null or _pitch == null or _camera == null: return
	

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------

