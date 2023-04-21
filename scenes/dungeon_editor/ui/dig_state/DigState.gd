@tool
extends Control


# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal direction_changed(direction)

# ------------------------------------------------------------------------------
# Constants and ENUMs
# ------------------------------------------------------------------------------
enum DIRECTION {Down=0, Foreward=1, Up=2}

const HIGHLIGHT_MODULATION_COLOR : Color = Color.TOMATO

# ------------------------------------------------------------------------------
# Export Variables
# ------------------------------------------------------------------------------
@export var initial_direction : DIRECTION = DIRECTION.Foreward

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _direction : DIRECTION = DIRECTION.Foreward

# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
@onready var _btn_dig_up = $btn_dig_up
@onready var _btn_dig_foreward = $btn_dig_foreward
@onready var _btn_dig_down = $btn_dig_Down

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	_direction = initial_direction
	_UpdateDirectionHighlight()

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _UpdateDirectionHighlight() -> void:
	match _direction:
		DIRECTION.Down:
			_btn_dig_down.modulate = HIGHLIGHT_MODULATION_COLOR
			_btn_dig_foreward.modulate = Color.WHITE
			_btn_dig_up.modulate = Color.WHITE
		DIRECTION.Foreward:
			_btn_dig_down.modulate = Color.WHITE
			_btn_dig_foreward.modulate = HIGHLIGHT_MODULATION_COLOR
			_btn_dig_up.modulate = Color.WHITE
		DIRECTION.Up:
			_btn_dig_down.modulate = Color.WHITE
			_btn_dig_foreward.modulate = Color.WHITE
			_btn_dig_up.modulate = HIGHLIGHT_MODULATION_COLOR

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func cycle_direction() -> void:
	match _direction:
		DIRECTION.Down:
			_direction = DIRECTION.Foreward
		DIRECTION.Foreward:
			_direction = DIRECTION.Up
		DIRECTION.Up:
			_direction = DIRECTION.Down
	_UpdateDirectionHighlight()
	direction_changed.emit(_direction)

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_btn_dig_up_pressed():
	_direction = DIRECTION.Up
	_UpdateDirectionHighlight()
	direction_changed.emit(_direction)

func _on_btn_dig_foreward_pressed():
	_direction = DIRECTION.Foreward
	_UpdateDirectionHighlight()
	direction_changed.emit(_direction)

func _on_btn_dig_down_pressed():
	_direction = DIRECTION.Down
	_UpdateDirectionHighlight()
	direction_changed.emit(_direction)
