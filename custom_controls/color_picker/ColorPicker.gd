extends Control

# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal changed(color)

# ------------------------------------------------------------------------------
# Export Variables
# ------------------------------------------------------------------------------
@export_category("Color Picker")
@export var color : Color:			set = set_color, get = get_color

# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
@onready var _color_rect : ColorRect = %ColorRect

@onready var _edit_hex : LineEdit = %EditHex

@onready var _slider_hue : HSlider = %SliderHue
@onready var _slider_saturation : HSlider = %SliderSaturation
@onready var _slider_luminance : HSlider = %SliderLuminance

@onready var _slider_r : HSlider = %SliderR
@onready var _slider_g : HSlider = %SliderG
@onready var _slider_b : HSlider = %SliderB

# ------------------------------------------------------------------------------
# Setters/Getters
# ------------------------------------------------------------------------------
func set_color(c : Color) -> void:
	if _color_rect == null: return
	_color_rect.color = c
	_UpdateControlsToColor()

func get_color() -> Color:
	if _color_rect != null:
		return _color_rect.color
	return Color.WHITE

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	_UpdateControlsToColor()

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _UpdateControlsToColor() -> void:
	_UpdateHexControls()
	_UpdateHSVControls()
	_UpdateRGBControls()

func _UpdateHexControls() -> void:
	if _color_rect == null: return
	_edit_hex.text = _color_rect.color.to_html(false)

func _UpdateHSVControls() -> void:
	if _color_rect == null: return
	_slider_hue.value = _color_rect.color.h * 100.0
	_slider_saturation.value = _color_rect.color.s * 100.0
	_slider_luminance.value = _color_rect.color.v * 100.0

func _UpdateRGBControls() -> void:
	if _color_rect == null: return
	_slider_r.value = _color_rect.color.r * 255.0
	_slider_g.value = _color_rect.color.g * 255.0
	_slider_b.value = _color_rect.color.b * 255.0

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_slider_hue_value_changed(value : float) -> void:
	if _color_rect == null: return
	_color_rect.color.h = value * 0.01
	_UpdateRGBControls()
	_UpdateHexControls()
	changed.emit(_color_rect.color)


func _on_slider_saturation_value_changed(value : float) -> void:
	if _color_rect == null: return
	_color_rect.color.s = value * 0.01
	_UpdateRGBControls()
	_UpdateHexControls()
	changed.emit(_color_rect.color)


func _on_slider_luminance_value_changed(value : float) -> void:
	if _color_rect == null: return
	_color_rect.color.v = value * 0.01
	_UpdateRGBControls()
	_UpdateHexControls()
	changed.emit(_color_rect.color)


func _on_slider_r_value_changed(value : float) -> void:
	if _color_rect == null: return
	_color_rect.color.r = value / 255
	_UpdateHSVControls()
	_UpdateHexControls()
	changed.emit(_color_rect.color)


func _on_slider_g_value_changed(value : float) -> void:
	if _color_rect == null: return
	_color_rect.color.g = value / 255
	_UpdateHSVControls()
	_UpdateHexControls()
	changed.emit(_color_rect.color)


func _on_slider_b_value_changed(value : float) -> void:
	if _color_rect == null: return
	_color_rect.color.b = value / 255
	_UpdateHSVControls()
	_UpdateHexControls()
	changed.emit(_color_rect.color)
