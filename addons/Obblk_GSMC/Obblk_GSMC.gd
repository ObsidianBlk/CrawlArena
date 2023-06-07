@tool
extends EditorPlugin

const AUTOLOAD_NAME : String = "GSMC"

func _enter_tree():
	add_autoload_singleton(AUTOLOAD_NAME, "res://addons/Obblk_GSMC/autoloads/GSMC.gd")


func _exit_tree():
	remove_autoload_singleton(AUTOLOAD_NAME)
