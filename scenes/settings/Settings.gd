extends Control



# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal action_requested(action_name, payload)


# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const ICON_EYE_OPEN : Texture = preload("res://assets/icons/eye_open.svg")
const ICON_EYE_CLOSED : Texture = preload("res://assets/icons/eye_closed.svg")

# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
@onready var _line_twitch_client_id : LineEdit = %LineTwitchClientID
@onready var _line_twitch_secret : LineEdit = %LineTwitchSecret
@onready var _btn_twitch_client_id : Button = %BtnTwitchClientID
@onready var _btn_twitch_secret : Button = %BtnTwitchSecret


# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	_btn_twitch_client_id.pressed.connect(_on_toggle_line_secret.bind(
		_line_twitch_client_id, _btn_twitch_client_id
	))
	
	_btn_twitch_secret.pressed.connect(_on_toggle_line_secret.bind(
		_line_twitch_secret, _btn_twitch_secret
	))

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# Handler methods
# ------------------------------------------------------------------------------
func _on_btn_done_pressed() -> void:
	action_requested.emit(&"close_system_settings", null)

func _on_btn_reset_pressed() -> void:
	print("Not sure what I really want to do with this control yet. Stay tuned...")

func _on_toggle_line_secret(line : LineEdit, btn : Button) -> void:
	line.secret = not line.secret
	btn.icon = ICON_EYE_OPEN if line.secret else ICON_EYE_CLOSED

