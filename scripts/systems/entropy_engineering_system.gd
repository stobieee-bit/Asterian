## EntropyEngineeringSystem — Enemy scanning, item deconstruction, mastery tracking
##
## Entropy-scan enemies to produce echo_data (cross-skill for Signal Archaeology).
## Deconstruct items into entropic materials + thread filaments (cross-skill for
## Dimensional Weaving). Mastering enemy types grants permanent combat bonuses.
extends Node

# ── Constants ──
const SCAN_COOLDOWN: float = 3.0
const SCAN_BASE_XP: int = 20
const MASTERY_THRESHOLD: int = 50
const MASTERY_BONUS: float = 1.10   # 10% damage bonus for mastered enemies
const MASTERY_BONUS_MAX: float = 1.15  # 15% at level 99

# ── Deconstruct tier outputs ──
# item tier → { primary: item_id, amount_min, amount_max, secondary: item_id (chance) }
const DECON_OUTPUTS: Dictionary = {
    1: { "primary": "entropic_dust", "min": 1, "max": 2 },
    2: { "primary": "entropic_dust", "min": 2, "max": 4 },
    3: { "primary": "entropic_shard", "min": 1, "max": 2 },
    4: { "primary": "entropic_shard", "min": 2, "max": 3 },
    5: { "primary": "entropic_core", "min": 1, "max": 1 },
    6: { "primary": "entropic_core", "min": 1, "max": 2 },
    7: { "primary": "entropic_core", "min": 2, "max": 3, "bonus": "decay_catalyst", "bonus_chance": 0.1 },
    8: { "primary": "entropic_core", "min": 3, "max": 4, "bonus": "decay_catalyst", "bonus_chance": 0.15 },
    9: { "primary": "entropic_core", "min": 4, "max": 6, "bonus": "decay_catalyst", "bonus_chance": 0.25 },
}

# ── State ──
var _scan_cooldown_timer: float = 0.0

func _ready() -> void:
    pass

func _process(delta: float) -> void:
    if _scan_cooldown_timer > 0.0:
        _scan_cooldown_timer -= delta

# ── Public API: Entropy Scan ──

func entropy_scan_enemy(enemy_node: Node) -> void:
    if _scan_cooldown_timer > 0.0:
        var remaining: float = snappedf(_scan_cooldown_timer, 0.1)
        EventBus.chat_message.emit("[Entropy] Scan on cooldown (%.1fs)" % remaining, "system")
        return

    if enemy_node == null or not is_instance_valid(enemy_node):
        return

    var enemy_id: String = ""
    if "enemy_id" in enemy_node:
        enemy_id = str(enemy_node.enemy_id)
    elif "id" in enemy_node:
        enemy_id = str(enemy_node.id)
    else:
        EventBus.chat_message.emit("[Entropy] Cannot identify target.", "system")
        return

    _scan_cooldown_timer = SCAN_COOLDOWN

    # Increment scan count
    var scan_count: int = int(GameState.entropy_scans.get(enemy_id, 0)) + 1
    GameState.entropy_scans[enemy_id] = scan_count

    # Award XP
    var skill_level: int = int(GameState.skills.get("entropy_engineering", {}).get("level", 1))
    var xp_amount: int = SCAN_BASE_XP + skill_level * 2
    EventBus.player_xp_gained.emit("entropy_engineering", xp_amount)

    # Produce echo_data (cross-skill → Signal Archaeology)
    if GameState.has_inventory_space():
        GameState.add_item("echo_data", 1)
        EventBus.chat_message.emit("[Entropy] Scanned %s — echo data acquired (+%d XP)" % [enemy_id, xp_amount], "system")
    else:
        EventBus.chat_message.emit("[Entropy] Scanned %s (+%d XP) — inventory full, echo data lost!" % [enemy_id, xp_amount], "system")

    EventBus.entropy_scan_performed.emit(enemy_id, scan_count)

    # Check mastery threshold
    if scan_count >= MASTERY_THRESHOLD and not GameState.entropy_mastery.has(enemy_id):
        GameState.entropy_mastery[enemy_id] = true
        EventBus.entropy_mastery_unlocked.emit(enemy_id)
        EventBus.chat_message.emit("[Entropy] MASTERY UNLOCKED: %s — permanent combat bonus!" % enemy_id, "system")

# ── Public API: Item Deconstruction ──

func deconstruct_item(item_id: String) -> Dictionary:
    var item_data: Dictionary = DataManager.get_item(item_id)
    if item_data.is_empty():
        EventBus.chat_message.emit("[Entropy] Unknown item.", "system")
        return {}

    var tier: int = int(item_data.get("tier", 1))
    var skill_level: int = int(GameState.skills.get("entropy_engineering", {}).get("level", 1))

    # Check skill level requirement (need ~tier*10 level to decon high tiers)
    var required_level: int = maxi(1, tier * 8)
    if skill_level < required_level:
        EventBus.chat_message.emit("[Entropy] Need Entropy Engineering level %d to deconstruct tier %d items." % [required_level, tier], "system")
        return {}

    # Remove the item from inventory
    if not GameState.remove_item(item_id, 1):
        EventBus.chat_message.emit("[Entropy] Item not in inventory.", "system")
        return {}

    var outputs: Dictionary = {}
    var decon_data: Dictionary = DECON_OUTPUTS.get(tier, DECON_OUTPUTS[1])

    # Primary output
    var primary_id: String = decon_data["primary"]
    var amount: int = randi_range(int(decon_data["min"]), int(decon_data["max"]))

    # Check for Decay Protocol buff (doubles yield)
    var entropy_buff: float = GameState.get_buff_value("entropy_yield")
    if entropy_buff > 0.0:
        amount *= 2

    GameState.add_item(primary_id, amount)
    outputs[primary_id] = amount

    # Cross-skill: chance to yield thread filaments for Dimensional Weaving
    if randf() < 0.35:
        GameState.add_item("minor_thread_filament", 1)
        outputs["minor_thread_filament"] = 1

    # Bonus output (decay_catalyst at high tiers)
    if decon_data.has("bonus") and randf() < float(decon_data.get("bonus_chance", 0.0)):
        var bonus_id: String = decon_data["bonus"]
        GameState.add_item(bonus_id, 1)
        outputs[bonus_id] = 1

    # Award XP (scales with tier)
    var xp_amount: int = 10 + tier * 12 + skill_level
    EventBus.player_xp_gained.emit("entropy_engineering", xp_amount)

    EventBus.item_deconstructed.emit(item_id, outputs)

    var item_name: String = item_data.get("name", item_id)
    EventBus.chat_message.emit("[Entropy] Deconstructed %s (+%d XP)" % [item_name, xp_amount], "system")

    return outputs

# ── Public API: Mastery Bonus ──

func get_mastery_bonus(enemy_id: String) -> float:
    if not GameState.entropy_mastery.has(enemy_id):
        return 1.0
    var skill_level: int = int(GameState.skills.get("entropy_engineering", {}).get("level", 1))
    if skill_level >= 99:
        return MASTERY_BONUS_MAX
    return MASTERY_BONUS

# ── Public API: Can Deconstruct ──

func can_deconstruct(item_id: String) -> bool:
    var item_data: Dictionary = DataManager.get_item(item_id)
    if item_data.is_empty():
        return false
    var tier: int = int(item_data.get("tier", 1))
    var skill_level: int = int(GameState.skills.get("entropy_engineering", {}).get("level", 1))
    var required_level: int = maxi(1, tier * 8)
    return skill_level >= required_level
