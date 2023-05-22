extends Node2D

# ------------------------------------------------------------------------------
# Contants
# ------------------------------------------------------------------------------
const DUNGEON_EDITOR : PackedScene = preload("res://scenes/dungeon_editor/DungeonEditor.tscn")

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _active_node : Node = null

# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
@onready var ot4g_oauth : OT4G_OAuth = $OT4G_OAuth
#@onready var _de_window : Window = %DEWindow
@onready var _canvas : CanvasLayer = %Canvas
@onready var _ui : UI = %UI


# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	if not FileAccess.file_exists("./auth"):
		printerr("Failed to find expected auth file.")
		return
	
	var file : FileAccess = FileAccess.open("./auth", FileAccess.READ)
	var client_id : String = file.get_line()
	var client_secret : String = file.get_line()
	file.close()
	
	# await(ot4g_oauth.authenticate_async(client_id, client_secret))
	# print("Twitch Authentication Complete")


# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
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



#func _OpenDungeonEditor() -> void:
#	if _de_window.visible: return
#	var de : Control = DUNGEON_EDITOR.instantiate()
#	if de == null:
#		printerr("Failed to instantiate the dungeon editor.")
#		return
#
#	_de_window.close_requested.connect(_on_close_de_window_requested, CONNECT_ONE_SHOT)
#	_de_window.add_child(de)
#	var screen_size : Vector2i = DisplayServer.screen_get_size()
#	#_de_window.popup()
#	_de_window.popup(Rect2i(Vector2i.ZERO, screen_size))

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
#func _on_close_de_window_requested() -> void:
#	if not _de_window.visible: return
#	_de_window.hide()
#	for child in _de_window.get_children():
#		_de_window.remove_child(child)
#		child.queue_free()

func _on_ui_action_requested(action_name : StringName, payload : Variant) -> void:
	match action_name:
		&"dungeon_editor":
			_OpenDungeonEditor()
			_ui.show_menu(&"")
		&"close":
			_CloseActiveNode(&"MainMenu")
		&"quit_app":
			get_tree().quit()

