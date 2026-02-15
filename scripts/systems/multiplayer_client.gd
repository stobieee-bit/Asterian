## MultiplayerClient — WebSocket multiplayer client for Asterian
##
## Connects to the Asterian WebSocket server and syncs player state, chat,
## combat events, and remote player rendering. Ported from multiplayer.js.
##
## Public API:
##   connect_to_server(url, player_name) — connect with a display name
##   disconnect_from_server()            — graceful disconnect
##   is_connected() -> bool              — check connection state
##   send_chat(text)                     — broadcast chat message
##   send_attack(enemy_id, damage, style)— broadcast attack event
##   send_kill(enemy_id)                 — broadcast enemy kill event
##
## Added to group "multiplayer_client" so other nodes can find it via:
##   get_tree().get_first_node_in_group("multiplayer_client")
extends Node

# ── Constants ──

const SERVER_URL_DEFAULT: String = "wss://asterian-server.onrender.com"
const POSITION_SYNC_INTERVAL: float = 0.1        ## 10 updates per second
const INTERPOLATION_SPEED: float = 10.0           ## Lerp speed for remote players
const MAX_RECONNECT_DELAY: float = 30.0           ## Cap for exponential backoff
const INITIAL_RECONNECT_DELAY: float = 1.0        ## Starting backoff delay
const CHAT_MAX_LENGTH: int = 200                  ## Max characters per chat message
const NAMEPLATE_Y_OFFSET: float = 2.6             ## Height above remote player origin
const CONNECTION_TIMEOUT: float = 15.0              ## Seconds before treating connect as failed

## Combat style → color mapping for remote player tinting
const STYLE_COLORS: Dictionary = {
	"nano": Color(0.2, 0.9, 0.3),     # Green
	"tesla": Color(0.2, 0.4, 1.0),    # Blue
	"void": Color(0.7, 0.2, 0.9),     # Purple
}
const DEFAULT_STYLE_COLOR: Color = Color(0.6, 0.6, 0.6)  # Grey fallback

# ── WebSocket ──

var _ws: WebSocketPeer = WebSocketPeer.new()
var _connected: bool = false
var _server_url: String = ""
var _player_name: String = ""
var _my_id: String = ""

# ── Reconnection ──

var _should_reconnect: bool = false
var _reconnect_delay: float = INITIAL_RECONNECT_DELAY
var _reconnect_timer: float = 0.0
var _reconnecting: bool = false
var _connect_timeout_timer: float = 0.0

# ── Position sync ──

var _position_timer: float = 0.0
var _last_sent_x: float = 0.0
var _last_sent_z: float = 0.0
var _last_sent_ry: float = 0.0
var _last_sent_moving: bool = false

# ── Stats & equipment change detection ──

var _last_stats_hash: String = ""
var _last_equip_hash: String = ""

# ── Remote players ──
## Dictionary keyed by server-assigned id string.
## Each value is a Dictionary:
##   {
##     "node": Node3D,
##     "nameplate": Label3D,
##     "body": CSGCylinder3D,
##     "head": CSGSphere3D,
##     "target_x": float,
##     "target_z": float,
##     "target_ry": float,
##     "moving": bool,
##     "stats": Dictionary,
##     "equipment": Dictionary,
##   }
var _remote_players: Dictionary = {}

# ── Cached node references ──

var _player_node: CharacterBody3D = null

# ──────────────────────────────────────────────
#  Lifecycle
# ──────────────────────────────────────────────

func _ready() -> void:
	add_to_group("multiplayer_client")

	# Connect to EventBus signals for automatic broadcasting
	EventBus.item_equipped.connect(_on_equipment_changed)
	EventBus.item_unequipped.connect(_on_equipment_changed)
	EventBus.player_level_up.connect(_on_stats_changed)
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.player_healed.connect(_on_player_healed)
	EventBus.player_moved_to_area.connect(_on_area_changed)
	EventBus.dungeon_started.connect(_on_dungeon_visibility_changed)
	EventBus.dungeon_exited.connect(_on_dungeon_visibility_changed_no_args)

	# Auto-connect on startup — use saved name or generate one
	var mp_name: String = str(GameState.settings.get("mp_name", ""))
	if mp_name == "":
		# Generate a default name: "Player" + random 4 digits
		mp_name = "Player%04d" % (randi() % 10000)
		GameState.settings["mp_name"] = mp_name
	var url: String = str(GameState.settings.get("mp_server", SERVER_URL_DEFAULT))
	# Defer connection to let the rest of the scene tree finish loading
	call_deferred("connect_to_server", url, mp_name)


func _process(delta: float) -> void:
	# Cache player node reference once available
	if _player_node == null:
		_player_node = get_tree().get_first_node_in_group("player") as CharacterBody3D

	# Poll WebSocket every frame (required by Godot 4.4 WebSocketPeer)
	_ws.poll()

	var state: int = _ws.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		# Process all incoming packets
		while _ws.get_available_packet_count() > 0:
			var pkt: PackedByteArray = _ws.get_packet()
			var text: String = pkt.get_string_from_utf8()
			_handle_message(text)

		# Position sync tick
		_position_timer += delta
		if _position_timer >= POSITION_SYNC_INTERVAL:
			_position_timer -= POSITION_SYNC_INTERVAL
			_send_position()

		# Stats & equipment change detection (checked every frame, sends only on change)
		_check_stats_changed()
		_check_equipment_changed()

	elif state == WebSocketPeer.STATE_CLOSING:
		pass  # Wait for the close handshake to finish

	elif state == WebSocketPeer.STATE_CLOSED:
		if _connected:
			_on_connection_closed()

	elif state == WebSocketPeer.STATE_CONNECTING:
		# Track connection timeout — server may be asleep (Render free tier)
		_connect_timeout_timer += delta
		if _connect_timeout_timer >= CONNECTION_TIMEOUT:
			_connect_timeout_timer = 0.0
			_ws.close()
			EventBus.chat_message.emit("Connection timed out. Server may be waking up — retrying...", "system")
			if _should_reconnect:
				_schedule_reconnect()

	# Handle reconnection timer
	if _reconnecting:
		_reconnect_timer -= delta
		if _reconnect_timer <= 0.0:
			_reconnecting = false
			_attempt_connect()

	# Interpolate remote player positions
	_interpolate_remote_players(delta)

	# Toggle remote player visibility based on dungeon state
	_update_remote_visibility()

# ──────────────────────────────────────────────
#  Public API
# ──────────────────────────────────────────────

## Connect to the Asterian WebSocket server.
## [param url] WebSocket server URL (e.g. "wss://asterian-server.onrender.com")
## [param player_name] Display name for this player
func connect_to_server(url: String, player_name: String) -> void:
	if _connected:
		push_warning("MultiplayerClient: Already connected. Disconnect first.")
		return

	_server_url = url
	_player_name = player_name
	_should_reconnect = true
	_reconnect_delay = INITIAL_RECONNECT_DELAY

	# Save name to settings for auto-reconnect on next session
	GameState.settings["mp_name"] = player_name

	_attempt_connect()


## Disconnect from the server gracefully.
func disconnect_from_server() -> void:
	_should_reconnect = false
	_reconnecting = false

	if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.close()

	_cleanup_all_remote_players()

	if _connected:
		_connected = false
		EventBus.chat_message.emit("Disconnected from multiplayer.", "system")
		EventBus.multiplayer_disconnected.emit()


## Returns true if currently connected and authenticated with the server.
## Named is_mp_connected to avoid collision with Godot's Object.is_connected(signal, callable).
func is_mp_connected() -> bool:
	return _connected


## Send a chat message to all players.
## [param text] Message text (clamped to 200 characters)
func send_chat(text: String) -> void:
	if not _connected:
		EventBus.chat_message.emit("Not connected to multiplayer.", "system")
		return
	if text.length() == 0:
		return

	var clamped_text: String = text.substr(0, CHAT_MAX_LENGTH)
	_send({"type": "chat", "text": clamped_text})


## Broadcast an attack event to other players.
## [param enemy_id] The enemy type being attacked
## [param damage] Damage dealt
## [param style] Combat style used (nano, tesla, void)
func send_attack(enemy_id: String, damage: int, style: String) -> void:
	if not _connected:
		return
	var pos_x: float = 0.0
	var pos_z: float = 0.0
	if _player_node != null:
		pos_x = snapped(_player_node.global_position.x, 0.01)
		pos_z = snapped(_player_node.global_position.z, 0.01)
	_send({
		"type": "attack",
		"enemyId": enemy_id,
		"damage": damage,
		"style": style,
		"x": pos_x,
		"z": pos_z,
	})


## Broadcast an enemy kill event to other players.
## [param enemy_id] The enemy type that was killed
func send_kill(enemy_id: String) -> void:
	if not _connected:
		return
	_send({"type": "enemyKill", "enemyId": enemy_id})

# ──────────────────────────────────────────────
#  Connection management
# ──────────────────────────────────────────────

## Attempt to open a WebSocket connection to the server.
func _attempt_connect() -> void:
	print("MultiplayerClient: Connecting to %s ..." % _server_url)
	EventBus.chat_message.emit("Connecting to multiplayer...", "system")

	# Reset the peer and timeout timer
	_ws = WebSocketPeer.new()
	_connect_timeout_timer = 0.0

	var err: int = _ws.connect_to_url(_server_url)
	if err != OK:
		push_warning("MultiplayerClient: connect_to_url failed with error %d" % err)
		_schedule_reconnect()
		return

	# The STATE_OPEN transition will be caught in _process → _handle_message
	# once the server sends "welcome".


## Called when the WebSocket transitions to STATE_CLOSED.
func _on_connection_closed() -> void:
	var was_connected: bool = _connected
	_connected = false
	_my_id = ""

	_cleanup_all_remote_players()

	if was_connected:
		EventBus.chat_message.emit("Lost connection to multiplayer.", "system")
		EventBus.multiplayer_disconnected.emit()

	if _should_reconnect:
		_schedule_reconnect()


## Schedule a reconnection attempt with exponential backoff.
func _schedule_reconnect() -> void:
	_reconnect_timer = _reconnect_delay
	_reconnecting = true
	print("MultiplayerClient: Reconnecting in %.1f seconds..." % _reconnect_delay)
	_reconnect_delay = minf(_reconnect_delay * 2.0, MAX_RECONNECT_DELAY)

# ──────────────────────────────────────────────
#  Sending
# ──────────────────────────────────────────────

## Send a JSON dictionary to the server.
func _send(data: Dictionary) -> void:
	if _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_ws.send_text(JSON.stringify(data))


## Send the join message (called once on open).
func _send_join() -> void:
	_send({"type": "join", "name": _player_name})


## Send current position to the server (called at 10 Hz).
func _send_position() -> void:
	if not _connected:
		return
	if _player_node == null:
		return

	var px: float = snapped(_player_node.global_position.x, 0.01)
	var pz: float = snapped(_player_node.global_position.z, 0.01)
	var ry: float = snapped(_player_node.rotation.y, 0.01)
	var moving: bool = _player_node.is_moving if "is_moving" in _player_node else false

	# Only send if something actually changed
	if px == _last_sent_x and pz == _last_sent_z and ry == _last_sent_ry and moving == _last_sent_moving:
		return

	_last_sent_x = px
	_last_sent_z = pz
	_last_sent_ry = ry
	_last_sent_moving = moving

	_send({
		"type": "move",
		"x": px,
		"z": pz,
		"ry": ry,
		"moving": moving,
	})


## Build a stats hash string for change detection.
func _build_stats_hash() -> String:
	var level: int = GameState.get_combat_level()
	var style: String = str(GameState.player.get("combat_style", "nano"))
	var hp: int = int(GameState.player.get("hp", 100))
	var max_hp: int = int(GameState.player.get("max_hp", 100))
	var area: String = GameState.current_area
	return "%d|%s|%d|%d|%s" % [level, style, hp, max_hp, area]


## Check if stats changed and send update if so.
func _check_stats_changed() -> void:
	if not _connected:
		return
	var current_hash: String = _build_stats_hash()
	if current_hash == _last_stats_hash:
		return
	_last_stats_hash = current_hash

	_send({
		"type": "stats",
		"level": GameState.get_combat_level(),
		"combatStyle": str(GameState.player.get("combat_style", "nano")),
		"hp": int(GameState.player.get("hp", 100)),
		"maxHp": int(GameState.player.get("max_hp", 100)),
		"area": GameState.current_area,
	})


## Build an equipment hash string for change detection.
func _build_equip_hash() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for slot in GameState.equipment:
		parts.append("%s=%s" % [slot, str(GameState.equipment[slot])])
	return "|".join(parts)


## Check if equipment changed and send update if so.
func _check_equipment_changed() -> void:
	if not _connected:
		return
	var current_hash: String = _build_equip_hash()
	if current_hash == _last_equip_hash:
		return
	_last_equip_hash = current_hash

	var equip_data: Dictionary = {}
	for slot in GameState.equipment:
		var item_id: String = str(GameState.equipment[slot])
		if item_id == "":
			continue
		var item_info: Dictionary = DataManager.get_item(item_id)
		var entry: Dictionary = {
			"id": item_id,
			"tier": int(item_info.get("tier", 1)),
		}
		# Weapon also gets a style field
		if slot == "weapon":
			entry["style"] = str(item_info.get("style", str(GameState.player.get("combat_style", "nano"))))
		equip_data[slot] = entry

	_send({
		"type": "equip",
		"equipment": equip_data,
	})

# ──────────────────────────────────────────────
#  Receiving
# ──────────────────────────────────────────────

## Parse and route an incoming JSON message from the server.
func _handle_message(raw: String) -> void:
	var parsed: Variant = JSON.parse_string(raw)
	if parsed == null or not (parsed is Dictionary):
		push_warning("MultiplayerClient: Malformed message: %s" % raw.substr(0, 120))
		return

	var msg: Dictionary = parsed as Dictionary
	var msg_type: String = str(msg.get("type", ""))

	match msg_type:
		"welcome":
			_handle_welcome(msg)
		"join":
			_handle_player_join(msg)
		"leave":
			_handle_player_leave(msg)
		"move":
			_handle_player_move(msg)
		"chat":
			_handle_chat(msg)
		"stats":
			_handle_stats(msg)
		"equip":
			_handle_equip(msg)
		"attack":
			_handle_remote_attack(msg)
		"enemyKill":
			_handle_remote_kill(msg)
		"ping":
			_send({"type": "pong"})
		"error":
			var error_msg: String = str(msg.get("msg", "Unknown server error"))
			push_warning("MultiplayerClient: Server error: %s" % error_msg)
			EventBus.chat_message.emit("Server: %s" % error_msg, "system")
		_:
			pass  # Ignore unknown message types


## Handle the "welcome" message — server accepted our join.
func _handle_welcome(msg: Dictionary) -> void:
	_my_id = str(msg.get("id", ""))
	_connected = true
	_reconnect_delay = INITIAL_RECONNECT_DELAY  # Reset backoff on success

	# Send join message now that connection is open
	_send_join()

	# Spawn existing players
	var players: Array = msg.get("players", []) as Array
	for p in players:
		var pid: String = str(p.get("id", ""))
		if pid == "" or pid == _my_id:
			continue
		_spawn_remote_player(pid, p)

	var player_count: int = players.size() + 1  # Include self
	EventBus.chat_message.emit("Connected to multiplayer! %d player(s) online." % player_count, "system")
	EventBus.multiplayer_connected.emit(player_count)

	# Force-send initial stats and equipment
	_last_stats_hash = ""
	_last_equip_hash = ""
	_check_stats_changed()
	_check_equipment_changed()

	print("MultiplayerClient: Connected as '%s' (id: %s), %d others online." % [_player_name, _my_id, players.size()])


## Handle another player joining the server.
func _handle_player_join(msg: Dictionary) -> void:
	var pid: String = str(msg.get("id", ""))
	if pid == "" or pid == _my_id:
		return
	var pname: String = str(msg.get("name", "Unknown"))

	_spawn_remote_player(pid, msg)

	EventBus.chat_message.emit("%s joined the server." % pname, "multiplayer")
	EventBus.multiplayer_player_joined.emit(pname)


## Handle another player leaving the server.
func _handle_player_leave(msg: Dictionary) -> void:
	var pid: String = str(msg.get("id", ""))
	if pid == "":
		return

	var pname: String = "Unknown"
	if _remote_players.has(pid):
		var info: Dictionary = _remote_players[pid]
		var stats: Dictionary = info.get("stats", {}) as Dictionary
		pname = str(stats.get("name", "Unknown"))

	_remove_remote_player(pid)

	EventBus.chat_message.emit("%s left the server." % pname, "multiplayer")
	EventBus.multiplayer_player_left.emit(pname)


## Handle a remote player's position update.
func _handle_player_move(msg: Dictionary) -> void:
	var pid: String = str(msg.get("id", ""))
	if pid == "" or pid == _my_id:
		return
	if not _remote_players.has(pid):
		return

	var info: Dictionary = _remote_players[pid]
	info["target_x"] = float(msg.get("x", info.get("target_x", 0.0)))
	info["target_z"] = float(msg.get("z", info.get("target_z", 0.0)))
	info["target_ry"] = float(msg.get("ry", info.get("target_ry", 0.0)))
	info["moving"] = bool(msg.get("moving", false))


## Handle a remote chat message.
func _handle_chat(msg: Dictionary) -> void:
	var sender_name: String = str(msg.get("name", "Unknown"))
	var text: String = str(msg.get("text", ""))
	if text.length() == 0:
		return

	EventBus.chat_message.emit("%s: %s" % [sender_name, text], "multiplayer")


## Handle a remote player's stats update.
func _handle_stats(msg: Dictionary) -> void:
	var pid: String = str(msg.get("id", ""))
	if pid == "" or pid == _my_id:
		return
	if not _remote_players.has(pid):
		return

	var info: Dictionary = _remote_players[pid]
	var stats: Dictionary = msg.get("stats", {}) as Dictionary
	info["stats"] = stats

	# Update nameplate text
	var nameplate: Label3D = info.get("nameplate") as Label3D
	if nameplate != null:
		var display_name: String = str(stats.get("name", info["stats"].get("name", "Player")))
		var level: int = int(stats.get("level", 1))
		nameplate.text = "%s (Lv %d)" % [display_name, level]

	# Update body color based on combat style
	var style: String = str(stats.get("combatStyle", "nano"))
	_tint_remote_player(info, style)


## Handle a remote player's equipment update.
func _handle_equip(msg: Dictionary) -> void:
	var pid: String = str(msg.get("id", ""))
	if pid == "" or pid == _my_id:
		return
	if not _remote_players.has(pid):
		return

	var info: Dictionary = _remote_players[pid]
	info["equipment"] = msg.get("equipment", {}) as Dictionary


## Handle a remote player attacking an enemy.
func _handle_remote_attack(msg: Dictionary) -> void:
	var pid: String = str(msg.get("id", ""))
	if pid == "" or pid == _my_id:
		return

	var damage: int = int(msg.get("damage", 0))
	var attacker_name: String = str(msg.get("name", "Player"))
	var style: String = str(msg.get("style", "nano"))

	# Show float text at the remote player's position if they exist
	if _remote_players.has(pid):
		var info: Dictionary = _remote_players[pid]
		var node: Node3D = info.get("node") as Node3D
		if node != null:
			var float_pos: Vector3 = node.global_position + Vector3(0, 2.0, 0)
			var dmg_color: Color = STYLE_COLORS.get(style, DEFAULT_STYLE_COLOR)
			EventBus.float_text_requested.emit(str(damage), float_pos, dmg_color)


## Handle a remote player killing an enemy.
func _handle_remote_kill(msg: Dictionary) -> void:
	var killer_name: String = str(msg.get("name", "Player"))
	var enemy_id: String = str(msg.get("enemyId", "unknown"))

	# Try to get a display-friendly enemy name from DataManager
	var enemy_data: Dictionary = DataManager.get_enemy(enemy_id)
	var enemy_name: String = str(enemy_data.get("name", enemy_id))

	EventBus.chat_message.emit("%s defeated %s!" % [killer_name, enemy_name], "multiplayer")

# ──────────────────────────────────────────────
#  Remote player rendering
# ──────────────────────────────────────────────

## Spawn a visual representation of a remote player.
func _spawn_remote_player(pid: String, data: Dictionary) -> void:
	if _remote_players.has(pid):
		return  # Already exists

	var root: Node3D = Node3D.new()
	root.name = "RemotePlayer_%s" % pid

	# --- Body (cylinder) ---
	var body: CSGCylinder3D = CSGCylinder3D.new()
	body.name = "Body"
	body.radius = 0.35
	body.height = 1.6
	body.sides = 12
	body.material = StandardMaterial3D.new()
	(body.material as StandardMaterial3D).albedo_color = DEFAULT_STYLE_COLOR
	body.position = Vector3(0, 0.8, 0)
	root.add_child(body)

	# --- Head (sphere) ---
	var head: CSGSphere3D = CSGSphere3D.new()
	head.name = "Head"
	head.radius = 0.3
	head.radial_segments = 12
	head.rings = 6
	head.material = StandardMaterial3D.new()
	(head.material as StandardMaterial3D).albedo_color = Color(0.9, 0.8, 0.7)  # Skin tone
	head.position = Vector3(0, 1.9, 0)
	root.add_child(head)

	# --- Nameplate (Label3D) ---
	var nameplate: Label3D = Label3D.new()
	nameplate.name = "Nameplate"
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate.no_depth_test = true
	nameplate.font_size = 32
	nameplate.outline_size = 6
	nameplate.modulate = Color(1, 1, 1, 1)
	nameplate.outline_modulate = Color(0, 0, 0, 1)
	nameplate.position = Vector3(0, NAMEPLATE_Y_OFFSET, 0)
	nameplate.pixel_size = 0.005

	# Set initial nameplate text
	var display_name: String = str(data.get("name", "Player"))
	var stats: Dictionary = data.get("stats", {}) as Dictionary
	var level: int = int(stats.get("level", 1))
	nameplate.text = "%s (Lv %d)" % [display_name, level]

	root.add_child(nameplate)

	# Set initial position
	var start_x: float = float(data.get("x", 0.0))
	var start_z: float = float(data.get("z", 0.0))
	var start_ry: float = float(data.get("ry", 0.0))
	root.position = Vector3(start_x, 0, start_z)
	root.rotation.y = start_ry

	# Add to scene tree
	add_child(root)

	# Store in tracking dictionary
	var info: Dictionary = {
		"node": root,
		"nameplate": nameplate,
		"body": body,
		"head": head,
		"target_x": start_x,
		"target_z": start_z,
		"target_ry": start_ry,
		"moving": bool(data.get("moving", false)),
		"stats": stats,
		"equipment": data.get("equipment", {}) as Dictionary,
		"name": display_name,
	}
	_remote_players[pid] = info

	# Apply initial combat style tint
	var style: String = str(stats.get("combatStyle", str(data.get("combatStyle", "nano"))))
	_tint_remote_player(info, style)


## Remove a remote player's visual and tracking data.
func _remove_remote_player(pid: String) -> void:
	if not _remote_players.has(pid):
		return

	var info: Dictionary = _remote_players[pid]
	var node: Node3D = info.get("node") as Node3D
	if node != null and is_instance_valid(node):
		node.queue_free()

	_remote_players.erase(pid)


## Remove all remote players (on disconnect or reconnect).
func _cleanup_all_remote_players() -> void:
	for pid in _remote_players.keys():
		var info: Dictionary = _remote_players[pid]
		var node: Node3D = info.get("node") as Node3D
		if node != null and is_instance_valid(node):
			node.queue_free()
	_remote_players.clear()


## Tint a remote player's body cylinder to match their combat style.
func _tint_remote_player(info: Dictionary, style: String) -> void:
	var body: CSGCylinder3D = info.get("body") as CSGCylinder3D
	if body == null:
		return
	var mat: StandardMaterial3D = body.material as StandardMaterial3D
	if mat == null:
		return
	mat.albedo_color = STYLE_COLORS.get(style, DEFAULT_STYLE_COLOR)


## Smoothly interpolate all remote players toward their target positions.
func _interpolate_remote_players(delta: float) -> void:
	for pid in _remote_players:
		var info: Dictionary = _remote_players[pid]
		var node: Node3D = info.get("node") as Node3D
		if node == null or not is_instance_valid(node):
			continue

		var target_x: float = float(info.get("target_x", 0.0))
		var target_z: float = float(info.get("target_z", 0.0))
		var target_ry: float = float(info.get("target_ry", 0.0))

		var current_pos: Vector3 = node.position
		var target_pos: Vector3 = Vector3(target_x, current_pos.y, target_z)
		node.position = current_pos.lerp(target_pos, INTERPOLATION_SPEED * delta)

		# Smooth rotation interpolation
		node.rotation.y = lerp_angle(node.rotation.y, target_ry, INTERPOLATION_SPEED * delta)


## Show or hide remote players when entering/exiting a dungeon.
func _update_remote_visibility() -> void:
	var in_dungeon: bool = GameState.dungeon_active
	for pid in _remote_players:
		var info: Dictionary = _remote_players[pid]
		var node: Node3D = info.get("node") as Node3D
		if node != null and is_instance_valid(node):
			node.visible = not in_dungeon

# ──────────────────────────────────────────────
#  EventBus signal handlers
# ──────────────────────────────────────────────

## Triggered when equipment changes — schedule an equipment sync.
func _on_equipment_changed(_slot: String, _item_id: String) -> void:
	# Change detection in _check_equipment_changed will pick this up next frame
	pass


## Triggered when player levels up — schedule a stats sync.
func _on_stats_changed(_skill: String, _new_level: int) -> void:
	# Change detection in _check_stats_changed will pick this up next frame
	pass


## Triggered when player takes damage — stats sync needed.
## Signature matches EventBus.player_damaged(amount: int, source: String)
func _on_player_damaged(_amount: int, _source: String) -> void:
	# Change detection in _check_stats_changed will pick this up next frame
	pass


## Triggered when player heals — stats sync needed.
## Signature matches EventBus.player_healed(amount: int)
func _on_player_healed(_amount: int) -> void:
	# Change detection in _check_stats_changed will pick this up next frame
	pass


## Triggered when player moves to a new area — stats sync needed.
func _on_area_changed(_area_id: String) -> void:
	# Change detection in _check_stats_changed will pick this up next frame
	pass


## Triggered when a dungeon starts — hide remote players.
func _on_dungeon_visibility_changed(_floor_data: Dictionary) -> void:
	# Visibility updated in _update_remote_visibility each frame
	pass


## Triggered when a dungeon exits — show remote players.
func _on_dungeon_visibility_changed_no_args() -> void:
	# Visibility updated in _update_remote_visibility each frame
	pass
