@tool
extends EditorPlugin

const CONFIGS : Dictionary = {
	"OT4G_OAuth":{
		"base":"Node",
		"script":preload("res://addons/Obblk_TAPI4G/nodes/ot4g_oauth.gd"),
		"icon":preload("res://addons/Obblk_TAPI4G/icons/OT4G_OAuth.svg")
	}
}

func _enter_tree():
	for type_name in CONFIGS.keys():
		if CONFIGS[type_name]["script"] == null: continue
		add_custom_type(
			type_name,
			CONFIGS[type_name]["base"],
			CONFIGS[type_name]["script"],
			CONFIGS[type_name]["icon"]
		)


func _exit_tree():
	for type_name in CONFIGS.keys():
		if CONFIGS[type_name]["script"] == null: continue
		remove_custom_type(type_name)
