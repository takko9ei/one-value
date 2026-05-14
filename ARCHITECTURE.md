# 零和分配射击游戏 - 架构白皮书与 Agent 上下文

## 一、 核心概念 (Core Concept)
本作是一款基于“零和资源分配”机制的俯视角射击游戏（类《土豆兄弟》）。
全局拥有固定的“源力点（SP）”（如100点），玩家在升级或调整时，必须在不同的属性（如攻击、生命、移速，甚至是敌人的削弱属性）之间进行权衡和再分配。所有的数值变化均受限于这个零和池。

## 二、 项目结构与节点映射 (Project Structure & Node Mapping)

**目录规范**：
- `script/`：存放所有的核心 GDScript 逻辑代码。
- `prefab/`：存放所有的场景预制体（如 `.tscn` 文件）。
- `mat/`：存放材质与资源。

**核心实体映射**：
- **GameManager (Autoload/单例)**
  - 脚本: `script/GameManager.gd`
  - 职责: 存储全局状态（源力点分配字典 `stats`，最大点数 `MAX_TOTAL_POINTS = 100`），处理分配逻辑，广播状态变更信号。控制整个游戏的生命周期与场景跳转逻辑（使用 `call_deferred` 确保物理层安全），如 `start_new_game`, `next_level`, `retry_current_level` 等。
- **LevelBase & LevelController (关卡基类与控制器)**
  - 场景: `scene/LevelBase.tscn` | 脚本: `script/LevelController.gd`
  - 包含: `SpawnTimer (Timer)`, `SpawnPoints (Node2D + Marker2D)` 以及对地图障碍物、玩家、UI 的基础封装。
  - 职责: 所有的具体关卡都派生自 `LevelBase`。`LevelController` 负责控制敌人的波次与生成，监听并统计所有生成的敌人的 `died` 信号。达到击杀目标后，自动停止刷怪并通知 `GameManager` 进入下一关。
- **Player (CharacterBody2D)**
  - 场景: `prefab/Player.tscn` | 脚本: `script/Player.gd`
  - 包含: `CollisionShape2D`, `Sprite2D`, `ShootTimer`, `Camera2D`, `Muzzle(Marker2D)`, `HealthBar(ProgressBar)`, `StaminaBar(ProgressBar)`
  - 职责: 监听单例更新自身属性，动态同步悬浮生命值与耐力值进度条。处理输入移动、冲刺。包含精准的自动索敌逻辑（计算从 `Muzzle` 到活着的敌人的方向），并实现多发子弹的扇形发射算法。玩家死亡后会触发同一场景中的 `GameOverUI` 的显示。
- **EnemyBase (CharacterBody2D)**
  - 场景: `prefab/EnemyBase.tscn` | 脚本: `script/EnemyBase.gd`
  - 包含: `CollisionPolygon2D`, `Sprite2D`, `Hitbox(Area2D)`, `ProgressBar(ProgressBar)`
  - 职责: 计算被削减后的运行时属性，追踪玩家，在碰撞时造成伤害，并实时将扣血反馈至头顶悬浮血条。血量归零时发射 `died` 信号供外部统计，并自我销毁。
- **PlayerProjectile (Area2D)**
  - 场景: `prefab/PlayerProjectile.tscn` | 脚本: `script/PlayerProjectile.gd`
  - 包含: `Sprite2D`, `CollisionShape2D` (内部动态生成生命周期 `Timer`)
  - 职责: 沿给定方向直线运动，碰到敌人造成伤害，撞到敌人或环境墙壁后自我销毁；3 秒生存期结束后自动销毁防止内存泄漏。
- **GameOverUI (CanvasLayer)**
  - 场景: `prefab/GameOverUI.tscn` | 脚本: `script/GameOverUI.gd`
  - 包含: `RestartButton (Button)`, `BackButton (Button)`
  - 职责: 监听玩家死亡，控制全局时停 (`get_tree().paused = true`) 并显示交互菜单。节点模式必须设为 `PROCESS_MODE_ALWAYS` 以豁免时停。包含基于 `KEY_R` 的物理快捷键光速重开逻辑。重启后会调用 `GameManager.retry_current_level()` 退回 `Allocation UI` 重置加点。
- **MainMenu (Control)**
  - 场景: `scene/MainMenu.tscn` | 脚本: `script/MainMenu.gd`
  - 包含: `StartButton`, `QuitButton`
  - 职责: 游戏标题画面，处理基础流程控制，负责调用 `GameManager.start_new_game()` 进入游戏。
- **AllocationUI (Control)**
  - 场景: `scene/AllocationUI.tscn` | 脚本: `script/AllocationUI.gd`
  - 包含: `LevelNameLabel`, `PointsLabel`, `SliderContainer (内含 7 个与 stats 字典同名的 HSlider)`
  - 职责: 游戏内的零和资源分配终端。内置 **UI 橡皮筋拉回机制**以防止加点超出上限。同时承担着当前阶段命名的展示（Stage1: Swarm, Stage2: Golem 等）。

## 三、 数据流向与零和分配字典 (Data Flow & Stats Dictionary)
**GameManager 是唯一的真理来源 (Single Source of Truth)。**
1. **状态更新**：任何对数值的修改（加点、减点、Debuff）必须直接调用 `GameManager` 提供的方法。
2. **状态读取**：其他所有实体节点（Player, Enemy, Projectile）只能通过读取 `GameManager.stats` 字典来初始化属性。
3. **响应式更新**：实体必须连接 `GameManager.stats_updated` 信号。当玩家在 UI 中调整分配点数时，场上存在的实体应自动重新计算运行时属性。

**当前 `stats` 字典的规范映射及其影响**：
- `hp`: 提升玩家最大血量（计算公式：`100.0 + hp * 20.0`）。`Player` 初始化时满血，受击调用 `take_damage` 扣减。
- `atk`: 提升玩家基础攻击力（计算公式：`10.0 + atk * 2.0`）。此数值会动态赋予发射出的 `PlayerProjectile`。
- `stamina`: 提升玩家最大耐力（计算公式：`2 + floori(stamina / 20.0)`）。
  - **冲刺机制 (Dash)**：按下 `dash` 键消耗 1 点耐力，获得 `2.5` 倍移速持续 `0.15` 秒。
  - **耐力恢复**：每 `1.5` 秒自动恢复 `1` 点耐力直至上限。
- `projectiles`: 提升多重投射物数量。**每 20 点增加 1 发额外子弹**。`Player.gd` 会自动启用**扇形散布算法**，均匀发射多发子弹。
- `enemy_slow`: 敌人减速 Debuff。乘区公式 `1.0 - mini(0.8, slow / 100.0)`，**硬上限 80%** 防止怪物倒退。
- `enemy_atk_debuff`: 敌人攻击力削弱 Debuff。乘区公式 `1.0 - mini(0.8, atk_debuff / 100.0)`，**硬上限 80%** 防止攻击力变负数反向治疗玩家。
- `enemy_def_debuff`: 敌人防御力削减（破甲）。
  - **有效护甲计算**：`effective_def = maxf(0.0, base_def - def_debuff * 2.0)`，**硬下限 0** 防止负护甲导致分母崩溃或伤害倍增。
  - **承伤模型**：采用经典的有效生命值公式 `100.0 / (100.0 + effective_def)`。防御力越高，额外减伤收益递减，但有效血量呈线性增长。

## 四、 物理与碰撞矩阵 (Physics & Collision Matrix)

| 实体 | 所在层 (Layer) | 碰撞遮罩 (Mask) - 会撞到什么 | 说明 |
| :--- | :--- | :--- | :--- |
| **Player** (CharacterBody2D) | **1** (Player) | **3** (Env) | 玩家属于层1。检测环境防穿墙。**不勾选 2**，使其能直接穿过敌人而不被阻挡。 |
| **Enemy** (CharacterBody2D) | **2** (Enemy) | **2** (Enemy), **3** (Env) | 敌人属于层2。互相挤压、被墙壁阻挡。**不勾选 1**，使其不会物理阻挡/推动玩家。 |
| **Enemy Hitbox** (Area2D) | *(无/默认)* | **1** (Player) | 独立于物理碰撞！这是专门用来检测玩家进入以造成伤害的唯一途径。 |
| **PlayerProjectile** (Area2D)| **4** (PlayerBullet)| **2** (Enemy), **3** (Env) | 玩家子弹层。**绝对不能**勾选 Mask 1，否则会一发射就击中玩家自己。 |

*(注：建议在 Godot 的 Project Settings -> Layer Names -> 2D Physics 中将 1-4 层命名为 `Player`, `Enemy`, `Environment`, `PlayerBullet` 以规范化开发)*

## 五、 通信协议 (Communication Protocol)
- **伤害传递**：
  - 发起方（如子弹、Hitbox）检测到目标后，**必须**检查目标是否拥有特定方法：`if body.has_method("take_damage"):`
  - 接受方（玩家、敌人）**必须**实现 `func take_damage(amount: float) -> void:` 方法。
- **属性同步**：
  - 必须使用信号：`GameManager.stats_updated.connect(_sync_stats)`
  - 绝对不要在 `_process` 中轮询检查 GameManager 的属性。
- **获取目标引用**：
  - 利用 Godot 的 Node Group 系统，如 `get_tree().get_nodes_in_group("player")` 获取玩家引用，禁止传递硬引用或绝对路径。

## 六、 AI 编码规范 (Vibe Coding Rules)
在后续的所有开发和代码生成中，必须严格遵循以下原则：
1. **GDScript 2.0 规范**：全程使用严格类型提示（如 `var hp: int`, `-> void`）。
2. **禁止硬编码路径**：绝对禁止使用 `get_node("../../Node")` 这种脆弱的树状依赖。
3. **依赖解耦**：
   - 外部参数：通过 `@export` 暴露给编辑器调整。
   - 内部子节点：必须在文件顶部定义 `@onready var child: Node = $Child` 并附带完整的 `【Agent Context】` 注释。
   - 全局跨节点交互：优先通过 Group 获取对象引用，或通过全局信号（Signal Bus / GameManager）进行跨系统交互。
4. **防御性编程**：在访问数组元素（如获取第一个玩家）前，必须验证数组是否为空（`is_empty()` 或 `size() > 0`）。

## 七、 关卡流转与数值设计企图 (Level Flow & Design Intent)

### 1. 典型流程
- **流程流转**：开始 -> 分配第一关资源 -> 第一关战斗 -> 分配第二关资源 -> 第二关战斗 ...以此类推。
- **胜负判定**：
  - **通关**：每一关在击杀设定的敌人数量后（由 `LevelController` 的 `total_enemies_to_kill` 判定），会自动调用 `GameManager.next_level()` 进入下一关（中途会先跳转至 AllocationUI 进行再分配）。
  - **失败重开**：失败后可直接按 Retry 按钮或物理快捷键 `R`。游戏会调用 `GameManager.retry_current_level()` 重置当前加点，从当前关卡的资源分配起重开。
- **关卡总数**：当前项目预设 6 关。

### 2. 数值设计的企图
整体游戏难度偏高，但所有关卡均经过测试验证可通关。核心玩法要求玩家针对敌人特性进行“极限加点”：
- **第一关 (Swarm / 虫群)**：数量大、速度快、伤害不低。要求玩家点**弹丸数量**（增加每次射出的子弹数）进行群攻。
- **第二关 (Golem / 巨像)**：血厚防御高、移动速度慢。要求玩家点**极高的攻击力**来破防。
- **第三关 (Hound / 猎犬)**：移动速度极快、攻击高。要求玩家点**怪物速度 Debuff** 降低其速度，并适当增加攻击与玩家的**冲刺次数 (Stamina)**。
- **第四关 (Leech / 水蛭)**：低攻击、数量极其庞大、速度极快。要求玩家点**高血量**及适当增加弹丸数量，在怪堆里面抗伤至结束。
- **第五关 (Warden / 典狱长)**：怪物属性比较均衡。要求适当降低敌人速度、加高攻击，并适当削弱敌人的防御。

## 八、 扩展指南：如何添加新关卡与新敌人

### 1. 添加新敌人
- **继承基类**：新建场景并继承 `prefab/EnemyBase.tscn`（或对应的基础敌人场景）。
- **配置属性**：在 Inspector 面板中，可以直接调整该子类敌人的初始数值（如基础血量、移速、攻击、防御等），并替换其美术素材。

### 2. 添加新关卡与跳转逻辑
- **继承基类**：新建场景并继承 `scene/LevelBase.tscn`。
- **配置波次**：选中场景中的 `LevelController` 子节点，在 Inspector 中进行如下配置：
  - 将刚才制作的新敌人场景拖入 `Enemy Scene` 属性中。
  - 修改 `Total Enemies To Kill`（过关所需打败的敌人数量）。
  - 修改 `Spawn Interval`（刷怪间隔）。
  - 修改 `Max Enemies On Screen`（最大同屏数量）。
- **注册关卡跳转**：
  - 打开 `script/GameManager.gd`。
  - 找到 `@export var level_scenes: Array[String]` 数组。
  - 将新关卡的场景路径（例如 `"res://scene/level6_final.tscn"`）追加至该数组的末尾。
  - **底层原理**：`LevelController` 内部已封装好针对每个生成怪物 `died` 信号的监听逻辑。当总击杀数达标时，它会自动停止刷怪并调用 `GameManager.next_level()`。而 `GameManager` 会将自身的 `current_level_index` 自增，并根据 `level_scenes` 的内容自动加载下一关场景或过渡UI。无需手动去 `LevelController` 内部增添硬编码跳转代码。
