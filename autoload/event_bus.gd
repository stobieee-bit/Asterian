## EventBus — Global signal hub (autoloaded singleton)
##
## Replaces the JS EventBus pub/sub pattern. Any node can emit or connect
## to these signals without needing direct references to other nodes.
##
## Usage:
##   EventBus.player_died.emit()
##   EventBus.enemy_killed.connect(_on_enemy_killed)
extends Node

# ── Player signals ──
signal player_died
signal player_respawned
signal player_healed(amount: int)
signal player_damaged(amount: int, source: String)
signal player_level_up(skill: String, new_level: int)
signal player_xp_gained(skill: String, amount: int)
signal player_credits_changed(new_total: int)
signal player_moved_to_area(area_id: String)

# ── Combat signals ──
signal combat_started(enemy_id: String)
signal combat_ended
signal enemy_killed(enemy_id: String, enemy_type: String)
signal enemy_spawned(enemy_node: Node)
signal hit_landed(target: Node, damage: int, is_crit: bool)
signal hit_missed(target: Node)
signal player_attacked
signal combat_style_changed(new_style: String)

# ── Equipment & Inventory signals ──
signal item_added(item_id: String, quantity: int)
signal item_removed(item_id: String, quantity: int)
signal item_equipped(slot: String, item_id: String)
signal item_unequipped(slot: String, item_id: String)
signal inventory_full
signal item_dropped_to_ground(item_id: String, quantity: int, position: Vector3)

# ── Skill signals ──
signal gathering_started(skill: String, node_id: String)
signal gathering_complete(skill: String, item_id: String)
signal crafting_started(recipe_id: String)
signal crafting_complete(recipe_id: String)

# ── Quest signals ──
signal quest_accepted(quest_id: String)
signal quest_progress(quest_id: String, step: int)
signal quest_completed(quest_id: String)
signal quest_reward_claimed(quest_id: String)

# ── UI signals ──
signal panel_opened(panel_name: String)
signal panel_closed(panel_name: String)
signal tooltip_requested(data: Dictionary, global_pos: Vector2)
signal tooltip_hidden
signal context_menu_requested(options: Array, global_pos: Vector2)
signal context_menu_hidden
signal float_text_requested(text: String, position: Vector3, color: Color)
signal chat_message(text: String, channel: String)

# ── World signals ──
signal area_entered(area_id: String)
signal area_exited(area_id: String)
signal portal_activated(from_area: String, to_area: String)

# ── System signals ──
signal game_saved
signal game_loaded
signal settings_changed(key: String, value: Variant)

# ── Achievement signals ──
signal achievement_unlocked(achievement_id: String)

# ── Prestige signals ──
signal prestige_triggered(new_tier: int)

# ── Dungeon signals ──
signal dungeon_started(floor_data: Dictionary)
signal dungeon_floor_advanced(floor_data: Dictionary)
signal dungeon_room_cleared(grid_x: int, grid_z: int)
signal dungeon_exited

# ── Pet signals ──
signal pet_summoned(pet_id: String)
signal pet_dismissed
signal pet_level_up(pet_id: String, new_level: int)

# ── Multiplayer signals ──
signal multiplayer_connected(player_count: int)
signal multiplayer_disconnected
signal multiplayer_player_joined(player_name: String)
signal multiplayer_player_left(player_name: String)
