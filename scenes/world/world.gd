extends Node2D

# ------------------------------------------------------------------------------
# Contants
# ------------------------------------------------------------------------------
const DUNGEON_EDITOR : PackedScene = preload("res://scenes/dungeon_editor/DungeonEditor.tscn")

# ------------------------------------------------------------------------------
# Onready Variables
# ------------------------------------------------------------------------------
@onready var ot4g_oauth : OT4G_OAuth = $OT4G_OAuth
@onready var _de_window : Window = %DEWindow


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
func _OpenDungeonEditor() -> void:
	if _de_window.visible: return
	var de : Control = DUNGEON_EDITOR.instantiate()
	if de == null:
		printerr("Failed to instantiate the dungeon editor.")
		return
	
	_de_window.close_requested.connect(_on_close_de_window_requested, CONNECT_ONE_SHOT)
	_de_window.add_child(de)
	var screen_size : Vector2i = DisplayServer.screen_get_size()
	#_de_window.popup()
	_de_window.popup(Rect2i(Vector2i.ZERO, screen_size))

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_close_de_window_requested() -> void:
	if not _de_window.visible: return
	_de_window.hide()
	for child in _de_window.get_children():
		_de_window.remove_child(child)
		child.queue_free()

func _on_ui_action_requested(action_name : StringName, payload : Variant) -> void:
	match action_name:
		&"dungeon_editor":
			_OpenDungeonEditor()
		&"quit_app":
			get_tree().quit()

