@tool
extends Control


# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal active()

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const DEFAULT_THEME_TYPE : StringName = &"ResourceSelectionWindow"
const THEME_STYLE_BASE : String = "item"
const THEME_STATE_NORMAL : String = "normal"
const THEME_STATE_HOVER : String = "hover"
const THEME_STATE_FOCUS : String = "focus"
const THEME_STATE_ACTIVE : String = "active"

const THEME_FONT_NAME : String = "item_name"
const THEME_FONT_SIZE_NAME : String = "item_name_size"


# ------------------------------------------------------------------------------
# Export Variables
# ------------------------------------------------------------------------------
@export_category("Resource Entry Item")
@export_group("Information")
@export var entry_name : String = "":					set = set_entry_name
@export var description : String = "":					set = set_description


# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _meta : Variant = null

var _hover_active : bool = false
var _focus_active : bool = false
var _item_active : bool = false

# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
@onready var _cpanel : PanelContainer = $CPanel
@onready var _lbl_name : Label = $CPanel/LblName


# ------------------------------------------------------------------------------
# Settings
# ------------------------------------------------------------------------------
func set_entry_name(n : String) -> void:
	entry_name = n
	if _lbl_name != null:
		_lbl_name.text = entry_name

func set_description(d : String) -> void:
	description = d
	tooltip_text = description

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	set_entry_name(entry_name)
	set_description(description)
	_UpdateTheme()

func _notification(what : int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			_hover_active = true
			_UpdateTheme()
		NOTIFICATION_MOUSE_EXIT:
			_hover_active = false
			_UpdateTheme()
		NOTIFICATION_FOCUS_ENTER:
			_focus_active = true
			_UpdateTheme()
		NOTIFICATION_FOCUS_EXIT:
			_focus_active = false
			_UpdateTheme()
		NOTIFICATION_THEME_CHANGED:
			_UpdateTheme()
		NOTIFICATION_VISIBILITY_CHANGED:
			pass
		NOTIFICATION_RESIZED:
			pass

func _gui_input(event : InputEvent) -> void:
	if _hover_active and is_instance_of(event, InputEventMouseButton):
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			_item_active = not _item_active
			_UpdateTheme()
			if _item_active:
				active.emit()
			accept_event()
	elif _focus_active and event.is_action_pressed("ui_select"):
		_item_active = not _item_active
		_UpdateTheme()
		if _item_active:
			active.emit()
		accept_event()

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

func _UpdateTheme() -> void:
	var state : String = THEME_STATE_NORMAL
	if _item_active:
		state = THEME_STATE_ACTIVE
	elif _hover_active:
		state = THEME_STATE_HOVER
	elif _focus_active:
		state = THEME_STATE_FOCUS
		
	if _cpanel != null:
		var sb : StyleBox = _GetThemeStyleBox("%s_%s"%[THEME_STYLE_BASE, state])
		_cpanel.add_theme_stylebox_override(&"panel", sb)
	
	if _lbl_name != null:
		var font : Font = _GetThemeFont("%s_%s"%[THEME_FONT_NAME, state])
		var font_size : int = _GetThemeFontSize("%s_%s"%[THEME_FONT_SIZE_NAME, state])
		_lbl_name.add_theme_font_override(&"font", font)
		_lbl_name.add_theme_font_size_override(&"font_size", font_size)


# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func is_active() -> bool:
	return _item_active

func set_active(active : bool) -> void:
	_item_active = active
	_UpdateTheme()

func set_meta_data(meta : Variant) -> void:
	_meta = meta

func get_meta_data() -> Variant:
	return _meta

