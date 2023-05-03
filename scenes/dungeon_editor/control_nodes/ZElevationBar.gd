@tool
extends Control
class_name ZElevationBar

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const DEFAULT_THEME_TYPE : StringName = &"ZElevationBar"
const THEME_FONT : StringName = &"font"
const THEME_FONT_SIZE : StringName = &"font_size"
const THEME_FONT_COLOR : StringName = &"font_color"
const THEME_STYLE_BACKGROUND : StringName = &"background"
const THEME_STYLE_HIGHLIGHT : StringName = &"highlight"
const THEME_CONST_SPACING : StringName = &"spacing"

# ------------------------------------------------------------------------------
# Export Variables
# ------------------------------------------------------------------------------
@export var min_z_level : int = 0:				set = set_min_z_level
@export var max_z_level : int = 0:				set = set_max_z_level
@export var z_level : int = 0:					set = set_z_level
@export var show_z_level : bool = true:			set = set_show_z_level

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# Setters
# ------------------------------------------------------------------------------
func set_min_z_level(z : int) -> void:
	if z != min_z_level:
		min_z_level = z
		if max_z_level < min_z_level:
			max_z_level = min_z_level
		if z_level < min_z_level:
			z_level = min_z_level
		queue_redraw()

func set_max_z_level(z : int) -> void:
	if z != max_z_level:
		max_z_level = z
		if min_z_level > max_z_level:
			min_z_level = max_z_level
		if z_level > max_z_level:
			z_level = max_z_level
		queue_redraw()

func set_z_level(z : int) -> void:
	if z != z_level and z >= min_z_level and z <= max_z_level:
		z_level = z
		queue_redraw()

func set_show_z_level(s : bool) -> void:
	if s != show_z_level:
		show_z_level = s
		queue_redraw()

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	resized.connect(queue_redraw)
	theme_changed.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	var background : StyleBox = _GetThemeStyleBox(THEME_STYLE_BACKGROUND)
	var highlight : StyleBox = _GetThemeStyleBox(THEME_STYLE_HIGHLIGHT)
	var spacing : int = _GetThemeConstant(THEME_CONST_SPACING)
	
	var canvas_size : Vector2 = get_size()
	var steps : float = 1.0 + abs(max_z_level - min_z_level)
	var rsize : Vector2 = Vector2(canvas_size.x, (canvas_size.y / steps) - float(spacing))
	var rpos : Vector2 = Vector2(0, canvas_size.y - rsize.y)
	var rect : Rect2 = Rect2(rpos, rsize)
	
	for i in range(steps):
		draw_style_box(highlight if min_z_level + i == z_level else background, rect)
		if min_z_level + i == z_level and show_z_level:
			_DrawZLevelText(rect)
		rect.position.y -= rect.size.y + float(spacing)

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _DrawZLevelText(rect : Rect2) -> void:
	var font : Font = _GetThemeFont(THEME_FONT)
	var font_size : int = _GetThemeFontSize(THEME_FONT_SIZE)
	var font_color : Color = _GetThemeColor(THEME_FONT_COLOR)
	
	var text : String = "%d"%[z_level]
	var text_size : Vector2 = font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	text_size.y = 0.0
	var pos : Vector2 = (rect.position + rect.size * 0.5) - (text_size * 0.5)
	
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, font_color)

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
	return get_theme_color(color_name, _GetThemeType())

func _GetThemeConstant(const_name : StringName) -> int:
	return get_theme_constant(const_name, _GetThemeType())
