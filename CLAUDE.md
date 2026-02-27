# Asterian — RuneScape-inspired Sci-Fi RPG

Godot 4.4 project, GDScript only. Main scene: `scenes/main/main.tscn`.

## Architecture

**Signal-driven** — all systems communicate via `EventBus` (115+ signals), not direct references.
**Data-driven** — enemy stats, items, areas, quests, etc. defined in `data/*.json` (16 files).

### Autoloads (load order matters)

| Singleton      | Purpose                                      |
|----------------|----------------------------------------------|
| `EventBus`     | Pub/sub signal hub — no state, only signals  |
| `GameState`    | Single source of truth for all runtime state |
| `DataManager`  | Loads JSON from `data/` at startup, getter functions (`get_enemy()`, `get_item()`, etc.) |
| `SaveManager`  | Persistence — serializes GameState to JSON   |
| `AudioManager` | Runtime-synthesized SFX and ambient audio    |

### Core patterns

- **Controller / Builder / Spawner** — Controllers handle logic + state, Builders generate meshes from primitives, Spawners manage instantiation and pooling.
- Emit signals: `EventBus.signal_name.emit(args)` — connect in `_ready()`.
- Game data: read/write through `GameState` dictionaries (`player`, `skills`, `equipment`, `inventory`, etc.).
- Data lookups: `DataManager.get_enemy(id)`, `DataManager.get_item(id)`, etc.
- Enemy meshes: subclass `EnemyMeshBuilder` (RefCounted), override `build_mesh(params) -> Node3D`, compose from static helpers (`add_sphere`, `add_capsule`, `add_box`, `add_cylinder`, `add_torus`, `add_cone`).
- Player meshes: `PlayerMeshBuilder` static methods, 3 style themes (nano/tesla/void).
- UI panels: extend `PanelContainer`, wire up EventBus signals in `_ready()`.
- Flat world — all ground at Y=0, no terrain plugin.

## Directory layout

```
autoload/          5 singletons (EventBus, GameState, DataManager, SaveManager, AudioManager)
data/              16 JSON data files (items, enemies, areas, quests, recipes, etc.)
scenes/
  entities/        Player and enemy .tscn scenes
  main/            Main scene + root script
  areas/           Pre-baked area scenes
  enemies/         Pre-baked enemy scenes
scripts/
  enemies/         enemy_controller.gd, enemy_spawner.gd, enemy_mesh_builder.gd,
                   boss_ai.gd, elite_affixes.gd, enemy_telegraph.gd,
                   templates/ — 18 mesh template classes (e.g. arachnid_mesh.gd)
  player/          player_controller.gd (click-to-move CharacterBody3D),
                   combat_controller.gd (targeting, abilities, adrenaline),
                   player_mesh_builder.gd, camera_rig.gd, interaction_controller.gd
  systems/         12 game systems — quest, crafting, achievement, equipment,
                   loot, combo, dungeon, slayer, prestige, pet, multiplayer
  world/           area_manager.gd (procedural sci-fi world gen), gathering nodes,
                   NPCs, weather, dungeon rendering
  ui/              22 UI panels (inventory, equipment, skills, shop, crafting, etc.)
  tools/           Scene baking scripts (bake_area_scenes.gd, bake_enemy_scenes.gd, etc.)
```

## GDScript conventions

- **Indentation**: 4 spaces (not tabs)
- **Naming**: `snake_case` vars/funcs, `PascalCase` classes, `SCREAMING_SNAKE_CASE` constants, `_underscore` prefix for private members
- **Type annotations**: always explicit — `var x: float = 0.0`, `func foo() -> void:`
- **Section headers**: `# ── Section Name ──` decorative dividers to organize code blocks
- **Docstrings**: `##` comment at file top describing the script's purpose
- **File organization order**:
  1. `extends` + `class_name`
  2. Enums and constants
  3. `@export` variables
  4. `@onready` variables
  5. Private member variables
  6. `_ready()`
  7. `_process()` / `_physics_process()`
  8. `_input()` / `_unhandled_input()`
  9. Public functions
  10. Private helper functions

## Combat system

Three combat styles with distinct ranges and themes:
- **Nano** (cyan) — fast close-range, 2.0 range
- **Tesla** (gold) — medium arc swings, 2.8 range
- **Void** (purple) — long-range channeled, 4.5 range

Enemy state machine: `IDLE → AGGRO → CHASE → ATTACKING → RETURNING → DEAD`

Adrenaline (RS3-style energy) builds from attacks, powers special abilities.

## Running the project

- Open in Godot 4.4 editor, press F5
- No test framework configured
- Bake scripts in `scripts/tools/` for pre-generating area/enemy scenes
