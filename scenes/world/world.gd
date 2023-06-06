extends Node2D

# ------------------------------------------------------------------------------
# Contants
# ------------------------------------------------------------------------------
const DUNGEON_EDITOR : PackedScene = preload("res://scenes/dungeon_editor/DungeonEditor.tscn")
const GAME : PackedScene = preload("res://scenes/game/Game.tscn")

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _active_node : Node = null

# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
@onready var ot4g_oauth : OT4G_OAuth = $OT4G_OAuth
@onready var _settings_window : Window = %SettingsWindow
#@onready var _de_window : Window = %DEWindow
@onready var _canvas : CanvasLayer = %Canvas
@onready var _ui : UI = %UI
@onready var _ot4g_irc = $OT4G_OAuth/OT4G_IRC


# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	_settings_window.visible = false
	
#	if not FileAccess.file_exists("./auth"):
#		printerr("Failed to find expected auth file.")
#		return
#
#	var file : FileAccess = FileAccess.open("./auth", FileAccess.READ)
#	var client_id : String = file.get_line()
#	var client_secret : String = file.get_line()
#	file.close()
	var kr : Keyring = Arena.get_keyring()
	kr.service_changed.connect(_on_keyring_service_changed)
	_AuthenticateTwitch()


# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _AuthenticateTwitch() -> void:
	if ot4g_oauth.authenticated(): return
	
	var kr : Keyring = Arena.get_keyring()
	if kr.has_service("twitch"):
		var ring : Dictionary = kr.get_service_keys("twitch")
		ot4g_oauth.authenticate_async(ring["client_id"], ring["client_secret"])

func _CloseActiveNode(return_menu : StringName = &"") -> void:
	if _active_node == null: return
	_canvas.remove_child(_active_node)
	if _active_node.has_signal("action_requested"):
		if _active_node.action_requested.is_connected(_on_ui_action_requested):
			_active_node.action_requested.disconnect(_on_ui_action_requested)
	_active_node.queue_free()
	_active_node = null
	_ui.show_menu(return_menu)

func _OpenDungeonEditor() -> void:
	if _active_node != null: return
	_active_node = DUNGEON_EDITOR.instantiate()
	if _active_node == null:
		printerr("Failed to instantiate the dungeon editor.")
		return
	if _active_node.has_signal("action_requested"):
		_active_node.action_requested.connect(_on_ui_action_requested)
	_canvas.add_child(_active_node)

func _OpenGame() -> void:
	if _active_node != null: return
	_active_node = GAME.instantiate()
	if _active_node == null:
		printerr("Failed to instantiate the Game.")
		return
	if _active_node.has_signal("action_requested"):
		_active_node.action_requested.connect(_on_ui_action_requested)
	_canvas.add_child(_active_node)

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_keyring_service_changed(service_name : String) -> void:
	if service_name == "twitch":
		_AuthenticateTwitch()

func _on_ui_action_requested(action_name : StringName, payload : Variant) -> void:
	match action_name:
		&"dungeon_editor":
			_OpenDungeonEditor()
			_ui.show_menu(&"")
		&"start_game":
			_OpenGame()
			_ui.show_menu(&"")
		&"system_settings":
			if _settings_window.visible: return
			_settings_window.popup_centered()
		&"close_system_settings":
			_settings_window.visible = false
		&"close":
			_CloseActiveNode(&"MainMenu")
		&"quit_app":
			get_tree().quit()


func _on_ot4g_irc_message_received(msgctx : OT4G_IRC.MessageContext) -> void:
	if _active_node == null: return
	if _active_node.has_method("handle_message"):
		_active_node.handle_message(msgctx)


func _on_ot_4g_irc_channel_joined(channel_name : StringName):
	print("Channel name: ", channel_name)


func _on_ot4g_oauth_user_token_authentication_completed() -> void:
	print("Twitch Authentication Completed")


func _on_ot4g_oauth_user_token_authentication_started():
	print("Twitch Authentication Started...")
