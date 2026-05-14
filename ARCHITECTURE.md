# Zero-Sum Allocation Shooter - Architecture Whitepaper & Agent Context

## I. Core Concept
This project is a top-down shooter game based on a "zero-sum resource allocation" mechanism (similar to "Brotato").
There is a fixed pool of "Source Points (SP)" (e.g., 100 points) globally. When the player upgrades or adjusts stats, they must trade off and reallocate these points among different attributes (such as attack, health, movement speed, and even enemy debuffs). All stat changes are strictly bound by this zero-sum pool.

## II. Project Structure & Node Mapping

**Directory Conventions**:
- `script/`: Stores all core GDScript logic code.
- `prefab/`: Stores all scene prefabs (e.g., `.tscn` files).
- `mat/`: Stores materials and assets.

**Core Entity Mapping**:
- **GameManager (Autoload/Singleton)**
  - Script: `script/GameManager.gd`
  - Responsibilities: Stores global state (the allocation dictionary `stats`, max points `MAX_TOTAL_POINTS = 100`), handles allocation logic, and broadcasts state change signals. Controls the entire game lifecycle and scene transition logic (using `call_deferred` to ensure physics safety), such as `start_new_game`, `next_level`, `retry_current_level`, etc.
- **LevelBase & LevelController**
  - Scene: `scene/LevelBase.tscn` | Script: `script/LevelController.gd`
  - Contains: `SpawnTimer (Timer)`, `SpawnPoints (Node2D + Marker2D)`, and basic encapsulation for map obstacles, player, and UI.
  - Responsibilities: All specific levels inherit from `LevelBase`. `LevelController` is responsible for controlling enemy waves and spawning, listening to and tracking the `died` signals of all spawned enemies. Once the kill target is reached, it automatically stops spawning and notifies `GameManager` to proceed to the next level.
- **Player (CharacterBody2D)**
  - Scene: `prefab/Player.tscn` | Script: `script/Player.gd`
  - Contains: `CollisionShape2D`, `Sprite2D`, `ShootTimer`, `Camera2D`, `Muzzle(Marker2D)`, `HealthBar(ProgressBar)`, `StaminaBar(ProgressBar)`
  - Responsibilities: Listens to singleton updates to adjust its own stats, dynamically syncs floating health and stamina progress bars. Handles input movement and dashing. Contains precise auto-aim logic (calculating the direction from `Muzzle` to living enemies) and implements an algorithm to fire multiple bullets in a cone spread. Upon death, it triggers the display of the `GameOverUI` located in the same scene.
- **EnemyBase (CharacterBody2D)**
  - Scene: `prefab/EnemyBase.tscn` | Script: `script/EnemyBase.gd`
  - Contains: `CollisionPolygon2D`, `Sprite2D`, `Hitbox(Area2D)`, `ProgressBar(ProgressBar)`
  - Responsibilities: Calculates debuffed runtime stats, tracks the player, deals damage upon collision, and reflects health deductions in real-time to the floating health bar. When health reaches zero, it emits a `died` signal for external tracking and destroys itself.
- **PlayerProjectile (Area2D)**
  - Scene: `prefab/PlayerProjectile.tscn` | Script: `script/PlayerProjectile.gd`
  - Contains: `Sprite2D`, `CollisionShape2D` (internally dynamically generates a lifecycle `Timer`)
  - Responsibilities: Travels in a straight line along a given direction, deals damage when hitting enemies, and destroys itself upon hitting enemies or environment walls; it also automatically destroys itself after a 3-second lifespan ends to prevent memory leaks.
- **GameOverUI (CanvasLayer)**
  - Scene: `prefab/GameOverUI.tscn` | Script: `script/GameOverUI.gd`
  - Contains: `RestartButton (Button)`, `BackButton (Button)`
  - Responsibilities: Listens for player death, triggers global time stop (`get_tree().paused = true`), and displays an interactive menu. The node mode MUST be set to `PROCESS_MODE_ALWAYS` to be exempt from the time stop. Includes instant restart logic mapped to the physical `KEY_R`. Upon restart, it calls `GameManager.retry_current_level()` to return to `Allocation UI` and reset points.
- **MainMenu (Control)**
  - Scene: `scene/MainMenu.tscn` | Script: `script/MainMenu.gd`
  - Contains: `StartButton`, `QuitButton`
  - Responsibilities: The title screen of the game, handles basic flow control, and calls `GameManager.start_new_game()` to enter the game.
- **AllocationUI (Control)**
  - Scene: `scene/AllocationUI.tscn` | Script: `script/AllocationUI.gd`
  - Contains: `LevelNameLabel`, `PointsLabel`, `SliderContainer (containing 7 HSliders named after stats keys)`
  - Responsibilities: The in-game terminal for zero-sum resource allocation. Features a built-in **UI rubber-banding mechanism** to prevent allocations from exceeding the cap. It also displays the name of the current stage (e.g., Stage1: Swarm, Stage2: Golem).

## III. Data Flow & Zero-Sum Allocation Dictionary
**GameManager is the Single Source of Truth.**
1. **State Updates**: Any modification to stats (adding points, removing points, debuffs) MUST directly call the methods provided by `GameManager`.
2. **State Reading**: All other entity nodes (Player, Enemy, Projectile) can only read the `GameManager.stats` dictionary to initialize their properties.
3. **Reactive Updates**: Entities must connect to the `GameManager.stats_updated` signal. When the player adjusts points in the UI, entities present on the field should automatically recalculate their runtime stats.

**Current `stats` Dictionary Mapping and Effects**:
- `hp`: Increases the player's max health (Formula: `100.0 + hp * 20.0`). The `Player` initializes with full health and deducts it via `take_damage` upon being hit.
- `atk`: Increases the player's base attack power (Formula: `10.0 + atk * 2.0`). This value is dynamically passed to the fired `PlayerProjectile`.
- `stamina`: Increases the player's max stamina (Formula: `2 + floori(stamina / 20.0)`).
  - **Dash Mechanic**: Pressing the `dash` key consumes 1 stamina point to gain `2.5x` movement speed for `0.15` seconds.
  - **Stamina Regeneration**: Automatically regenerates `1` point of stamina every `1.5` seconds until full.
- `projectiles`: Increases the number of multiple projectiles. **Every 20 points add 1 extra bullet**. `Player.gd` automatically enables a **cone spread algorithm** to fire multiple bullets evenly.
- `enemy_slow`: Enemy slowdown debuff. Multiplier formula: `1.0 - mini(0.8, slow / 100.0)`, with a **hard cap of 80%** to prevent monsters from moving backward.
- `enemy_atk_debuff`: Enemy attack reduction debuff. Multiplier formula: `1.0 - mini(0.8, atk_debuff / 100.0)`, with a **hard cap of 80%** to prevent negative attack power from healing the player.
- `enemy_def_debuff`: Enemy defense reduction (armor penetration).
  - **Effective Armor Calculation**: `effective_def = maxf(0.0, base_def - def_debuff * 2.0)`, with a **hard floor of 0** to prevent negative armor from causing denominator crashes or damage multiplication.
  - **Damage Taken Model**: Uses the classic effective health formula `100.0 / (100.0 + effective_def)`. The higher the defense, the more diminishing the returns on extra damage reduction, but effective health scales linearly.

## IV. Physics & Collision Matrix

| Entity | Layer | Mask (What it collides with) | Description |
| :--- | :--- | :--- | :--- |
| **Player** (CharacterBody2D) | **1** (Player) | **3** (Env) | Player is on Layer 1. Detects environment to prevent walking through walls. **Do NOT check 2**, allowing the player to pass directly through enemies without physical blocking. |
| **Enemy** (CharacterBody2D) | **2** (Enemy) | **2** (Enemy), **3** (Env) | Enemies are on Layer 2. They push against each other and are blocked by walls. **Do NOT check 1**, so they don't physically block/push the player. |
| **Enemy Hitbox** (Area2D) | *(None/Default)* | **1** (Player) | Independent of physics collision! This is exclusively used to detect when the player enters to deal damage. |
| **PlayerProjectile** (Area2D)| **4** (PlayerBullet)| **2** (Enemy), **3** (Env) | Player bullet layer. **Absolutely do NOT** check Mask 1, otherwise it will hit the player immediately upon firing. |

*(Note: It is recommended to name Layers 1-4 as `Player`, `Enemy`, `Environment`, and `PlayerBullet` in Godot's Project Settings -> Layer Names -> 2D Physics for standardized development)*

## V. Communication Protocol
- **Damage Transfer**:
  - The initiator (e.g., bullet, Hitbox) **must** check if the target has a specific method after detecting it: `if body.has_method("take_damage"):`
  - The receiver (Player, Enemy) **must** implement the method: `func take_damage(amount: float) -> void:`
- **Stat Synchronization**:
  - Signals must be used: `GameManager.stats_updated.connect(_sync_stats)`
  - Absolutely do NOT poll `GameManager` attributes inside `_process`.
- **Acquiring Target References**:
  - Utilize Godot's Node Group system, such as `get_tree().get_nodes_in_group("player")` to get a player reference. Passing hard references or absolute paths is strictly forbidden.

## VI. AI Coding Standards (Vibe Coding Rules)
In all subsequent development and code generation, the following principles MUST be strictly followed:
1. **GDScript 2.0 Standards**: Use strict type hints everywhere (e.g., `var hp: int`, `-> void`).
2. **No Hardcoded Paths**: Absolutely do not use fragile tree-based dependencies like `get_node("../../Node")`.
3. **Dependency Decoupling**:
   - External Parameters: Expose them to the editor via `@export`.
   - Internal Child Nodes: Must be defined at the top of the file as `@onready var child: Node = $Child` along with complete `[Agent Context]` comments.
   - Global Cross-Node Interaction: Prioritize acquiring object references via Groups, or use global signals (Signal Bus / GameManager) for cross-system interactions.
4. **Defensive Programming**: Before accessing array elements (like getting the first player), verify that the array is not empty (`is_empty()` or `size() > 0`).

## VII. Level Flow & Numerical Design Intent

### 1. Typical Flow
- **Progression**: Start -> Allocate resources for Level 1 -> Level 1 Combat -> Allocate resources for Level 2 -> Level 2 Combat ... and so on.
- **Win/Loss Conditions**:
  - **Clear**: After killing the set number of enemies in a level (determined by `LevelController`'s `total_enemies_to_kill`), it will automatically call `GameManager.next_level()` to enter the next level (briefly transitioning to AllocationUI for reallocation).
  - **Failure/Retry**: Upon failure, press the Retry button or physical shortcut `R` directly. The game will call `GameManager.retry_current_level()` to reset the current allocation and restart from the resource allocation phase of the current level.
- **Total Levels**: The project is currently preset with 6 levels.

### 2. Numerical Design Intent
The overall game difficulty is moderately high, but all levels have been verified to be clearable through testing. The core gameplay requires players to employ "extreme point allocation" based on enemy characteristics:
- **Level 1 (Swarm)**: High quantity, fast speed, decent damage. Requires the player to invest in **projectile count** (increasing bullets per shot) for AoE clearing.
- **Level 2 (Golem)**: High health and defense, slow movement. Requires the player to invest in **extremely high attack power** to break through their armor.
- **Level 3 (Hound)**: Extremely fast movement, high attack. Requires the player to invest heavily in the **enemy slow debuff** to reduce their speed, moderately increase attack, and invest in the player's **dash count (Stamina)**.
- **Level 4 (Leech)**: Low attack, massive quantity, extremely fast speed. Requires the player to invest in **high health** and moderately increase projectile count, tanking damage inside the swarm until the end.
- **Level 5 (Warden)**: Balanced enemy stats. Requires moderately slowing the enemy down, increasing attack, and reducing enemy defense.

## VIII. Expansion Guide: How to Add New Levels and Enemies

### 1. Adding a New Enemy
- **Inherit Base Class**: Create a new scene and inherit from `prefab/EnemyBase.tscn` (or the corresponding base enemy scene).
- **Configure Properties**: In the Inspector panel, you can directly adjust the initial values for this subclass enemy (such as base health, speed, attack, defense, etc.) and replace its visual assets.

### 2. Adding a New Level and Transition Logic
- **Inherit Base Class**: Create a new scene and inherit from `scene/LevelBase.tscn`.
- **Configure Waves**: Select the `LevelController` child node in the scene and configure the following in the Inspector:
  - Drag the newly created enemy scene into the `Enemy Scene` property.
  - Modify `Total Enemies To Kill` (enemies needed to clear the level).
  - Modify `Spawn Interval`.
  - Modify `Max Enemies On Screen`.
- **Register Level Transition**:
  - Open `script/GameManager.gd`.
  - Find the `@export var level_scenes: Array[String]` array.
  - Append the scene path of the new level (e.g., `"res://scene/level6_final.tscn"`) to the end of this array.
  - **Underlying Mechanism**: The `LevelController` internally encapsulates the logic to listen for the `died` signal of each spawned monster. When the total kill count reaches the target, it automatically stops spawning and calls `GameManager.next_level()`. `GameManager` then increments its `current_level_index` and automatically loads the next scene or transition UI based on the contents of `level_scenes`. There is no need to manually add hardcoded transition code inside `LevelController`.
