## DimensionalWeavingSystem — Thread anchors, construct placement, spatial folds
##
## Manages placed constructs (snares, shields, barriers), ticking their expiry.
## Expired constructs yield entropic_residue (cross-skill → Entropy Engineering).
## Spatial folds provide instant teleportation with limited uses.
extends Node

# ── Constants ──
const CONSTRUCT_TICK_INTERVAL: float = 1.0
const SNARE_RADIUS: float = 4.0
const SNARE_STUN_DURATION: float = 3.0
const SNARE_USES: int = 5
const DEFAULT_CONSTRUCT_DURATION: float = 300.0  # 5 minutes

# ── Construct durations by type ──
const CONSTRUCT_DURATIONS: Dictionary = {
    "minor_snare": 300.0,
    "spatial_fold_short": 600.0,
    "spatial_fold_medium": 600.0,
    "spatial_fold_long": 600.0,
}

# ── Spatial fold distances ──
const FOLD_DISTANCES: Dictionary = {
    "spatial_fold_short": 30.0,
    "spatial_fold_medium": 60.0,
    "spatial_fold_long": 120.0,
}

# ── State ──
var _tick_timer: float = 0.0
var _player_node: Node3D = null

func _ready() -> void:
    EventBus.buff_applied.connect(_on_buff_applied)

func _process(delta: float) -> void:
    _tick_timer += delta
    if _tick_timer >= CONSTRUCT_TICK_INTERVAL:
        _tick_timer = 0.0
        _tick_constructs()

# ── Public API: Place Construct ──

func place_construct(construct_type: String, pos: Vector3) -> bool:
    # Remove the item from inventory
    if not GameState.remove_item(construct_type, 1):
        EventBus.chat_message.emit("[Weaving] No %s in inventory." % construct_type, "system")
        return false

    var duration: float = CONSTRUCT_DURATIONS.get(construct_type, DEFAULT_CONSTRUCT_DURATION)

    # Check for level 80 bonus (50% longer duration)
    var skill_level: int = int(GameState.skills.get("dimensional_weaving", {}).get("level", 1))
    if skill_level >= 80:
        duration *= 1.5

    var uses: int = SNARE_USES if construct_type == "minor_snare" else 3
    var now: float = Time.get_unix_time_from_system()

    var construct: Dictionary = {
        "type": construct_type,
        "position": [pos.x, pos.y, pos.z],
        "uses_remaining": uses,
        "expires_at": now + duration,
    }

    GameState.active_constructs.append(construct)
    EventBus.construct_placed.emit(construct_type, pos)

    var item_data: Dictionary = DataManager.get_item(construct_type)
    var name: String = item_data.get("name", construct_type) if not item_data.is_empty() else construct_type
    EventBus.chat_message.emit("[Weaving] Placed %s (%.0fs duration)" % [name, duration], "system")

    # Award XP
    var xp_amount: int = 15 + skill_level * 2
    EventBus.player_xp_gained.emit("dimensional_weaving", xp_amount)

    return true

# ── Public API: Use Spatial Fold (teleport) ──

func use_spatial_fold(construct_index: int) -> bool:
    if construct_index < 0 or construct_index >= GameState.active_constructs.size():
        return false

    var construct: Dictionary = GameState.active_constructs[construct_index]
    var ctype: String = construct.get("type", "")

    if not FOLD_DISTANCES.has(ctype):
        EventBus.chat_message.emit("[Weaving] Not a spatial fold.", "system")
        return false

    _find_player()
    if _player_node == null:
        return false

    var distance: float = FOLD_DISTANCES[ctype]
    var forward: Vector3 = -_player_node.global_basis.z.normalized()
    forward.y = 0.0
    if forward.length() < 0.01:
        forward = Vector3.FORWARD
    forward = forward.normalized()

    var target_pos: Vector3 = _player_node.global_position + forward * distance
    target_pos.y = _player_node.global_position.y
    _player_node.global_position = target_pos

    # Decrement uses
    construct["uses_remaining"] = int(construct["uses_remaining"]) - 1
    if int(construct["uses_remaining"]) <= 0:
        _expire_construct(construct_index)
    else:
        GameState.active_constructs[construct_index] = construct

    EventBus.chat_message.emit("[Weaving] Spatial fold — teleported %.0fm forward!" % distance, "system")
    return true

# ── Public API: Nearby Snare Check (for combat integration) ──

func get_nearby_snare(pos: Vector3) -> Dictionary:
    for i in range(GameState.active_constructs.size()):
        var construct: Dictionary = GameState.active_constructs[i]
        if construct.get("type", "") != "minor_snare":
            continue
        if int(construct.get("uses_remaining", 0)) <= 0:
            continue

        var cpos_arr: Array = construct.get("position", [0, 0, 0])
        var cpos: Vector3 = Vector3(float(cpos_arr[0]), float(cpos_arr[1]), float(cpos_arr[2]))
        var dist_sq: float = pos.distance_squared_to(cpos)

        if dist_sq <= SNARE_RADIUS * SNARE_RADIUS:
            # Use up one charge
            construct["uses_remaining"] = int(construct["uses_remaining"]) - 1
            if int(construct["uses_remaining"]) <= 0:
                _expire_construct(i)
            else:
                GameState.active_constructs[i] = construct
            return { "stun_duration": SNARE_STUN_DURATION, "position": cpos }

    return {}

# ── Construct Ticking ──

func _tick_constructs() -> void:
    if GameState.active_constructs.is_empty():
        return

    var now: float = Time.get_unix_time_from_system()

    for i in range(GameState.active_constructs.size() - 1, -1, -1):
        var construct: Dictionary = GameState.active_constructs[i]
        var expires: float = float(construct.get("expires_at", 0.0))

        if now >= expires:
            _expire_construct(i)

func _expire_construct(index: int) -> void:
    if index < 0 or index >= GameState.active_constructs.size():
        return

    var construct: Dictionary = GameState.active_constructs[index]
    var ctype: String = construct.get("type", "unknown")

    GameState.active_constructs.remove_at(index)

    # Cross-skill: yield entropic_residue on expiry
    if GameState.has_inventory_space():
        GameState.add_item("entropic_residue", 1)
        EventBus.chat_message.emit("[Weaving] %s expired — entropic residue recovered." % ctype, "system")
    else:
        EventBus.chat_message.emit("[Weaving] %s expired — inventory full, residue lost." % ctype, "system")

    EventBus.construct_expired.emit(ctype)

# ── Buff Listener: Resonance Protocol reveals hidden anchors ──

func _on_buff_applied(buff_type: String, _value: float, _duration: float) -> void:
    if buff_type == "reveal_anchors":
        _find_player()
        if _player_node != null:
            EventBus.thread_anchor_revealed.emit(_player_node.global_position)
            EventBus.chat_message.emit("[Weaving] Resonance Protocol active — hidden thread anchors revealed!", "system")

# ── Helpers ──

func _find_player() -> void:
    if _player_node != null and is_instance_valid(_player_node):
        return
    var players: Array[Node] = get_tree().get_nodes_in_group("player")
    if players.size() > 0:
        _player_node = players[0] as Node3D
