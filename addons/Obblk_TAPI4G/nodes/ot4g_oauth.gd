extends Node
class_name OT4G_OAuth

# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal user_token_authentication_started()
signal user_token_authentication_completed()
signal user_token_received(token)
signal user_token_invalid()
signal user_token_valid()

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const USER_AGENT : String = "User-Agent: OT4G/0.1 (Godot Engine)"
const TWITCH_HTTP_TOKEN_OBTAIN : String = "https://id.twitch.tv/oauth2/token"
const TWITCH_HTTP_TOKEN_VALIDATION : String = "https://id.twitch.tv/oauth2/validate"

const AUTH_BASE_PATH : String = "user://obblk_tapi4g/auth"
const TOKEN_FILENAME : String = "token"

# ------------------------------------------------------------------------------
# Export Variables
# ------------------------------------------------------------------------------
@export_category("Obblk's TAPI4G OAuth")
@export var redirect_uri : String = "http://localhost"
@export var port : int = 15815:										set = set_port
@export var scopes : Array[String] = ["chat:edit", "chat:read"]

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _client_id : String = ""
var _client_secret : String = ""

var _user_id : String = ""
var _username : String = ""
var _token : Dictionary = {}
var _authenticated : bool = false
var _authenticating : bool = false

var _peer : StreamPeerTCP = null
var _server : TCPServer = TCPServer.new()

# ------------------------------------------------------------------------------
# Setters
# ------------------------------------------------------------------------------
func set_port(p : int) -> void:
	if p >= 1024 and p <= 49151:
		port = p

# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _init() -> void:
	pass

func _process(_delta : float) -> void:
	if not _server.is_listening(): return
	if _peer == null:
		_peer = _server.take_connection()
		return
	
	var data : Dictionary = _ProcessPeerResponse()
	if data.is_empty(): return
	
	if "error" in data:
		var msg : String = "Error %s: %s"%[data["error"], data["error_description"]]
		_ClosePeer(400, msg)
		print(msg)
	else:
		print("Authorization Granted")
		_ClosePeer(200, "Authorization Granted!")
		#authorization_code
		_ObtainToken_Async("authorization_code", data["code"])

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _StoreToken(token_data : String) -> void:
	if _client_secret.is_empty(): return
	if !DirAccess.dir_exists_absolute(AUTH_BASE_PATH):
		DirAccess.make_dir_recursive_absolute(AUTH_BASE_PATH)
	var file : FileAccess = FileAccess.open_encrypted_with_pass(
		AUTH_BASE_PATH.path_join(TOKEN_FILENAME), 
		FileAccess.WRITE,
		_client_secret
	)
	file.store_string(token_data)
	file.close()

func _LoadToken() -> void:
	if _client_secret.is_empty(): return
	var token_file_path : String = AUTH_BASE_PATH.path_join(TOKEN_FILENAME)
	if FileAccess.file_exists(token_file_path):
		var file : FileAccess = FileAccess.open_encrypted_with_pass(
			token_file_path,
			FileAccess.READ,
			_client_secret
		)
		var token : Dictionary = JSON.parse_string(file.get_as_text())
		file.close()
		
		var scopes_valid : bool = ("scope" in token and token["scope"].size() == scopes.size())
		if scopes_valid:
			for scope in scopes:
				if not token["scope"].has(scope):
					scopes_valid = false
					break
		if scopes_valid:
			_token = token

func _IsTokenValid_Async(token : Dictionary) -> bool:
	if not "access_token" in token: return false
	var req : HTTPRequest = HTTPRequest.new()
	add_child(req)
	req.request(TWITCH_HTTP_TOKEN_VALIDATION, [USER_AGENT, "Authorization: OAuth %s"%[token["access_token"]]])
	var data = await(req.request_completed)
	if data[1] == 200:
		var payload : Dictionary = JSON.parse_string(data[3].get_string_from_utf8())
		_user_id = payload["user_id"]
		_username = payload["login"]
		return true
	return false

func _RequestToken() -> void:
	if _client_id.is_empty() or _client_secret.is_empty() or redirect_uri.is_empty(): return
	if _server.is_listening(): return
	print("Requesting new token")
	
	var uri = "%s:%d"%[redirect_uri, port]
	
	var scope_req : String = (" ".join(PackedStringArray(scopes))).uri_encode()
	OS.shell_open("https://id.twitch.tv/oauth2/authorize?response_type=code&force_verify=true&client_id=%s&redirect_uri=%s&scope=%s"%[
		_client_id,
		uri,
		scope_req
	])
	_server.listen(port)
	print("Waiting for user to login...")
	# From this point on, the _process() method is listening and the response will be handled
	# between _ProcessPeerResponse(), _ClosePeer(), and _ObtainToken_Async() methods


func _ProcessPeerResponse() -> Dictionary:
	if _peer == null: return {}
	if _peer.get_status() != _peer.STATUS_CONNECTED: return {}
	_peer.poll()
	var bytes : int = _peer.get_available_bytes()
	
	if bytes <= 0: return {}
	var response : String = _peer.get_utf8_string(bytes)
	if response == "":
		return {}
	
	var start : int = response.find("?")
	response = response.substr(start + 1, response.find(" ", start) - start)
	var data : Dictionary = {}
	for entry in response.split("&"):
		var pair : Array = entry.split("=")
		data[pair[0]] = pair[1]
	return data

func _ClosePeer(response_code : int, msg : String) -> void:
	var body : PackedByteArray = msg.to_utf8_buffer()
	_peer.put_utf8_string("HTTP/1.1 %d\r\n"%[response_code])
	_peer.put_utf8_string("Content-Length: %d\r\n\r\n"%[body.size()])
	_peer.put_data(body)
	_peer.disconnect_from_host()
	_peer = null
	_server.stop()

func _ObtainToken_Async(grant : String, code : String) -> void:
	if _client_id.is_empty() or _client_secret.is_empty() or redirect_uri.is_empty(): return
	var uri = "%s:%d"%[redirect_uri, port]
	
	var request : HTTPRequest = HTTPRequest.new()
	add_child(request)
	
	request.request(
		TWITCH_HTTP_TOKEN_OBTAIN,
		[USER_AGENT, "Content-Type: application/x-www-form-urlencoded"],
		HTTPClient.METHOD_POST,
		"client_id=%s&client_secret=%s&code=%s&grant_type=%s&redirect_uri=%s"%[
			_client_id,
			_client_secret,
			code,
			grant,
			uri
		]
	)
	var answer = await(request.request_completed)
	var token_data : String = answer[3].get_string_from_utf8()
	var token : Dictionary = JSON.parse_string(token_data)
	if not "status" in token:
		_StoreToken(token_data)
	request.queue_free()
	user_token_received.emit(JSON.parse_string(token_data))

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func authenticated() -> bool:
	return _authenticated

func authenticate_async(client_id : String, client_secret : String) -> void:
	if _authenticating: return
	_client_id = client_id
	_client_secret = client_secret
	if _client_secret.is_empty(): return
	
	_authenticated = false
	user_token_authentication_started.emit()
	_authenticating = true
	
	_token = {}
	_LoadToken()
	
	var is_valid : bool = false
	if _token.is_empty():
		_RequestToken()
		_token = await(user_token_received)
	is_valid = await(_IsTokenValid_Async(_token))
	
	# TODO: If validation fails check for a refresh code and attempt a refresh before reauthenticating.
	while not is_valid:
		_RequestToken()
		_token = await(user_token_received)
		is_valid = await(_IsTokenValid_Async(_token))
	
	print("User token verified")
	_authenticated = true
	user_token_valid.emit()
	get_tree().create_timer(3600).timeout.connect(_on_token_refresh_timeout)
	_authenticating = false
	user_token_authentication_completed.emit()

func get_client_id() -> String:
	return _client_id

func get_user_info() -> Dictionary:
	if _token.is_empty(): return {}
	return {
		"id":_user_id,
		"username":_username,
		"access_token":_token["access_token"]
	}

func get_token() -> Dictionary:
	return _token

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_token_refresh_timeout() -> void:
	if await(_IsTokenValid_Async(_token["access_token"])) == false:
		_authenticated = false
		user_token_invalid.emit()
		if not "refresh_token" in _token: return
		
		_ObtainToken_Async("", _token["refresh_token"])
		var token : Dictionary = await(user_token_received)
		if "error" in token: return
		
		_token = token
	get_tree().create_timer(3600).timeout.connect(_on_token_refresh_timeout)
