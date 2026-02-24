# CLAUDE.md — Asterian

## Project Overview

Asterian is a sci-fi RPG inspired by RuneScape, built in **Godot 4.4** using **GDScript**. It targets **web (HTML5/WebAssembly)** via Godot's web export and is deployed to GitHub Pages. The game features click-to-move 3D gameplay with procedural meshes, skill progression, quests, dungeons, crafting, and combat with an ability/adrenaline system.

## Repository Structure

```
Asterian/
├── autoload/              # Godot autoload singletons (global state)
│   ├── event_bus.gd       # Signal hub (115+ signals for pub/sub)
│   ├── game_state.gd      # Central mutable game state
│   ├── data_manager.gd    # Loads and caches JSON game data
│   ├── save_manager.gd    # Save/load (IndexedDB on web via user://)
│   └── audio_manager.gd   # Sound effect playback
├── data/                  # JSON game balance/content data (16 files)
│   ├── items.json         # 170+ items with stats, tiers, requirements
│   ├── enemies.json       # 100+ enemy definitions
│   ├── recipes.json       # 200+ crafting recipes
│   ├── areas.json         # World areas, corridors, spawning zones
│   ├── skills.json        # Skill definitions, XP table, unlocks
│   ├── abilities.json     # Combat abilities and special attacks
│   ├── quests.json        # Quest chains and board quests
│   ├── equipment.json     # Armor sets, weapons, stats
│   ├── dungeons.json      # Dungeon themes, modifiers, traps
│   ├── npcs.json          # NPC definitions and dialogue
│   ├── pets.json          # Pet companions
│   ├── prestige.json      # Prestige shop items
│   ├── achievements.json  # Achievement definitions
│   ├── combos.json        # Combat combo definitions
│   ├── enemy_defs.json    # Enemy variant definitions
│   └── enemy_loot_tables.json
├── scenes/                # Godot scene files (.tscn)
│   ├── main/              # main.tscn + main.gd (entry point)
│   ├── world/             # game_world.tscn, ground_item.tscn
│   ├── entities/          # player.tscn, enemy.tscn
│   └── ui/                # hud.tscn + hud.gd
├── scripts/               # GDScript source (~75 files)
│   ├── player/            # Player controller, combat, camera, mesh
│   ├── enemies/           # Enemy AI, spawner, elite affixes, telegraphs
│   │   └── templates/     # 18 procedural enemy mesh builders
│   ├── systems/           # Core game systems (see below)
│   ├── ui/                # UI panels (inventory, skills, quests, etc.)
│   └── world/             # Area manager, NPCs, gathering, dungeons
├── addons/                # Godot plugins
│   └── terrain_3d/        # Terrain3D GDExtension plugin
├── tools/                 # Development tools
│   └── extract_data.js    # Data extraction/migration tool
├── .github/workflows/     # CI/CD
│   └── deploy-web.yml     # Build and deploy to GitHub Pages
├── project.godot          # Godot project configuration
└── export_presets.cfg     # Web export settings
```

## Architecture

### Singleton Pattern (Autoloads)

Five autoloaded singletons are initialized in this order (defined in `project.godot`):

1. **EventBus** — Global signal hub for decoupled communication. All game events go through here. Nodes emit/connect without direct references.
2. **GameState** — Central mutable state: player stats, skills, inventory, equipment, quests, buffs, settings, panel layout.
3. **DataManager** — Read-only access to all JSON game data. Loads and caches everything at startup.
4. **SaveManager** — Persistence layer. Auto-saves every 30s. Uses `user://` (IndexedDB on web). Includes backup/recovery for corruption.
5. **AudioManager** — Sound effect playback.

### Startup Flow (`scenes/main/main.gd`)

1. Load save file (or start new game)
2. Instantiate GameWorld scene (3D terrain)
3. Spawn Player at saved position (or Station Hub default)
4. Attach systems as child nodes: EquipmentSystem, InteractionController, FloatTextSystem, LootSystem, CraftingSystem, QuestSystem, SlayerSystem, AchievementSystem, PrestigeSystem, DungeonSystem, PetSystem, DungeonRenderer, NPCSpawner, GatheringSpawner, StationSpawner, MultiplayerClient, ComboSystem
5. Spawn HUD canvas layer
6. Register web save hooks (beforeunload, visibilitychange)
7. Apply DPI scaling for high-DPI displays
8. Give starter gear on new game

### Event-Driven Communication

The codebase uses Godot signals exclusively for cross-system communication via `EventBus`. Key signal categories:

- **Player**: `player_died`, `player_healed`, `player_level_up`, `player_xp_gained`, `player_moved_to_area`
- **Combat**: `combat_started`, `combat_ended`, `enemy_killed`, `hit_landed`, `hit_missed`, `ability_used`
- **Inventory/Equipment**: `item_added`, `item_removed`, `item_equipped`, `item_unequipped`, `inventory_full`
- **Skills**: `gathering_started`, `gathering_complete`, `crafting_started`, `crafting_complete`
- **Quests**: `quest_accepted`, `quest_progress`, `quest_completed`, `quest_abandoned`
- **UI**: `panel_opened`, `panel_closed`, `tooltip_requested`, `context_menu_requested`, `float_text_requested`
- **World/Dungeon**: `area_entered`, `dungeon_started`, `dungeon_floor_advanced`, `dungeon_exited`
- **System**: `game_saved`, `game_loaded`, `settings_changed`, `achievement_unlocked`, `prestige_triggered`

### Data-Driven Design

All game balance and content is defined in JSON files under `data/`. The `DataManager` singleton loads these at startup. When modifying game content (items, enemies, recipes, areas), edit the JSON files — not the GDScript code.

## Core Game Systems

| System | Script | Purpose |
|--------|--------|---------|
| Combat | `scripts/player/combat_controller.gd` | Targeting, auto-attack, abilities, adrenaline, GCD (1.8s) |
| Equipment | `scripts/systems/equipment_system.gd` | Equipping, set bonuses, degradation (tier 5+), stat calc |
| Loot | `scripts/systems/loot_system.gd` | Enemy loot rolls, ground items, pickup |
| Crafting | `scripts/systems/crafting_system.gd` | Recipe lookup, ingredient checking, skill training |
| Quests | `scripts/systems/quest_system.gd` | Quest lifecycle, progression, rewards |
| Dungeons | `scripts/systems/dungeon_system.gd` | Procedural dungeon generation, floor scaling |
| Slayer | `scripts/systems/slayer_system.gd` | Slayer tasks and reputation |
| Achievements | `scripts/systems/achievement_system.gd` | Achievement tracking and unlocks |
| Prestige | `scripts/systems/prestige_system.gd` | Prestige/reset mechanic |
| Pets | `scripts/systems/pet_system.gd` | Pet summoning, leveling, buffs |
| Combos | `scripts/systems/combo_system.gd` | Combo streak tracking |
| Multiplayer | `scripts/systems/multiplayer_client.gd` | WebSocket client (partial implementation) |

### Combat System Details

- **Three combat styles**: Nano (close range), Tesla (medium range), Void (long range)
- **Combat triangle**: Rock-paper-scissors weakness/resistance mechanics
- **Attack range**: 2.0–4.5 units depending on style
- **Attack speed**: 2.0s (Nano) to 3.2s (Void)
- **Adrenaline system**: Builds with attacks, spent on abilities
- **GCD**: 1.8s global cooldown on abilities
- **Equipment degradation**: Tier 5+ items lose condition (0.1% per attack, 0.2% per hit taken)

### Enemy System

- Enemy AI uses a state machine: IDLE → AGGRO → CHASE → ATTACKING
- 18 procedural mesh templates in `scripts/enemies/templates/` (arachnid, mantis, jellyfish, worm, crystal_golem, etc.)
- Elite affix system: vampiric, shielded, explosive, regenerating modifiers
- Telegraph system for heavy attacks
- Boss-specific AI via `boss_ai.gd`

### World Generation

- `scripts/world/area_manager.gd` generates 3D sci-fi environments from JSON area data using CSG geometry
- Terrain3D plugin for painted terrain surfaces
- NPCs, gathering nodes, and processing stations are spawned at predefined positions

### UI System

- All panels are draggable and resizable, built programmatically from `PanelContainer`
- Panel layout is persisted in save data
- 21 UI scripts in `scripts/ui/` covering: inventory, equipment, bank, skills, quests, bestiary, crafting, shop, dialogue, dungeon, pets, prestige, achievements, settings, tutorial, world map, combat log, DPS meter, tooltips, context menu
- Context menus for right-click interactions on items, NPCs, ground items

## Development Workflow

### Running Locally

Open `project.godot` in the Godot 4.4 editor and press F5 (or Play). The main scene is `scenes/main/main.tscn`.

### Building for Web

The CI/CD pipeline handles web builds automatically. For manual builds:

1. Set up Godot 4.4.1 export templates (including `web_dlink_nothreads_*` variants for Terrain3D)
2. Export with the "Web" preset defined in `export_presets.cfg`
3. Post-process: patch COEP headers from `require-corp` to `credentialless` in the service worker

### CI/CD (GitHub Actions)

Defined in `.github/workflows/deploy-web.yml`:

- **Trigger**: Push to `master` branch or manual dispatch
- **Container**: `barichello/godot-ci:4.4.1`
- **Steps**: Setup templates → Import project → Export to Web → Patch COEP headers → Add cache-buster → Deploy to GitHub Pages
- **Key details**:
  - Threads disabled (uses `web_nothreads_*` templates)
  - Extensions support enabled for Terrain3D (`web_dlink_nothreads_*` templates)
  - COEP set to `credentialless` for cross-origin WebSocket support
  - Cache-buster script injected to force fresh asset loading on deploy

### Input Mappings

Defined in `project.godot`:

| Action | Binding |
|--------|---------|
| `move_click` | Left mouse button |
| `camera_rotate` | Middle mouse button |
| `right_click` | Right mouse button |
| `toggle_inventory` | I |
| `toggle_equipment` | E |
| `toggle_skills` | K |
| `toggle_quests` | Q |
| `toggle_bestiary` | L |

## Coding Conventions

### GDScript Style

- **Godot 4 GDScript** with static typing: use `var x: Type` and `func foo() -> ReturnType`
- Doc comments use `##` (double hash) at the top of files and above functions
- Constants use `UPPER_SNAKE_CASE`
- Private members and methods use `_leading_underscore`
- Signals use `snake_case` matching the pattern `noun_verb_past` (e.g., `enemy_killed`, `quest_completed`)
- Preloaded resources use `preload()` for scenes and scripts; `load()` only when needed at runtime

### System Instantiation Pattern

Systems are created as plain Nodes with scripts attached at runtime (not scene instances):

```gdscript
var sys: Node = Node.new()
sys.name = "SystemName"
sys.set_script(system_script)
add_child(sys)
```

### Communication Pattern

Never reference other systems directly. Always use EventBus signals:

```gdscript
# Emitting
EventBus.enemy_killed.emit(enemy_id, enemy_type)

# Listening
EventBus.enemy_killed.connect(_on_enemy_killed)
```

### Data Access Pattern

Always go through DataManager for game data:

```gdscript
var item: Dictionary = DataManager.get_item("scrap_nanoblade")
var enemy: Dictionary = DataManager.get_enemy("chithari_larva")
```

### State Mutation Pattern

Mutate state through GameState methods, not direct dictionary access where methods exist:

```gdscript
GameState.add_item("item_id", quantity)
GameState.add_credits(100)
```

## Save Data Structure

The save file (stored at `user://` / IndexedDB on web) contains:

- `current_area` — Active area ID
- `player` — HP, energy, adrenaline, credits, combat_style, position
- `skills` — Per-skill level and XP
- `equipment` — Equipped item per slot
- `equipment_condition` — Durability per slot (0.0–1.0)
- `inventory` — Array of `{item_id, quantity}`, max 28 slots
- `bank` — Array of `{item_id, quantity}`, max 48 slots
- `active_quests` / `completed_quests` — Quest tracking
- `prestige_tier`, `prestige_points`, `prestige_purchases`
- `slayer_task`, `slayer_points`, `slayer_streak`
- `unlocked_achievements`, `collection_log`, `boss_kills`
- `dungeon_active`, `dungeon_floor`, `dungeon_max_floor`
- `active_pet`, `owned_pets` — Pet data
- `active_buffs` — Temporary stat modifiers
- `settings` — Audio volumes, display preferences
- `panel_layout` — Per-panel position, visibility, lock state
- `tutorial` — Tutorial progress
- `total_play_time`

## Key Files to Know

| File | Purpose |
|------|---------|
| `project.godot` | Engine config, autoloads, input mappings, rendering settings |
| `scenes/main/main.gd` | Entry point — orchestrates all initialization |
| `autoload/event_bus.gd` | All signals — read this to understand available events |
| `autoload/game_state.gd` | All mutable state — read this to understand game state shape |
| `autoload/data_manager.gd` | Data loading — read this to understand data access patterns |
| `autoload/save_manager.gd` | Persistence — save/load logic and format |
| `scripts/player/combat_controller.gd` | Combat mechanics and ability system |
| `scripts/enemies/enemy_controller.gd` | Enemy AI state machine |
| `scripts/world/area_manager.gd` | World generation from JSON data |
| `export_presets.cfg` | Web export configuration |
| `.github/workflows/deploy-web.yml` | CI/CD pipeline |

## Common Tasks

### Adding a new item

1. Add the item definition to `data/items.json`
2. If it's equipment, also add to `data/equipment.json`
3. If it's craftable, add a recipe to `data/recipes.json`
4. If it drops from enemies, add to `data/enemy_loot_tables.json`

### Adding a new enemy

1. Add the enemy definition to `data/enemies.json`
2. Add a mesh template in `scripts/enemies/templates/` if it needs a unique look
3. Add spawn data to the relevant area in `data/areas.json`
4. Add loot entries to `data/enemy_loot_tables.json`

### Adding a new quest

1. Add the quest definition to `data/quests.json`
2. Quest system (`scripts/systems/quest_system.gd`) handles lifecycle automatically based on the JSON structure

### Adding a new UI panel

1. Create a new script in `scripts/ui/` extending the existing panel pattern
2. Register hotkey in `project.godot` input map if needed
3. Add panel toggle signal handling in the HUD (`scenes/ui/hud.gd`)

### Adding a new game system

1. Create the system script in `scripts/systems/`
2. Add signals to `autoload/event_bus.gd` as needed
3. Preload and instantiate in `scenes/main/main.gd` following the existing pattern
4. Add any persistent state fields to `autoload/game_state.gd` and `autoload/save_manager.gd`

## Testing

There is no automated testing framework. The project relies on manual play testing via the Godot editor. When making changes:

- Run the project in the editor (F5) and verify behavior
- Check the Godot output console for errors and debug prints
- Test save/load by restarting the game
- For web-specific features, test in a browser using Godot's web export

## Important Notes

- **No formal test suite** — validate changes through manual playtesting
- **Web target** — all code must be compatible with Godot's web export (no threads, IndexedDB for saves, JavaScriptBridge for browser interop)
- **Terrain3D plugin** — requires `web_dlink_*` export templates for GDExtension support on web
- **Weather system is disabled** — commented out in `main.gd` due to visual issues with square particles
- **Multiplayer is partial** — WebSocket client exists but full multiplayer is not yet implemented
- **Rendering**: GL Compatibility mode with MSAA 3D x4, canvas texture filtering disabled (pixel art style)
