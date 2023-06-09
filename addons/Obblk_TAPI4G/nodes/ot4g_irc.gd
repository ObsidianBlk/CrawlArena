extends Node
class_name OT4G_IRC

# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal irc_connected()
signal irc_login_attempted(result)
signal irc_permission_denied()

signal irc_reconnecting()
signal irc_unavailable()
signal irc_disconnected()

signal channel_joined(username, channel_name)
signal channel_left(username, channel_name)

signal user_notice_sent(channel, msg, tags)

signal message_received(msgctx)

signal unhandled_message(msg, tags)


# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------
const SERVICE_NAME : String = "Twitch"
const TWITCH_IRC_ADDRESS = "wss://irc-ws.chat.twitch.tv:443"

const PING_MESSAGE : String = "PING :tmi.twitch.tv"
const PONG_RESPONSE : String = "PONG :tmi.twitch.tv"

# ------------------------------------------------------------------------------
# Export Variables
# ------------------------------------------------------------------------------
@export_category("Obblk's TAPI4G IRC")
@export var verbose_messages : bool = true
@export var oauth_path : NodePath = "":				set = set_oauth_path
@export var chat_timeout_ms : int = 320
@export var auto_connect : bool = true:				set = set_auto_connect
@export var initial_channel : String = ""

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
var _user_info : Dictionary = {}

var _websocket : WebSocketPeer = null
var _connected : bool = false
var _reconnecting : bool = false

var _channels : Array[String] = []

var user_regex : RegEx = RegEx.new()

# ------------------------------------------------------------------------------
# Setters
# ------------------------------------------------------------------------------
func set_oauth_path(p : NodePath) -> void:
	var o = get_node_or_null(oauth_path)
	if not is_instance_of(o, OT4G_OAuth):
		o = null
	
	oauth_path = p
	
	var n = get_node_or_null(oauth_path)
	if not is_instance_of(n, OT4G_OAuth):
		n = null
	
	if n == o:
		o = null
	_UpdateOAuthConnections(o, n)

func set_auto_connect(a : bool) -> void:
	auto_connect = a
	if auto_connect and not _user_info.is_empty():
		connect_async()


# ------------------------------------------------------------------------------
# Override Methods
# ------------------------------------------------------------------------------
func _ready() -> void:
	user_regex.compile("(?<=!)[\\w]*(?=@)")
	if oauth_path != ^"":
		var n = get_node_or_null(oauth_path)
		if not is_instance_of(n, OT4G_OAuth):
			n = null
		if n != null:
			_UpdateOAuthConnections(null, n)
	else:
		var parent = get_parent()
		if is_instance_of(parent, OT4G_OAuth):
			set_oauth_path(get_path_to(parent))
	if not initial_channel.is_empty():
		join_channel(initial_channel)

func _process(_delta : float) -> void:
	if _websocket == null: return
	_websocket.poll()
	var state := _websocket.get_ready_state()
	match state:
		WebSocketPeer.STATE_OPEN:
			if not _connected:
				_connected = true
				irc_connected.emit()
			else:
				while _websocket.get_available_packet_count() > 0:
					var data : Array = _ParsePacket(_websocket.get_packet())
					for info in data:
						_HandleMessage(info.message, info.tags)
		WebSocketPeer.STATE_CLOSED:
			if not _connected:
				irc_unavailable.emit()
				_websocket = null
			elif _reconnecting:
				irc_reconnecting.emit()
				_websocket.close()
				_websocket = null
				connect_async()
				await(irc_login_attempted)
				_reconnecting = false
			else:
				_websocket.close()
				_websocket = null
				irc_disconnected.emit()
				_connected = false

# ------------------------------------------------------------------------------
# Private Methods
# ------------------------------------------------------------------------------
func _Print(args : Array) -> void:
	if not verbose_messages: return
	var str : String = ""
	for item in args:
		str = "%s%s"%[str, item]
	print(str)

func _UpdateOAuthConnections(old_oauth : OT4G_OAuth, new_oauth : OT4G_OAuth) -> void:
	if old_oauth != null:
		if old_oauth.user_token_invalid.is_connected(_on_user_token_invalid):
			old_oauth.user_token_invalid.disconnect(_on_user_token_invalid)
		if old_oauth.user_token_valid.is_connected(_on_user_token_valid.bind(old_oauth)):
			old_oauth.user_token_valid.disconnect(_on_user_token_valid.bind(old_oauth))
		_user_info = {}
	
	if new_oauth != null:
		if not new_oauth.user_token_invalid.is_connected(_on_user_token_invalid):
			new_oauth.user_token_invalid.connect(_on_user_token_invalid)
		if not new_oauth.user_token_valid.is_connected(_on_user_token_valid.bind(new_oauth)):
			new_oauth.user_token_valid.connect(_on_user_token_valid.bind(new_oauth))
		if new_oauth.authenticated():
			_user_info = new_oauth.get_user_info()
			if auto_connect:
				connect_async()

func _ParsePacket(data : PackedByteArray) -> Array:
	var msgarr : PackedStringArray = data.get_string_from_utf8().strip_edges().split("\r\n")
	var messages : Array = []

	for str in msgarr:
		var tags : Dictionary = {}
		if str.begins_with("@"):
			var tags_end : int = str.find(" ")
			for tag in str.substr(0, tags_end + 1).split(";"):
				var pair : PackedStringArray = tag.split("=", true)
				tags[pair[0]] = pair[1]
			str = str.substr(tags_end + 1)
		messages.append({"message":str, "tags":tags})

	return messages


func _HandleMessage(msg : String, tags : Dictionary) -> void:
	# First check for the special case, PING
	if msg == PING_MESSAGE:
		send(PONG_RESPONSE)
		return
	
	var psa : PackedStringArray = msg.split(" ", true, 3)
	#_Print([psa, " | ", tags])
	match psa[1]:
		"001":
			irc_login_attempted.emit(true)
			for channel in _channels:
				join_channel(channel)
		"NOTICE":
			if psa[3] == ":Login authentication failed" or psa[3] == "Login unsuccessful":
				irc_login_attempted.emit(false)
			elif psa[3] == "You don't have permission to perform that action":
				irc_permission_denied.emit()
		"PRIVMSG", "WHISPER":
			var usr : String = user_regex.search(psa[0]).get_string()
			var channel : String = psa[2].right(-1)
			var muser : GSMCUser = null
			var uid : String = "%s:%s"%[usr, channel]
			if GSMC.has_user(SERVICE_NAME, uid):
				muser = GSMC.get_user(SERVICE_NAME, uid)
			else:
				muser = GSMC.store_user(SERVICE_NAME, uid, {
					"username":usr,
					"owner":usr == initial_channel,
					"meta":{"channel":channel},
					"send":(func(msg : String): say(channel, msg)),
					"reply":(func(msg : String): say(channel, msg, usr))
				})
			var mmsg : GSMCMessage = GSMC.store_message(
				SERVICE_NAME, uid, psa[3].right(-1), {
					"whisper": psa[1] == "WHISPER",
					"meta": tags,
					"send": (
						func(msg : String):
							if not "id" in tags: return
							reply(tags["id"], usr, msg))
				})
			message_received.emit(mmsg)
		"RECONNECT":
			_reconnecting = true
		"JOIN", "PART":
			var usr : String = user_regex.search(psa[0]).get_string()
			var channels : PackedStringArray = psa[2].split(" ")
			for channel in channels:
				var uid : String = "%s:%s"%[usr, channel]
				if psa[1] == "JOIN":
					GSMC.set_user_active(SERVICE_NAME, uid)
					channel_joined.emit(usr, channel.strip_edges().right(channel.length() - 1))
				else:
					GSMC.set_user_active(SERVICE_NAME, uid, false)
					channel_left.emit(usr, channel.strip_edges().right(channel.length() - 1))
		"USERNOTICE":
			var channels : PackedStringArray = psa[2].split(" ")
			for channel in channels:
				if not "login" in tags or not "msg-id" in tags: continue
				var usr : String = tags["login"]
				var uid : String = "%s:%s"%[usr, channel]
				var state : String = tags["msg-id"]
				if (state == "sub" or state == "resub") and GSMC.has_user(SERVICE_NAME, uid):
					var user : GSMCUser = GSMC.get_user(SERVICE_NAME, uid)
					user.set_meta("subscriber", "1")
				user_notice_sent.emit(channel, psa[3], tags)
		"ROOMSTATE":
			pass
		_:
			unhandled_message.emit(msg, tags)

# ------------------------------------------------------------------------------
# Public Methods
# ------------------------------------------------------------------------------
func connect_async() -> void:
	if _user_info.is_empty(): return
	if _websocket != null: return
	
	_Print(["Connecting Async"])
	_websocket = WebSocketPeer.new()
	_websocket.connect_to_url(TWITCH_IRC_ADDRESS)
	await(irc_connected)
	_Print(["IRC Connected: ", _user_info])
	send("PASS oauth:%s"%[_user_info["access_token"]])
	send("NICK %s"%[_user_info["username"].to_lower()])
	var success : bool = await(irc_login_attempted)
	_Print(["Login response status: ", success])
	if not success:
		_websocket.close()
		_websocket = null
		_connected = false
	else:
		send("CAP REQ :twitch.tv/commands twitch.tv/membership twitch.tv/tags")

func send(text : String) -> void:
	if _websocket == null: return
	_websocket.send_text(text)

func say(channel : String, msg : String, mention : String = "") -> void:
	if not mention.is_empty():
		mention = "#%s"%[mention]
	send("PRIVMSG #%s :%s %s"%[channel, mention, msg])

func reply(id : String, username : String, msg : String) -> void:
	send("@reply-parent-msg-id=%s PRIVMSG #%s :%s"%[id, username, msg])

func join_channel(channel_name : String) -> void:
	if _channels.find(channel_name) < 0:
		_channels.append(channel_name)
	send("JOIN #%s"%[channel_name])

# ------------------------------------------------------------------------------
# Handler Methods
# ------------------------------------------------------------------------------
func _on_user_token_valid(oauth : OT4G_OAuth) -> void:
	_user_info = oauth.get_user_info()
	if auto_connect:
		connect_async()

func _on_user_token_invalid() -> void:
	_user_info = {}
	_websocket.close()
	_websocket = null


