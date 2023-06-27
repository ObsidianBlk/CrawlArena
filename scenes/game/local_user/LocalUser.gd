extends Control


# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal message_received(msg)

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const SERVICE_NAME : String = "LOCAL"

const COLOR_OUTBOUND : Color = Color.WHEAT
const COLOR_INBOUND : Color = Color.LIGHT_BLUE
const COLOR_ERROR : Color = Color.TOMATO

const MAX_MESSAGES : int = 100

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _username : String = ""
var _user : GSMCUser = null

var _msglist : Array = []


# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
@onready var _msg_container : VBoxContainer = %MsgContainer
@onready var _msg_line_edit : LineEdit = %MsgLineEdit

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	pass

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _UpdateUser() -> void:
	if _user != null:
		if _user.username != _username:
			GSMC.set_user_active(SERVICE_NAME, _user.uid, false)
		_user = null
	if not _username.is_empty():
		_user = GSMC.store_user(SERVICE_NAME, "%s:%s"%[SERVICE_NAME, _username], {
			"username":_username,
			"owner":true,
			"send":(func(msg : String): _DisplayMessage(msg, COLOR_INBOUND)),
			"reply":(func(msg : String): _DisplayMessage(msg, COLOR_INBOUND))
		})

func _DisplayMessage(msg : String, color : Color) -> void:
	var lbl: Label = Label.new()
	lbl.text = msg
	lbl.add_theme_color_override("font_color", color)
	_msg_container.add_child(lbl)
	_msglist.append(lbl)
	if _msglist.size() > MAX_MESSAGES:
		_msg_container.remove_child(_msglist[0])
		_msglist[0].queue_free()
		_msglist.pop_front()

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------

func _on_name_line_edit_text_changed(username : String) -> void:
	_username = username

func _on_msg_line_edit_text_submitted(msg : String) -> void:
	if msg.is_empty(): return
	var mmsg : GSMCMessage = null
	_UpdateUser()
	if _user == null:
		_DisplayMessage("Missing display name!", COLOR_ERROR)
	else:
		mmsg = GSMC.store_message(SERVICE_NAME, _user.uid, msg, {
			"whisper": false,
			"send": (func(msg : String): _DisplayMessage(msg, COLOR_INBOUND))
		})
		_DisplayMessage(msg, COLOR_OUTBOUND)
	_msg_line_edit.text = ""
	if mmsg != null:
		message_received.emit(mmsg)

func _on_btn_send_pressed():
	_on_msg_line_edit_text_submitted(_msg_line_edit.text)
