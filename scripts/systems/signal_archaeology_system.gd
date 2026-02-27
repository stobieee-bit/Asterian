## SignalArchaeologySystem — Scan mode, ephemeral fragment spawning, proximity collection
##
## Press Z to toggle scan mode. While scanning, signal fragments spawn near the
## player every few seconds. Walk through them to collect. Fragment tier scales
## with Signal Archaeology skill level and current area.
extends Node3D

# ── Constants ──
const SCAN_PULSE_INTERVAL: float = 2.0
const MAX_ACTIVE_FRAGMENTS: int = 5
const COLLECT_RADIUS: float = 2.0
const BASE_XP: int = 15
const XP_PER_LEVEL: int = 3
const FRAGMENT_LIFETIME: float = 30.0

# ── Fragment tiers by level ──
const FRAGMENT_TIERS: Array[Dictionary] = [
    { "min_level": 1, "item": "alpha_signal_fragment" },
    { "min_level": 10, "item": "beta_signal_fragment" },
    { "min_level": 20, "item": "gamma_signal_fragment" },
    { "min_level": 40, "item": "delta_signal_fragment" },
    { "min_level": 60, "item": "omega_signal_fragment" },
    { "min_level": 90, "item": "primordial_signal_fragment" },
]

# ── Area level bonus (higher areas roll rarer fragments more often) ──
const AREA_LEVEL_BONUS: Dictionary = {
    "station-hub": 0,
    "asteroid-mines": 5,
    "gathering-grounds": 0,
    "mycelium-hollows": 10,
    "spore-marshes": 15,
    "hive-cluster": 20,
    "solarith-wastes": 30,
    "fungal-abyss": 35,
    "stalker-reaches": 45,
    "void-citadel": 55,
    "the-abyss": 70,
}

# ── State ──
var _scan_active: bool = false
var _pulse_timer: float = 0.0
var _active_fragments: Array[Node3D] = []
var _player_node: Node3D = null

func _ready() -> void:
    set_process(false)

func _process(delta: float) -> void:
    if not _scan_active:
        return

    _pulse_timer += delta
    if _pulse_timer >= SCAN_PULSE_INTERVAL:
        _pulse_timer = 0.0
        _try_spawn_fragment()

    _check_fragment_proximity()

# ── Public API ──

func toggle_scan() -> void:
    _scan_active = not _scan_active
    set_process(_scan_active)
    _pulse_timer = 0.0

    if not _scan_active:
        _clear_all_fragments()

    EventBus.scan_mode_toggled.emit(_scan_active)

    var state_text: String = "ON" if _scan_active else "OFF"
    EventBus.chat_message.emit("[Signal Archaeology] Scan mode: %s" % state_text, "system")

func is_scanning() -> bool:
    return _scan_active

# ── Fragment spawning ──

func _try_spawn_fragment() -> void:
    if _active_fragments.size() >= MAX_ACTIVE_FRAGMENTS:
        return

    _find_player()
    if _player_node == null:
        return

    if not GameState.has_inventory_space():
        return

    var fragment_id: String = _roll_fragment_tier()
    var spawn_pos: Vector3 = _get_spawn_position()

    var frag_node: Node3D = _create_fragment_visual(fragment_id)
    frag_node.global_position = spawn_pos
    frag_node.set_meta("fragment_id", fragment_id)
    frag_node.set_meta("spawn_time", Time.get_unix_time_from_system())
    get_tree().current_scene.add_child(frag_node)
    _active_fragments.append(frag_node)

func _roll_fragment_tier() -> String:
    var skill_level: int = int(GameState.skills.get("signal_archaeology", {}).get("level", 1))
    var area_bonus: int = AREA_LEVEL_BONUS.get(GameState.current_area, 0)
    var effective_level: int = skill_level + area_bonus

    # Roll from highest eligible tier down with decreasing probability
    var eligible: Array[Dictionary] = []
    for tier in FRAGMENT_TIERS:
        if skill_level >= int(tier["min_level"]):
            eligible.append(tier)

    if eligible.is_empty():
        return "alpha_signal_fragment"

    # Weight higher tiers less: top tier = 1, next = 2, etc.
    var weights: Array[float] = []
    var total_weight: float = 0.0
    for i in range(eligible.size()):
        var w: float = float(i + 1)
        # Boost higher tiers slightly when effective level is much higher
        if effective_level >= 50 and i == eligible.size() - 1:
            w *= 0.7  # Make top tier more common
        weights.append(w)
        total_weight += w

    var roll: float = randf() * total_weight
    var cumulative: float = 0.0
    for i in range(eligible.size()):
        cumulative += weights[i]
        if roll <= cumulative:
            return eligible[i]["item"]

    return eligible[0]["item"]

func _get_spawn_position() -> Vector3:
    var base_pos: Vector3 = _player_node.global_position
    var angle: float = randf() * TAU
    var dist: float = 4.0 + randf() * 6.0  # 4-10m from player
    return Vector3(
        base_pos.x + cos(angle) * dist,
        base_pos.y + 1.0 + randf() * 0.5,
        base_pos.z + sin(angle) * dist
    )

# ── Fragment visual ──

func _create_fragment_visual(fragment_id: String) -> Node3D:
    var root: Node3D = Node3D.new()
    root.name = "SignalFragment"

    # Glowing mesh
    var mesh_instance: MeshInstance3D = MeshInstance3D.new()
    var sphere: SphereMesh = SphereMesh.new()
    sphere.radius = 0.15
    sphere.height = 0.3
    mesh_instance.mesh = sphere

    var mat: StandardMaterial3D = StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.emission_enabled = true
    mat.emission = Color(0.2, 0.85, 1.0)
    mat.emission_energy_multiplier = 4.0
    mat.albedo_color = Color(0.2, 0.85, 1.0, 0.8)
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mesh_instance.material_override = mat

    root.add_child(mesh_instance)

    # Gentle floating bob
    var anim_tween: Tween = root.create_tween()
    anim_tween.set_loops()
    anim_tween.tween_property(mesh_instance, "position:y", 0.3, 1.0) \
        .set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
    anim_tween.tween_property(mesh_instance, "position:y", 0.0, 1.0) \
        .set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

    return root

# ── Proximity collection ──

func _check_fragment_proximity() -> void:
    _find_player()
    if _player_node == null:
        return

    var player_pos: Vector3 = _player_node.global_position
    var now: float = Time.get_unix_time_from_system()

    for i in range(_active_fragments.size() - 1, -1, -1):
        var frag: Node3D = _active_fragments[i]
        if not is_instance_valid(frag):
            _active_fragments.remove_at(i)
            continue

        # Check lifetime expiry
        var spawn_time: float = float(frag.get_meta("spawn_time", 0.0))
        if now - spawn_time > FRAGMENT_LIFETIME:
            frag.queue_free()
            _active_fragments.remove_at(i)
            continue

        # Check collection range
        var dist_sq: float = player_pos.distance_squared_to(frag.global_position)
        if dist_sq <= COLLECT_RADIUS * COLLECT_RADIUS:
            _collect_fragment(frag)
            _active_fragments.remove_at(i)

func _collect_fragment(frag_node: Node3D) -> void:
    var fragment_id: String = frag_node.get_meta("fragment_id", "alpha_signal_fragment")

    if not GameState.has_inventory_space():
        EventBus.chat_message.emit("Inventory full — cannot collect signal fragment.", "system")
        return

    GameState.add_item(fragment_id, 1)

    # Award XP
    var skill_level: int = int(GameState.skills.get("signal_archaeology", {}).get("level", 1))
    var xp_amount: int = BASE_XP + XP_PER_LEVEL * skill_level
    EventBus.player_xp_gained.emit("signal_archaeology", xp_amount)

    # Emit signal
    EventBus.signal_fragment_collected.emit(fragment_id)

    var item_data: Dictionary = DataManager.get_item(fragment_id)
    var item_name: String = item_data.get("name", fragment_id) if not item_data.is_empty() else fragment_id
    EventBus.chat_message.emit("Collected: %s (+%d XP)" % [item_name, xp_amount], "system")

    frag_node.queue_free()

# ── Cleanup ──

func _clear_all_fragments() -> void:
    for frag in _active_fragments:
        if is_instance_valid(frag):
            frag.queue_free()
    _active_fragments.clear()

func _find_player() -> void:
    if _player_node != null and is_instance_valid(_player_node):
        return
    var players: Array[Node] = get_tree().get_nodes_in_group("player")
    if players.size() > 0:
        _player_node = players[0] as Node3D
