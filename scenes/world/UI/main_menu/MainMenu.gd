extends UIMenu

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_btn_dungeon_editor_pressed():
	send_action_request(&"dungeon_editor")

func _on_btn_quit_pressed():
	send_action_request(&"quit_app")


func _on_btn_start_game_pressed():
	send_action_request(&"start_game")
