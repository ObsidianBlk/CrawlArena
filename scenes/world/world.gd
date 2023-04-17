extends Node2D

@onready var ot4g_oauth : OT4G_OAuth = $OT4G_OAuth

func _ready() -> void:
	if not FileAccess.file_exists("./auth"):
		printerr("Failed to find expected auth file.")
		return
	
	var file : FileAccess = FileAccess.open("./auth", FileAccess.READ)
	var client_id : String = file.get_line()
	var client_secret : String = file.get_line()
	file.close()
	
	await(ot4g_oauth.authenticate_async(client_id, client_secret))
	print("Twitch Authentication Complete")
